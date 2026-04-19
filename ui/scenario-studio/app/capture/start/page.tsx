"use client";

import { useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { AppLink } from "@/lib/links";

type Scenario = {
  ScenarioID: number;
  Name: string;
  CreatedAt: string;
  Notes: string | null;
};

export default function CaptureStartPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const preselectedScenario = searchParams.get("scenarioName");

  const [scenarios, setScenarios] = useState<Scenario[]>([]);
  const [selectedScenario, setSelectedScenario] = useState<string>(preselectedScenario ?? "");
  const [notes, setNotes] = useState<string>("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function loadScenarios() {
    try {
      const res = await fetch("/api/scenarios");
      const json = (await res.json()) as { items?: Scenario[]; error?: string };
      if (!res.ok) throw new Error(json.error ?? "Failed to load scenarios");
      setScenarios(json.items ?? []);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to load scenarios");
    }
  }

  async function startCapture() {
    if (!selectedScenario.trim()) {
      setError("Please select or enter a scenario name");
      return;
    }

    setBusy(true);
    setError(null);

    try {
      const res = await fetch("/api/capture/start", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ scenarioName: selectedScenario.trim(), notes: notes.trim() || null }),
      });

      const json = (await res.json()) as { runId?: string; error?: string };
      if (!res.ok) throw new Error(json.error ?? "Failed to start capture");

      if (json.runId) {
        router.push(`/runs/${encodeURIComponent(json.runId)}`);
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to start capture");
      setBusy(false);
    }
  }

  useEffect(() => {
    void loadScenarios();
  }, []);

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Start capture</h1>
          <p className="mt-1 text-sm text-zinc-600">Begin a new scenario capture run.</p>
        </div>
        <AppLink
          href="/scenarios"
          target="_self"
          className="rounded-xl border border-black/10 bg-white px-4 py-2 text-sm text-zinc-900 shadow-sm hover:bg-zinc-50"
        >
          Back to scenarios
        </AppLink>
      </div>

      <div className="rounded-2xl border border-black/10 bg-white p-6 shadow-sm">
        <div className="space-y-4">
          <label className="block">
            <div className="mb-2 text-sm font-medium text-zinc-900">Scenario</div>
            <input
              type="text"
              list="scenarios"
              value={selectedScenario}
              onChange={(e) => setSelectedScenario(e.target.value)}
              placeholder="Select or type scenario name"
              className="h-10 w-full rounded-xl border border-black/10 bg-white px-3 text-sm text-zinc-900 placeholder:text-zinc-400 outline-none focus:border-black/20"
              disabled={busy}
            />
            <datalist id="scenarios">
              {scenarios.map((s) => (
                <option key={s.ScenarioID} value={s.Name} />
              ))}
            </datalist>
          </label>

          <label className="block">
            <div className="mb-2 text-sm font-medium text-zinc-900">Notes (optional)</div>
            <input
              type="text"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="Describe this run"
              className="h-10 w-full rounded-xl border border-black/10 bg-white px-3 text-sm text-zinc-900 placeholder:text-zinc-400 outline-none focus:border-black/20"
              disabled={busy}
            />
          </label>

          {error ? <div className="rounded-xl bg-red-50 px-4 py-3 text-sm text-red-900">{error}</div> : null}

          <button
            onClick={() => void startCapture()}
            disabled={busy || !selectedScenario.trim()}
            className="h-10 rounded-xl bg-red-600 px-6 text-sm font-medium text-white disabled:opacity-40 flex items-center gap-2"
          >
            {busy && (
              <svg className="animate-spin h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
            )}
            {busy ? "Starting capture..." : "Start capture"}
          </button>
        </div>
      </div>
    </div>
  );
}
