import { NextResponse } from "next/server";
import { execProc } from "@/lib/db";

type ResetBody = {
  preserveRunId?: string | null;
  commit?: boolean;
};

function parseGuid(v: unknown) {
  if (typeof v !== "string") return null;
  const s = v.trim();
  return s.length ? s : null;
}

export async function POST(req: Request) {
  const body = (await req.json()) as ResetBody;

  const preserveRunId = parseGuid(body.preserveRunId);
  const commit = !!body.commit;
  const dryRun = commit ? 0 : 1;

  try {
    const res = await execProc<Record<string, unknown>>("dbo.ResetFramework", {
      PreserveRunID: preserveRunId,
      DryRun: dryRun,
      Commit: commit ? 1 : 0,
    });

    return NextResponse.json({
      preserveRunId,
      commit,
      dryRun: !!dryRun,
      recordset: res.recordset ?? [],
      recordsets: res.recordsets ?? [],
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : "ResetFramework failed";
    return NextResponse.json({ error: msg }, { status: 500 });
  }
}
