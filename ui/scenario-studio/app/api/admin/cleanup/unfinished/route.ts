import { NextResponse } from "next/server";
import { execQuery } from "@/lib/db";

export async function POST() {
  // Deletes runs that are not finished capturing yet (EndedAt IS NULL) and all framework artifacts tied to those runs.
  // This intentionally only touches framework tables, not the underlying application data tables.
  try {
    await execQuery(
      `
      SET NOCOUNT ON;
      BEGIN TRANSACTION;

      IF OBJECT_ID('tempdb..#Runs') IS NOT NULL DROP TABLE #Runs;
      SELECT r.RunID INTO #Runs
      FROM dbo.MigrationScenarioRun r
      WHERE r.EndedAt IS NULL;

      -- Remove run-scoped artifacts
      DELETE c
      FROM dbo.DataDictionaryRelationshipCandidate c
      WHERE c.EvidenceRunID IN (SELECT RunID FROM #Runs);

      DELETE FROM dbo.MigrationScenarioRelationship WHERE RunID IN (SELECT RunID FROM #Runs);
      DELETE FROM dbo.MigrationScenarioNewRows WHERE RunID IN (SELECT RunID FROM #Runs);
      DELETE FROM dbo.MigrationScenarioIdentityBaseline WHERE RunID IN (SELECT RunID FROM #Runs);
      DELETE FROM dbo.MigrationScenarioRow WHERE RunID IN (SELECT RunID FROM #Runs);

      -- Delete the runs
      DELETE FROM dbo.MigrationScenarioRun WHERE RunID IN (SELECT RunID FROM #Runs);

      COMMIT TRANSACTION;
      `,
    );

    return NextResponse.json({ status: "ok" });
  } catch (e) {
    const msg = e instanceof Error ? e.message : "cleanup failed";
    return NextResponse.json({ error: msg }, { status: 500 });
  }
}
