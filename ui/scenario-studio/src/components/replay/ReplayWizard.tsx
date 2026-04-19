"use client";

import { useState, useEffect, useMemo, useRef, useCallback } from "react";
import ExpressionHelp from "./ExpressionHelp";
import GeneratorPicker from "./GeneratorPicker";

type CapturedRow = {
  PkColumn: string;
  PkValue: number;
  CapturedAt: string;
  RowJson: string;
  ChangeType: string | null;
  ExcludeFromReplay: boolean;
};

type CapturedData = Record<
  string,
  {
    dependencyLevel: number;
    rows: CapturedRow[];
  }
>;

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

type PreviewItem = Record<string, Record<string, unknown>>;
type PreviewFieldData = {
  original: string | null;
  generated: string | null;
  generator: string | null;
  isSame: boolean;
  usesCtx: boolean;
  parentRelationship: string | null;
};

type DetectedPattern = {
  expression: string;
  pattern: 'exact' | 'concat';
  sourceFields: string[];
};

function detectStringResemblance(mappings: Mapping[], previewValues: Record<string, string>): Record<string, DetectedPattern> {
  const patterns: Record<string, DetectedPattern> = {};

  // Collect string field values > 3 chars, skip FK/numeric-only
  // Use preview values if available (for generated fields), otherwise use example (original captured value)
  const fields: { key: string; comp: string; table: string; value: string }[] = [];
  for (const m of mappings) {
    const previewKey = `${m.componentKey}.${m.fieldKey}`;
    const value = previewValues[previewKey] || m.example;
    if (!value || value.length <= 3 || m.parentRelationship) continue;
    if (/^\d+$/.test(value)) continue; // skip pure numbers
    if (/^\d{4}-\d{2}-\d{2}/.test(value)) continue; // skip dates
    fields.push({ key: m.fieldKey.toLowerCase(), comp: m.componentKey, table: m.physicalTable, value });
  }

  // Count value frequency — skip very common values (constants like "Source_Taxpayer")
  const valueCounts: Record<string, number> = {};
  for (const f of fields) valueCounts[f.value] = (valueCounts[f.value] || 0) + 1;

  const isCmf = (t: string) => /^CMF/i.test(t);
  // Prefer non-CMF sources as "primary"
  const primary = fields.filter(f => !isCmf(f.table));

  for (const target of fields) {
    const tk = `${target.comp}.${target.key}`;

    // 1. Concatenation patterns (check first — more specific)
    let found = false;
    for (const sep of [', ', ' - ', ' ']) {
      if (!target.value.includes(sep)) continue;
      const parts = target.value.split(sep);
      if (parts.length < 2 || parts.length > 4 || parts.some(p => p.length < 2)) continue;

      const matched: string[] = [];
      let ok = true;
      for (const part of parts) {
        const src = primary.find(f => f.value === part && f.comp !== target.comp)
          || fields.find(f => f.value === part && f.comp !== target.comp);
        if (src) matched.push(src.key);
        else { ok = false; break; }
      }

      if (ok && matched.length >= 2) {
        const exprParts: string[] = [];
        for (let i = 0; i < matched.length; i++) {
          if (i > 0) exprParts.push(`'${sep}'`);
          exprParts.push(`ctx(${matched[i]})`);
        }
        patterns[tk] = { expression: `concat(${exprParts.join(', ')})`, pattern: 'concat', sourceFields: matched };
        found = true;
        break;
      }
    }
    if (found) continue;

    // 2. Exact match across different components (skip overly common values)
    if (valueCounts[target.value] > 3) continue;
    const src = primary.find(f => f.value === target.value && f.comp !== target.comp && f.key !== target.key)
      || fields.find(f => f.value === target.value && f.comp !== target.comp && f.key !== target.key);
    if (src) {
      patterns[tk] = { expression: `ctx(${src.key})`, pattern: 'exact', sourceFields: [src.key] };
    }
  }

  return patterns;
}

type WizardStep = "review" | "configure" | "preview" | "execute";

