import { AppLink } from "@/lib/links";
import { execQuery } from "@/lib/db";
import RunTabs from "@/components/runs/RunTabs";
import CaptureTab from "@/components/runs/CaptureTab";
import AnalysisTab from "@/components/runs/AnalysisTab";
import ReplayTab from "@/components/runs/ReplayTab";

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

async function getRun(runId: string): Promise<RunRow | null> {
  const res = await execQuery<RunRow>(
    `
    SELECT TOP (1)
      r.RunID,
      r.ScenarioID,
      s.Name AS ScenarioName,
      r.StartedAt,
      r.EndedAt,
      r.Notes
    FROM dbo.MigrationScenarioRun r
    INNER JOIN dbo.MigrationScenario s
      ON s.ScenarioID = r.ScenarioID
    WHERE r.RunID = @RunID;
    `,
    { RunID: runId },
  );

  return res.recordset?.[0] ?? null;
}

export default async function RunHubPage({ params }: { params: Promise<{ runId: string }> }) {
  const { runId } = await params;
  const run = await getRun(runId);

  if (!run) {
    return (
      <div className="space-y-4">
        <h1 className="text-2xl font-semibold tracking-tight">Run not found</h1>
        <AppLink
          href="/runs"
          target="_self"
          className="rounded-xl border border-black/10 bg-white px-4 py-2 text-sm text-zinc-900 shadow-sm hover:bg-zinc-50"
        >
          Back to runs
        </AppLink>
      </div>
    );
  }

  const url = process.env.CAPTURE_APP_URL ?? "http://localhost:38086/BeInformed/";
  const isEnded = !!run.EndedAt;

  return (
    <div className="w-full space-y-8">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Run</h1>
          <div className="mt-2 text-sm text-zinc-700">
            <div>
              <span className="font-medium">Scenario:</span> {run.ScenarioName} #{run.ScenarioID}
            </div>
            <div>
              <span className="font-medium">RunID:</span> <span className="font-mono text-xs">{run.RunID}</span>
            </div>
            <div className="mt-1 text-xs text-zinc-500">
              Started: {fmt(run.StartedAt)}{run.EndedAt ? ` • Ended: ${fmt(run.EndedAt)}` : ""}
            </div>
          </div>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <AppLink
            href="/runs"
            target="_self"
            className="rounded-xl border border-black/10 bg-white px-4 py-2 text-sm text-zinc-900 shadow-sm hover:bg-zinc-50"
          >
            Back
          </AppLink>
          <AppLink
            href={url}
            target="_blank"
            rel="noopener noreferrer"
            className="rounded-xl bg-zinc-900 px-4 py-2 text-sm font-medium text-white hover:bg-zinc-800"
          >
            Open application
          </AppLink>
        </div>
      </div>

      <RunTabs isEnded={isEnded}>
        {{
          capture: <CaptureTab runId={run.RunID} isEnded={isEnded} />,
          analysis: <AnalysisTab runId={run.RunID} />,
          replay: <ReplayTab runId={run.RunID} />,
        }}
      </RunTabs>
    </div>
  );
}
