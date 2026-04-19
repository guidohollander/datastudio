import { NextResponse } from "next/server";
import { execQuery } from "@/lib/db";

export async function GET(_req: Request, { params }: { params: Promise<{ runId: string }> }) {
  const { runId } = await params;

  try {
    // Get relationships discovered for this run, with table order
    const result = await execQuery<{
      RelationshipID: number;
      ParentTable: string;
      ParentColumn: string;
      ChildTable: string;
      ChildColumn: string;
      Source: string;
      Notes: string | null;
    }>(
      `
      SELECT
        r.RelationshipID,
        r.ParentTable,
        r.ParentColumn,
        r.ChildTable,
        r.ChildColumn,
        r.Source,
        r.Notes
      FROM dbo.MigrationScenarioRelationship sr
      JOIN dbo.MigrationTableRelationships r ON r.RelationshipID = sr.RelationshipID
      WHERE sr.RunID = @RunID
      ORDER BY r.ParentTable, r.ChildTable;
      `,
      { RunID: runId },
    );

    // Get table order (topological sort based on relationships)
    const tablesResult = await execQuery<{ TableName: string; DependencyLevel: number }>(
      `
      SET NOCOUNT ON;

      -- Get all tables involved in this run
      IF OBJECT_ID('tempdb..#Tables') IS NOT NULL DROP TABLE #Tables;
      SELECT DISTINCT TableName
      INTO #Tables
      FROM dbo.MigrationScenarioRow
      WHERE RunID = @RunID;

      -- Build dependency levels
      IF OBJECT_ID('tempdb..#Levels') IS NOT NULL DROP TABLE #Levels;
      CREATE TABLE #Levels (TableName SYSNAME, DependencyLevel INT);

      -- Level 0: tables with no parents (or parents not in this run)
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

      -- Iteratively assign levels
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

        IF @Level > 50 BREAK; -- safety
      END

      SELECT TableName, DependencyLevel
      FROM #Levels
      ORDER BY DependencyLevel, TableName;
      `,
      { RunID: runId },
    );

    return NextResponse.json({
      relationships: result.recordset ?? [],
      tableOrder: tablesResult.recordset ?? [],
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : "Failed to get relationships";
    return NextResponse.json({ error: msg }, { status: 500 });
  }
}
