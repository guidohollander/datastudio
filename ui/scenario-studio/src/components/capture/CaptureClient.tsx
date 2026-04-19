"use client";

import { useMemo, useState } from "react";

export default function CaptureClient({ initialRunId }: { initialRunId: string | null }) {
  const [scenarioName, setScenarioName] = useState<string>("Individual");
  const [notes, setNotes] = useState<string>("");
  const [runId, setRunId] = useState<string | null>(initialRunId);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);

  const canStart = useMemo(() => !busy && !runId && scenarioName.trim().length > 0, [busy, runId, scenarioName]);
  const canEnd = useMemo(() => !busy && !!runId, [busy, runId]);

  async function start() {
    setBusy(true);
    setMsg(null);
    try {
      const res = await fetch("/api/capture/start", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ scenarioName, notes: notes.trim().length ? notes.trim() : null }),
      });
      const json = (await res.json()) as { runId?: string; error?: string };
      if (!res.ok) throw new Error(json.error ?? "Failed to start");
      if (!json.runId) throw new Error("No runId returned");
      setRunId(json.runId);
      setMsg("Capture started.");
      window.location.reload();
    } catch (e) {
      setMsg(e instanceof Error ? e.message : "Failed to start");
    } finally {
      setBusy(false);
    }
  }

  async function end() {
    if (!runId) return;
    setBusy(true);
    setMsg(null);
    try {
      const res = await fetch("/api/capture/end", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ runId, notes: notes.trim().length ? notes.trim() : null }),
      });
      const json = (await res.json()) as { status?: string; error?: string };
      if (!res.ok) throw new Error(json.error ?? "Failed to end");
      setMsg("Capture ended and data captured.");
      setRunId(null);
      window.location.reload();
    } catch (e) {
      setMsg(e instanceof Error ? e.message : "Failed to end");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex flex-wrap items-center gap-3">
      <input
        value={scenarioName}
        onChange={(e) => setScenarioName(e.target.value)}
        placeholder="Scenario name"
        className="h-10 w-48 rounded-xl border border-white/10 bg-black/40 px-3 text-sm text-white placeholder:text-zinc-400 outline-none focus:border-white/20"
        disabled={busy || !!runId}
      />
      <input
        value={notes}
        onChange={(e) => setNotes(e.target.value)}
        placeholder="Notes (optional)"
        className="h-10 w-56 rounded-xl border border-white/10 bg-black/40 px-3 text-sm text-white placeholder:text-zinc-400 outline-none focus:border-white/20"
        disabled={busy}
      />

      <button
        onClick={start}
        disabled={!canStart}
        className="h-10 rounded-xl bg-white px-4 text-sm font-medium text-zinc-950 disabled:opacity-40"
      >
        Start capture
      </button>
      <button
        onClick={end}
        disabled={!canEnd}
        className="h-10 rounded-xl border border-red-500/40 bg-red-500/10 px-4 text-sm font-medium text-red-200 disabled:opacity-40"
      >
        End capture
      </button>

      {msg ? <div className="text-xs text-zinc-300/80">{msg}</div> : null}
    </div>
  );
}
