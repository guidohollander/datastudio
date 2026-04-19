import { NextResponse } from "next/server";
import { execQuery } from "@/lib/db";

type EvalResult = { Result: string | null };

export async function POST(req: Request) {
  const body = (await req.json()) as {
    expression?: string;
    itemIndex?: number;
    contextJson?: string;
  };

  const expression = body.expression?.trim();
  const itemIndex = Number.isFinite(body.itemIndex) ? body.itemIndex : 1;
  const contextJson = body.contextJson || "{}";

  if (!expression) {
    return NextResponse.json({ error: "expression is required" }, { status: 400 });
  }

  try {
    const evalRes = await execQuery<EvalResult>(
      `DECLARE @Result NVARCHAR(MAX);
       EXEC dbo.EvaluateGeneratorExpression 
         @Expression = @Expression,
         @ItemIndex = @ItemIndex,
         @ContextJson = @ContextJson,
         @Result = @Result OUTPUT;
       SELECT @Result as Result;`,
      {
        Expression: expression,
        ItemIndex: itemIndex,
        ContextJson: contextJson,
      }
    );

    const result = evalRes.recordset?.[0]?.Result;
    
    return NextResponse.json({ result });
  } catch (e) {
    const msg = e instanceof Error ? e.message : "Generator evaluation failed";
    return NextResponse.json({ error: msg }, { status: 500 });
  }
}
