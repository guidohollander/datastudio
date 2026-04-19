"use client";

import { useParams } from "next/navigation";
import { useEffect, useState } from "react";

type Component = {
  componentKey: string;
  displayName: string;
  minOccurs: number;
  maxOccurs: number | null;
  fields: Field[];
};

type Field = {
  fieldKey: string;
  type: string;
  required: boolean;
  maxLength: number;
  example?: string;
};

type Mapping = {
  objectKey: string;
  componentKey: string;
  componentDisplayName: string;
  fieldKey: string;
  physicalTable: string;
  physicalColumn: string;
  dataType: string;
  required: boolean;
  example: string | null;
  gen: string | null;
  parentRelationship: string | null;
};

type ContractData = {
  contractJson: string;
  mappings: Mapping[];
  error?: string;
};

type ComponentSchema = {
  type: string;
  description?: string;
  properties?: Record<string, FieldSchema | ArraySchema | ComponentSchema>;
  required?: string[];
};

type FieldSchema = {
  description: string;
  type: string;
  maxLength?: number;
  format?: string;
  examples?: string[];
};

type ArraySchema = {
  type: "array";
  items: ComponentSchema;
  description: string;
};

type SampleValue = string | number | boolean | null | SampleObject | SampleValue[];
type SampleObject = Record<string, SampleValue>;

