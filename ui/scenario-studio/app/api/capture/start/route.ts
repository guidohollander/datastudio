import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import { execProc } from "@/lib/db";
import { ACTIVE_RUN_COOKIE } from "@/lib/recording";

export const maxDuration = 120; // Allow up to 2 minutes for snapshot creation

export async function POST(req: Request) {
  try {
    const body = (await req.json()) as { scenarioName?: string; notes?: string | null };
    if (!body.scenarioName || body.scenarioName.trim().length === 0) {
      return NextResponse.json({ error: "scenarioName is required" }, { status: 400 });
    }

    console.log(`Starting capture for scenario: ${body.scenarioName}`);
    
    const out = await execProc<{ RunID: string }>("dbo.StartMigrationScenarioRun", {
      ScenarioName: body.scenarioName.trim(),
      Notes: body.notes ?? null,
    });

    console.log(`Procedure result:`, out);

    const first = out.recordset?.[0] as unknown as Record<string, unknown> | undefined;
    const runId = (first?.RunID as string | undefined) ?? undefined;
    if (!runId) {
      console.error(`No RunID returned from procedure. Result:`, out);
      return NextResponse.json({ error: "StartMigrationScenarioRun did not return RunID" }, { status: 500 });
    }

    const jar = await cookies();
    jar.set(ACTIVE_RUN_COOKIE, runId, { httpOnly: true, sameSite: "lax", path: "/" });

    console.log(`Capture started successfully. RunID: ${runId}`);
    return NextResponse.json({ runId });
  } catch (error) {
    console.error(`Error starting capture:`, error);
    return NextResponse.json({ 
      error: error instanceof Error ? error.message : "Failed to start capture" 
    }, { status: 500 });
  }
}
