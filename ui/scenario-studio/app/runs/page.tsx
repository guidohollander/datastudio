import { AppLink } from "@/lib/links";
import { execQuery } from "@/lib/db";

type RunRow = {
  RunID: string;
  ScenarioID: number;
  ScenarioName: string;
  StartedAt: string | Date;
  EndedAt: string | Date | null;
  Notes: string | null;
};

function fmt(v: string | Date | null) {
  if (!v) return "";
  if (v instanceof Date) return v.toISOString();
  return v;
}

async function getRuns(): Promise<RunRow[]> {
  const res = await execQuery<RunRow>(
    `
    SELECT TOP (50)
      r.RunID,
      r.ScenarioID,
      s.Name AS ScenarioName,
      r.StartedAt,
      r.EndedAt,
      r.Notes
    FROM dbo.MigrationScenarioRun r
    INNER JOIN dbo.MigrationScenario s
      ON s.ScenarioID = r.ScenarioID
    ORDER BY r.StartedAt DESC;
    `,
  );

  return res.recordset ?? [];
}

export default async function RunsPage() {
  const runs = await getRuns();

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Runs</h1>
          <p className="mt-1 text-sm text-zinc-600">
            Pick a run to capture, edit dataset, replay, or reset.
          </p>
        </div>
        <AppLink
          href="/scenarios"
          target="_self"
          className="rounded-xl border border-black/10 bg-white px-4 py-2 text-sm text-zinc-900 shadow-sm hover:bg-zinc-50"
        >
          Manage scenarios
        </AppLink>
      </div>

      <div className="overflow-hidden rounded-2xl border border-black/10 bg-white shadow-sm">
        <div className="border-b border-black/5 px-6 py-4">
          <div className="text-sm font-semibold text-zinc-900">Recent runs</div>
        </div>
        <div className="divide-y divide-black/5">
          {runs.map((r) => (
            <AppLink
              key={r.RunID}
              href={`/runs/${encodeURIComponent(r.RunID)}`}
              target="_self"
              className="block px-6 py-4 hover:bg-zinc-50"
            >
              <div className="flex items-start justify-between gap-4">
                <div className="min-w-0">
                  <div className="truncate text-sm font-medium text-zinc-900">
                    {r.ScenarioName} <span className="text-zinc-500">#{r.ScenarioID}</span>
                  </div>
                  <div className="mt-1 truncate font-mono text-xs text-zinc-500">{r.RunID}</div>
                  <div className="mt-1 truncate text-xs text-zinc-500">{r.Notes ?? ""}</div>
                </div>
                <div className="shrink-0 text-right text-xs text-zinc-500">
                  <div>Started: {fmt(r.StartedAt)}</div>
                  <div>Ended: {fmt(r.EndedAt)}</div>
                </div>
              </div>
            </AppLink>
          ))}

          {runs.length === 0 ? <div className="px-6 py-6 text-sm text-zinc-600">No runs found yet.</div> : null}
        </div>
      </div>
    </div>
  );
}