export default function ReplayWizard({ runId }: { runId: string }) {
  const [currentStep, setCurrentStep] = useState<WizardStep>("review");
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);

  // Step 1: Review & Exclude
  const [capturedData, setCapturedData] = useState<CapturedData>({});
  const [expandedTables, setExpandedTables] = useState<Set<string>>(new Set());

  // Step 2: Configure
  const [objectKey, setObjectKey] = useState<string>("captured_data");
  const [contractJson, setContractJson] = useState<string | null>(null);
  const [mappings, setMappings] = useState<Mapping[]>([]);
  const [previewValues, setPreviewValues] = useState<Record<string, string>>({});

  // Step 3: Preview
  const [previewItems, setPreviewItems] = useState<PreviewItem[]>([]);
  const [times, setTimes] = useState<number>(5);

  // Step 4: Execute
  const [commit, setCommit] = useState<boolean>(true);
  const [replayResult, setReplayResult] = useState<{ totalItems: number; replayRuns: unknown[] } | null>(null);

  // Collapsible component sections (CMF* collapsed by default)
  const [collapsedConfigComponents, setCollapsedConfigComponents] = useState<Set<string>>(new Set());
  const [collapsedPreviewComponents, setCollapsedPreviewComponents] = useState<Set<string>>(new Set());
  // Detected string resemblance patterns
  const [detectedPatterns, setDetectedPatterns] = useState<Record<string, DetectedPattern>>({});
  // Collapsible preview items (all except first collapsed by default)
  const [collapsedPreviewItems, setCollapsedPreviewItems] = useState<Set<number>>(new Set());
  // Track which field was just changed to show resemblance suggestions
  const [changedFieldKey, setChangedFieldKey] = useState<string | null>(null);
  const contractLoadRequestedRef = useRef(false);
  const previewLoadRequestedRef = useRef(false);
  
  // Reactive resemblance detection: run after preview values are updated
  useEffect(() => {
    if (changedFieldKey && Object.keys(previewValues).length > 0) {
      const patterns = detectStringResemblance(mappings, previewValues);
      setDetectedPatterns(patterns);
      
      // Count how many other fields have resemblance patterns
      const relatedFields = Object.keys(patterns).filter(k => k !== changedFieldKey.toLowerCase());
      if (relatedFields.length > 0) {
        setMsg(`✨ Found ${relatedFields.length} field${relatedFields.length > 1 ? 's' : ''} with similar values that could be linked (marked with purple LINKED badge)`);
      } else {
        setMsg('No fields with similar values found');
      }
      
      // Clear the changed field key after detection
      setChangedFieldKey(null);
    }
  }, [previewValues, changedFieldKey, mappings]);

  const steps: { id: WizardStep; label: string; description: string }[] = [
    { id: "review", label: "Review & Exclude", description: "Select which tables and rows to include in replay" },
    { id: "configure", label: "Configure", description: "Set up field generators and transformations" },
    { id: "preview", label: "Preview", description: "See what will be created before executing" },
    { id: "execute", label: "Execute", description: "Run the replay with optional commit" },
  ];

  const currentStepIndex = steps.findIndex((s) => s.id === currentStep);

  const loadCapturedData = useCallback(async () => {
    setBusy(true);
    setMsg(null);
    try {
      const res = await fetch(`/api/runs/${encodeURIComponent(runId)}/captured-data`);
      const json = (await res.json()) as { capturedData?: CapturedData; error?: string };
      if (!res.ok) throw new Error(json.error ?? "Failed to load captured data");
      setCapturedData(json.capturedData ?? {});

      const tables = Object.keys(json.capturedData ?? {});
      if (tables.length > 0) {
        setExpandedTables(new Set([tables[0]]));
      }
    } catch (e) {
      setMsg(e instanceof Error ? e.message : "Failed to load captured data");
    } finally {
      setBusy(false);
    }
  }, [runId]);

  async function toggleTableExclusion(tableName: string, excluded: boolean) {
    setBusy(true);
    try {
      const res = await fetch(`/api/runs/${encodeURIComponent(runId)}/exclusions`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ tableName, excluded }),
      });
      if (!res.ok) throw new Error("Failed to update exclusion");

      setCapturedData((prev) => ({
        ...prev,
        [tableName]: {
          ...prev[tableName],
          rows: prev[tableName].rows.map((r) => ({ ...r, ExcludeFromReplay: excluded })),
        },
      }));
    } catch (e) {
      setMsg(e instanceof Error ? e.message : "Failed to update exclusion");
    } finally {
      setBusy(false);
    }
  }

  async function toggleRowExclusion(tableName: string, pkValue: number, excluded: boolean) {
    setBusy(true);
    try {
      const res = await fetch(`/api/runs/${encodeURIComponent(runId)}/exclusions`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ tableName, pkValue, excluded }),
      });
      if (!res.ok) throw new Error("Failed to update exclusion");

      setCapturedData((prev) => ({
        ...prev,
        [tableName]: {
          ...prev[tableName],
          rows: prev[tableName].rows.map((r) =>
            r.PkValue === pkValue ? { ...r, ExcludeFromReplay: excluded } : r
          ),
        },
      }));
    } catch (e) {
      setMsg(e instanceof Error ? e.message : "Failed to update exclusion");
    } finally {
      setBusy(false);
    }
  }

  const loadContract = useCallback(async () => {
    setBusy(true);
    setMsg(null);
    try {
      // First, auto-generate contract from captured data
      setMsg("Generating contract from captured business tables...");
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

      const generated = (await genRes.json()) as { objectKey: string; displayName: string };
      setObjectKey(generated.objectKey); // Store the generated objectKey
      setMsg(`Contract generated: ${generated.displayName}. Loading...`);

      // Now load the generated contract
      const res = await fetch(
        `/api/contract?runId=${encodeURIComponent(runId)}&objectKey=${encodeURIComponent(generated.objectKey)}`,
        { method: "GET" }
      );

      if (!res.ok) {
        const text = await res.text();
        try {
          const json = JSON.parse(text);
          throw new Error(json.error ?? json.details ?? "Failed to load contract");
        } catch {
          throw new Error(`Failed to load contract: ${res.status}`);
        }
      }

      const json = (await res.json()) as { contractJson: string; mappings: Mapping[] };
      setContractJson(json.contractJson);

      // Do NOT run resemblance detection on load - only when user changes a field
      setDetectedPatterns({});
      setMappings(json.mappings);

      // Collapse CMF*, CHANGES, MUTATION framework components by default
      const frameworkKeys = new Set<string>();
      for (const m of json.mappings) {
        if (/^(CMF|CHANGES|MUTATION)$/i.test(m.physicalTable)) {
          frameworkKeys.add(m.componentKey);
        }
      }
      setCollapsedConfigComponents(frameworkKeys);
      setCollapsedPreviewComponents(new Set(frameworkKeys));

      const compCount = Array.from(new Set(json.mappings.map(m => m.componentKey))).length;
      setMsg(`Contract loaded: ${json.mappings.length} fields across ${compCount} components`);
    } catch (e) {
      setMsg(e instanceof Error ? e.message : "Failed to load contract");
    } finally {
      setBusy(false);
    }
  }, [runId]);

  const generateAllPreviews = useCallback(async (currentMappings: Mapping[]) => {
    // Build comprehensive cross-component context from ALL captured values
    // This allows ctx() expressions to reference fields from any component
    const context: Record<string, string> = {};
    
    // First pass: populate context with all original captured values
    for (const m of currentMappings) {
      if (m.example) {
        context[m.fieldKey.toLowerCase()] = m.example;
      }
    }

    const newPreviews: Record<string, string> = {};

    // Second pass: evaluate generators progressively
    // Process fields that generate new values first (non-ctx generators)
    // Then process fields that reference other fields (ctx-based generators)
    const nonCtxFields = currentMappings.filter(m => m.gen && !m.parentRelationship && !m.gen.includes('ctx('));
    const ctxFields = currentMappings.filter(m => m.gen && !m.parentRelationship && m.gen.includes('ctx('));
    
    // First evaluate non-ctx fields (these generate new values)
    for (const m of nonCtxFields) {
      const contextJson = JSON.stringify(context);
      try {
        const res = await fetch("/api/generator/evaluate", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ expression: m.gen, itemIndex: 1, contextJson }),
        });
        if (!res.ok) continue;
        const json = (await res.json()) as { result?: string };
        if (json.result) {
          newPreviews[`${m.componentKey}.${m.fieldKey}`] = json.result;
          // Update context with generated value so other fields can reference it
          context[m.fieldKey.toLowerCase()] = json.result;
        }
      } catch {
        // skip
      }
    }
    
    // Then evaluate ctx-based fields (these reference other fields)
    for (const m of ctxFields) {
      const contextJson = JSON.stringify(context);
      try {
        const res = await fetch("/api/generator/evaluate", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ expression: m.gen, itemIndex: 1, contextJson }),
        });
        if (!res.ok) continue;
        const json = (await res.json()) as { result?: string };
        if (json.result) {
          newPreviews[`${m.componentKey}.${m.fieldKey}`] = json.result;
          // Update context with generated value
          context[m.fieldKey.toLowerCase()] = json.result;
        }
      } catch {
        // skip
      }
    }

    setPreviewValues(newPreviews);
  }, []);

  const saveGenerators = useCallback(async () => {
    setBusy(true);
    setMsg("Saving generator changes...");
    try {
      // Save all generator changes to database
      for (const m of mappings) {
        await fetch("/api/contract/field-gen", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ objectKey, componentKey: m.componentKey, fieldKey: m.fieldKey, gen: m.gen }),
        });
      }
      setMsg("All generators saved successfully");
    } catch (e) {
      setMsg(e instanceof Error ? e.message : "Failed to save generators");
      throw e;
    } finally {
      setBusy(false);
    }
  }, [mappings, objectKey]);

  const loadPreview = useCallback(async () => {
    setBusy(true);
    setMsg(null);
    try {
      // First save any generator changes
      await saveGenerators();
      
      // Then load preview with updated generators
      const res = await fetch("/api/replay/preview", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ sourceRunId: runId, objectKey, times, previewCount: 5 }),
      });
      const json = (await res.json()) as { previewItems?: PreviewItem[]; error?: string };
      if (!res.ok) throw new Error(json.error ?? "Failed to load preview");

      const items = json.previewItems ?? [];
      setPreviewItems(items);
      // Collapse all items except the first
      const collapsed = new Set<number>();
      for (let i = 1; i < items.length; i++) {
        collapsed.add(i);
      }
      setCollapsedPreviewItems(collapsed);
      
      // Ensure at least one non-framework component is expanded in preview
      // Keep framework components (CMF*, CHANGES, MUTATION) collapsed
      const firstItem = items[0];
      if (firstItem) {
        const componentKeys = Object.keys(firstItem);
        const frameworkKeys = componentKeys.filter(k => {
          const mapping = mappings.find(m => m.componentKey === k);
          const tableName = mapping?.physicalTable || k;
          return /^(CMF|CHANGES|MUTATION)$/i.test(tableName);
        });
        setCollapsedPreviewComponents(new Set(frameworkKeys));
      }
      
      setMsg(`Preview loaded: showing first 5 of ${times} items`);
    } catch (e) {
      setMsg(e instanceof Error ? e.message : "Failed to load preview");
    } finally {
      setBusy(false);
    }
  }, [mappings, objectKey, runId, saveGenerators, times]);

  useEffect(() => {
    if (currentStep === "review") {
      contractLoadRequestedRef.current = false;
      previewLoadRequestedRef.current = false;
      void loadCapturedData();
    }
  }, [currentStep, loadCapturedData]);

  useEffect(() => {
    if (currentStep !== "configure") return;
    previewLoadRequestedRef.current = false;
    if (contractJson || contractLoadRequestedRef.current) return;
    contractLoadRequestedRef.current = true;
    void loadContract();
  }, [currentStep, contractJson, loadContract]);

  useEffect(() => {
    if (currentStep !== "preview") return;
    if (!contractJson || previewItems.length > 0 || previewLoadRequestedRef.current) return;
    previewLoadRequestedRef.current = true;
    void loadPreview();
  }, [currentStep, contractJson, previewItems.length, loadPreview]);

  useEffect(() => {
    if (mappings.length > 0 && currentStep === "configure") {
      void generateAllPreviews(mappings);
    }
  }, [mappings, currentStep, generateAllPreviews]);

  async function executeReplay() {
    setBusy(true);
    setMsg(null);
    try {
      const startTime = Date.now();
      const estimatedRate = 10; // items per second based on testing
      const estimatedDuration = times / estimatedRate;
      
      // Update progress message every second
      const progressInterval = setInterval(() => {
        const elapsed = (Date.now() - startTime) / 1000;
        const progress = Math.min(100, (elapsed / estimatedDuration) * 100);
        const estimatedItemsProcessed = Math.min(times, Math.floor(elapsed * estimatedRate));
        setMsg(`Processing ${times} items... ${elapsed.toFixed(0)}s elapsed, ~${estimatedItemsProcessed}/${times} items (${progress.toFixed(0)}%)`);
      }, 1000);
      
      try {
        const res = await fetch("/api/replay/domain", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ sourceRunId: runId, objectKey, times, commit }),
        });
        const json = (await res.json()) as { times?: number; replayRuns?: unknown[]; error?: string };
        if (!res.ok) throw new Error(json.error ?? "Failed to execute replay");

        clearInterval(progressInterval);
        
        const duration = ((Date.now() - startTime) / 1000).toFixed(1);
        const itemsPerSecond = (json.times ?? 0) / parseFloat(duration);
        
        setReplayResult({ totalItems: json.times ?? 0, replayRuns: json.replayRuns ?? [] });
        setMsg(
          commit
            ? `✓ Replay completed and committed: ${json.times} items created in ${duration}s (${itemsPerSecond.toFixed(1)} items/s)`
            : `✓ Replay completed (dry run): ${json.times} items created but rolled back in ${duration}s (${itemsPerSecond.toFixed(1)} items/s)`
        );
      } finally {
        clearInterval(progressInterval);
      }
    } catch (e) {
      setMsg(e instanceof Error ? e.message : "Failed to execute replay");
    } finally {
      setBusy(false);
    }
  }

  const includedTableCount = useMemo(() => {
    return Object.values(capturedData).filter((t) => t.rows.some((r) => !r.ExcludeFromReplay)).length;
  }, [capturedData]);

  const includedRowCount = useMemo(() => {
    return Object.values(capturedData).reduce(
      (sum, t) => sum + t.rows.filter((r) => !r.ExcludeFromReplay).length,
      0
    );
  }, [capturedData]);

  function goToStep(step: WizardStep) {
    const stepIndex = steps.findIndex((s) => s.id === step);
    if (stepIndex <= currentStepIndex + 1) {
      setCurrentStep(step);
      setMsg(null);
    }
  }

  return (
    <div className="w-full">
      <div className="mb-6">
        <h1 className="text-2xl font-bold" style={{ color: 'var(--foreground)' }}>Replay Wizard</h1>
        <p className="mt-2 text-sm" style={{ color: 'var(--text-secondary)' }}>
          Follow the steps to configure and execute your replay
        </p>
      </div>

      {/* Progress Steps */}
      <div className="mb-8 flex items-center justify-between">
        {steps.map((step, idx) => (
          <div key={step.id} className="flex flex-1 items-center">
            <button
              onClick={() => goToStep(step.id)}
              disabled={idx > currentStepIndex + 1}
              className="flex flex-col items-center disabled:opacity-40"
            >
              <div
                className="flex h-10 w-10 items-center justify-center rounded-full border-2 text-sm font-medium"
                style={{
                  borderColor: idx < currentStepIndex ? 'var(--success)' : idx === currentStepIndex ? 'var(--primary)' : 'var(--border)',
                  backgroundColor: idx < currentStepIndex ? 'var(--success)' : idx === currentStepIndex ? 'var(--primary)' : 'var(--background)',
                  color: idx < currentStepIndex || idx === currentStepIndex ? '#ffffff' : 'var(--text-muted)',
                  boxShadow: idx === currentStepIndex ? 'var(--shadow)' : 'none'
                }}
              >
                {idx < currentStepIndex ? "✓" : idx + 1}
              </div>
              <div className="mt-2 text-xs font-medium" style={{ color: 'var(--foreground)' }}>{step.label}</div>
            </button>
            {idx < steps.length - 1 && (
              <div
                className="mx-2 h-0.5 flex-1"
                style={{ backgroundColor: idx < currentStepIndex ? 'var(--success)' : 'var(--border)' }}
              />
            )}
          </div>
        ))}
      </div>

      {/* Step Content */}
      <div className="rounded-2xl border p-6" style={{ borderColor: 'var(--border)', backgroundColor: 'var(--surface)', boxShadow: 'var(--shadow)' }}>
        <h2 className="text-lg font-semibold" style={{ color: 'var(--foreground)' }}>
          {steps[currentStepIndex].label}
        </h2>
        <p className="mt-2 text-sm" style={{ color: 'var(--text-secondary)' }}>{steps[currentStepIndex].description}</p>

        {msg && (
          <div className="mt-4 rounded-xl p-4 text-sm" style={{ backgroundColor: 'var(--info-light)', color: 'var(--info)', border: '1px solid var(--info)' }}>{msg}</div>
        )}

        {/* Step 1: Review & Exclude */}
        {currentStep === "review" && (
          <div className="mt-6">
            <div className="mb-4 rounded-xl p-4" style={{ backgroundColor: 'var(--surface-hover)', border: '1px solid var(--border)' }}>
              <div className="flex items-center justify-between">
                <div>
                  <div className="text-sm font-medium" style={{ color: 'var(--foreground)' }}>
                    {includedTableCount} tables, {includedRowCount} rows included
                  </div>
                  <div className="mt-1 text-xs" style={{ color: 'var(--text-secondary)' }}>
                    Uncheck tables or rows you don&apos;t want to replay
                  </div>
                </div>
                <button
                  onClick={() => setCurrentStep("configure")}
                  disabled={busy || includedRowCount === 0}
                  className="h-10 rounded-xl bg-blue-600 px-6 text-sm font-medium text-white disabled:opacity-40"
                >
                  Next: Configure Transformations
                </button>
              </div>
            </div>

            <div className="space-y-2">
              {Object.entries(capturedData)
                .sort(([, a], [, b]) => a.dependencyLevel - b.dependencyLevel)
                .map(([tableName, tableData]) => {
                  const isExpanded = expandedTables.has(tableName);
                  const allExcluded = tableData.rows.every((r) => r.ExcludeFromReplay);
                  const someExcluded = tableData.rows.some((r) => r.ExcludeFromReplay);

                  return (
                    <div key={tableName} className="rounded-xl border" style={{ borderColor: 'var(--border)', backgroundColor: 'var(--background)' }}>
                      <div className="flex items-center gap-3 p-4">
                        <input
                          type="checkbox"
                          checked={!allExcluded}
                          onChange={(e) => void toggleTableExclusion(tableName, !e.target.checked)}
                          disabled={busy}
                          className="h-4 w-4"
                        />
                        <button
                          onClick={() =>
                            setExpandedTables((prev) => {
                              const next = new Set(prev);
                              if (next.has(tableName)) next.delete(tableName);
                              else next.add(tableName);
                              return next;
                            })
                          }
                          className="flex flex-1 items-center gap-2 text-left"
                        >
                          <span className="text-sm font-medium text-zinc-900">{tableName}</span>
                          <span className="text-xs text-zinc-500">
                            Level {tableData.dependencyLevel} · {tableData.rows.length} rows
                            {someExcluded && !allExcluded && " · Some excluded"}
                          </span>
                          <span className="ml-auto text-zinc-400">{isExpanded ? "▼" : "▶"}</span>
                        </button>
                      </div>

                      {isExpanded && (
                        <div className="border-t border-zinc-200 p-4">
                          <div className="space-y-2">
                            {tableData.rows.map((row) => (
                              <div
                                key={row.PkValue}
                                className="flex items-start gap-3 rounded-lg bg-zinc-50 p-3"
                              >
                                <input
                                  type="checkbox"
                                  checked={!row.ExcludeFromReplay}
                                  onChange={(e) =>
                                    void toggleRowExclusion(tableName, row.PkValue, !e.target.checked)
                                  }
                                  disabled={busy}
                                  className="mt-1 h-4 w-4"
                                />
                                <div className="flex-1">
                                  <div className="flex items-center gap-2">
                                    <span className="text-xs font-medium text-zinc-700">
                                      {row.PkColumn}: {row.PkValue}
                                    </span>
                                    {row.ChangeType && (
                                      <span
                                        className={`rounded px-1.5 py-0.5 text-xs font-medium ${
                                          row.ChangeType === "INSERT"
                                            ? "bg-green-100 text-green-700"
                                            : row.ChangeType === "UPDATE"
                                            ? "bg-yellow-100 text-yellow-700"
                                            : "bg-red-100 text-red-700"
                                        }`}
                                      >
                                        {row.ChangeType}
                                      </span>
                                    )}
                                  </div>
                                  <pre className="mt-1 max-h-20 overflow-auto text-xs text-zinc-600">
                                    {JSON.stringify(JSON.parse(row.RowJson), null, 2).substring(0, 200)}
                                    {row.RowJson.length > 200 && "..."}
                                  </pre>
                                </div>
                              </div>
                            ))}
                          </div>
                        </div>
                      )}
                    </div>
                  );
                })}
            </div>

            <div className="mt-6 flex justify-end">
              <button
                onClick={() => setCurrentStep("configure")}
                disabled={busy || includedRowCount === 0}
                className="h-10 rounded-xl bg-blue-600 px-6 text-sm font-medium text-white disabled:opacity-40"
              >
                Next: Configure Transformations
              </button>
            </div>
          </div>
        )}

        {/* Step 2: Configure */}
        {currentStep === "configure" && (
          <div className="mt-6">
            {!contractJson ? (
              <div>
                <p className="text-sm text-zinc-600">
                  Load the domain contract to configure field generators and transformations.
                </p>
                <button
                  onClick={() => void loadContract()}
                  disabled={busy}
                  className="mt-4 h-10 rounded-xl bg-zinc-900 px-6 text-sm font-medium text-white disabled:opacity-40"
                >
                  Load Contract
                </button>
              </div>
            ) : (
              <div>
                <ExpressionHelp />

                <div className="mt-6 mb-4 rounded-xl bg-zinc-50 p-4">
                  <div className="flex items-center justify-between">
                    <div>
                      <div className="text-sm font-medium text-zinc-900">Configure Field Generators</div>
                      <div className="mt-1 text-xs text-zinc-600">
                        Set generator expressions for each field. Fields appearing in multiple components use ctx() for consistency.
                      </div>
                    </div>
                    <button
                      onClick={() => setCurrentStep("preview")}
                      disabled={busy}
                      className="h-10 rounded-xl bg-blue-600 px-6 text-sm font-medium text-white disabled:opacity-40"
                    >
                      Next: Preview Results
                    </button>
                  </div>
                </div>

                <div className="space-y-4">
                  {(() => {
                    const groupedByComponent: Record<string, typeof mappings> = {};
                    for (const m of mappings) {
                      if (!groupedByComponent[m.componentKey]) {
                        groupedByComponent[m.componentKey] = [];
                      }
                      groupedByComponent[m.componentKey].push(m);
                    }

                    // Build available context variables from all fields across all components
                    const ctxVars = mappings
                      .filter((m) => !m.parentRelationship)
                      .map((m) => ({
                        name: m.fieldKey.toLowerCase(),
                        source: `${m.componentKey}.${m.fieldKey}`,
                        generator: m.gen,
                        example: previewValues[`${m.componentKey}.${m.fieldKey}`] || m.example,
                      }));
                    // Deduplicate by name, keep first occurrence
                    const seen = new Set<string>();
                    const availableContextVars = ctxVars.filter((v) => {
                      if (seen.has(v.name)) return false;
                      seen.add(v.name);
                      return true;
                    });

                    return Object.entries(groupedByComponent).map(([componentKey, fields]) => {
                      const isFrameworkComponent = /^(CMF|CHANGES|MUTATION)$/i.test(fields[0]?.physicalTable || '');
                      const isCollapsed = collapsedConfigComponents.has(componentKey);
                      const patternCount = fields.filter(f => detectedPatterns[`${f.componentKey}.${f.fieldKey.toLowerCase()}`]).length;

                      return (
                      <div key={componentKey} className="rounded-lg border border-zinc-200 bg-white">
                        <div
                          className="border-b border-zinc-200 bg-zinc-50 px-3 py-2 cursor-pointer select-none flex items-center justify-between"
                          onClick={() => setCollapsedConfigComponents(prev => {
                            const next = new Set(prev);
                            if (next.has(componentKey)) next.delete(componentKey); else next.add(componentKey);
                            return next;
                          })}
                        >
                          <div>
                            <h3 className="text-sm font-semibold text-zinc-900">
                              {fields[0]?.componentDisplayName || componentKey}
                            </h3>
                            <div className="text-xs text-zinc-500">
                              <span className="font-mono text-zinc-600">{componentKey}</span>
                              {' • '}
                              Table: <span className="font-mono text-zinc-700">{fields[0]?.physicalTable || 'N/A'}</span>
                              {' • '}
                              {fields.length} field{fields.length !== 1 ? "s" : ""}
                            </div>
                          </div>
                          <div className="flex items-center gap-2">
                            {patternCount > 0 && (
                              <span className="text-[10px] bg-purple-100 text-purple-700 px-2 py-0.5 rounded font-medium">
                                {patternCount} auto-linked
                              </span>
                            )}
                            {isFrameworkComponent && (
                              <span className="text-[10px] bg-zinc-200 text-zinc-600 px-2 py-0.5 rounded font-medium">Framework</span>
                            )}
                            <span className="text-zinc-400 text-sm">{isCollapsed ? '▸' : '▾'}</span>
                          </div>
                        </div>
                        {!isCollapsed && (
                        <div className="overflow-x-auto">
                          <table className="w-full text-xs border-collapse">
                            <thead>
                              <tr className="bg-zinc-100">
                                <th className="text-left p-2 border border-zinc-200 font-medium w-[180px]">Field</th>
                                <th className="text-left p-2 border border-zinc-200 font-medium w-[150px]">Original Value</th>
                                <th className="text-left p-2 border border-zinc-200 font-medium w-[150px]">Preview Value</th>
                                <th className="text-left p-2 border border-zinc-200 font-medium">Generator Expression</th>
                              </tr>
                            </thead>
                            <tbody>
                              {fields.map((m) => {
                                // Use m.example as original value (it contains captured data)
                                const originalValue = m.example || '';
                                
                                // Detect FK/relationship fields via API-provided relationship data
                                const isRelationshipField = !!m.parentRelationship;
                                
                                // Determine preview value based on generator
                                const previewKey = `${m.componentKey}.${m.fieldKey}`;
                                let previewValue = '';
                                let previewClass = 'text-zinc-700';
                                
                                // Check if field has been modified from default ctx()
                                const defaultGen = `ctx(${m.fieldKey.toLowerCase()})`;
                                const isModified = m.gen && m.gen !== defaultGen && !m.gen.includes('ctx(');
                                const detectedPattern = detectedPatterns[`${m.componentKey}.${m.fieldKey.toLowerCase()}`];
                                
                                if (isRelationshipField) {
                                  previewValue = 'will be generated';
                                  previewClass = 'text-zinc-400 italic';
                                } else if (previewValues[previewKey]) {
                                  // Show computed preview value (works for both ctx() and other generators)
                                  previewValue = previewValues[previewKey];
                                  previewClass = m.gen?.includes('ctx(') ? 'text-blue-600' : 'text-green-600';
                                } else if (m.gen?.includes('ctx(')) {
                                  // ctx() with no computed preview yet — show original
                                  previewValue = originalValue;
                                  previewClass = 'text-blue-600';
                                } else if (m.gen) {
                                  // Has generator but no preview yet
                                  previewValue = '...';
                                  previewClass = 'text-zinc-400 italic';
                                } else {
                                  // No generator, will use original value
                                  previewValue = originalValue;
                                  previewClass = 'text-zinc-600';
                                }
                                
                                return (
                                  <tr key={m.fieldKey} className={isRelationshipField ? 'bg-amber-50' : detectedPattern ? 'bg-purple-50' : isModified ? 'bg-yellow-50' : ''}>
                                    <td className="p-2 border border-zinc-200">
                                      <div className="flex items-baseline gap-2">
                                        <span className="font-medium text-zinc-700 truncate">{m.fieldKey}</span>
                                        <span className="text-[10px] text-zinc-400">{m.dataType}</span>
                                        {isRelationshipField && (
                                          <span className="text-[10px] text-amber-600 font-semibold">FK</span>
                                        )}
                                        {detectedPattern && (
                                          <span className="text-[10px] text-purple-700 font-semibold" title={`Auto-detected: ${detectedPattern.expression} (${detectedPattern.pattern})`}>
                                            LINKED
                                          </span>
                                        )}
                                        {isModified && !detectedPattern && (
                                          <span className="text-[10px] text-yellow-700 font-semibold">MODIFIED</span>
                                        )}
                                      </div>
                                    </td>
                                    <td className="p-2 border border-zinc-200 font-mono text-zinc-600 max-w-[150px] truncate" title={originalValue}>
                                      {originalValue || <span className="text-zinc-400 italic">null</span>}
                                    </td>
                                    <td className={`p-2 border border-zinc-200 font-mono max-w-[150px] truncate ${previewClass}`} title={previewValue}>
                                      {previewValue || <span className="text-zinc-400 italic">null</span>}
                                    </td>
                                    <td className="p-2 border border-zinc-200">
                                      {isRelationshipField ? (
                                        <div className="text-xs text-amber-700 italic px-2 py-1">
                                          {m.parentRelationship
                                            ? <>Mapped from <span className="font-mono font-semibold not-italic">{m.parentRelationship}</span></>
                                            : 'Auto-remapped (FK)'
                                          }
                                        </div>
                                      ) : (
                                        <GeneratorPicker
                                          fieldKey={m.fieldKey}
                                          dataType={m.dataType}
                                          currentGen={m.gen}
                                          originalValue={originalValue}
                                          availableContextVars={availableContextVars}
                                          onChange={async (expression) => {
                                            const updated = mappings.map((x) =>
                                              x.componentKey === m.componentKey && x.fieldKey === m.fieldKey
                                                ? { ...x, gen: expression }
                                                : x
                                            );
                                            setMappings(updated);
                                            
                                            // Mark this field as changed for reactive resemblance detection
                                            if (expression && !expression.includes('ctx(')) {
                                              setChangedFieldKey(`${m.componentKey}.${m.fieldKey}`);
                                            } else {
                                              // User changed back to ctx() - clear patterns
                                              setDetectedPatterns({});
                                              setChangedFieldKey(null);
                                            }
                                            
                                            // Re-evaluate ALL previews progressively so cross-field ctx() refs update
                                            // After preview generation, the useEffect will trigger resemblance detection
                                            void generateAllPreviews(updated);
                                          }}
                                        />
                                      )}
                                    </td>
                                  </tr>
                                );
                              })}
                            </tbody>
                          </table>
                        </div>
                        )}
                      </div>
                      );
                    });
                  })()}
                </div>

                <div className="mt-6">
                  <label className="text-sm font-medium text-zinc-900">Number of items to create</label>
                  <input
                    type="number"
                    value={times}
                    onChange={(e) => setTimes(Math.max(1, parseInt(e.target.value) || 1))}
                    min="1"
                    disabled={busy}
                    className="mt-2 h-10 w-full rounded-xl border border-zinc-300 px-4 text-sm"
                  />
                </div>

                <div className="mt-6 flex justify-between">
                  <button
                    onClick={() => setCurrentStep("review")}
                    disabled={busy}
                    className="h-10 rounded-xl border border-zinc-300 px-6 text-sm font-medium text-zinc-900 disabled:opacity-40"
                  >
                    Back
                  </button>
                  <button
                    onClick={() => setCurrentStep("preview")}
                    disabled={busy}
                    className="h-10 rounded-xl bg-blue-600 px-6 text-sm font-medium text-white disabled:opacity-40"
                  >
                    Next: Preview Results
                  </button>
                </div>
              </div>
            )}
          </div>
        )}

        {/* Step 3: Preview */}
        {currentStep === "preview" && (
          <div className="mt-6">
            {previewItems.length === 0 ? (
              <div>
                <p className="text-sm text-zinc-600">
                  Preview what will be created before executing the replay.
                </p>
                <button
                  onClick={() => void loadPreview()}
                  disabled={busy}
                  className="mt-4 h-10 rounded-xl bg-zinc-900 px-6 text-sm font-medium text-white disabled:opacity-40"
                >
                  Load Preview
                </button>
              </div>
            ) : (
              <div>
                <div className="mb-4 rounded-xl bg-zinc-50 p-4">
                  <div className="flex items-center justify-between">
                    <div>
                      <div className="text-sm font-medium text-zinc-900">
                        Preview: First 5 of {times} items
                      </div>
                      <div className="mt-1 text-xs text-zinc-600">
                        Review the generated data before executing
                      </div>
                    </div>
                    <button
                      onClick={() => setCurrentStep("execute")}
                      disabled={busy}
                      className="h-10 rounded-xl bg-blue-600 px-6 text-sm font-medium text-white disabled:opacity-40"
                    >
                      Next: Execute Replay
                    </button>
                  </div>
                </div>

                <div className="space-y-4">
                  {previewItems.map((item, idx) => {
                    const isCollapsed = collapsedPreviewItems.has(idx);
                    return (
                    <div key={idx} className="rounded-xl border border-zinc-200">
                      <div
                        className="p-4 cursor-pointer select-none flex items-center justify-between bg-zinc-50"
                        onClick={() => setCollapsedPreviewItems(prev => {
                          const next = new Set(prev);
                          if (next.has(idx)) next.delete(idx); else next.add(idx);
                          return next;
                        })}
                      >
                        <div className="text-sm font-medium text-zinc-900">Item {idx + 1}</div>
                        <span className="text-zinc-400 text-sm">{isCollapsed ? '▸' : '▾'}</span>
                      </div>
                      {!isCollapsed && (
                      <div className="p-4">
                      
                      {Object.entries(item).map(([componentKey, fields]) => {
                        // Get table name from mappings
                        const mapping = mappings.find(m => m.componentKey === componentKey);
                        const tableName = mapping?.physicalTable || componentKey;
                        const isFrameworkComponent = /^(CMF|CHANGES|MUTATION)$/i.test(tableName);
                        const isCollapsed = collapsedPreviewComponents.has(componentKey);
                        
                        return (
                        <div key={componentKey} className="mb-4 rounded-lg border border-zinc-200 bg-white">
                          <div
                            className="bg-zinc-50 px-3 py-2 cursor-pointer select-none flex items-center justify-between"
                            onClick={() => setCollapsedPreviewComponents(prev => {
                              const next = new Set(prev);
                              if (next.has(componentKey)) next.delete(componentKey); else next.add(componentKey);
                              return next;
                            })}
                          >
                            <div className="text-xs font-semibold text-zinc-700 uppercase">
                              {componentKey}
                              <span className="ml-2 text-[10px] font-normal text-zinc-500">
                                (Table: {tableName})
                              </span>
                            </div>
                            <div className="flex items-center gap-2">
                              {isFrameworkComponent && (
                                <span className="text-[10px] bg-zinc-200 text-zinc-600 px-2 py-0.5 rounded font-medium">Framework</span>
                              )}
                              <span className="text-zinc-400 text-sm">{isCollapsed ? '▸' : '▾'}</span>
                            </div>
                          </div>
                          {!isCollapsed && (
                          <div className="overflow-x-auto">
                            <table className="w-full text-xs border-collapse table-fixed">
                              <colgroup>
                                <col style={{ width: '180px' }} />
                                <col style={{ width: '200px' }} />
                                <col style={{ width: '200px' }} />
                                <col />
                              </colgroup>
                              <thead>
                                <tr className="bg-zinc-100">
                                  <th className="text-left p-2 border border-zinc-200 font-medium">Field</th>
                                  <th className="text-left p-2 border border-zinc-200 font-medium">Original</th>
                                  <th className="text-left p-2 border border-zinc-200 font-medium">Generated</th>
                                  <th className="text-left p-2 border border-zinc-200 font-medium">Generator</th>
                                </tr>
                              </thead>
                              <tbody>
                                {Object.entries(fields as Record<string, PreviewFieldData>).map(([fieldKey, fieldData]) => {
                                  const data = fieldData;
                                  const isSame = data.isSame;
                                  const usesCtx = data.usesCtx;
                                  
                                  // Detect FK/relationship fields via API-provided relationship data
                                  const isRelationshipField = !!data.parentRelationship;
                                  
                                  // Check if field has been modified from default ctx()
                                  const defaultGen = `ctx(${fieldKey.toLowerCase()})`;
                                  const isModified = data.generator && data.generator !== defaultGen && !usesCtx;
                                  
                                  // Visual hierarchy: unchanged (green) > changed (yellow) > FK remapped (muted amber)
                                  let rowClass = '';
                                  if (isRelationshipField) {
                                    rowClass = 'bg-amber-50/40'; // Muted amber for FK remapping (expected)
                                  } else if (isSame) {
                                    rowClass = 'bg-green-50'; // Green for unchanged
                                  } else if (!isSame && data.original !== null) {
                                    rowClass = 'bg-yellow-100 font-medium'; // Bright yellow for changed values
                                  } else if (isModified) {
                                    rowClass = 'bg-yellow-50';
                                  }
                                  
                                  return (
                                    <tr key={fieldKey} className={rowClass}>
                                      <td className="p-2 border border-zinc-200 font-mono truncate" title={fieldKey}>
                                        {fieldKey}
                                        {isRelationshipField && <span className="ml-1 text-[10px] text-amber-600 font-semibold">FK</span>}
                                        {isModified && <span className="ml-1 text-[10px] text-yellow-700 font-semibold">MODIFIED</span>}
                                      </td>
                                      <td className="p-2 border border-zinc-200 font-mono text-zinc-600 truncate" title={data.original || ''}>
                                        {data.original ?? <span className="text-zinc-400 italic">null</span>}
                                      </td>
                                      <td className="p-2 border border-zinc-200 font-mono truncate" title={data.generated || ''}>
                                        {isRelationshipField ? (
                                          <span className="text-zinc-400 italic">will be generated</span>
                                        ) : (
                                          data.generated ?? <span className="text-zinc-400 italic">null</span>
                                        )}
                                      </td>
                                      <td className="p-2 border border-zinc-200 text-zinc-500 font-mono text-[10px] truncate" title={data.generator || ''}>
                                        {isRelationshipField ? (
                                          <span className="text-amber-700 italic">
                                            {data.parentRelationship
                                              ? <>Mapped from <span className="font-semibold not-italic">{data.parentRelationship}</span></>
                                              : 'auto-remapped'
                                            }
                                          </span>
                                        ) : data.generator ? (
                                          <span className={usesCtx ? 'text-blue-600 font-semibold' : ''}>
                                            {data.generator}
                                          </span>
                                        ) : (
                                          <span className="text-zinc-400 italic">-</span>
                                        )}
                                      </td>
                                    </tr>
                                  );
                                })}
                              </tbody>
                            </table>
                          </div>
                          )}
                        </div>
                        );
                      })}
                      </div>
                      )}
                    </div>
                    );
                  })}
                </div>

                <div className="mt-6 flex justify-between">
                  <button
                    onClick={() => setCurrentStep("configure")}
                    disabled={busy}
                    className="h-10 rounded-xl border border-zinc-300 px-6 text-sm font-medium text-zinc-900 disabled:opacity-40"
                  >
                    Back
                  </button>
                  <button
                    onClick={() => setCurrentStep("execute")}
                    disabled={busy}
                    className="h-10 rounded-xl bg-blue-600 px-6 text-sm font-medium text-white disabled:opacity-40"
                  >
                    Next: Execute Replay
                  </button>
                </div>
              </div>
            )}
          </div>
        )}

        {/* Step 4: Execute */}
        {currentStep === "execute" && (
          <div className="mt-6">
            {!replayResult ? (
              <div>
                <div className="mb-4 rounded-xl bg-yellow-50 p-4">
                  <div className="text-sm font-medium text-yellow-900">Ready to Execute</div>
                  <div className="mt-1 text-xs text-yellow-700">
                    You&apos;re about to create {times} items. Start with a dry run (no commit) to verify
                    everything works.
                  </div>
                </div>

                <label className="flex items-center gap-2 text-sm text-zinc-900">
                  <input
                    type="checkbox"
                    checked={commit}
                    onChange={(e) => setCommit(e.target.checked)}
                    disabled={busy}
                    className="h-4 w-4"
                  />
                  Commit changes (uncheck for dry run)
                </label>

                <div className="mt-6 flex justify-between">
                  <button
                    onClick={() => setCurrentStep("preview")}
                    disabled={busy}
                    className="h-10 rounded-xl border border-zinc-300 px-6 text-sm font-medium text-zinc-900 disabled:opacity-40"
                  >
                    Back
                  </button>
                  <button
                    onClick={() => void executeReplay()}
                    disabled={busy}
                    className="h-10 rounded-xl bg-green-600 px-6 text-sm font-medium text-white disabled:opacity-40"
                  >
                    {commit ? "Execute & Commit" : "Execute Dry Run"}
                  </button>
                </div>
              </div>
            ) : (
              <div>
                <div className="rounded-xl bg-green-50 p-4">
                  <div className="text-sm font-medium text-green-900">
                    {commit ? "✓ Replay Completed" : "✓ Dry Run Completed"}
                  </div>
                  <div className="mt-1 text-xs text-green-700">
                    {replayResult.totalItems} items processed
                    {!commit && " (changes rolled back)"}
                  </div>
                </div>

                {!commit && (
                  <div className="mt-4">
                    <button
                      onClick={() => {
                        setCommit(true);
                        setReplayResult(null);
                      }}
                      disabled={busy}
                      className="h-10 rounded-xl bg-green-600 px-6 text-sm font-medium text-white disabled:opacity-40"
                    >
                      Run Again with Commit
                    </button>
                  </div>
                )}
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
