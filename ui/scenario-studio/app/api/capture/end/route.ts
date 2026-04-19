import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import { execProc, execQuery } from "@/lib/db";
import { ACTIVE_RUN_COOKIE } from "@/lib/recording";

export const maxDuration = 120; // Allow up to 2 minutes for snapshot comparison

export async function POST(req: Request) {
  try {
    const body = (await req.json()) as { runId?: string; notes?: string | null };
    if (!body.runId || body.runId.trim().length === 0) {
      return NextResponse.json({ error: "runId is required" }, { status: 400 });
    }

    const runId = body.runId.trim();
    console.log(`Ending capture for run: ${runId}`);

    const state = await execQuery<{ EndedAt: string | Date | null }>(
      `SELECT EndedAt FROM dbo.MigrationScenarioRun WHERE RunID = @RunID;`,
      { RunID: runId },
    );
    const endedAt = state.recordset?.[0]?.EndedAt ?? null;
    if (endedAt) {
      return NextResponse.json({ error: "Capture already ended for this run." }, { status: 400 });
    }

    console.log(`Calling EndMigrationScenarioRun...`);
    await execProc("dbo.EndMigrationScenarioRun", { RunID: runId, Notes: body.notes ?? null });
    
    console.log(`Calling InferScenarioRelationships...`);
    await execProc("dbo.InferScenarioRelationships", { RunID: runId, AlsoInsertIntoRegistry: 1 });
    
    console.log(`Calling RefreshDataDictionaryRelationshipCandidates...`);
    await execProc("dbo.RefreshDataDictionaryRelationshipCandidates", { RunID: runId });

    const jar = await cookies();
    jar.delete(ACTIVE_RUN_COOKIE);

    console.log(`Capture ended successfully for run: ${runId}`);
    return NextResponse.json({ runId, status: "ended" });
  } catch (error) {
    console.error(`Error ending capture:`, error);
    return NextResponse.json({ 
      error: error instanceof Error ? error.message : "Failed to end capture" 
    }, { status: 500 });
  }
}
