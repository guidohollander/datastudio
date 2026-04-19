import { NextResponse } from "next/server";
import { execProc } from "@/lib/db";

export async function GET(
  _req: Request,
  { params }: { params: Promise<{ scenarioId: string }> },
) {
  const { scenarioId } = await params;
  const id = Number(scenarioId);
  if (!Number.isFinite(id)) {
    return NextResponse.json({ error: "invalid scenarioId" }, { status: 400 });
  }

  const res = await execProc<{
    RunID: string;
    ScenarioID: number;
    StartedAt: string;
    EndedAt: string | null;
    SnapshotID: string | null;
    Notes: string | null;
  }>("dbo.GetScenarioRuns", { ScenarioID: id });

  return NextResponse.json({ items: res.recordset ?? [] });
}
