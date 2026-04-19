import { NextResponse } from "next/server";
import { execQuery } from "@/lib/db";

export async function GET(_req: Request, { params }: { params: Promise<{ runId: string }> }) {
  const { runId } = await params;

  try {
    // Calculate table dependency levels
    const levelsResult = await execQuery<{ TableName: string; DependencyLevel: number }>(
      `
      SET NOCOUNT ON;

      IF OBJECT_ID('tempdb..#Tables') IS NOT NULL DROP TABLE #Tables;
      SELECT DISTINCT TableName
      INTO #Tables
      FROM dbo.MigrationScenarioRow
      WHERE RunID = @RunID;

      IF OBJECT_ID('tempdb..#Levels') IS NOT NULL DROP TABLE #Levels;
      CREATE TABLE #Levels (TableName SYSNAME, DependencyLevel INT);

      INSERT INTO #Levels (TableName, DependencyLevel)
      SELECT t.TableName, 0
      FROM #Tables t
      WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.MigrationScenarioRelationship sr
        JOIN dbo.MigrationTableRelationships r ON r.RelationshipID = sr.RelationshipID
        WHERE sr.RunID = @RunID
          AND r.ChildTable = t.TableName
          AND r.IsActive = 1
          AND EXISTS (SELECT 1 FROM #Tables pt WHERE pt.TableName = r.ParentTable)
      );

      DECLARE @Level INT = 0;
      WHILE EXISTS (SELECT 1 FROM #Tables t WHERE NOT EXISTS (SELECT 1 FROM #Levels l WHERE l.TableName = t.TableName))
      BEGIN
        SET @Level = @Level + 1;

        INSERT INTO #Levels (TableName, DependencyLevel)
        SELECT DISTINCT t.TableName, @Level
        FROM #Tables t
        WHERE NOT EXISTS (SELECT 1 FROM #Levels l WHERE l.TableName = t.TableName)
          AND NOT EXISTS (
            SELECT 1
            FROM dbo.MigrationScenarioRelationship sr
            JOIN dbo.MigrationTableRelationships r ON r.RelationshipID = sr.RelationshipID
            WHERE sr.RunID = @RunID
              AND r.ChildTable = t.TableName
              AND r.IsActive = 1
              AND EXISTS (SELECT 1 FROM #Tables pt WHERE pt.TableName = r.ParentTable)
              AND NOT EXISTS (SELECT 1 FROM #Levels pl WHERE pl.TableName = r.ParentTable)
          );

        IF @Level > 50 BREAK;
      END

      SELECT TableName, DependencyLevel
      FROM #Levels
      ORDER BY DependencyLevel, TableName;
      `,
      { RunID: runId },
    );

    const tableLevels: Record<string, number> = {};
    for (const row of levelsResult.recordset ?? []) {
      tableLevels[row.TableName] = row.DependencyLevel;
    }

    const result = await execQuery<{
      TableName: string;
      PkColumn: string;
      PkValue: number;
      CapturedAt: string;
      RowJson: string;
      ChangeType: string | null;
      ExcludeFromReplay: boolean;
    }>(
      `
      SELECT
        TableName,
        PkColumn,
        PkValue,
        CapturedAt,
        RowJson,
        ChangeType,
        CAST(ExcludeFromReplay AS BIT) as ExcludeFromReplay
      FROM dbo.MigrationScenarioRow
      WHERE RunID = @RunID
      ORDER BY TableName, PkValue;
      `,
      { RunID: runId },
    );

    // Group by table with dependency level
    const byTable: Record<
      string,
      {
        dependencyLevel: number;
        rows: Array<{ PkColumn: string; PkValue: number; CapturedAt: string; RowJson: string; ChangeType: string | null; ExcludeFromReplay: boolean }>;
      }
    > = {};

    for (const row of result.recordset ?? []) {
      if (!byTable[row.TableName]) {
        byTable[row.TableName] = {
          dependencyLevel: tableLevels[row.TableName] ?? 999,
          rows: [],
        };
      }
      byTable[row.TableName].rows.push({
        PkColumn: row.PkColumn,
        PkValue: row.PkValue,
        CapturedAt: row.CapturedAt,
        RowJson: row.RowJson,
        ChangeType: row.ChangeType,
        ExcludeFromReplay: row.ExcludeFromReplay,
      });
    }

    return NextResponse.json({ capturedData: byTable });
  } catch (e) {
    const msg = e instanceof Error ? e.message : "Failed to get captured data";
    return NextResponse.json({ error: msg }, { status: 500 });
  }
}
