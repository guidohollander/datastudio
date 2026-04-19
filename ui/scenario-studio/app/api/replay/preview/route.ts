import { NextResponse } from "next/server";
import { execQuery, execProc } from "@/lib/db";

function parseGuid(v: unknown) {
  if (typeof v !== "string") return null;
  const s = v.trim();
  return s.length ? s : null;
}

function getGenFromNotes(notes: string | null) {
  if (!notes) return null;
  const m = notes.split(/\r?\n/).map((x) => x.trim()).find((x) => x.toLowerCase().startsWith("gen:"));
  if (!m) return null;
  return m.slice(4).trim() || null;
}

type ContractRow = { ContractJson: string };
type EvalResult = { Result: string | null };

type FieldRow = {
  ObjectKey: string;
  ComponentKey: string;
  FieldKey: string;
  DataType: string;
  ExampleValue: string | null;
  Notes: string | null;
  PhysicalColumn: string;
  PhysicalTable: string;
};

export async function POST(req: Request) {
  const body = (await req.json()) as {
    sourceRunId?: string;
    objectKey?: string;
    times?: number;
    previewCount?: number;
  };

  const sourceRunId = parseGuid(body.sourceRunId);
  const objectKey = (body.objectKey ?? "individual").trim() || "individual";
  const times = Number.isFinite(body.times) ? Math.max(1, Number(body.times)) : 1;
  const previewCount = Number.isFinite(body.previewCount) ? Math.min(10, Math.max(1, Number(body.previewCount))) : 3;

  if (!sourceRunId) {
    return NextResponse.json({ error: "sourceRunId is required" }, { status: 400 });
  }

  try {
    const contractRes = await execProc<ContractRow>("dbo.GenerateDomainContractJson", {
      RunID: sourceRunId,
      ObjectKey: objectKey,
    });
    const contractJson = contractRes.recordset?.[0]?.ContractJson;
    if (!contractJson) {
      return NextResponse.json({ error: "GenerateDomainContractJson returned no ContractJson" }, { status: 500 });
    }

    const fieldsRes = await execQuery<FieldRow>(
      `
      SELECT f.ObjectKey, f.ComponentKey, f.FieldKey, f.PhysicalColumn, f.DataType, f.ExampleValue, f.Notes,
             c.PhysicalTable
      FROM dbo.MigrationDomainField f
      INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
      WHERE f.ObjectKey=@ObjectKey
      ORDER BY f.ComponentKey, f.FieldKey;
      `,
      { ObjectKey: objectKey }
    );

    const fieldRows = fieldsRes.recordset ?? [];

    // Fetch relationships for FK enrichment
    type RelRow = { ParentTable: string; ParentColumn: string; ChildTable: string; ChildColumn: string };
    const relRes = await execQuery<RelRow>(
      `SELECT ParentTable, ParentColumn, ChildTable, ChildColumn
       FROM dbo.MigrationTableRelationships WHERE IsActive = 1`,
      {}
    );
    const relLookup: Record<string, string> = {};
    for (const r of relRes.recordset ?? []) {
      const key = `${r.ChildTable}.${r.ChildColumn}`;
      if (relLookup[key]) relLookup[key] += ` / ${r.ParentTable}.${r.ParentColumn}`;
      else relLookup[key] = `${r.ParentTable}.${r.ParentColumn}`;
    }

    // Fetch sample captured values - get one row per table for original value display
    const capturedValuesRes = await execQuery<{ TableName: string; RowJson: string }>(
      `
      WITH FirstRowPerTable AS (
        SELECT TableName, RowJson,
               ROW_NUMBER() OVER (PARTITION BY TableName ORDER BY PkValue) as rn
        FROM dbo.MigrationScenarioRow
        WHERE RunID = @RunID
      )
      SELECT TableName, RowJson
      FROM FirstRowPerTable
      WHERE rn = 1
      ORDER BY TableName;
      `,
      { RunID: sourceRunId }
    );
    
    const capturedSamples: Array<Record<string, unknown>> = [];
    const capturedByTable: Record<string, Record<string, unknown>> = {};
    
    for (const row of capturedValuesRes.recordset ?? []) {
      if (row.RowJson && typeof row.RowJson === 'string') {
        try {
          const parsed = JSON.parse(row.RowJson);
          capturedSamples.push(parsed);
          // Store by table name for component-level lookup
          if (!capturedByTable[row.TableName]) {
            capturedByTable[row.TableName] = parsed;
          }
        } catch {
          // Skip invalid JSON
        }
      }
    }

    // Identify fields that appear in multiple components (need context for consistency)
    const fieldOccurrences = new Map<string, { count: number; generator: string | null }>();
    
    for (const f of fieldRows) {
      const existing = fieldOccurrences.get(f.FieldKey);
      const gen = getGenFromNotes(f.Notes);
      
      if (existing) {
        existing.count += 1;
        // Keep the first non-ctx generator we find
        if (!existing.generator || existing.generator.includes('ctx(')) {
          if (gen && !gen.includes('ctx(')) {
            existing.generator = gen;
          }
        }
      } else {
        fieldOccurrences.set(f.FieldKey, { count: 1, generator: gen });
      }
    }

    // Extract context fields (appear in 2+ components and have ctx() expressions)
    const contextFields: Array<{ key: string; expr: string }> = [];
    for (const [fieldKey, info] of fieldOccurrences.entries()) {
      if (info.count >= 2) {
        // For fields with ctx(), we need to determine the actual generator
        // Check if any field uses ctx() for this key
        const usesCtx = fieldRows.some(f => f.FieldKey === fieldKey && getGenFromNotes(f.Notes)?.includes('ctx('));
        
        if (usesCtx) {
          // Determine the generator based on field name
          let generator = '';
          const lowerKey = fieldKey.toLowerCase();
          
          if (lowerKey.includes('firstname') || lowerKey === 'firstnames') {
            generator = 'pool(firstNames.male)';
          } else if (lowerKey.includes('surname') || lowerKey.includes('birthname')) {
            generator = 'pool(surnames.dutch)';
          } else if (lowerKey === 'gender') {
            generator = 'weighted(Male:51|Female:49)';
          } else if (lowerKey.includes('dateofbirth') || lowerKey === 'birthdate') {
            generator = 'ageRange(25, 65)';
          } else if (lowerKey.includes('personguid')) {
            generator = 'newguid()';
          } else if (lowerKey.includes('placeofbirth')) {
            generator = 'pool(cities.netherlands)';
          } else if (info.generator && !info.generator.includes('ctx(')) {
            generator = info.generator;
          }
          
          if (generator) {
            contextFields.push({ key: fieldKey, expr: generator });
          }
        }
      }
    }

    const items: Record<string, unknown>[] = [];
    for (let i = 0; i < previewCount; i += 1) {
      // Build comprehensive context from ALL captured tables
      const context: Record<string, string> = {};

      // Populate context with values from all captured tables
      // This allows ctx() to reference fields from any component
      for (const [, tableRow] of Object.entries(capturedByTable)) {
        for (const [key, value] of Object.entries(tableRow)) {
          if (value !== null && value !== undefined) {
            context[key.toLowerCase()] = String(value);
          }
        }
      }

      // Then add generated values for fields that need consistency
      for (const cf of contextFields) {
        // Skip if we already have a captured value
        if (context[cf.key.toLowerCase()]) continue;
        
        try {
          const evalRes = await execQuery<EvalResult>(
            `DECLARE @Result NVARCHAR(MAX);
             EXEC dbo.EvaluateGeneratorExpression 
               @Expression = @Expression,
               @ItemIndex = @ItemIndex,
               @ContextJson = NULL,
               @Result = @Result OUTPUT;
             SELECT @Result as Result;`,
            { Expression: cf.expr, ItemIndex: i + 1 }
          );
          const evaluated = evalRes.recordset?.[0]?.Result;
          if (evaluated) context[cf.key] = evaluated;
        } catch (e) {
          console.error(`Error building context ${cf.key}:`, e);
        }
      }

      const item: Record<string, Record<string, unknown>> = {};

      // Sort fields: non-ctx generators first, then ctx-based generators
      // This ensures progressive context building works correctly
      const nonCtxFields = fieldRows.filter(f => {
        const gen = getGenFromNotes(f.Notes);
        return gen && !gen.includes('ctx(');
      });
      const ctxFields = fieldRows.filter(f => {
        const gen = getGenFromNotes(f.Notes);
        return gen && gen.includes('ctx(');
      });
      const noGenFields = fieldRows.filter(f => {
        const gen = getGenFromNotes(f.Notes);
        return !gen;
      });
      const sortedFields = [...nonCtxFields, ...ctxFields, ...noGenFields];

      for (const f of sortedFields) {
        const gen = getGenFromNotes(f.Notes);
        let generatedValue: string | null = f.ExampleValue ?? null;
        let originalValue: string | null = null;

        // Get original captured value for this field from the correct table's captured row
        const tableCapturedRow = capturedByTable[f.PhysicalTable] || {};
        const fieldValue = tableCapturedRow[f.PhysicalColumn];
        
        if (fieldValue !== null && fieldValue !== undefined) {
          originalValue = String(fieldValue);
        }

        // Detect FK/relationship fields via relationship lookup
        const relKey = `${f.PhysicalTable}.${f.PhysicalColumn}`;
        const isRelationshipField = !!relLookup[relKey];

        // Build fresh contextJson each iteration so downstream fields see computed values
        const contextJson = JSON.stringify(context);

        if (isRelationshipField) {
          // FK fields are auto-remapped, not generated
          generatedValue = null;
        } else if (gen) {
          try {
            // Call stored procedure with progressive context
            const evalRes = await execQuery<EvalResult>(
              `DECLARE @Result NVARCHAR(MAX);
               EXEC dbo.EvaluateGeneratorExpression 
                 @Expression = @Expression,
                 @ItemIndex = @ItemIndex,
                 @ContextJson = @ContextJson,
                 @Result = @Result OUTPUT;
               SELECT @Result as Result;`,
              {
                Expression: gen,
                ItemIndex: i + 1,
                ContextJson: contextJson,
              }
            );
            const evaluated = evalRes.recordset?.[0]?.Result;
            if (evaluated !== null && evaluated !== undefined) {
              generatedValue = evaluated;
              // Store computed value back into context so downstream fields can use ctx(fieldKey)
              context[f.FieldKey.toLowerCase()] = evaluated;
            }
          } catch (e) {
            console.error(`Error evaluating ${f.FieldKey}:`, e);
          }
        }

        if (generatedValue === null && originalValue === null) continue;

        if (!item[f.ComponentKey]) item[f.ComponentKey] = {};
        
        // Store both original and generated values for comparison
        item[f.ComponentKey][f.FieldKey] = {
          original: originalValue,
          generated: generatedValue,
          generator: gen,
          isSame: originalValue === generatedValue,
          usesCtx: gen?.includes('ctx(') || false,
          parentRelationship: relLookup[relKey] ?? null,
        };
      }

      items.push(item);
    }

    return NextResponse.json({
      sourceRunId,
      objectKey,
      totalItems: times,
      previewItems: items,
      contractJson,
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : "Preview generation failed";
    return NextResponse.json({ error: msg }, { status: 500 });
  }
}
