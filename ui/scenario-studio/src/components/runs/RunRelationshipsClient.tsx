"use client";

import { useEffect, useState } from "react";

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

export default function RunRelationshipsClient({ runId }: { runId: string }) {
  const [relationships, setRelationships] = useState<Relationship[]>([]);
  const [tableOrder, setTableOrder] = useState<TableOrder[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  async function loadRelationships() {
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
    void loadRelationships();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [runId]);

  if (loading) {
    return <div className="text-sm text-zinc-600">Loading relationships...</div>;
  }

  if (error) {
    return <div className="rounded-xl bg-red-50 px-4 py-3 text-sm text-red-900">{error}</div>;
  }

  return (
    <div className="space-y-6">
      <div className="overflow-hidden rounded-2xl border border-black/10 bg-white shadow-sm">
        <div className="border-b border-black/5 px-6 py-4">
          <div className="text-sm font-semibold text-zinc-900">Table replay order</div>
          <div className="mt-1 text-xs text-zinc-600">
            Tables ordered by dependency level (parents first). Level 0 = no dependencies.
          </div>
        </div>

        <div className="divide-y divide-black/5">
          {tableOrder.length > 0 ? (
            tableOrder.map((t) => (
              <div key={t.TableName} className="flex items-center justify-between px-6 py-3">
                <div className="font-mono text-sm text-zinc-900">{t.TableName}</div>
                <div className="rounded-lg bg-zinc-100 px-2 py-1 text-xs font-medium text-zinc-700">
                  Level {t.DependencyLevel}
                </div>
              </div>
            ))
          ) : (
            <div className="px-6 py-6 text-sm text-zinc-600">No tables captured yet.</div>
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
          {relationships.length > 0 ? (
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
            <div className="px-6 py-6 text-sm text-zinc-600">No relationships discovered yet.</div>
          )}
        </div>
      </div>
    </div>
  );
}
