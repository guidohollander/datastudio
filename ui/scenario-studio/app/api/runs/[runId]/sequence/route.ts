import { NextResponse } from "next/server";
import { execQuery } from "@/lib/db";

type RowData = {
  TableName: string;
  PkColumn: string;
  PkValue: number;
  RowJson: string;
  ChangeType: string | null;
  DependencyLevel: number;
};

type RelationshipData = {
  ParentTable: string;
  ChildTable: string;
  ChildColumn: string;
  ParentPkColumn: string;
};

export async function GET(
  req: Request,
  { params }: { params: Promise<{ runId: string }> }
) {
  const { runId } = await params;

  try {
    // Get all captured rows with dependency levels using same logic as ReplayScenarioRun
    const rowsResult = await execQuery<RowData>(
      `
      -- Use the EXACT same topological sort logic as ReplayScenarioRun
      DECLARE @RunID UNIQUEIDENTIFIER = @RunIDParam;
      
      IF OBJECT_ID('tempdb..#Tables') IS NOT NULL DROP TABLE #Tables;
      IF OBJECT_ID('tempdb..#Rels') IS NOT NULL DROP TABLE #Rels;
      IF OBJECT_ID('tempdb..#Order') IS NOT NULL DROP TABLE #Order;
      IF OBJECT_ID('tempdb..#State') IS NOT NULL DROP TABLE #State;

      SELECT DISTINCT r.TableName
      INTO #Tables
      FROM dbo.MigrationScenarioRow r
      WHERE r.RunID = @RunID;

      SELECT
          c.ParentTable COLLATE DATABASE_DEFAULT AS ParentTable,
          c.ChildTable COLLATE DATABASE_DEFAULT AS ChildTable,
          c.ChildColumn COLLATE DATABASE_DEFAULT AS ChildColumn
      INTO #Rels
      FROM dbo.DataDictionaryRelationshipCandidate c
      WHERE c.Source = N'Pattern'
        AND c.IsActive = 1
        AND EXISTS (SELECT 1 FROM #Tables t WHERE t.TableName = c.ParentTable)
        AND EXISTS (SELECT 1 FROM #Tables t WHERE t.TableName = c.ChildTable);

      CREATE TABLE #Order (
          TableName NVARCHAR(128) COLLATE DATABASE_DEFAULT NOT NULL,
          Lvl INT NOT NULL
      );

      CREATE TABLE #State (
          TableName NVARCHAR(128) COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY,
          InDegree INT NOT NULL,
          Lvl INT NOT NULL,
          Processed BIT NOT NULL
      );

      INSERT INTO #State(TableName, InDegree, Lvl, Processed)
      SELECT
          CAST(t.TableName AS NVARCHAR(128)) COLLATE DATABASE_DEFAULT,
          (
              SELECT COUNT(DISTINCT r.ParentTable)
              FROM #Rels r
              WHERE r.ChildTable = CAST(t.TableName AS NVARCHAR(128)) COLLATE DATABASE_DEFAULT
                AND r.ParentTable <> r.ChildTable
          ) AS InDegree,
          0 AS Lvl,
          0 AS Processed
      FROM #Tables t;

      -- Force CMFCASE and CMFRECORD to level 0 (same as ReplayScenarioRun)
      IF EXISTS (SELECT 1 FROM #State WHERE TableName = N'CMFRECORD')
          UPDATE #State SET InDegree = 0, Lvl = 0 WHERE TableName = N'CMFRECORD';

      IF EXISTS (SELECT 1 FROM #State WHERE TableName = N'CMFCASE')
          UPDATE #State SET InDegree = 0, Lvl = 0 WHERE TableName = N'CMFCASE';

      -- Topological sort
      DECLARE @Remaining INT = (SELECT COUNT(*) FROM #State);
      DECLARE @CurTable NVARCHAR(128);
      DECLARE @CurLvl INT;

      WHILE @Remaining > 0
      BEGIN
          SELECT TOP 1
              @CurTable = s.TableName,
              @CurLvl = s.Lvl
          FROM #State s
          WHERE s.Processed = 0
            AND s.InDegree = 0
          ORDER BY s.Lvl, s.TableName;

          IF @CurTable IS NULL
          BEGIN
              INSERT INTO #Order(TableName, Lvl)
              SELECT s.TableName, 999
              FROM #State s
              WHERE s.Processed = 0
              ORDER BY s.TableName;
              UPDATE #State SET Processed = 1 WHERE Processed = 0;
              BREAK;
          END

          INSERT INTO #Order(TableName, Lvl) VALUES (@CurTable, @CurLvl);
          UPDATE #State SET Processed = 1 WHERE TableName = @CurTable;

          UPDATE child
          SET
              child.InDegree = CASE WHEN child.InDegree > 0 THEN child.InDegree - 1 ELSE 0 END,
              child.Lvl = CASE WHEN child.Lvl < @CurLvl + 1 THEN @CurLvl + 1 ELSE child.Lvl END
          FROM #State child
          WHERE child.Processed = 0
            AND EXISTS (
                SELECT 1
                FROM #Rels r
                WHERE r.ParentTable = @CurTable
                  AND r.ChildTable = child.TableName
            );

          SET @CurTable = NULL;
          SET @Remaining = (SELECT COUNT(*) FROM #State WHERE Processed = 0);
      END

      -- Return rows ordered by dependency level (same as replay execution order)
      SELECT 
        r.TableName,
        r.PkColumn,
        r.PkValue,
        r.RowJson,
        r.ChangeType,
        o.Lvl as DependencyLevel
      FROM dbo.MigrationScenarioRow r
      INNER JOIN #Order o ON o.TableName = r.TableName
      WHERE r.RunID = @RunID
      ORDER BY o.Lvl, r.TableName, r.PkValue;
      `,
      { RunIDParam: runId }
    );

    // Get relationships between captured tables
    const relsResult = await execQuery<RelationshipData>(
      `
      SELECT DISTINCT
        c.ParentTable,
        c.ChildTable,
        c.ChildColumn,
        pc.ColumnName as ParentPkColumn
      FROM dbo.DataDictionaryRelationshipCandidate c
      INNER JOIN dbo.DataDictionaryColumn pc
        ON pc.TableObjectId = OBJECT_ID(c.ParentTable)
        AND pc.IsPrimaryKey = 1
      WHERE c.IsActive = 1
        AND EXISTS (SELECT 1 FROM dbo.MigrationScenarioRow r WHERE r.RunID = @RunID AND r.TableName = c.ParentTable)
        AND EXISTS (SELECT 1 FROM dbo.MigrationScenarioRow r WHERE r.RunID = @RunID AND r.TableName = c.ChildTable)
      ORDER BY c.ParentTable, c.ChildTable;
      `,
      { RunID: runId }
    );

    const rows = rowsResult.recordset ?? [];
    const relationships = relsResult.recordset ?? [];

    // Build sequence steps
    const steps: Array<{
      stepNumber: number;
      action: string;
      tableName: string;
      pkColumn: string;
      pkValue: number;
      changeType: string | null;
      dependencyLevel: number;
      foreignKeys: Array<{ column: string; referencesTable: string; referencesValue: number | null }>;
      typeInfo?: string;
    }> = [];

    let stepNumber = 1;
    for (const row of rows) {
      const rowData = JSON.parse(row.RowJson);
      
      // Extract type information for CMFCASE and CMFRECORD
      let typeInfo = "";
      if (row.TableName === "CMFCASE" && rowData.CASETYPE) {
        typeInfo = rowData.CASETYPE;
      } else if (row.TableName === "CMFRECORD" && rowData.RECORDTYPE) {
        typeInfo = rowData.RECORDTYPE;
      }
      
      // Find foreign key references
      const foreignKeys = relationships
        .filter((rel) => rel.ChildTable === row.TableName)
        .map((rel) => {
          const fkValue = rowData[rel.ChildColumn];
          return {
            column: rel.ChildColumn,
            referencesTable: rel.ParentTable,
            referencesValue: fkValue ?? null,
          };
        });

      steps.push({
        stepNumber: stepNumber++,
        action: row.ChangeType === "INSERT" ? "INSERT" : row.ChangeType === "UPDATE" ? "UPDATE" : row.ChangeType === "DELETE" ? "DELETE" : "INSERT",
        tableName: row.TableName,
        pkColumn: row.PkColumn,
        pkValue: row.PkValue,
        changeType: row.ChangeType,
        dependencyLevel: row.DependencyLevel,
        foreignKeys,
        typeInfo,
      });
    }

    return NextResponse.json({ steps });
  } catch (error) {
    console.error("Error generating sequence data:", error);
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Failed to generate sequence data" },
      { status: 500 }
    );
  }
}
