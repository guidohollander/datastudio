"use client";

import { useParams, useRouter } from "next/navigation";
import { useEffect, useState } from "react";

type Component = {
  componentKey: string;
  displayName: string;
  minOccurs: number;
  maxOccurs: number | null;
  fields: Field[];
  physicalTable?: string;
};

type Field = {
  fieldKey: string;
  type: string;
  required: boolean;
  maxLength: number;
  example?: string;
};

type ContractMapping = {
  componentKey: string;
  physicalTable?: string;
  fieldKey?: string;
  parentRelationship?: string | null;
};

type ContractData = {
  contractJson: string;
  mappings: ContractMapping[];
  error?: string;
};

export default function CustomizeContractPage() {
  const params = useParams();
  const router = useRouter();
  const runId = params.runId as string;
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [contract, setContract] = useState<Component[] | null>(null);
  const [excludedComponents, setExcludedComponents] = useState<Set<string>>(new Set());
  const [excludedFields, setExcludedFields] = useState<Set<string>>(new Set()); // format: "componentKey.fieldKey"
  const [fieldOrder, setFieldOrder] = useState<Record<string, string[]>>({}); // componentKey -> ordered fieldKeys
  const [customCardinality, setCustomCardinality] = useState<Record<string, { minOccurs: number; maxOccurs: number | null }>>({}); // componentKey -> cardinality
  const [customNesting, setCustomNesting] = useState<Record<string, string | null>>({}); // childKey -> parentKey (null = root level)
  const [componentOrder, setComponentOrder] = useState<string[]>([]); // ordered component keys
  const [hasUnsavedChanges, setHasUnsavedChanges] = useState(false);

  useEffect(() => {
    async function loadContract() {
      setLoading(true);
      setError(null);
      try {
        // Generate contract from captured data
        const genRes = await fetch("/api/contract/generate", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ 
            runId, 
            objectKey: "captured_data",
            displayName: "Captured Business Data"
          }),
        });

        if (!genRes.ok) {
          const genJson = (await genRes.json()) as { error?: string };
          throw new Error(genJson.error ?? "Failed to generate contract");
        }

        const generated = (await genRes.json()) as { objectKey: string };
        
        // Load the full contract (including framework tables for admin view)
        const res = await fetch(`/api/contract?runId=${runId}&objectKey=${generated.objectKey}&excludeFramework=false`);
        const data = (await res.json()) as ContractData;
        
        if (!res.ok) {
          throw new Error(data.error || "Failed to load contract");
        }

        const parsed = JSON.parse(data.contractJson);
        let contractArray = parsed?.components || [];
        
        // Convert maxOccurs -1 to null (unlimited)
        contractArray = contractArray.map((comp: Component) => ({
          ...comp,
          maxOccurs: comp.maxOccurs === -1 ? null : comp.maxOccurs
        }));
        
        // Add physical table info from mappings
        const mappings = data.mappings || [];
        contractArray.forEach((comp: Component) => {
          const mapping = mappings.find((m) => m.componentKey === comp.componentKey);
          comp.physicalTable = mapping?.physicalTable || comp.componentKey;
        });
        
        // Filter out framework tables completely - don't show them at all
        // Check both the physical table name and component key
        contractArray = contractArray.filter((c: Component) => {
          const tableName = (c.physicalTable || c.componentKey).toUpperCase();
          return !tableName.startsWith('CMF') && 
                 tableName !== 'CHANGES' && 
                 tableName !== 'MUTATION';
        });
        
        // Filter out relationship fields (caseid, userid, etc.) from each component
        const relationshipFieldPatterns = /^(caseid|userid|recordid|.*id)$/i;
        contractArray = contractArray.map((c: Component) => ({
          ...c,
          fields: c.fields.filter((f: Field) => {
            // Check if field is a relationship field based on mappings
            const mapping = mappings.find((m) => 
              m.componentKey === c.componentKey && m.fieldKey === f.fieldKey
            );
            const isRelationshipField = !!mapping?.parentRelationship;
            const matchesPattern = relationshipFieldPatterns.test(f.fieldKey);
            
            // Exclude if it's a relationship field or matches common ID patterns
            return !isRelationshipField && !matchesPattern;
          })
        }));
        
        setContract(contractArray);
        
        // Load saved exclusions from localStorage
        const savedExcludedComponents = localStorage.getItem(`contract-excluded-components-${runId}`);
        const savedExcludedFields = localStorage.getItem(`contract-excluded-fields-${runId}`);
        const savedFieldOrder = localStorage.getItem(`contract-field-order-${runId}`);
        const savedCardinality = localStorage.getItem(`contract-custom-cardinality-${runId}`);
        const savedNesting = localStorage.getItem(`contract-custom-nesting-${runId}`);
        const savedComponentOrder = localStorage.getItem(`contract-component-order-${runId}`);
        
        if (savedExcludedComponents) {
          setExcludedComponents(new Set(JSON.parse(savedExcludedComponents)));
        }
        
        if (savedExcludedFields) {
          setExcludedFields(new Set(JSON.parse(savedExcludedFields)));
        }
        
        if (savedFieldOrder) {
          setFieldOrder(JSON.parse(savedFieldOrder));
        }
        
        if (savedCardinality) {
          setCustomCardinality(JSON.parse(savedCardinality));
        }
        
        if (savedNesting) {
          setCustomNesting(JSON.parse(savedNesting));
        }
        
        if (savedComponentOrder) {
          setComponentOrder(JSON.parse(savedComponentOrder));
        } else {
          // Initialize with current order
          setComponentOrder(contractArray.map((c: Component) => c.componentKey));
        }
      } catch (e) {
        setError(e instanceof Error ? e.message : "Failed to load contract");
      } finally {
        setLoading(false);
      }
    }

    if (runId) {
      void loadContract();
    }
  }, [runId]);

  function toggleComponent(componentKey: string) {
    setExcludedComponents(prev => {
      const next = new Set(prev);
      if (next.has(componentKey)) {
        next.delete(componentKey);
      } else {
        next.add(componentKey);
      }
      return next;
    });
  }

  function toggleField(componentKey: string, fieldKey: string) {
    const key = `${componentKey}.${fieldKey}`;
    setExcludedFields(prev => {
      const next = new Set(prev);
      if (next.has(key)) {
        next.delete(key);
      } else {
        next.add(key);
      }
      return next;
    });
  }

  function moveFieldUp(componentKey: string, fieldKey: string) {
    setFieldOrder(prev => {
      const currentOrder = prev[componentKey] || contract?.find(c => c.componentKey === componentKey)?.fields.map(f => f.fieldKey) || [];
      const index = currentOrder.indexOf(fieldKey);
      if (index <= 0) return prev;
      
      const newOrder = [...currentOrder];
      [newOrder[index - 1], newOrder[index]] = [newOrder[index], newOrder[index - 1]];
      
      return { ...prev, [componentKey]: newOrder };
    });
  }

  function moveFieldDown(componentKey: string, fieldKey: string) {
    setFieldOrder(prev => {
      const currentOrder = prev[componentKey] || contract?.find(c => c.componentKey === componentKey)?.fields.map(f => f.fieldKey) || [];
      const index = currentOrder.indexOf(fieldKey);
      if (index < 0 || index >= currentOrder.length - 1) return prev;
      
      const newOrder = [...currentOrder];
      [newOrder[index], newOrder[index + 1]] = [newOrder[index + 1], newOrder[index]];
      
      return { ...prev, [componentKey]: newOrder };
    });
  }

  function updateCardinality(componentKey: string, minOccurs: number, maxOccurs: number | null) {
    setCustomCardinality(prev => ({
      ...prev,
      [componentKey]: { minOccurs, maxOccurs }
    }));
  }

  function saveCustomization() {
    setSaving(true);
    try {
      localStorage.setItem(`contract-excluded-components-${runId}`, JSON.stringify(Array.from(excludedComponents)));
      localStorage.setItem(`contract-excluded-fields-${runId}`, JSON.stringify(Array.from(excludedFields)));
      localStorage.setItem(`contract-field-order-${runId}`, JSON.stringify(fieldOrder));
      localStorage.setItem(`contract-custom-cardinality-${runId}`, JSON.stringify(customCardinality));
      localStorage.setItem(`contract-custom-nesting-${runId}`, JSON.stringify(customNesting));
      localStorage.setItem(`contract-component-order-${runId}`, JSON.stringify(componentOrder));
      setHasUnsavedChanges(false);
      
      // Ask user if they want to view the updated documentation
      const viewDoc = confirm("Customization saved successfully!\n\nWould you like to view the updated documentation now?");
      if (viewDoc) {
        router.push(`/contract/${runId}`);
      }
    } catch (e) {
      alert("Failed to save customization: " + (e instanceof Error ? e.message : "Unknown error"));
    } finally {
      setSaving(false);
    }
  }

  function moveComponentUp(componentKey: string) {
    setComponentOrder(prev => {
      const index = prev.indexOf(componentKey);
      if (index <= 0) return prev;
      
      const newOrder = [...prev];
      [newOrder[index - 1], newOrder[index]] = [newOrder[index], newOrder[index - 1]];
      return newOrder;
    });
  }

  function moveComponentDown(componentKey: string) {
    setComponentOrder(prev => {
      const index = prev.indexOf(componentKey);
      if (index < 0 || index >= prev.length - 1) return prev;
      
      const newOrder = [...prev];
      [newOrder[index], newOrder[index + 1]] = [newOrder[index + 1], newOrder[index]];
      return newOrder;
    });
  }

  function updateNesting(componentKey: string, parentKey: string | null) {
    setCustomNesting(prev => ({
      ...prev,
      [componentKey]: parentKey
    }));
  }

  function viewDocumentation() {
    router.push(`/contract/${runId}`);
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 p-8">
        <div className="max-w-6xl mx-auto">
          <div className="text-center py-12">
            <div className="text-lg text-gray-600">Loading contract...</div>
          </div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-gray-50 p-8">
        <div className="max-w-6xl mx-auto">
          <div className="bg-red-50 border border-red-200 rounded-lg p-6">
            <h2 className="text-lg font-semibold text-red-900 mb-2">Error Loading Contract</h2>
            <p className="text-red-700">{error}</p>
          </div>
        </div>
      </div>
    );
  }

  const includedComponents = contract?.filter(c => !excludedComponents.has(c.componentKey)) || [];
  const totalFields = contract?.reduce((sum, c) => sum + c.fields.length, 0) || 0;
  const includedFields = contract?.reduce((sum, c) => {
    if (excludedComponents.has(c.componentKey)) return sum;
    return sum + c.fields.filter(f => !excludedFields.has(`${c.componentKey}.${f.fieldKey}`)).length;
  }, 0) || 0;

  return (
    <div className="min-h-screen bg-gray-50 p-8">
      <div className="max-w-6xl mx-auto">
        {/* Header */}
        <div className="bg-white rounded-lg shadow p-6 mb-6">
          <div className="flex items-start justify-between mb-4">
            <div>
              <h1 className="text-3xl font-bold text-gray-900 mb-2">Customize Contract Documentation</h1>
              <p className="text-gray-600">Select which components and fields to include in customer-facing documentation</p>
              <p className="text-sm text-gray-500 mt-1">Run ID: {runId}</p>
            </div>
            <div className="flex gap-2">
              <button
                onClick={() => router.push(`/replay?runId=${runId}&objectKey=captured_data`)}
                className="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition-colors flex items-center gap-2 font-semibold"
              >
                <span>🎯</span>
                <span>Start Replay</span>
              </button>
              <button
                onClick={viewDocumentation}
                className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
              >
                View Documentation
              </button>
              <button
                onClick={saveCustomization}
                disabled={saving}
                className={`px-4 py-2 text-white rounded-lg transition-colors disabled:opacity-50 ${
                  hasUnsavedChanges ? 'bg-orange-600 hover:bg-orange-700' : 'bg-green-600 hover:bg-green-700'
                }`}
              >
                {saving ? "Saving..." : hasUnsavedChanges ? "Save Changes *" : "Save Customization"}
              </button>
            </div>
          </div>

          {/* Stats */}
          <div className="grid grid-cols-3 gap-4">
            <div className="bg-blue-50 rounded-lg p-4 border border-blue-200">
              <div className="text-sm font-medium text-blue-700">Components</div>
              <div className="text-2xl font-bold text-blue-900">
                {includedComponents.length} / {contract?.length || 0}
              </div>
            </div>
            <div className="bg-green-50 rounded-lg p-4 border border-green-200">
              <div className="text-sm font-medium text-green-700">Fields</div>
              <div className="text-2xl font-bold text-green-900">
                {includedFields} / {totalFields}
              </div>
            </div>
            <div className="bg-amber-50 rounded-lg p-4 border border-amber-200">
              <div className="text-sm font-medium text-amber-700">Excluded</div>
              <div className="text-2xl font-bold text-amber-900">
                {excludedComponents.size} components, {excludedFields.size} fields
              </div>
            </div>
          </div>
        </div>

        {/* Info Box */}
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
          <h3 className="font-semibold text-blue-900 mb-2">ℹ️ How This Works</h3>
          <ul className="text-sm text-blue-800 space-y-1">
            <li>• <strong>Framework tables</strong> (CMF*, CHANGES, MUTATION) are automatically hidden and cannot be modified</li>
            <li>• <strong>Relationship fields</strong> (caseid, userid, etc.) are automatically hidden as they are auto-generated</li>
            <li>• <strong>Component ordering</strong> can be changed using ▲▼ buttons next to each component</li>
            <li>• <strong>Nesting</strong> can be configured by selecting a parent component from the dropdown (or &quot;Root level&quot;)</li>
            <li>• <strong>Cardinality</strong> can be broadened (e.g., from required to optional, or from limited to unlimited)</li>
            <li>• <strong>Excluded components</strong> will not appear in customer documentation</li>
            <li>• <strong>Excluded fields</strong> will not be shown but will use original captured values during migration</li>
            <li>• <strong>Field order</strong> can be changed using ▲▼ buttons - this affects both documentation and replay wizard</li>
            <li>• Changes are saved locally and apply only to this migration scenario</li>
          </ul>
        </div>

        {/* Components List */}
        <div className="space-y-4">
          {contract?.sort((a, b) => {
            const orderA = componentOrder.indexOf(a.componentKey);
            const orderB = componentOrder.indexOf(b.componentKey);
            if (orderA === -1 && orderB === -1) return 0;
            if (orderA === -1) return 1;
            if (orderB === -1) return -1;
            return orderA - orderB;
          }).map((component, index) => {
            const isExcluded = excludedComponents.has(component.componentKey);
            const isFramework = /^(CMF|CHANGES|MUTATION)$/i.test(component.physicalTable || '');
            
            return (
              <div key={component.componentKey} className="bg-white rounded-lg border border-gray-300 shadow-sm">
                <div className="p-4 border-b border-gray-200">
                  <div className="flex items-start justify-between gap-4">
                    <div className="flex items-start gap-3 flex-1">
                      <div className="flex flex-col gap-1 pt-1">
                        <button
                          onClick={() => moveComponentUp(component.componentKey)}
                          disabled={index === 0}
                          className="text-xs text-gray-500 hover:text-gray-700 disabled:opacity-30 disabled:cursor-not-allowed"
                          title="Move up"
                        >
                          ▲
                        </button>
                        <button
                          onClick={() => moveComponentDown(component.componentKey)}
                          disabled={index === (contract?.length || 0) - 1}
                          className="text-xs text-gray-500 hover:text-gray-700 disabled:opacity-30 disabled:cursor-not-allowed"
                          title="Move down"
                        >
                          ▼
                        </button>
                      </div>
                      <input
                        type="checkbox"
                        checked={!isExcluded}
                        onChange={() => toggleComponent(component.componentKey)}
                        className="w-5 h-5 rounded border-gray-300 mt-1"
                      />
                      <div className="flex-1">
                        <h3 className="text-lg font-semibold text-gray-900">{component.displayName}</h3>
                        <div className="flex items-center gap-2 text-sm text-gray-600 mb-2">
                          <span className="font-mono">{component.componentKey}</span>
                          <span>•</span>
                          <span className="font-mono">{component.physicalTable}</span>
                          {isFramework && (
                            <span className="bg-gray-200 text-gray-700 px-2 py-0.5 rounded text-xs font-medium">
                              Framework
                            </span>
                          )}
                        </div>
                        <div className="flex items-center gap-2">
                          <label className="text-xs text-gray-600">Nested under:</label>
                          <select
                            value={customNesting[component.componentKey] || ''}
                            onChange={(e) => updateNesting(component.componentKey, e.target.value || null)}
                            className="text-xs border border-gray-300 rounded px-2 py-1"
                          >
                            <option value="">Root level</option>
                            {contract?.filter(c => c.componentKey !== component.componentKey).map(c => (
                              <option key={c.componentKey} value={c.componentKey}>
                                {c.displayName}
                              </option>
                            ))}
                          </select>
                        </div>
                      </div>
                    </div>
                    <div className="flex flex-col items-end gap-2">
                      <div className="text-right">
                        <div className="text-xs text-gray-500 mb-1">Cardinality per Individual</div>
                        {(() => {
                          const currentCard = customCardinality[component.componentKey] || { minOccurs: component.minOccurs, maxOccurs: component.maxOccurs };
                          const originalMin = component.minOccurs;
                          const originalMax = component.maxOccurs;
                          
                          // Generate realistic options that only broaden the requirements
                          const options: Array<{ min: number; max: number | null; label: string; description: string }> = [];
                          
                          // Original cardinality
                          const originalDesc = originalMin === 1 && originalMax === 1 
                            ? "Exactly 1 required"
                            : originalMin === 0 && originalMax === 1
                            ? "Optional, max 1"
                            : originalMin === 1 && originalMax === null
                            ? "At least 1 required"
                            : originalMin === 0 && originalMax === null
                            ? "Optional, unlimited"
                            : `Min ${originalMin}, Max ${originalMax === null ? '∞' : originalMax}`;
                          
                          options.push({ 
                            min: originalMin, 
                            max: originalMax, 
                            label: `${originalMin}..${originalMax === null ? '∞' : originalMax}`,
                            description: originalDesc
                          });
                          
                          // If originally required (min=1), allow making it optional (min=0)
                          if (originalMin === 1) {
                            const optionalDesc = originalMax === 1
                              ? "Optional, max 1"
                              : originalMax === null
                              ? "Optional, unlimited"
                              : `Optional, max ${originalMax}`;
                            
                            options.push({ 
                              min: 0, 
                              max: originalMax, 
                              label: `0..${originalMax === null ? '∞' : originalMax}`,
                              description: optionalDesc
                            });
                          }
                          
                          // If originally has max limit, allow removing it
                          if (originalMax !== null && originalMax > 1) {
                            const unlimitedDesc = currentCard.minOccurs === 0
                              ? "Optional, unlimited"
                              : `At least ${currentCard.minOccurs} required`;
                            
                            options.push({ 
                              min: currentCard.minOccurs, 
                              max: null, 
                              label: `${currentCard.minOccurs}..∞`,
                              description: unlimitedDesc
                            });
                          }
                          
                          return (
                            <div>
                              <select
                                value={`${currentCard.minOccurs}..${currentCard.maxOccurs === null ? 'null' : currentCard.maxOccurs}`}
                                onChange={(e) => {
                                  const [min, max] = e.target.value.split('..');
                                  updateCardinality(component.componentKey, parseInt(min), max === 'null' ? null : parseInt(max));
                                }}
                                className="text-xs border border-gray-300 rounded px-2 py-1 font-mono w-full"
                              >
                                {options.map(opt => (
                                  <option key={`${opt.min}..${opt.max}`} value={`${opt.min}..${opt.max === null ? 'null' : opt.max}`}>
                                    {opt.label} - {opt.description}
                                  </option>
                                ))}
                              </select>
                              <div className="text-[10px] text-gray-500 mt-1 italic">
                                Each Individual {currentCard.minOccurs === 0 ? 'may have' : 'must have'}{' '}
                                {currentCard.minOccurs === currentCard.maxOccurs && currentCard.minOccurs === 1
                                  ? 'exactly 1'
                                  : currentCard.minOccurs === 0 && currentCard.maxOccurs === 1
                                  ? '0 or 1'
                                  : currentCard.minOccurs === 0 && currentCard.maxOccurs === null
                                  ? 'any number of'
                                  : currentCard.minOccurs === 1 && currentCard.maxOccurs === null
                                  ? 'at least 1'
                                  : currentCard.maxOccurs === null
                                  ? `${currentCard.minOccurs} or more`
                                  : `${currentCard.minOccurs} to ${currentCard.maxOccurs}`
                                }{' '}
                                {component.displayName}
                              </div>
                            </div>
                          );
                        })()}
                      </div>
                      <div className="text-xs text-gray-600">
                        {component.fields.filter(f => !excludedFields.has(`${component.componentKey}.${f.fieldKey}`)).length} / {component.fields.length} fields
                      </div>
                    </div>
                  </div>
                </div>

                {!isExcluded && (
                  <div className="p-4">
                    <div className="space-y-1">
                      {(() => {
                        const orderedFields = fieldOrder[component.componentKey] 
                          ? component.fields.sort((a, b) => {
                              const orderA = fieldOrder[component.componentKey].indexOf(a.fieldKey);
                              const orderB = fieldOrder[component.componentKey].indexOf(b.fieldKey);
                              if (orderA === -1 && orderB === -1) return 0;
                              if (orderA === -1) return 1;
                              if (orderB === -1) return -1;
                              return orderA - orderB;
                            })
                          : component.fields;
                        
                        return orderedFields.map((field, index) => {
                          const fieldKey = `${component.componentKey}.${field.fieldKey}`;
                          const isFieldExcluded = excludedFields.has(fieldKey);
                          const isFirst = index === 0;
                          const isLast = index === orderedFields.length - 1;
                          
                          return (
                            <div
                              key={field.fieldKey}
                              className={`flex items-center gap-2 p-2 rounded border ${
                                isFieldExcluded ? 'bg-gray-50 border-gray-200' : 'bg-white border-gray-300'
                              }`}
                            >
                              <div className="flex flex-col gap-1">
                                <button
                                  onClick={() => moveFieldUp(component.componentKey, field.fieldKey)}
                                  disabled={isFirst}
                                  className="text-xs text-gray-500 hover:text-gray-700 disabled:opacity-30 disabled:cursor-not-allowed"
                                  title="Move up"
                                >
                                  ▲
                                </button>
                                <button
                                  onClick={() => moveFieldDown(component.componentKey, field.fieldKey)}
                                  disabled={isLast}
                                  className="text-xs text-gray-500 hover:text-gray-700 disabled:opacity-30 disabled:cursor-not-allowed"
                                  title="Move down"
                                >
                                  ▼
                                </button>
                              </div>
                              <input
                                type="checkbox"
                                checked={!isFieldExcluded}
                                onChange={() => toggleField(component.componentKey, field.fieldKey)}
                                className="w-4 h-4 rounded border-gray-300"
                              />
                              <div className="flex-1 min-w-0">
                                <div className="font-mono text-sm text-gray-900 truncate">{field.fieldKey}</div>
                                <div className="text-xs text-gray-500">{field.type}</div>
                              </div>
                              {field.required && (
                                <span className="text-red-500 font-bold text-xs">*</span>
                              )}
                              <span className="text-xs text-gray-400 font-mono">#{index + 1}</span>
                            </div>
                          );
                        });
                      })()}
                    </div>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
