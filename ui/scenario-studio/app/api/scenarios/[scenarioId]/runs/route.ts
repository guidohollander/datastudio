import { NextResponse } from "next/server";
import { execQuery } from "@/lib/db";

export async function GET(
  _req: Request,
  { params }: { params: Promise<{ scenarioId: string }> },
) {
  const { scenarioId } = await params;
  const id = Number(scenarioId);
  if (!Number.isFinite(id)) {
    return NextResponse.json({ error: "invalid scenarioId" }, { status: 400 });
  }

  const res = await execQuery<{
    RunID: string;
    StartedAt: string;
    EndedAt: string | null;
    Notes: string | null;
  }>(
    `
    SELECT RunID, StartedAt, EndedAt, Notes
    FROM dbo.MigrationScenarioRun
    WHERE ScenarioID = @ScenarioID
    ORDER BY StartedAt DESC;
    `,
    { ScenarioID: id },
  );

  return NextResponse.json({ runs: res.recordset ?? [] });
}
