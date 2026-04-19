import { NextResponse } from "next/server";
import { execProc } from "@/lib/db";

export async function POST() {
  try {
    // Full framework wipe (including scenarios/runs/replay artifacts) using existing framework procedure.
    await execProc("dbo.ResetFramework", { PreserveRunID: null, DryRun: 0, Commit: 1 });

    // Recreate baseline defaults (domain contract + scenario record).
    await execProc("dbo.EnsureDomainContractDefaults");
    await execProc("dbo.CreateScenario", { ScenarioName: "Individual", Notes: "Baseline scenario" });

    return NextResponse.json({ status: "ok" });
  } catch (e) {
    const msg = e instanceof Error ? e.message : "cleanup failed";
    return NextResponse.json({ error: msg }, { status: 500 });
  }
}
