"use client";

import { useState } from "react";

export default function RunCapturePanelClient({ runId, isEnded }: { runId: string; isEnded: boolean }) {
  const [busy, setBusy] = useState(false);
  const [notes, setNotes] = useState("");
  const [msg, setMsg] = useState<string | null>(null);

  async function endCapture() {
    setBusy(true);
    setMsg(null);
    try {
      const res = await fetch("/api/capture/end", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ runId, notes: notes.trim() || null }),
      });
      const json = (await res.json()) as { error?: string };
      if (!res.ok) throw new Error(json.error ?? "Failed to end capture");
      setMsg("Capture ended and rows captured. Refreshing...");
      
      // Refresh page to show relationships and captured data
      setTimeout(() => {
        window.location.reload();
      }, 500);
    } catch (e) {
      setMsg(e instanceof Error ? e.message : "Failed to end capture");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="space-y-3">
      <div className="text-sm text-zinc-700">
        Step 1: Use the application (look for the red recording badge), then end capture to snapshot diffs and collect captured rows.
      </div>
      <div className="flex flex-wrap items-center gap-2">
        <input
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          placeholder="Notes (optional)"
          className="h-10 w-72 rounded-xl border border-black/10 bg-white px-3 text-sm text-zinc-900 placeholder:text-zinc-400 outline-none focus:border-black/20"
          disabled={busy || isEnded}
        />
        <button
          onClick={endCapture}
          disabled={busy || isEnded}
          className="h-10 rounded-xl bg-red-600 px-4 text-sm font-medium text-white disabled:opacity-40 flex items-center gap-2"
        >
          {busy && (
            <svg className="animate-spin h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
          )}
          {isEnded ? "Capture ended" : busy ? "Ending capture..." : "End capture"}
        </button>
        {msg ? <div className="text-xs text-zinc-600">{msg}</div> : null}
      </div>
      {isEnded ? <div className="text-xs text-zinc-600">This run is already ended.</div> : null}
    </div>
  );
}
