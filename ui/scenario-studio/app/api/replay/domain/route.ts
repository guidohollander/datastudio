import { NextResponse } from "next/server";
import { execProc } from "@/lib/db";

function parseGuid(v: unknown) {
  if (typeof v !== "string") return null;
  const s = v.trim();
  return s.length ? s : null;
}

export async function POST(req: Request) {
  const body = (await req.json()) as {
    sourceRunId?: string;
    objectKey?: string;
    times?: number;
    notes?: string | null;
    commit?: boolean;
  };

  const sourceRunId = parseGuid(body.sourceRunId);
  const objectKey = (body.objectKey ?? "individual").trim() || "individual";
  const times = Number.isFinite(body.times) ? Math.max(1, Number(body.times)) : 1;
  const commit = !!body.commit;
  const notes = typeof body.notes === "string" && body.notes.trim().length ? body.notes.trim() : null;

  if (!sourceRunId) {
    return NextResponse.json({ error: "sourceRunId is required" }, { status: 400 });
  }

  try {
    // For small batches (<= 100), process all at once
    if (times <= 100) {
      const replayRes = await execProc<{ ItemIndex: number; ReplayRunID: string }>("dbo.ReplayDomainFast", {
        SourceRunID: sourceRunId,
        ObjectKey: objectKey,
        Times: times,
        Notes: notes,
        Commit: commit ? 1 : 0,
      });

      return NextResponse.json({
        sourceRunId,
        objectKey,
        commit,
        times,
        replayRuns: replayRes.recordset ?? [],
      });
    }

    // For larger batches, process in chunks of 100 to enable progress reporting
    const batchSize = 100;
    const batches = Math.ceil(times / batchSize);
    const allResults: { ItemIndex: number; ReplayRunID: string }[] = [];

    for (let batch = 0; batch < batches; batch++) {
      const batchStart = batch * batchSize;
      const batchCount = Math.min(batchSize, times - batchStart);
      
      const replayRes = await execProc<{ ItemIndex: number; ReplayRunID: string }>("dbo.ReplayDomainFast", {
        SourceRunID: sourceRunId,
        ObjectKey: objectKey,
        Times: batchCount,
        Notes: notes,
        Commit: commit ? 1 : 0,
      });

      const batchResults = replayRes.recordset ?? [];
      // Adjust ItemIndex to be global across all batches
      batchResults.forEach((r) => {
        r.ItemIndex += batchStart;
        allResults.push(r);
      });
    }

    return NextResponse.json({
      sourceRunId,
      objectKey,
      commit,
      times,
      replayRuns: allResults,
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : "ReplayDomainFast failed";
    return NextResponse.json({ error: msg }, { status: 500 });
  }
}
