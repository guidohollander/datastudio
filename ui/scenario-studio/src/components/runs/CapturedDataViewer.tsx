"use client";

import { useEffect, useState } from "react";

type CapturedRow = {
  PkColumn: string;
  PkValue: number;
  CapturedAt: string;
  RowJson: string;
  ChangeType: string | null;
};

type CapturedData = Record<
  string,
  {
    dependencyLevel: number;
    rows: CapturedRow[];
  }
>;

export default function CapturedDataViewer({ runId }: { runId: string }) {
  const [data, setData] = useState<CapturedData>({});
  const [expandedTables, setExpandedTables] = useState<Set<string>>(new Set());
  const [expandedRows, setExpandedRows] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  async function loadData() {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(`/api/runs/${encodeURIComponent(runId)}/captured-data`);
      const json = (await res.json()) as { capturedData?: CapturedData; error?: string };
      if (!res.ok) throw new Error(json.error ?? "Failed to load captured data");
      setData(json.capturedData ?? {});
      
      // Auto-expand first table
      const tables = Object.keys(json.capturedData ?? {});
      if (tables.length > 0) {
        setExpandedTables(new Set([tables[0]]));
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to load captured data");
      setData({});
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadData();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [runId]);

  function toggleTable(table: string) {
    const next = new Set(expandedTables);
    if (next.has(table)) {
      next.delete(table);
    } else {
      next.add(table);
    }
    setExpandedTables(next);
  }

  function toggleRow(key: string) {
    const next = new Set(expandedRows);
    if (next.has(key)) {
      next.delete(key);
    } else {
      next.add(key);
    }
    setExpandedRows(next);
  }

  if (loading) {
    return <div className="text-sm text-zinc-600">Loading captured data...</div>;
  }

  if (error) {
    return <div className="rounded-xl bg-red-50 px-4 py-3 text-sm text-red-900">{error}</div>;
  }

  const tables = Object.keys(data).sort((a, b) => {
    const levelA = data[a].dependencyLevel;
    const levelB = data[b].dependencyLevel;
    if (levelA !== levelB) return levelA - levelB;
    return a.localeCompare(b);
  });

  if (tables.length === 0) {
    return <div className="text-sm text-zinc-600">No data captured yet. End capture to see captured rows.</div>;
  }

  const totalRows = tables.reduce((sum, t) => sum + data[t].rows.length, 0);

  return (
    <div className="space-y-3">
      <div className="text-xs text-zinc-600">
        {tables.length} {tables.length === 1 ? "table" : "tables"}, {totalRows} {totalRows === 1 ? "row" : "rows"} captured
      </div>

      {tables.map((table) => {
        const tableData = data[table];
        const rows = tableData.rows;
        const isExpanded = expandedTables.has(table);

        return (
          <div key={table} className="overflow-hidden rounded-xl border border-black/10 bg-white">
            <button
              onClick={() => toggleTable(table)}
              className="flex w-full items-center justify-between px-4 py-3 text-left hover:bg-zinc-50"
            >
              <div className="flex items-center gap-2">
                <span className="text-lg text-zinc-400">{isExpanded ? "▼" : "▶"}</span>
                <span className="font-mono text-sm font-medium text-zinc-900">{table}</span>
                <span className="rounded-lg bg-zinc-100 px-2 py-0.5 text-xs font-medium text-zinc-700">
                  Level {tableData.dependencyLevel}
                </span>
                <span className="rounded-lg bg-zinc-100 px-2 py-0.5 text-xs font-medium text-zinc-700">
                  {rows.length} {rows.length === 1 ? "row" : "rows"}
                </span>
              </div>
            </button>

            {isExpanded && (
              <div className="border-t border-black/5">
                {rows.map((row) => {
                  const rowKey = `${table}-${row.PkValue}`;
                  const isRowExpanded = expandedRows.has(rowKey);
                  let parsedJson: unknown = null;
                  try {
                    parsedJson = JSON.parse(row.RowJson);
                  } catch {
                    parsedJson = null;
                  }

                  return (
                    <div key={rowKey} className="border-t border-black/5 first:border-t-0">
                      <button
                        onClick={() => toggleRow(rowKey)}
                        className="flex w-full items-center justify-between px-6 py-2 text-left hover:bg-zinc-50"
                      >
                        <div className="flex items-center gap-2">
                          <span className="text-sm text-zinc-400">{isRowExpanded ? "▼" : "▶"}</span>
                          <span className="font-mono text-xs text-zinc-700">
                            {row.PkColumn} = {row.PkValue}
                          </span>
                          {row.ChangeType && (
                            <span
                              className={`rounded px-1.5 py-0.5 text-xs font-medium ${
                                row.ChangeType === 'INSERT'
                                  ? 'bg-green-100 text-green-800'
                                  : row.ChangeType === 'UPDATE'
                                  ? 'bg-blue-100 text-blue-800'
                                  : row.ChangeType === 'DELETE'
                                  ? 'bg-red-100 text-red-800'
                                  : 'bg-zinc-100 text-zinc-800'
                              }`}
                            >
                              {row.ChangeType}
                            </span>
                          )}
                        </div>
                        <span className="text-xs text-zinc-500">
                          {new Date(row.CapturedAt).toLocaleString()}
                        </span>
                      </button>

                      {isRowExpanded && (
                        <div className="bg-zinc-50 px-6 pb-3">
                          <pre className="overflow-auto rounded-lg border border-black/10 bg-white p-3 text-xs text-zinc-800">
                            {(() => {
                              try {
                                if (parsedJson) {
                                  const jsonStr = JSON.stringify(parsedJson, null, 2);
                                  // Truncate if too large (> 100KB)
                                  if (jsonStr.length > 100000) {
                                    return jsonStr.substring(0, 100000) + '\n\n... (truncated)';
                                  }
                                  return jsonStr;
                                }
                                return row.RowJson.length > 100000 
                                  ? row.RowJson.substring(0, 100000) + '\n\n... (truncated)'
                                  : row.RowJson;
                              } catch (error) {
                                return `Error displaying JSON: ${error instanceof Error ? error.message : 'Unknown error'}`;
                              }
                            })()}
                          </pre>
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
  );
}
