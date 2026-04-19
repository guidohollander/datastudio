import { NextResponse } from "next/server";
import { execProc, execQuery } from "@/lib/db";

export const maxDuration = 300; // Allow up to 5 minutes for baseline refresh

export async function POST() {
  try {
    console.log("Starting global baseline refresh...");
    
    await execProc("dbo.RefreshGlobalBaseline");
    
    console.log("Global baseline refresh complete. Fetching stats...");
    
    const stats = await execQuery<{ TotalBaselineRows: number; TotalTables: number }>(
      "SELECT COUNT(*) as TotalBaselineRows, COUNT(DISTINCT TableName) as TotalTables FROM dbo.MigrationGlobalBaseline"
    );
    
    const totalRows = stats.recordset?.[0]?.TotalBaselineRows ?? 0;
    const totalTables = stats.recordset?.[0]?.TotalTables ?? 0;
    
    console.log(`Baseline refreshed: ${totalRows} rows across ${totalTables} tables`);
    
    return NextResponse.json({ totalRows, totalTables });
  } catch (error) {
    console.error("Error refreshing global baseline:", error);
    return NextResponse.json({
      error: error instanceof Error ? error.message : "Failed to refresh global baseline"
    }, { status: 500 });
  }
}
