import { NextResponse } from "next/server";
import { execProc } from "@/lib/db";

export async function POST(req: Request) {
  let body: {
    runId?: string;
    objectKey?: string;
    displayName?: string;
  };

  try {
    body = (await req.json()) as typeof body;
  } catch {
    return NextResponse.json({ error: "Request body must be valid JSON" }, { status: 400 });
  }

  const runId = body.runId?.trim();
  const objectKey = body.objectKey?.trim() || null;
  const displayName = body.displayName?.trim() || null;

  if (!runId) {
    return NextResponse.json({ error: "runId is required" }, { status: 400 });
  }

  try {
    console.log(`Generating contract from capture for run ${runId}...`);
    
    const result = await execProc<{ ObjectKey: string; DisplayName: string }>(
      "dbo.GenerateContractFromCapture",
      {
        RunID: runId,
        ObjectKey: objectKey,
        ObjectDisplayName: displayName,
      }
    );

    const generated = result.recordset?.[0];
    if (!generated) {
      return NextResponse.json(
        { error: "Contract generation returned no result" },
        { status: 500 }
      );
    }

    console.log(`Contract generated: ${generated.ObjectKey} - ${generated.DisplayName}`);

    return NextResponse.json({
      objectKey: generated.ObjectKey,
      displayName: generated.DisplayName,
    });
  } catch (error) {
    console.error("Error generating contract:", error);
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Failed to generate contract" },
      { status: 500 }
    );
  }
}
