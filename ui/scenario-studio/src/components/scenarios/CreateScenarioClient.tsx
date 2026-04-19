"use client";

import { useState } from "react";

export default function CreateScenarioClient() {
  const [name, setName] = useState("Individual");
  const [notes, setNotes] = useState("");
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);

  async function create() {
    setBusy(true);
    setMsg(null);
    try {
      const res = await fetch("/api/scenarios", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ name: name.trim(), notes: notes.trim().length ? notes.trim() : null }),
      });
      const ct = res.headers.get("content-type") ?? "";
      const json = ct.includes("application/json")
        ? ((await res.json()) as { scenarioId?: number; error?: string })
        : null;
      if (!res.ok) {
        const txt = json?.error ?? (ct.includes("application/json") ? "Failed to create scenario" : await res.text());
        throw new Error(txt);
      }
      setMsg("Scenario created.");
      window.location.reload();
    } catch (e) {
      setMsg(e instanceof Error ? e.message : "Failed to create scenario");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex flex-wrap items-center gap-2">
      <input
        value={name}
        onChange={(e) => setName(e.target.value)}
        placeholder="Scenario name"
        className="h-10 w-48 rounded-xl border border-white/10 bg-black/40 px-3 text-sm text-white placeholder:text-zinc-400 outline-none focus:border-white/20"
        disabled={busy}
      />
      <input
        value={notes}
        onChange={(e) => setNotes(e.target.value)}
        placeholder="Notes (optional)"
        className="h-10 w-56 rounded-xl border border-white/10 bg-black/40 px-3 text-sm text-white placeholder:text-zinc-400 outline-none focus:border-white/20"
        disabled={busy}
      />
      <button
        onClick={create}
        disabled={busy || name.trim().length === 0}
        className="h-10 rounded-xl bg-white px-4 text-sm font-medium text-zinc-950 disabled:opacity-40"
      >
        Create
      </button>
      {msg ? <div className="text-xs text-zinc-300/80">{msg}</div> : null}
    </div>
  );
}
