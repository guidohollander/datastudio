import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import { execProc } from "@/lib/db";
import { ACTIVE_RUN_COOKIE } from "@/lib/recording";

export async function POST(req: Request) {
  const body = (await req.json()) as { runId?: string; notes?: string | null };
  if (!body.runId || body.runId.trim().length === 0) {
    return NextResponse.json({ error: "runId is required" }, { status: 400 });
  }

  const runId = body.runId.trim();

  await execProc("dbo.EndMigrationScenarioRun", { RunID: runId, Notes: body.notes ?? null });
  await execProc("dbo.CaptureScenarioRowDetails", { RunID: runId });
  await execProc("dbo.InferScenarioRelationships", { RunID: runId, AlsoInsertIntoRegistry: 1 });
  await execProc("dbo.RefreshDataDictionaryRelationshipCandidates", { RunID: runId });

  const jar = await cookies();
  jar.delete(ACTIVE_RUN_COOKIE);

  return NextResponse.json({ runId, status: "ended" });
}
