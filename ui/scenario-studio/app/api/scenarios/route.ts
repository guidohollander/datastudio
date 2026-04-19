import { NextResponse } from "next/server";
import { execProc } from "@/lib/db";

export async function GET() {
  const res = await execProc<{
    ScenarioID: number;
    Name: string;
    CreatedAt: string | Date;
    Notes: string | null;
  }>("dbo.GetScenarios");

  return NextResponse.json({ items: res.recordset ?? [] });
}

export async function POST(req: Request) {
  const body = (await req.json()) as { name?: string; notes?: string | null };
  if (!body.name || body.name.trim().length === 0) {
    return NextResponse.json({ error: "name is required" }, { status: 400 });
  }

  const res = await execProc<{ ScenarioID: number }>("dbo.CreateScenario", {
    ScenarioName: body.name.trim(),
    Notes: body.notes ?? null,
  });

  return NextResponse.json({ scenarioId: res.recordset?.[0]?.ScenarioID });
}
