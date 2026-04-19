import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import { execProc } from "@/lib/db";
import { ACTIVE_RUN_COOKIE } from "@/lib/recording";

export async function POST(req: Request) {
  const body = (await req.json()) as { scenarioName?: string; notes?: string | null };
  if (!body.scenarioName || body.scenarioName.trim().length === 0) {
    return NextResponse.json({ error: "scenarioName is required" }, { status: 400 });
  }

  const out = await execProc<{ RunID: string }>("dbo.StartMigrationScenarioRun", {
    ScenarioName: body.scenarioName.trim(),
    Notes: body.notes ?? null,
  });

  const first = out.recordset?.[0] as unknown as Record<string, unknown> | undefined;
  const runId = (first?.RunID as string | undefined) ?? undefined;
  if (!runId) {
    return NextResponse.json({ error: "StartMigrationScenarioRun did not return RunID" }, { status: 500 });
  }

  const jar = await cookies();
  jar.set(ACTIVE_RUN_COOKIE, runId, { httpOnly: true, sameSite: "lax", path: "/" });

  return NextResponse.json({ runId });
}
