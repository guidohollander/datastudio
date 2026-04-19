"use client";

import { useCallback, useEffect, useState } from "react";

type SequenceStep = {
  stepNumber: number;
  action: string;
  tableName: string;
  pkColumn: string;
  pkValue: number;
  changeType: string | null;
  dependencyLevel: number;
  foreignKeys: Array<{ column: string; referencesTable: string; referencesValue: number | null }>;
};

export default function SequenceDiagramViewer({ runId }: { runId: string }) {
  const [steps, setSteps] = useState<SequenceStep[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [expandedSteps, setExpandedSteps] = useState<Set<number>>(new Set());

  const loadSequence = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(`/api/runs/${encodeURIComponent(runId)}/sequence`);
      const json = (await res.json()) as { steps?: SequenceStep[]; error?: string };
      if (!res.ok) throw new Error(json.error ?? "Failed to load sequence");
      setSteps(json.steps ?? []);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to load sequence");
    } finally {
      setLoading(false);
    }
  }, [runId]);

  useEffect(() => {
    void loadSequence();
  }, [loadSequence]);

  function toggleStep(stepNumber: number) {
    setExpandedSteps((prev) => {
      const next = new Set(prev);
      if (next.has(stepNumber)) next.delete(stepNumber);
      else next.add(stepNumber);
      return next;
    });
  }

  if (loading) {
    return <div className="text-sm text-zinc-600">Loading sequence diagram...</div>;
  }

  if (error) {
    return <div className="text-sm text-red-600">Error: {error}</div>;
  }

  if (steps.length === 0) {
    return <div className="text-sm text-zinc-600">No data captured yet.</div>;
  }

  // Group by dependency level for visual separation
  const stepsByLevel = steps.reduce((acc, step) => {
    if (!acc[step.dependencyLevel]) acc[step.dependencyLevel] = [];
    acc[step.dependencyLevel].push(step);
    return acc;
  }, {} as Record<number, SequenceStep[]>);

  const levels = Object.keys(stepsByLevel)
    .map(Number)
    .sort((a, b) => a - b);

  return (
    <div className="space-y-6">
      <div className="rounded-xl bg-zinc-50 p-4">
        <div className="text-sm font-medium text-zinc-900">Write Sequence</div>
        <div className="mt-1 text-xs text-zinc-600">
          {steps.length} operations in dependency order. Click to expand and see foreign key references.
        </div>
      </div>

      {levels.map((level) => (
        <div key={level} className="space-y-2">
          <div className="flex items-center gap-2">
            <div className="h-px flex-1 bg-zinc-200" />
            <div className="rounded-full bg-zinc-100 px-3 py-1 text-xs font-medium text-zinc-700">
              Level {level} {level === 0 ? "(Root)" : ""}
            </div>
            <div className="h-px flex-1 bg-zinc-200" />
          </div>

          <div className="space-y-1">
            {stepsByLevel[level].map((step) => {
              const isExpanded = expandedSteps.has(step.stepNumber);
              const hasForeignKeys = step.foreignKeys.length > 0;

              return (
                <div
                  key={step.stepNumber}
                  className="rounded-lg border border-zinc-200 bg-white transition-all hover:border-zinc-300"
                >
                  <button
                    onClick={() => toggleStep(step.stepNumber)}
                    className="flex w-full items-center gap-3 p-3 text-left"
                  >
                    <div className="flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-full bg-zinc-100 text-xs font-medium text-zinc-700">
                      {step.stepNumber}
                    </div>

                    <div className="flex-1">
                      <div className="flex items-center gap-2">
                        <span
                          className={`rounded px-2 py-0.5 text-xs font-medium ${
                            step.action === "INSERT"
                              ? "bg-green-100 text-green-700"
                              : step.action === "UPDATE"
                              ? "bg-yellow-100 text-yellow-700"
                              : "bg-red-100 text-red-700"
                          }`}
                        >
                          {step.action}
                        </span>
                        <span className="text-sm font-medium text-zinc-900">{step.tableName}</span>
                      </div>
                      <div className="mt-1 text-xs text-zinc-600">
                        {step.pkColumn} = <span className="font-mono font-medium">{step.pkValue}</span>
                        {hasForeignKeys && (
                          <span className="ml-2 text-zinc-400">
                            • {step.foreignKeys.length} FK reference{step.foreignKeys.length !== 1 ? "s" : ""}
                          </span>
                        )}
                      </div>
                    </div>

                    {hasForeignKeys && (
                      <div className="text-zinc-400">{isExpanded ? "▼" : "▶"}</div>
                    )}
                  </button>

                  {isExpanded && hasForeignKeys && (
                    <div className="border-t border-zinc-200 bg-zinc-50 p-3">
                      <div className="text-xs font-medium text-zinc-700 mb-2">Foreign Key References:</div>
                      <div className="space-y-2">
                        {step.foreignKeys.map((fk, idx) => (
                          <div
                            key={idx}
                            className="flex items-center gap-2 rounded-lg bg-white p-2 text-xs"
                          >
                            <div className="flex-1">
                              <span className="font-medium text-zinc-900">{fk.column}</span>
                              <span className="mx-1 text-zinc-400">→</span>
                              <span className="text-zinc-700">{fk.referencesTable}</span>
                            </div>
                            <div className="font-mono text-zinc-600">
                              {fk.referencesValue !== null ? fk.referencesValue : "NULL"}
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
        </div>
      ))}

      <div className="rounded-xl border border-zinc-200 bg-white p-4">
        <div className="text-xs font-medium text-zinc-700">Legend</div>
        <div className="mt-2 flex flex-wrap gap-4 text-xs">
          <div className="flex items-center gap-2">
            <div className="h-6 w-6 rounded-full bg-zinc-100 text-center text-xs leading-6">N</div>
            <span className="text-zinc-600">Step number (write order)</span>
          </div>
          <div className="flex items-center gap-2">
            <span className="rounded bg-green-100 px-2 py-0.5 text-green-700">INSERT</span>
            <span className="text-zinc-600">New row</span>
          </div>
          <div className="flex items-center gap-2">
            <span className="rounded bg-yellow-100 px-2 py-0.5 text-yellow-700">UPDATE</span>
            <span className="text-zinc-600">Modified row</span>
          </div>
          <div className="flex items-center gap-2">
            <span className="rounded bg-red-100 px-2 py-0.5 text-red-700">DELETE</span>
            <span className="text-zinc-600">Deleted row</span>
          </div>
        </div>
      </div>
    </div>
  );
}
