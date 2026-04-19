import { NextResponse } from "next/server";
import { execQuery } from "@/lib/db";

export async function POST(req: Request) {
  const body = (await req.json()) as {
    objectKey?: string;
    componentKey?: string;
    fieldKey?: string;
    gen?: string | null;
  };

  const objectKey = (body.objectKey ?? "").trim();
  const componentKey = (body.componentKey ?? "").trim();
  const fieldKey = (body.fieldKey ?? "").trim();
  const gen = body.gen?.trim() || null;

  if (!objectKey || !componentKey || !fieldKey) {
    return NextResponse.json(
      { error: "objectKey, componentKey, and fieldKey are required" },
      { status: 400 }
    );
  }

  try {
    // Update the Notes field with the generator expression
    const notes = gen ? `gen: ${gen}` : null;

    await execQuery(
      `UPDATE dbo.MigrationDomainField 
       SET Notes = @Notes 
       WHERE ObjectKey = @ObjectKey 
         AND ComponentKey = @ComponentKey 
         AND FieldKey = @FieldKey`,
      {
        ObjectKey: objectKey,
        ComponentKey: componentKey,
        FieldKey: fieldKey,
        Notes: notes,
      }
    );

    return NextResponse.json({ success: true, gen });
  } catch (error) {
    console.error("Error updating field generator:", error);
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Failed to update field generator" },
      { status: 500 }
    );
  }
}
