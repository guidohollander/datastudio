"use client";

import { useEffect, useMemo, useState } from "react";

type Mapping = {
  objectKey: string;
  componentKey: string;
  fieldKey: string;
  physicalTable: string;
  physicalColumn: string;
  dataType: string;
  required: boolean;
  example: string | null;
  gen: string | null;
};

type ContractResponse = {
  contractJson: string;
  mappings: Mapping[];
  error?: string;
};

export default function DatasetEditorClient({
  initialRunId,
  embedded,
}: {
  initialRunId: string | null;
  scenarioName?: string;
  embedded?: boolean;
}) {
  const [runId, setRunId] = useState<string>(initialRunId ?? "");
  const [objectKey, setObjectKey] = useState<string>("individual"); // Always default to 'individual' - the only domain object currently defined
  const [times, setTimes] = useState<number>(3);
  const [commit, setCommit] = useState<boolean>(false);
  const [notes, setNotes] = useState<string>("");

  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);

  const [contractJson, setContractJson] = useState<string | null>(null);
  const [mappings, setMappings] = useState<Mapping[]>([]);

  const [resetBusy, setResetBusy] = useState(false);
  const [resetConfirm, setResetConfirm] = useState(false);
  const [resetPreserveSelected, setResetPreserveSelected] = useState(true);
  const [resetPreview, setResetPreview] = useState<unknown[] | null>(null);
  const [resetMsg, setResetMsg] = useState<string | null>(null);

  const canLoad = useMemo(() => runId.trim().length > 0 && !busy, [runId, busy]);

  async function loadContract() {
    setBusy(true);
    setMsg(null);
    try {
      const res = await fetch(
        `/api/contract?runId=${encodeURIComponent(runId.trim())}&objectKey=${encodeURIComponent(objectKey)}`,
        { method: "GET" },
      );
      
      if (!res.ok) {
        const text = await res.text();
        console.error("Load contract failed:", res.status, text);
        try {
          const json = JSON.parse(text);
          throw new Error(json.error ?? json.details ?? "Failed to load contract");
        } catch {
          throw new Error(`Failed to load contract: ${res.status} ${text.substring(0, 200)}`);
        }
      }
      
      const json = (await res.json()) as ContractResponse;
      setContractJson(json.contractJson);
      setMappings(json.mappings);
      setMsg("Contract loaded.");
    } catch (e) {
      setContractJson(null);
      setMappings([]);
      setMsg(e instanceof Error ? e.message : "Failed to load contract");
    } finally {
      setBusy(false);
    }

  }

  async function resetFramework(commitReset: boolean) {
    setResetBusy(true);
    setResetMsg(null);
    try {
      const preserveRunId = resetPreserveSelected && runId.trim().length ? runId.trim() : null;
      const res = await fetch("/api/reset", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ preserveRunId, commit: commitReset }),
      });
      const json = (await res.json()) as { error?: string; recordsets?: unknown[][] };
      if (!res.ok) throw new Error(json.error ?? "Reset failed");
      setResetPreview(json.recordsets?.[0] ?? null);
      setResetMsg(commitReset ? "Reset completed." : "Dry-run preview loaded.");
    } catch (e) {
      setResetMsg(e instanceof Error ? e.message : "Reset failed");
    } finally {
      setResetBusy(false);
    }
  }

  async function saveGen(m: Mapping, gen: string) {
    setMsg(null);
    try {
      const res = await fetch("/api/domain/field", {
        method: "PATCH",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          objectKey: m.objectKey,
          componentKey: m.componentKey,
          fieldKey: m.fieldKey,
          gen: gen.trim().length ? gen.trim() : null,
        }),
      });
      const ct = res.headers.get("content-type") ?? "";
      const json = ct.includes("application/json") ? ((await res.json()) as { error?: string; gen?: string | null }) : null;
      if (!res.ok) throw new Error(json?.error ?? "Failed to save");

      setMappings((prev) =>
        prev.map((x) =>
          x.objectKey === m.objectKey && x.componentKey === m.componentKey && x.fieldKey === m.fieldKey
            ? { ...x, gen: json?.gen ?? null }
            : x,
        ),
      );
    } catch (e) {
      setMsg(e instanceof Error ? e.message : "Failed to save");
    }
  }

  async function runReplay() {
    setBusy(true);
    setMsg(null);
    try {
      const res = await fetch("/api/replay/domain", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          sourceRunId: runId.trim(),
          objectKey,
          times,
          commit,
          notes: notes.trim().length ? notes.trim() : null,
        }),
      });
      const json = (await res.json()) as { error?: string; replayRuns?: { ItemIndex: number; ReplayRunID: string }[] };
      if (!res.ok) throw new Error(json.error ?? "Replay failed");
      const count = json.replayRuns?.length ?? 0;
      setMsg(`Replay completed. ${count} item(s).`);
    } catch (e) {
      setMsg(e instanceof Error ? e.message : "Replay failed");
    } finally {
      setBusy(false);
    }
  }

  useEffect(() => {
    if (initialRunId) {
      void loadContract();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div className="space-y-6">
      <div className="rounded-2xl border border-red-500/20 bg-red-50 p-6">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <div className="text-sm font-semibold text-red-900">Reset (wipe framework data)</div>
            <div className="mt-1 text-xs text-red-900/70">
              Calls <span className="font-mono">dbo.ResetFramework</span>. Preview first, then confirm to commit.
            </div>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <button
              onClick={() => {
                void resetFramework(false);
              }}
              disabled={resetBusy}
              className="h-10 rounded-xl border border-red-500/30 bg-white px-4 text-sm font-medium text-red-800 disabled:opacity-40"
            >
              Preview reset
            </button>
            <button
              onClick={() => {
                void resetFramework(true);
              }}
              disabled={resetBusy || !resetConfirm}
              className="h-10 rounded-xl bg-red-600 px-4 text-sm font-medium text-white disabled:opacity-40"
            >
              Reset (commit)
            </button>
          </div>
        </div>

        <div className="mt-4 flex flex-wrap items-center gap-4">
          <label className="flex items-center gap-2 text-sm text-red-900">
            <input
              type="checkbox"
              checked={resetPreserveSelected}
              onChange={(e) => setResetPreserveSelected(e.target.checked)}
              disabled={resetBusy}
            />
            Preserve selected runId
          </label>
          <label className="flex items-center gap-2 text-sm text-red-900">
            <input
              type="checkbox"
              checked={resetConfirm}
              onChange={(e) => setResetConfirm(e.target.checked)}
              disabled={resetBusy}
            />
            I understand this deletes data
          </label>
          {resetMsg ? <div className="text-xs text-red-900/70">{resetMsg}</div> : null}
        </div>

        {resetPreview ? (
          <pre className="mt-4 overflow-auto rounded-xl border border-red-500/20 bg-white p-4 text-xs text-red-900/80">
            {JSON.stringify(resetPreview, null, 2)}
          </pre>
        ) : null}
      </div>

      <div className="rounded-2xl border border-black/10 bg-white p-6 shadow-sm">
        <div className="grid gap-3 md:grid-cols-2">
          <label className="space-y-1">
            <div className="text-xs text-zinc-600">Source runId</div>
            <input
              value={runId}
              onChange={(e) => setRunId(e.target.value)}
              placeholder="GUID"
              className="h-10 w-full rounded-xl border border-black/10 bg-white px-3 text-sm text-zinc-900 placeholder:text-zinc-400 outline-none focus:border-black/20"
              disabled={busy || embedded}
            />
          </label>

          <label className="space-y-1">
            <div className="text-xs text-zinc-600">Object key</div>
            <input
              value={objectKey}
              onChange={(e) => setObjectKey(e.target.value)}
              placeholder="individual"
              className="h-10 w-full rounded-xl border border-black/10 bg-white px-3 text-sm text-zinc-900 placeholder:text-zinc-400 outline-none focus:border-black/20"
              disabled={busy || embedded}
            />
          </label>

          <label className="space-y-1">
            <div className="text-xs text-zinc-600">Times</div>
            <input
              value={String(times)}
              onChange={(e) => setTimes(Number(e.target.value) || 1)}
              type="number"
              min={1}
              max={200}
              className="h-10 w-full rounded-xl border border-black/10 bg-white px-3 text-sm text-zinc-900 outline-none focus:border-black/20"
              disabled={busy}
            />
          </label>

          <label className="flex items-end gap-2">
            <input type="checkbox" checked={commit} onChange={(e) => setCommit(e.target.checked)} disabled={busy} />
            <span className="text-sm text-zinc-700">Commit</span>
          </label>

          <label className="space-y-1 md:col-span-2">
            <div className="text-xs text-zinc-600">Notes</div>
            <input
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="Optional"
              className="h-10 w-full rounded-xl border border-black/10 bg-white px-3 text-sm text-zinc-900 placeholder:text-zinc-400 outline-none focus:border-black/20"
              disabled={busy}
            />
          </label>
        </div>

        <div className="mt-4 flex flex-wrap items-center gap-2">
          <button
            onClick={loadContract}
            disabled={!canLoad}
            className="h-10 rounded-xl bg-zinc-900 px-4 text-sm font-medium text-white disabled:opacity-40"
          >
            Load contract
          </button>
          <button
            onClick={runReplay}
            disabled={busy || !contractJson}
            className="h-10 rounded-xl border border-emerald-500/30 bg-emerald-50 px-4 text-sm font-medium text-emerald-800 disabled:opacity-40"
          >
            Run replay
          </button>
          {msg ? <div className="text-xs text-zinc-600">{msg}</div> : null}
        </div>
      </div>

      <div className="overflow-hidden rounded-2xl border border-black/10 bg-white shadow-sm">
        <div className="border-b border-black/5 px-6 py-4">
          <div className="text-sm font-semibold text-zinc-900">Field generators</div>
          <div className="mt-1 text-xs text-zinc-600">
            Expressions are stored as <span className="font-mono">gen:&lt;expr&gt;</span> in MigrationDomainField.Notes.
          </div>
        </div>

        <div className="divide-y divide-black/5">
          {mappings.map((m) => (
            <div key={`${m.componentKey}.${m.fieldKey}`} className="grid gap-3 px-6 py-4 md:grid-cols-12">
              <div className="md:col-span-3">
                <div className="text-sm text-zinc-900">
                  <span className="font-mono text-xs text-zinc-500">{m.componentKey}.</span>
                  <span className="font-medium text-zinc-900">{m.fieldKey}</span>
                </div>
                <div className="mt-1 text-xs text-zinc-600">
                  {m.dataType}
                  {m.required ? " • required" : ""}
                </div>
              </div>

              <div className="md:col-span-4">
                <div className="text-xs text-zinc-600">Physical mapping</div>
                <div className="mt-1 font-mono text-xs text-zinc-700">
                  {m.physicalTable}.{m.physicalColumn}
                </div>
              </div>

              <div className="md:col-span-3">
                <div className="text-xs text-zinc-600">Example</div>
                <div className="mt-1 font-mono text-xs text-zinc-700">{m.example ?? ""}</div>
              </div>

              <div className="md:col-span-2">
                <div className="text-xs text-zinc-600">Generator</div>
                <input
                  defaultValue={m.gen ?? ""}
                  placeholder="e.g. concat('Doe ', seq())"
                  className="mt-1 h-9 w-full rounded-xl border border-black/10 bg-white px-3 text-xs text-zinc-900 placeholder:text-zinc-400 outline-none focus:border-black/20"
                  disabled={busy}
                  onBlur={(e) => {
                    void saveGen(m, e.target.value);
                  }}
                />
              </div>
            </div>
          ))}

          {mappings.length === 0 ? (
            <div className="px-6 py-6 text-sm text-zinc-600">
              Load a contract to view fields.
            </div>
          ) : null}
        </div>
      </div>
    </div>
  );
}
