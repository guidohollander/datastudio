import { NextResponse } from "next/server";
import { execQuery } from "@/lib/db";

type ExclusionUpdate = {
  tableName: string;
  pkValue?: number;
  excluded: boolean;
};

export async function POST(
  req: Request,
  { params }: { params: Promise<{ runId: string }> }
) {
  const { runId } = await params;
  const body = (await req.json()) as ExclusionUpdate;

  if (!body.tableName) {
    return NextResponse.json({ error: "tableName is required" }, { status: 400 });
  }

  try {
    if (body.pkValue !== undefined) {
      // Update single row
      await execQuery(
        `UPDATE dbo.MigrationScenarioRow 
         SET ExcludeFromReplay = @Excluded 
         WHERE RunID = @RunID AND TableName = @TableName AND PkValue = @PkValue`,
        {
          RunID: runId,
          TableName: body.tableName,
          PkValue: body.pkValue,
          Excluded: body.excluded ? 1 : 0,
        }
      );
    } else {
      // Update entire table
      await execQuery(
        `UPDATE dbo.MigrationScenarioRow 
         SET ExcludeFromReplay = @Excluded 
         WHERE RunID = @RunID AND TableName = @TableName`,
        {
          RunID: runId,
          TableName: body.tableName,
          Excluded: body.excluded ? 1 : 0,
        }
      );
    }

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error("Error updating exclusions:", error);
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Failed to update exclusions" },
      { status: 500 }
    );
  }
}

export async function GET(
  req: Request,
  { params }: { params: Promise<{ runId: string }> }
) {
  const { runId } = await params;

  try {
    const result = await execQuery<{ TableName: string; ExcludedCount: number; TotalCount: number }>(
      `SELECT 
        TableName,
        SUM(CASE WHEN ExcludeFromReplay = 1 THEN 1 ELSE 0 END) as ExcludedCount,
        COUNT(*) as TotalCount
       FROM dbo.MigrationScenarioRow
       WHERE RunID = @RunID
       GROUP BY TableName
       ORDER BY TableName`,
      { RunID: runId }
    );

    return NextResponse.json({ exclusions: result.recordset ?? [] });
  } catch (error) {
    console.error("Error fetching exclusions:", error);
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Failed to fetch exclusions" },
      { status: 500 }
    );
  }
}
