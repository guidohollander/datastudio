import { NextResponse } from "next/server";
import { execQuery } from "@/lib/db";

type RunRow = {
  RunID: string;
  ScenarioID: number;
  ScenarioName: string;
  StartedAt: string | Date;
  EndedAt: string | Date | null;
  Notes: string | null;
};

function toIso(v: string | Date | null) {
  if (!v) return null;
  if (v instanceof Date) return v.toISOString();
  return v;
}

export async function GET(req: Request) {
  const url = new URL(req.url);
  const takeRaw = url.searchParams.get("take");
  const take = Math.max(1, Math.min(200, takeRaw ? Number(takeRaw) : 30));

  const res = await execQuery<RunRow>(
    `
    SELECT TOP (@Take)
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
    { Take: take },
  );

  const items = (res.recordset ?? []).map((r) => ({
    runId: r.RunID,
    scenarioId: r.ScenarioID,
    scenarioName: r.ScenarioName,
    startedAt: toIso(r.StartedAt),
    endedAt: toIso(r.EndedAt),
    notes: r.Notes,
  }));

  return NextResponse.json({ items });
}
