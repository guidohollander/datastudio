"use client";

import { useCallback, useEffect, useState } from "react";
import { AppLink } from "@/lib/links";

type Run = {
  RunID: string;
  StartedAt: string;
  EndedAt: string | null;
  Notes: string | null;
};

type Relationship = {
  RelationshipID: number;
  ParentTable: string;
  ParentColumn: string;
  ChildTable: string;
  ChildColumn: string;
  Source: string;
  Notes: string | null;
};

type TableOrder = {
  TableName: string;
  DependencyLevel: number;
};

export default function ScenarioDetailClient({
  scenarioId,
  scenarioName,
}: {
  scenarioId: number;
  scenarioName: string;
}) {
  const [runs, setRuns] = useState<Run[]>([]);
  const [selectedRunId, setSelectedRunId] = useState<string | null>(null);
  const [relationships, setRelationships] = useState<Relationship[]>([]);
  const [tableOrder, setTableOrder] = useState<TableOrder[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadRuns = useCallback(async () => {
    try {
      const res = await fetch(`/api/scenarios/${scenarioId}/runs`);
      const json = (await res.json()) as { runs?: Run[]; error?: string };
      if (!res.ok) throw new Error(json.error ?? "Failed to load runs");
      setRuns(json.runs ?? []);
      if (json.runs && json.runs.length > 0) {
        setSelectedRunId(json.runs[0].RunID);
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to load runs");
    }
  }, [scenarioId]);

  async function loadRelationships(runId: string) {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(`/api/runs/${encodeURIComponent(runId)}/relationships`);
      const json = (await res.json()) as {
        relationships?: Relationship[];
        tableOrder?: TableOrder[];
        error?: string;
      };
      if (!res.ok) throw new Error(json.error ?? "Failed to load relationships");
      setRelationships(json.relationships ?? []);
      setTableOrder(json.tableOrder ?? []);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to load relationships");
      setRelationships([]);
      setTableOrder([]);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadRuns();
  }, [loadRuns]);

  useEffect(() => {
    if (selectedRunId) {
      void loadRelationships(selectedRunId);
    }
  }, [selectedRunId]);

  return (
    <div className="space-y-6">
      <div className="overflow-hidden rounded-2xl border border-black/10 bg-white shadow-sm">
        <div className="border-b border-black/5 px-6 py-4">
          <div className="text-sm font-semibold text-zinc-900">Runs</div>
          <div className="mt-1 text-xs text-zinc-600">Select a run to view discovered relationships and table order.</div>
        </div>

        <div className="divide-y divide-black/5">
          {runs.map((r) => (
            <button
              key={r.RunID}
              onClick={() => setSelectedRunId(r.RunID)}
              className={`block w-full px-6 py-4 text-left transition-colors ${
                selectedRunId === r.RunID ? "bg-zinc-50" : "hover:bg-zinc-50/50"
              }`}
            >
              <div className="flex items-start justify-between gap-4">
                <div className="min-w-0 flex-1">
                  <div className="truncate font-mono text-xs text-zinc-700">{r.RunID}</div>
                  <div className="mt-1 truncate text-xs text-zinc-500">{r.Notes ?? ""}</div>
                </div>
                <div className="shrink-0 text-right text-xs text-zinc-600">
                  <div>Started: {new Date(r.StartedAt).toLocaleString()}</div>
                  {r.EndedAt ? (
                    <div className="text-emerald-700">Ended: {new Date(r.EndedAt).toLocaleString()}</div>
                  ) : (
                    <div className="text-red-700">Capturing...</div>
                  )}
                </div>
              </div>
            </button>
          ))}

          {runs.length === 0 ? (
            <div className="px-6 py-6 text-sm text-zinc-600">
              No runs yet.{" "}
              <AppLink href={`/capture/start?scenarioName=${encodeURIComponent(scenarioName)}`} className="text-zinc-900 underline">
                Start a capture
              </AppLink>
            </div>
          ) : null}
        </div>
      </div>

      {selectedRunId && (
        <>
          <div className="overflow-hidden rounded-2xl border border-black/10 bg-white shadow-sm">
            <div className="border-b border-black/5 px-6 py-4">
              <div className="text-sm font-semibold text-zinc-900">Table replay order</div>
              <div className="mt-1 text-xs text-zinc-600">
                Tables ordered by dependency level (parents first). Level 0 = no dependencies.
              </div>
            </div>

            <div className="divide-y divide-black/5">
              {loading ? (
                <div className="px-6 py-6 text-sm text-zinc-600">Loading...</div>
              ) : tableOrder.length > 0 ? (
                tableOrder.map((t) => (
                  <div key={t.TableName} className="flex items-center justify-between px-6 py-3">
                    <div className="font-mono text-sm text-zinc-900">{t.TableName}</div>
                    <div className="rounded-lg bg-zinc-100 px-2 py-1 text-xs font-medium text-zinc-700">
                      Level {t.DependencyLevel}
                    </div>
                  </div>
                ))
              ) : (
                <div className="px-6 py-6 text-sm text-zinc-600">No tables captured yet. End capture to see table order.</div>
              )}
            </div>
          </div>

          <div className="overflow-hidden rounded-2xl border border-black/10 bg-white shadow-sm">
            <div className="border-b border-black/5 px-6 py-4">
              <div className="text-sm font-semibold text-zinc-900">Discovered relationships</div>
              <div className="mt-1 text-xs text-zinc-600">
                Foreign key relationships inferred from captured data. These drive replay order and FK remapping.
              </div>
            </div>

            <div className="divide-y divide-black/5">
              {loading ? (
                <div className="px-6 py-6 text-sm text-zinc-600">Loading...</div>
              ) : relationships.length > 0 ? (
                relationships.map((rel) => (
                  <div key={rel.RelationshipID} className="px-6 py-3">
                    <div className="flex items-center gap-2 text-sm">
                      <span className="font-mono text-zinc-900">{rel.ParentTable}</span>
                      <span className="text-zinc-400">→</span>
                      <span className="font-mono text-zinc-900">{rel.ChildTable}</span>
                      <span className="text-xs text-zinc-500">
                        ({rel.ChildColumn} → {rel.ParentColumn})
                      </span>
                    </div>
                    <div className="mt-1 text-xs text-zinc-500">
                      Source: {rel.Source} {rel.Notes ? `• ${rel.Notes}` : ""}
                    </div>
                  </div>
                ))
              ) : (
                <div className="px-6 py-6 text-sm text-zinc-600">
                  No relationships discovered yet. End capture to infer relationships.
                </div>
              )}
            </div>
          </div>

          {error ? <div className="rounded-xl bg-red-50 px-4 py-3 text-sm text-red-900">{error}</div> : null}

          <div className="flex flex-wrap items-center gap-3">
            <AppLink
              href={`/runs/${encodeURIComponent(selectedRunId)}`}
              className="h-10 rounded-xl bg-zinc-900 px-4 text-sm font-medium text-white hover:bg-zinc-800"
            >
              Open Run Hub
            </AppLink>
            <AppLink
              href={`/api/contract?runId=${encodeURIComponent(selectedRunId)}`}
              target="_blank"
              className="h-10 rounded-xl border border-black/10 bg-white px-4 text-sm font-medium text-zinc-900 hover:bg-zinc-50"
            >
              View contract JSON
            </AppLink>
          </div>
        </>
      )}
    </div>
  );
}
