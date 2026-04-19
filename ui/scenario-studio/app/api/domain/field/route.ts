import { NextResponse } from "next/server";
import { execQuery } from "@/lib/db";

function normalizeGen(gen: unknown) {
  if (gen === null || gen === undefined) return null;
  if (typeof gen !== "string") return null;
  const s = gen.trim();
  return s.length ? s : null;
}

function getGenFromNotes(notes: string | null) {
  if (!notes) return null;
  const m = notes.split(/\r?\n/).map((x) => x.trim()).find((x) => x.toLowerCase().startsWith("gen:"));
  if (!m) return null;
  return m.slice(4).trim() || null;
}

function setGenInNotes(existingNotes: string | null, gen: string | null) {
  const lines = (existingNotes ?? "").split(/\r?\n/).map((x) => x.trim()).filter((x) => x.length > 0);
  const kept = lines.filter((x) => !x.toLowerCase().startsWith("gen:"));
  if (gen) kept.push(`gen:${gen}`);
  return kept.length ? kept.join("\n") : null;
}

export async function PATCH(req: Request) {
  const body = (await req.json()) as {
    objectKey?: string;
    componentKey?: string;
    fieldKey?: string;
    gen?: string | null;
  };

  const objectKey = (body.objectKey ?? "").trim();
  const componentKey = (body.componentKey ?? "").trim();
  const fieldKey = (body.fieldKey ?? "").trim();
  const gen = normalizeGen(body.gen);

  if (!objectKey || !componentKey || !fieldKey) {
    return NextResponse.json({ error: "objectKey, componentKey and fieldKey are required" }, { status: 400 });
  }

  const current = await execQuery<{ Notes: string | null }>(
    `
    SELECT Notes
    FROM dbo.MigrationDomainField
    WHERE ObjectKey=@ObjectKey AND ComponentKey=@ComponentKey AND FieldKey=@FieldKey;
    `,
    { ObjectKey: objectKey, ComponentKey: componentKey, FieldKey: fieldKey },
  );

  const row = current.recordset?.[0];
  if (!row) {
    return NextResponse.json({ error: "Domain field not found" }, { status: 404 });
  }

  const nextNotes = setGenInNotes(row.Notes ?? null, gen);

  await execQuery(
    `
    UPDATE dbo.MigrationDomainField
    SET Notes=@Notes
    WHERE ObjectKey=@ObjectKey AND ComponentKey=@ComponentKey AND FieldKey=@FieldKey;
    `,
    { Notes: nextNotes, ObjectKey: objectKey, ComponentKey: componentKey, FieldKey: fieldKey },
  );

  return NextResponse.json({
    objectKey,
    componentKey,
    fieldKey,
    gen: getGenFromNotes(nextNotes),
  });
}