export default function ContractDocumentationPage() {
  const params = useParams();
  const runId = params.runId as string;
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [contract, setContract] = useState<Component[] | null>(null);
  const [allComponents, setAllComponents] = useState<Component[] | null>(null);
  const [mappings, setMappings] = useState<Mapping[]>([]);
  const [objectKey] = useState("individual");
  const [collapsedComponents, setCollapsedComponents] = useState<Set<string>>(new Set());

  useEffect(() => {
    async function loadContract() {
      console.log('[CONTRACT] Starting contract load for runId:', runId);
      setLoading(true);
      setError(null);
      try {
        // FORCE clear ALL contract-related localStorage to show complete captured data
        console.log('[CONTRACT] Clearing localStorage customizations...');
        localStorage.removeItem(`contract-excluded-components-${runId}`);
        localStorage.removeItem(`contract-excluded-fields-${runId}`);
        localStorage.removeItem(`contract-field-order-${runId}`);
        localStorage.removeItem(`contract-custom-cardinality-${runId}`);
        localStorage.removeItem(`contract-custom-nesting-${runId}`);
        localStorage.removeItem(`contract-component-order-${runId}`);
        console.log('[CONTRACT] localStorage cleared');
        
        // Generate contract from captured data
        console.log('[CONTRACT] Generating contract from captured data...');
        const genRes = await fetch("/api/contract/generate", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            runId,
            objectKey: "captured_data",
            displayName: "Captured Business Data"
          })
        });

        const generated = (await genRes.json()) as { objectKey: string };
        if (!genRes.ok) throw new Error("Failed to generate contract");
        console.log('[CONTRACT] Generated objectKey:', generated.objectKey);

        // Fetch the generated contract including framework tables for hierarchy analysis
        console.log('[CONTRACT] Fetching contract data...');
        const res = await fetch(`/api/contract?runId=${runId}&objectKey=${generated.objectKey}&excludeFramework=false`);
        const data = (await res.json()) as ContractData;

        if (!res.ok) {
          throw new Error(data.error || "Failed to load contract");
        }

        const parsed = JSON.parse(data.contractJson);
        // The contract JSON has components nested inside an object
        let contractArray = parsed?.components || [];
        console.log('[CONTRACT] Initial component count:', contractArray.length);
        console.log('[CONTRACT] Component keys:', contractArray.map((c: Component) => c.componentKey));
        
        // Convert maxOccurs -1 to null (unlimited)
        contractArray = contractArray.map((c: Component) => ({
          ...c,
          maxOccurs: c.maxOccurs === -1 ? null : c.maxOccurs
        }));
        
        // Store all components including framework tables for hierarchy analysis
        setAllComponents(contractArray);
        console.log('[CONTRACT] Stored all components:', contractArray.length);
        
        // Apply customization filters from localStorage (if user has customized)
        const savedExcludedComponents = localStorage.getItem(`contract-excluded-components-${runId}`);
        const savedExcludedFields = localStorage.getItem(`contract-excluded-fields-${runId}`);
        console.log('[CONTRACT] Checking localStorage filters...');
        console.log('[CONTRACT] savedExcludedComponents:', savedExcludedComponents);
        console.log('[CONTRACT] savedExcludedFields:', savedExcludedFields);
        
        if (savedExcludedComponents) {
          const excludedComponents = new Set(JSON.parse(savedExcludedComponents));
          console.log('[CONTRACT] Applying component exclusions:', Array.from(excludedComponents));
          contractArray = contractArray.filter((c: Component) => !excludedComponents.has(c.componentKey));
          console.log('[CONTRACT] After component filter:', contractArray.length);
        }
        
        if (savedExcludedFields) {
          const excludedFields = new Set(JSON.parse(savedExcludedFields));
          console.log('[CONTRACT] Applying field exclusions:', Array.from(excludedFields).length, 'fields');
          contractArray = contractArray.map((c: Component) => ({
            ...c,
            fields: c.fields.filter((f: Field) => !excludedFields.has(`${c.componentKey}.${f.fieldKey}`))
          }));
        }
        
        console.log('[CONTRACT] Final component count:', contractArray.length);
        console.log('[CONTRACT] Final component keys:', contractArray.map((c: Component) => c.componentKey));
        
        // Apply field ordering from localStorage
        const savedFieldOrder = localStorage.getItem(`contract-field-order-${runId}`);
        if (savedFieldOrder) {
          const fieldOrder = JSON.parse(savedFieldOrder) as Record<string, string[]>;
          contractArray = contractArray.map((c: Component) => {
            if (fieldOrder[c.componentKey]) {
              const orderedFields = [...c.fields].sort((a, b) => {
                const orderA = fieldOrder[c.componentKey].indexOf(a.fieldKey);
                const orderB = fieldOrder[c.componentKey].indexOf(b.fieldKey);
                if (orderA === -1 && orderB === -1) return 0;
                if (orderA === -1) return 1;
                if (orderB === -1) return -1;
                return orderA - orderB;
              });
              return { ...c, fields: orderedFields };
            }
            return c;
          });
        }
        
        // Apply custom cardinality from localStorage
        const savedCardinality = localStorage.getItem(`contract-custom-cardinality-${runId}`);
        if (savedCardinality) {
          const customCardinality = JSON.parse(savedCardinality) as Record<string, { minOccurs: number; maxOccurs: number | null }>;
          contractArray = contractArray.map((c: Component) => {
            if (customCardinality[c.componentKey]) {
              return { ...c, ...customCardinality[c.componentKey] };
            }
            return c;
          });
        }
        
        setContract(contractArray);
        setMappings(data.mappings);
      } catch (e) {
        setError(e instanceof Error ? e.message : "Failed to load contract");
      } finally {
        setLoading(false);
      }
    }

    if (runId) {
      void loadContract();
    }
  }, [runId, objectKey]);

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 p-8">
        <div className="max-w-6xl mx-auto">
          <div className="text-center py-12">
            <div className="text-lg text-gray-600">Loading contract documentation...</div>
          </div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 p-8">
        <div className="max-w-6xl mx-auto">
          <div className="bg-red-50 border border-red-200 rounded-lg p-6">
            <h2 className="text-lg font-semibold text-red-900 mb-2">Error Loading Contract</h2>
            <p className="text-red-700">{error}</p>
          </div>
        </div>
      </div>
    );
  }

  const totalFields = contract?.reduce((sum, c) => sum + c.fields.length, 0) || 0;
  const requiredFields = contract?.reduce((sum, c) => sum + c.fields.filter(f => f.required).length, 0) || 0;

  function buildHierarchicalStructure() {
    if (!allComponents || !mappings) return null;
    
    // Check for custom nesting from localStorage
    const savedNesting = localStorage.getItem(`contract-custom-nesting-${runId}`);
    const customNesting = savedNesting ? JSON.parse(savedNesting) as Record<string, string | null> : {};
    
    console.log('Building hierarchy with custom nesting:', customNesting);
    
    // Build parent-child relationship map
    const childToParent: Record<string, string> = {};
    const parentToChildren: Record<string, string[]> = {};
    
    // If custom nesting exists, use it; otherwise use detected relationships
    if (Object.keys(customNesting).length > 0) {
      console.log('Using custom nesting configuration');
      // Use custom nesting
      Object.entries(customNesting).forEach(([childKey, parentKey]) => {
        if (parentKey) {
          childToParent[childKey] = parentKey;
          
          if (!parentToChildren[parentKey]) {
            parentToChildren[parentKey] = [];
          }
          if (!parentToChildren[parentKey].includes(childKey)) {
            parentToChildren[parentKey].push(childKey);
          }
      console.log('Auto-detecting relationships from database');
        }
      });
    } else {
      // Auto-detect from database relationships
      const componentMappings: Record<string, Mapping[]> = {};
      mappings.forEach((mapping) => {
        if (!componentMappings[mapping.componentKey]) {
          componentMappings[mapping.componentKey] = [];
        }
        componentMappings[mapping.componentKey].push(mapping);
      });
      
      Object.entries(componentMappings).forEach(([componentKey, compMappings]) => {
        const fkMappings = compMappings.filter(m => m.parentRelationship);
        
        if (fkMappings.length > 0) {
          const parentRelationship = fkMappings[0].parentRelationship;
          const parentTable = parentRelationship.split('.')[0];
          
          const parentComponent = allComponents.find(c => {
            const parentMapping = mappings.find((m) => m.componentKey === c.componentKey);
            return parentMapping?.physicalTable === parentTable;
          });
          
          if (parentComponent && componentKey !== parentComponent.componentKey) {
            childToParent[componentKey] = parentComponent.componentKey;
            
            if (!parentToChildren[parentComponent.componentKey]) {
              parentToChildren[parentComponent.componentKey] = [];
            }
            if (!parentToChildren[parentComponent.componentKey].includes(componentKey)) {
              parentToChildren[parentComponent.componentKey].push(componentKey);
            }
          }
        }
      });
    }
    
    // Find root components (those without parents) - filter to only non-framework for display
    const frameworkTablePatterns = /^(CMF|CHANGES|MUTATION)/i;
    const rootComponents = (contract || []).filter(c => {
      if (childToParent[c.componentKey]) return false;
      
      const mapping = mappings.find((m) => m.componentKey === c.componentKey);
      const physicalTable = mapping?.physicalTable || c.componentKey;
      return !frameworkTablePatterns.test(physicalTable);
    });
    
    console.log('Final hierarchy:', { rootComponents: rootComponents.map(c => c.componentKey), parentToChildren, childToParent });
    
    return { rootComponents, parentToChildren, childToParent };
  }

  function downloadSampleJson() {
    if (!contract) return;
    
    const hierarchy = buildHierarchicalStructure();
    if (!hierarchy) return;
    
    function buildComponentData(component: Component): SampleObject {
      const componentData: SampleObject = {};
      
      component.fields.forEach(field => {
        // Use example value if available, otherwise generate a sample based on type
        if (field.example) {
          componentData[field.fieldKey] = field.example;
        } else {
          switch (field.type.toLowerCase()) {
            case 'string':
              componentData[field.fieldKey] = `sample_${field.fieldKey}`;
              break;
            case 'integer':
            case 'number':
              componentData[field.fieldKey] = 0;
              break;
            case 'date':
              componentData[field.fieldKey] = new Date().toISOString().split('T')[0];
              break;
            case 'boolean':
              componentData[field.fieldKey] = false;
              break;
            default:
              componentData[field.fieldKey] = null;
          }
        }
      });
      
      // Add child components
      const children = hierarchy?.parentToChildren[component.componentKey] || [];
      children.forEach(childKey => {
        const childComponent = contract?.find(c => c.componentKey === childKey);
        if (childComponent) {
          const childData = buildComponentData(childComponent);
          
          // Handle cardinality
          if (childComponent.maxOccurs === 1) {
            componentData[childComponent.componentKey] = childData;
          } else {
            componentData[childComponent.componentKey] = [childData];
          }
        }
      });
      
      return componentData;
    }
    
    const sample: SampleObject = {};
    
    hierarchy.rootComponents.forEach(component => {
      const componentData = buildComponentData(component);
      
      // Handle cardinality for root components
      if (component.maxOccurs === 1) {
        sample[component.componentKey] = componentData;
      } else {
        sample[component.componentKey] = [componentData];
      }
    });
    
    const blob = new Blob([JSON.stringify(sample, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `contract-sample-${runId.substring(0, 8)}.json`;
    a.click();
    URL.revokeObjectURL(url);
  }

  function downloadJsonSchema() {
    if (!contract) return;
    
    const hierarchy = buildHierarchicalStructure();
    if (!hierarchy) return;
    
    function buildComponentSchema(component: Component): ComponentSchema {
      const componentSchema: ComponentSchema = {
        "type": "object",
        "properties": {},
        "required": []
      };
      
      component.fields.forEach(field => {
        const fieldSchema: FieldSchema = {
          "description": field.fieldKey
        };
        
        // Map types to JSON Schema types
        switch (field.type.toLowerCase()) {
          case 'string':
            fieldSchema.type = 'string';
            if (field.maxLength > 0) {
              fieldSchema.maxLength = field.maxLength;
            }
            break;
          case 'integer':
            fieldSchema.type = 'integer';
            break;
          case 'number':
            fieldSchema.type = 'number';
            break;
          case 'date':
            fieldSchema.type = 'string';
            fieldSchema.format = 'date';
            break;
          case 'boolean':
            fieldSchema.type = 'boolean';
            break;
          default:
            fieldSchema.type = 'string';
        }
        
        if (field.example) {
          fieldSchema.examples = [field.example];
        }
        
        componentSchema.properties[field.fieldKey] = fieldSchema;
        
        if (field.required) {
          componentSchema.required.push(field.fieldKey);
        }
      });
      
      // Add child components
      const children = hierarchy?.parentToChildren[component.componentKey] || [];
      children.forEach(childKey => {
        const childComponent = contract?.find(c => c.componentKey === childKey);
        if (childComponent) {
          const childSchema = buildComponentSchema(childComponent);
          
          // Add cardinality information
          const cardinalityDesc = childComponent.minOccurs === 1 && childComponent.maxOccurs === 1
            ? "Exactly one required"
            : childComponent.minOccurs === 0 && childComponent.maxOccurs === 1
            ? "Optional, maximum one"
            : childComponent.minOccurs === 0 && childComponent.maxOccurs == null
            ? "Optional, unlimited"
            : childComponent.minOccurs === 1 && childComponent.maxOccurs == null
            ? "At least one required"
            : `Minimum ${childComponent.minOccurs}, Maximum ${childComponent.maxOccurs == null ? 'unlimited' : childComponent.maxOccurs}`;
          
          childSchema.description = `${childComponent.displayName} (${cardinalityDesc})`;
          
          // Handle cardinality
          if (childComponent.maxOccurs === 1) {
            componentSchema.properties[childComponent.componentKey] = childSchema;
          } else {
            componentSchema.properties[childComponent.componentKey] = {
              "type": "array",
              "items": childSchema,
              "description": `${childComponent.displayName} (${cardinalityDesc})`
            };
          }
          
          if (childComponent.minOccurs > 0) {
            componentSchema.required.push(childComponent.componentKey);
          }
        }
      });
      
      return componentSchema;
    }
    
    const schema: ComponentSchema & { $schema: string; title: string } = {
      "$schema": "http://json-schema.org/draft-07/schema#",
      "title": `Migration Contract - ${objectKey}`,
      "description": "Data contract for migration scenario",
      "type": "object",
      "properties": {},
      "required": []
    };
    
    hierarchy.rootComponents.forEach(component => {
      const componentSchema = buildComponentSchema(component);
      
      // Add cardinality information
      const cardinalityDesc = component.minOccurs === 1 && component.maxOccurs === 1
        ? "Exactly one required"
        : component.minOccurs === 0 && component.maxOccurs === 1
        ? "Optional, maximum one"
        : component.minOccurs === 0 && component.maxOccurs == null
        ? "Optional, unlimited"
        : component.minOccurs === 1 && component.maxOccurs == null
        ? "At least one required"
        : `Minimum ${component.minOccurs}, Maximum ${component.maxOccurs == null ? 'unlimited' : component.maxOccurs}`;
      
      componentSchema.description = `${component.displayName} (${cardinalityDesc})`;
      
      // Handle cardinality for root components
      if (component.maxOccurs === 1) {
        schema.properties[component.componentKey] = componentSchema;
      } else {
        schema.properties[component.componentKey] = {
          "type": "array",
          "items": componentSchema,
          "description": `${component.displayName} (${cardinalityDesc})`
        };
      }
      
      if (component.minOccurs > 0) {
        schema.required.push(component.componentKey);
      }
    });
    
    const blob = new Blob([JSON.stringify(schema, null, 2)], { type: 'application/schema+json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `contract-schema-${runId.substring(0, 8)}.json`;
    a.click();
    URL.revokeObjectURL(url);
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 p-8">
      <div className="max-w-6xl mx-auto">
        {/* Header */}
        <div className="bg-white rounded-2xl shadow-xl p-8 mb-8">
          <div className="flex items-start justify-between mb-6">
            <div>
              <h1 className="text-4xl font-bold text-gray-900 mb-2">Data Contract Documentation</h1>
              <p className="text-lg text-gray-600">Migration Scenario: {objectKey}</p>
              <p className="text-sm text-gray-500 mt-1">Run ID: {runId}</p>
            </div>
            <div className="flex gap-2">
              <button
                onClick={() => window.location.href = `/replay?runId=${runId}&objectKey=${objectKey}`}
                className="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition-colors flex items-center gap-2 font-semibold"
              >
                <span>🎯</span>
                <span>Start Replay</span>
              </button>
              <button
                onClick={() => window.location.href = `/contract/${runId}/customize`}
                className="px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-colors flex items-center gap-2"
              >
                <span>⚙️</span>
                <span>Customize</span>
              </button>
              <button
                onClick={downloadSampleJson}
                className="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors flex items-center gap-2"
              >
                <span>📄</span>
                <span>Sample JSON</span>
              </button>
              <button
                onClick={downloadJsonSchema}
                className="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors flex items-center gap-2"
              >
                <span>📋</span>
                <span>JSON Schema</span>
              </button>
              <button
                onClick={() => window.print()}
                className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors flex items-center gap-2"
              >
                <span>🖨️</span>
                <span>Print</span>
              </button>
            </div>
          </div>

          {/* Summary Stats */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="bg-blue-50 rounded-lg p-4 border border-blue-200">
              <div className="text-sm font-medium text-blue-700 mb-1">Components</div>
              <div className="text-3xl font-bold text-blue-900">{contract?.length || 0}</div>
            </div>
            <div className="bg-green-50 rounded-lg p-4 border border-green-200">
              <div className="text-sm font-medium text-green-700 mb-1">Total Fields</div>
              <div className="text-3xl font-bold text-green-900">{totalFields}</div>
            </div>
            <div className="bg-amber-50 rounded-lg p-4 border border-amber-200">
              <div className="text-sm font-medium text-amber-700 mb-1">Required Fields</div>
              <div className="text-3xl font-bold text-amber-900">{requiredFields}</div>
            </div>
          </div>
        </div>

        {/* Introduction */}
        <div className="bg-white rounded-2xl shadow-xl p-8 mb-8">
          <h2 className="text-2xl font-bold text-gray-900 mb-4">📋 About This Contract</h2>
          <div className="prose max-w-none text-gray-700">
            <p className="mb-4">
              This document describes the data structure required for the <strong>{objectKey}</strong> migration scenario.
              Each component represents a logical grouping of related data fields that must be provided.
            </p>
            <p className="mb-4">
              <strong>How to use this document:</strong>
            </p>
            <ul className="list-disc pl-6 space-y-2 mb-4">
              <li><strong>Required fields</strong> are marked with a red asterisk (*) and must be provided</li>
              <li><strong>Optional fields</strong> can be omitted if not applicable</li>
              <li><strong>Data types</strong> indicate the format expected (string, integer, date, etc.)</li>
              <li><strong>Max length</strong> shows the maximum number of characters allowed</li>
              <li><strong>Example values</strong> demonstrate the expected format</li>
              <li><strong>FK (Foreign Key)</strong> fields reference other components and will be auto-generated during migration</li>
            </ul>
          </div>
        </div>

        {/* Components */}
        {(() => {
          const hierarchy = buildHierarchicalStructure();
          if (!hierarchy) return null;
          
          let componentCounter = 0;
          
          const renderComponent = (component: Component, depth: number = 0): React.ReactElement => {
            componentCounter++;
            const componentNumber = componentCounter;
            const mapping = mappings.find(m => m.componentKey === component.componentKey);
            const physicalTable = mapping?.physicalTable || component.componentKey;
            const children = hierarchy.parentToChildren[component.componentKey] || [];
            const childComponents = children.map(childKey => contract?.find(c => c.componentKey === childKey)).filter(Boolean) as Component[];
            const hasChildren = childComponents.length > 0;
            const isCollapsed = collapsedComponents.has(component.componentKey);
            
            const toggleCollapse = () => {
              setCollapsedComponents(prev => {
                const next = new Set(prev);
                if (next.has(component.componentKey)) {
                  next.delete(component.componentKey);
                } else {
                  next.add(component.componentKey);
                }
                return next;
              });
            };
            
            return (
              <>
                <div 
                  className="bg-white rounded-2xl shadow-xl p-8 mb-8" 
                  style={{ 
                    marginLeft: `${depth * 3}rem`,
                    borderLeft: depth > 0 ? '4px solid #3b82f6' : 'none'
                  }}
                >
              {/* Component Header */}
              <div className="mb-6 pb-4 border-b border-gray-200">
                <div className="flex items-start justify-between">
                  <div className="flex items-start gap-3 flex-1">
                    {hasChildren && (
                      <button
                        onClick={toggleCollapse}
                        className="mt-1 text-gray-600 hover:text-gray-900 transition-colors"
                        title={isCollapsed ? "Expand child components" : "Collapse child components"}
                      >
                        <span className="text-2xl">{isCollapsed ? '▶' : '▼'}</span>
                      </button>
                    )}
                    <div>
                      <h2 className="text-2xl font-bold text-gray-900 mb-2">
                        {componentNumber}. {component.displayName}
                        {depth > 0 && <span className="ml-2 text-sm text-blue-600">↳ nested under parent</span>}
                        {hasChildren && <span className="ml-2 text-sm text-green-600">({childComponents.length} child{childComponents.length !== 1 ? 'ren' : ''})</span>}
                      </h2>
                    <div className="flex items-center gap-4 text-sm text-gray-600">
                      <span className="font-mono bg-gray-100 px-2 py-1 rounded">
                        {component.componentKey}
                      </span>
                      <span className="font-mono bg-blue-50 px-2 py-1 rounded text-blue-700">
                        Table: {physicalTable}
                      </span>
                    </div>
                  </div>
                  </div>
                  <div className="text-right">
                    <div className="text-sm text-gray-600 mb-1">Cardinality per Individual</div>
                    <div className="text-lg font-semibold text-gray-900 mb-2">
                      {component.minOccurs}..{component.maxOccurs == null ? "∞" : component.maxOccurs}
                    </div>
                    <div className="text-xs space-y-1">
                      {component.minOccurs === 1 && component.maxOccurs === 1 && (
                        <div className="bg-red-50 text-red-700 px-2 py-1 rounded font-medium">
                          ✓ Exactly one required
                        </div>
                      )}
                      {component.minOccurs === 0 && component.maxOccurs === 1 && (
                        <div className="bg-blue-50 text-blue-700 px-2 py-1 rounded font-medium">
                          Optional (0 or 1)
                        </div>
                      )}
                      {component.minOccurs === 0 && component.maxOccurs == null && (
                        <div className="bg-blue-50 text-blue-700 px-2 py-1 rounded font-medium">
                          Optional (0 or more)
                        </div>
                      )}
                      {component.minOccurs === 1 && component.maxOccurs == null && (
                        <div className="bg-amber-50 text-amber-700 px-2 py-1 rounded font-medium">
                          ✓ At least one required
                        </div>
                      )}
                      {component.minOccurs > 1 && (
                        <div className="bg-red-50 text-red-700 px-2 py-1 rounded font-medium">
                          ✓ Minimum: {component.minOccurs}
                        </div>
                      )}
                      {component.maxOccurs != null && component.maxOccurs > 1 && (
                        <div className="bg-gray-50 text-gray-700 px-2 py-1 rounded font-medium">
                          Maximum: {component.maxOccurs}
                        </div>
                      )}
                    </div>
                    <div className="text-[10px] text-gray-500 mt-2 italic">
                      Each Individual {component.minOccurs === 0 ? 'may have' : 'must have'}{' '}
                      {component.minOccurs === component.maxOccurs && component.minOccurs === 1
                        ? 'exactly 1'
                        : component.minOccurs === 0 && component.maxOccurs === 1
                        ? '0 or 1'
                        : component.minOccurs === 0 && component.maxOccurs == null
                        ? 'any number of'
                        : component.minOccurs === 1 && component.maxOccurs == null
                        ? 'at least 1'
                        : component.maxOccurs == null
                        ? `${component.minOccurs} or more`
                        : `${component.minOccurs} to ${component.maxOccurs}`
                      }{' '}
                      {component.displayName}
                    </div>
                  </div>
                </div>
              </div>

              {/* Fields Table */}
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="bg-gray-50 border-b border-gray-200">
                      <th className="text-left p-3 text-sm font-semibold text-gray-700">Field Name</th>
                      <th className="text-left p-3 text-sm font-semibold text-gray-700">Type</th>
                      <th className="text-left p-3 text-sm font-semibold text-gray-700">Max Length</th>
                      <th className="text-left p-3 text-sm font-semibold text-gray-700">Required</th>
                      <th className="text-left p-3 text-sm font-semibold text-gray-700">Example</th>
                      <th className="text-left p-3 text-sm font-semibold text-gray-700">Notes</th>
                    </tr>
                  </thead>
                  <tbody>
                    {component.fields.map((field) => {
                      const fieldMapping = mappings.find(
                        m => m.componentKey === component.componentKey && m.fieldKey === field.fieldKey
                      );
                      const isFK = !!fieldMapping?.parentRelationship;
                      
                      return (
                        <tr key={field.fieldKey} className="border-b border-gray-100 hover:bg-gray-50">
                          <td className="p-3">
                            <div className="flex items-center gap-2">
                              <span className="font-mono text-sm text-gray-900">{field.fieldKey}</span>
                              {field.required && <span className="text-red-500 font-bold">*</span>}
                              {isFK && (
                                <span className="text-xs bg-amber-100 text-amber-700 px-2 py-0.5 rounded font-semibold">
                                  FK
                                </span>
                              )}
                            </div>
                            {fieldMapping && (
                              <div className="text-xs text-gray-500 mt-1 font-mono">
                                {fieldMapping.physicalColumn}
                              </div>
                            )}
                          </td>
                          <td className="p-3">
                            <span className="text-sm font-mono text-blue-700 bg-blue-50 px-2 py-1 rounded">
                              {field.type}
                            </span>
                          </td>
                          <td className="p-3 text-sm text-gray-600">
                            {field.maxLength > 0 ? field.maxLength : "—"}
                          </td>
                          <td className="p-3">
                            {field.required ? (
                              <span className="text-xs bg-red-100 text-red-700 px-2 py-1 rounded font-semibold">
                                Yes
                              </span>
                            ) : (
                              <span className="text-xs bg-gray-100 text-gray-600 px-2 py-1 rounded">
                                No
                              </span>
                            )}
                          </td>
                          <td className="p-3">
                            {field.example ? (
                              <span className="text-sm font-mono text-gray-700 bg-gray-50 px-2 py-1 rounded">
                                {field.example}
                              </span>
                            ) : (
                              <span className="text-sm text-gray-400">—</span>
                            )}
                          </td>
                          <td className="p-3 text-sm text-gray-600">
                            {isFK && (
                              <div className="text-xs text-amber-700">
                                References: {fieldMapping.parentRelationship}
                                <div className="text-amber-600 italic mt-1">Auto-generated during migration</div>
                              </div>
                            )}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            </div>
                {/* Render child components only if not collapsed */}
                {!isCollapsed && childComponents.map(child => (
                  <div key={child.componentKey}>
                    {renderComponent(child, depth + 1)}
                  </div>
                ))}
              </>
            );
          };
          
          // Render root components
          return hierarchy.rootComponents.map(component => (
            <div key={component.componentKey}>
              {renderComponent(component, 0)}
            </div>
          ));
        })()}

        {/* Footer */}
        <div className="bg-white rounded-2xl shadow-xl p-8 mb-8">
          <h2 className="text-2xl font-bold text-gray-900 mb-4">📞 Support & Questions</h2>
          <div className="prose max-w-none text-gray-700">
            <p className="mb-4">
              If you have questions about this data contract or need assistance preparing your data:
            </p>
            <ul className="list-disc pl-6 space-y-2">
              <li>Review the example values to understand the expected format</li>
              <li>Ensure all required fields (*) are provided</li>
              <li>Verify data types match the specifications</li>
              <li>Check that string values do not exceed the maximum length</li>
              <li>Foreign key (FK) fields will be automatically generated - do not provide values for these</li>
            </ul>
            <p className="mt-4 text-sm text-gray-500">
              Generated on {new Date().toLocaleString()} | Contract Version: {runId.substring(0, 8)}
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
