import { NextResponse } from "next/server";
import { execQuery } from "@/lib/db";

export async function DELETE(_req: Request, { params }: { params: Promise<{ scenarioId: string }> }) {
  const { scenarioId } = await params;
  const sid = Number(scenarioId);
  if (!Number.isFinite(sid)) {
    return NextResponse.json({ error: "invalid scenarioId" }, { status: 400 });
  }

  try {
    await execQuery(
      `
      SET NOCOUNT ON;
      SET XACT_ABORT ON;

      BEGIN TRANSACTION;

      IF OBJECT_ID('tempdb..#Runs') IS NOT NULL DROP TABLE #Runs;
      SELECT r.RunID INTO #Runs
      FROM dbo.MigrationScenarioRun r
      WHERE r.ScenarioID = @ScenarioID;

      -- Clean up replay runs (and their inserted data) for these source runs.
      DECLARE @ReplayRunID UNIQUEIDENTIFIER;
      DECLARE replay_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT rr.ReplayRunID
        FROM dbo.MigrationScenarioReplayRun rr
        WHERE rr.SourceRunID IN (SELECT RunID FROM #Runs)
        ORDER BY rr.CreatedAt DESC;

      OPEN replay_cursor;
      FETCH NEXT FROM replay_cursor INTO @ReplayRunID;
      WHILE @@FETCH_STATUS = 0
      BEGIN
        EXEC dbo.CleanupScenarioReplayRun @ReplayRunID = @ReplayRunID;
        FETCH NEXT FROM replay_cursor INTO @ReplayRunID;
      END
      CLOSE replay_cursor;
      DEALLOCATE replay_cursor;

      -- Remove replay metadata
      DELETE m
      FROM dbo.MigrationScenarioReplayMap m
      WHERE m.ReplayRunID IN (SELECT rr.ReplayRunID FROM dbo.MigrationScenarioReplayRun rr WHERE rr.SourceRunID IN (SELECT RunID FROM #Runs));

      DELETE FROM dbo.MigrationScenarioReplayRun
      WHERE SourceRunID IN (SELECT RunID FROM #Runs);

      -- Remove run-scoped artifacts
      DELETE c
      FROM dbo.DataDictionaryRelationshipCandidate c
      WHERE c.EvidenceRunID IN (SELECT RunID FROM #Runs);

      DELETE FROM dbo.MigrationScenarioRelationship WHERE RunID IN (SELECT RunID FROM #Runs);
      DELETE FROM dbo.MigrationScenarioNewRows WHERE RunID IN (SELECT RunID FROM #Runs);
      DELETE FROM dbo.MigrationScenarioIdentityBaseline WHERE RunID IN (SELECT RunID FROM #Runs);
      DELETE FROM dbo.MigrationScenarioRow WHERE RunID IN (SELECT RunID FROM #Runs);

      DELETE FROM dbo.MigrationScenarioRun WHERE ScenarioID = @ScenarioID;
      DELETE FROM dbo.MigrationScenario WHERE ScenarioID = @ScenarioID;

      COMMIT TRANSACTION;
      `,
      { ScenarioID: sid },
    );

    return NextResponse.json({ status: "deleted", scenarioId: sid });
  } catch (e) {
    const msg = e instanceof Error ? e.message : "delete failed";
    return NextResponse.json({ error: msg }, { status: 500 });
  }
}
