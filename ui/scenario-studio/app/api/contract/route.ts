import { NextResponse } from "next/server";
import { execProc, execQuery } from "@/lib/db";

function parseGuid(v: string | null) {
  const s = (v ?? "").trim();
  if (!s) return null;
  return s;
}

function getGenFromNotes(notes: string | null) {
  if (!notes) return null;
  const m = notes.split(/\r?\n/).map((x) => x.trim()).find((x) => x.toLowerCase().startsWith("gen:"));
  if (!m) return null;
  return m.slice(4).trim() || null;
}

type ContractRow = { ContractJson: string };

type RelationshipRow = {
  ParentTable: string;
  ParentColumn: string;
  ChildTable: string;
  ChildColumn: string;
};

type MappingRow = {
  ObjectKey: string;
  ComponentKey: string;
  ComponentDisplayName: string;
  FieldKey: string;
  FieldDisplayName: string | null;
  PhysicalTable: string;
  PhysicalColumn: string;
  DataType: string;
  IsRequired: boolean;
  ExampleValue: string | null;
  Notes: string | null;
};

export async function GET(req: Request) {
  const url = new URL(req.url);
  const runId = parseGuid(url.searchParams.get("runId"));
  const objectKey = (url.searchParams.get("objectKey") ?? "individual").trim() || "individual";
  const excludeFramework = url.searchParams.get("excludeFramework") === "true";

  if (!runId) {
    return NextResponse.json({ error: "runId is required" }, { status: 400 });
  }

  try {
    const fieldDisplayNameExistsRes = await execQuery<{ HasDisplayName: number }>(
      `
      SELECT CASE
        WHEN COL_LENGTH('dbo.MigrationDomainField', 'DisplayName') IS NOT NULL THEN 1
        ELSE 0
      END AS HasDisplayName;
      `,
      {},
    );
    const hasFieldDisplayName = fieldDisplayNameExistsRes.recordset?.[0]?.HasDisplayName === 1;

    const contractRes = await execProc<ContractRow>("dbo.GenerateDomainContractJson", {
      RunID: runId,
      ObjectKey: objectKey,
      ExcludeFrameworkTables: excludeFramework ? 1 : 0,
    });
    
    console.log("Contract response:", contractRes.recordset?.[0]);
    
    const contractJson = contractRes.recordset?.[0]?.ContractJson;
    if (!contractJson || contractJson.trim() === '') {
      console.error("GenerateDomainContractJson returned empty ContractJson");
      return NextResponse.json({ 
        error: "No domain contract found. The domain model may not be configured yet.",
        details: "Run 'EXEC dbo.EnsureDomainContractDefaults' to initialize the domain model."
      }, { status: 500 });
    }

    const mapQuery = hasFieldDisplayName
      ? `
        SELECT
          f.ObjectKey,
          f.ComponentKey,
          c.DisplayName AS ComponentDisplayName,
          f.FieldKey,
          f.DisplayName AS FieldDisplayName,
          c.PhysicalTable,
          f.PhysicalColumn,
          f.DataType,
          f.IsRequired,
          f.ExampleValue,
          f.Notes
        FROM dbo.MigrationDomainField f
        INNER JOIN dbo.MigrationDomainComponent c
          ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
        WHERE f.ObjectKey = @ObjectKey
        ORDER BY c.SortOrder, f.ComponentKey, f.FieldKey;
      `
      : `
        SELECT
          f.ObjectKey,
          f.ComponentKey,
          c.DisplayName AS ComponentDisplayName,
          f.FieldKey,
          CAST(NULL AS NVARCHAR(200)) AS FieldDisplayName,
          c.PhysicalTable,
          f.PhysicalColumn,
          f.DataType,
          f.IsRequired,
          f.ExampleValue,
          f.Notes
        FROM dbo.MigrationDomainField f
        INNER JOIN dbo.MigrationDomainComponent c
          ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
        WHERE f.ObjectKey = @ObjectKey
        ORDER BY c.SortOrder, f.ComponentKey, f.FieldKey;
      `;

    const mapRes = await execQuery<MappingRow>(mapQuery, { ObjectKey: objectKey });

    // Fetch active relationships for FK field enrichment
    const relRes = await execQuery<RelationshipRow>(
      `SELECT ParentTable, ParentColumn, ChildTable, ChildColumn
       FROM dbo.MigrationTableRelationships
       WHERE IsActive = 1
       ORDER BY ParentTable, ChildTable`,
      {},
    );

    // Build lookup: ChildTable.ChildColumn -> ParentTable.ParentColumn
    const relLookup: Record<string, string> = {};
    for (const r of relRes.recordset ?? []) {
      const key = `${r.ChildTable}.${r.ChildColumn}`;
      // May have multiple parents; collect them
      if (relLookup[key]) {
        relLookup[key] += ` / ${r.ParentTable}.${r.ParentColumn}`;
      } else {
        relLookup[key] = `${r.ParentTable}.${r.ParentColumn}`;
      }
    }

    const mappings = (mapRes.recordset ?? []).map((r) => {
      // Check if this field is an FK target
      const relKey = `${r.PhysicalTable}.${r.PhysicalColumn}`;
      return {
        objectKey: r.ObjectKey,
        componentKey: r.ComponentKey,
        componentDisplayName: r.ComponentDisplayName,
        fieldKey: r.FieldKey,
        displayName: r.FieldDisplayName,
        physicalTable: r.PhysicalTable,
        physicalColumn: r.PhysicalColumn,
        dataType: r.DataType,
        required: r.IsRequired,
        example: r.ExampleValue,
        gen: getGenFromNotes(r.Notes),
        parentRelationship: relLookup[relKey] ?? null,
      };
    });

    return NextResponse.json({ contractJson, mappings });
  } catch (error) {
    console.error("Error loading contract:", error);
    return NextResponse.json({
      error: error instanceof Error ? error.message : "Failed to load contract"
    }, { status: 500 });
  }
}
