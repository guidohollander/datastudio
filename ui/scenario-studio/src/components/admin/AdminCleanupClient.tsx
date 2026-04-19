"use client";

import { useEffect, useState } from "react";

type Scenario = {
  ScenarioID: number;
  Name: string;
  CreatedAt: string;
  Notes: string | null;
};

export default function AdminCleanupClient() {
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);

  const [confirmUnfinished, setConfirmUnfinished] = useState(false);
  const [confirmKeepOnly, setConfirmKeepOnly] = useState(false);
  const [confirmBaseline, setConfirmBaseline] = useState(false);

  const [scenarios, setScenarios] = useState<Scenario[]>([]);
  const [scErr, setScErr] = useState<string | null>(null);

  async function loadScenarios() {
    setScErr(null);
    try {
      const res = await fetch("/api/scenarios", { method: "GET" });
      const json = (await res.json()) as { items?: Scenario[]; error?: string };
      if (!res.ok) throw new Error(json.error ?? "Failed to load scenarios");
      setScenarios(json.items ?? []);
    } catch (e) {
      setScErr(e instanceof Error ? e.message : "Failed to load scenarios");
      setScenarios([]);
    }
  }

  async function cleanupUnfinished() {
    setBusy(true);
    setMsg(null);
    try {
      const res = await fetch("/api/admin/cleanup/unfinished", { method: "POST" });
      const json = (await res.json()) as { error?: string };
      if (!res.ok) throw new Error(json.error ?? "Cleanup failed");
      setMsg("Unfinished runs removed.");
      await loadScenarios();
    } catch (e) {
      setMsg(e instanceof Error ? e.message : "Cleanup failed");
    } finally {
      setBusy(false);
    }
  }

  async function keepOnlyIndividual() {
    setBusy(true);
    setMsg(null);
    try {
      const res = await fetch("/api/admin/cleanup/keep-only-individual", { method: "POST" });
      const json = (await res.json()) as { error?: string };
      if (!res.ok) throw new Error(json.error ?? "Cleanup failed");
      setMsg("Framework reset. Only Individual scenario kept.");
      await loadScenarios();
    } catch (e) {
      setMsg(e instanceof Error ? e.message : "Cleanup failed");
    } finally {
      setBusy(false);
    }
  }

  async function deleteScenario(id: number) {
    setBusy(true);
    setMsg(null);
    try {
      const res = await fetch(`/api/scenarios/${id}`, { method: "DELETE" });
      const json = (await res.json()) as { error?: string };
      if (!res.ok) throw new Error(json.error ?? "Delete failed");
      setMsg(`Scenario #${id} deleted.`);
      await loadScenarios();
    } catch (e) {
      setMsg(e instanceof Error ? e.message : "Delete failed");
    } finally {
      setBusy(false);
    }
  }

  async function refreshGlobalBaseline() {
    setBusy(true);
    setMsg("Refreshing global baseline... This may take several minutes for large databases.");
    try {
      const res = await fetch("/api/admin/refresh-baseline", { method: "POST" });
      const json = (await res.json()) as { totalRows?: number; totalTables?: number; error?: string };
      if (!res.ok) throw new Error(json.error ?? "Baseline refresh failed");
      setMsg(`Global baseline refreshed: ${json.totalRows ?? 0} rows across ${json.totalTables ?? 0} tables.`);
    } catch (e) {
      setMsg(e instanceof Error ? e.message : "Baseline refresh failed");
    } finally {
      setBusy(false);
      setConfirmBaseline(false);
    }
  }

  useEffect(() => {
    void loadScenarios();
  }, []);

  return (
    <div className="space-y-6">
      <div className="rounded-2xl border border-black/10 bg-white p-6 shadow-sm">
        <div className="text-sm font-semibold text-zinc-900">Cleanup</div>
        <div className="mt-2 text-sm text-zinc-700">
          Use these actions to get back to a clean state.
        </div>

        <div className="mt-4 grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          <div className="rounded-2xl border border-blue-500/20 bg-blue-50 p-5">
            <div className="text-sm font-medium text-blue-900">Refresh Global Baseline</div>
            <div className="mt-1 text-xs text-blue-900/70">
              Creates a snapshot of the entire database for change detection. Run once initially, then periodically after major data changes.
            </div>
            <label className="mt-3 flex items-center gap-2 text-sm text-blue-900">
              <input
                type="checkbox"
                checked={confirmBaseline}
                onChange={(e) => setConfirmBaseline(e.target.checked)}
                disabled={busy}
              />
              Confirm (may take 5-10 minutes)
            </label>
            <button
              onClick={() => void refreshGlobalBaseline()}
              disabled={busy || !confirmBaseline}
              className="mt-3 h-10 rounded-xl bg-blue-600 px-4 text-sm font-medium text-white disabled:opacity-40"
            >
              Refresh Baseline
            </button>
          </div>

          <div className="rounded-2xl border border-black/10 bg-white p-5">
            <div className="text-sm font-medium text-zinc-900">Remove unfinished runs</div>
            <div className="mt-1 text-xs text-zinc-600">Deletes runs where EndedAt is NULL, and their captured artifacts.</div>
            <label className="mt-3 flex items-center gap-2 text-sm text-zinc-700">
              <input
                type="checkbox"
                checked={confirmUnfinished}
                onChange={(e) => setConfirmUnfinished(e.target.checked)}
                disabled={busy}
              />
              Confirm
            </label>
            <button
              onClick={() => void cleanupUnfinished()}
              disabled={busy || !confirmUnfinished}
              className="mt-3 h-10 rounded-xl border border-black/10 bg-white px-4 text-sm font-medium text-zinc-900 shadow-sm disabled:opacity-40"
            >
              Remove unfinished
            </button>
          </div>

          <div className="rounded-2xl border border-red-500/20 bg-red-50 p-5">
            <div className="text-sm font-medium text-red-900">Keep only Individual</div>
            <div className="mt-1 text-xs text-red-900/70">
              Runs dbo.ResetFramework (commit) and recreates defaults + scenario Individual.
            </div>
            <label className="mt-3 flex items-center gap-2 text-sm text-red-900">
              <input
                type="checkbox"
                checked={confirmKeepOnly}
                onChange={(e) => setConfirmKeepOnly(e.target.checked)}
                disabled={busy}
              />
              I understand this deletes framework data
            </label>
            <button
              onClick={() => void keepOnlyIndividual()}
              disabled={busy || !confirmKeepOnly}
              className="mt-3 h-10 rounded-xl bg-red-600 px-4 text-sm font-medium text-white disabled:opacity-40"
            >
              Keep only Individual
            </button>
          </div>
        </div>

        {msg ? <div className="mt-3 text-xs text-zinc-600">{msg}</div> : null}
      </div>

      <div className="overflow-hidden rounded-2xl border border-black/10 bg-white shadow-sm">
        <div className="border-b border-black/5 px-6 py-4">
          <div className="text-sm font-semibold text-zinc-900">Scenarios</div>
          <div className="mt-1 text-xs text-zinc-600">Delete any scenario and its runs.</div>
        </div>

        <div className="divide-y divide-black/5">
          {scenarios.map((s) => (
            <div key={s.ScenarioID} className="flex items-center justify-between gap-4 px-6 py-4">
              <div className="min-w-0">
                <div className="truncate text-sm font-medium text-zinc-900">{s.Name}</div>
                <div className="mt-1 truncate text-xs text-zinc-500">#{s.ScenarioID} {s.Notes ?? ""}</div>
              </div>
              <button
                onClick={() => void deleteScenario(s.ScenarioID)}
                disabled={busy}
                className="h-9 rounded-xl border border-red-500/30 bg-red-50 px-3 text-xs font-medium text-red-700 disabled:opacity-40"
              >
                Delete
              </button>
            </div>
          ))}

          {scErr ? <div className="px-6 py-4 text-xs text-red-700">{scErr}</div> : null}
          {!scErr && scenarios.length === 0 ? <div className="px-6 py-6 text-sm text-zinc-600">No scenarios.</div> : null}
        </div>
      </div>
    </div>
  );
}
