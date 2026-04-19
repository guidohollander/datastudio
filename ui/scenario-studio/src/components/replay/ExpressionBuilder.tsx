"use client";

import { useState, useEffect, useCallback, useRef } from "react";

type ExpressionPart = {
  id: string;
  type: "function" | "literal" | "separator";
  expression: string;
  label: string;
};

type PreviewSample = {
  index: number;
  value: string | null;
  error?: string;
};

const EXPRESSION_TEMPLATES: {
  id: string;
  label: string;
  icon: string;
  category: string;
  expression: string;
  description: string;
  editable?: boolean;
  editHint?: string;
}[] = [
  // Keep
  { id: "ctx", label: "ctx(field)", icon: "📋", category: "Keep Original", expression: "ctx(FIELD)", description: "Use captured value", editable: true, editHint: "Replace FIELD with the field name" },
  // Text generators
  { id: "pool_fn_m", label: "First name (M)", icon: "👨", category: "Names", expression: "pool(firstNames.male)", description: "Random male first name" },
  { id: "pool_fn_f", label: "First name (F)", icon: "👩", category: "Names", expression: "pool(firstNames.female)", description: "Random female first name" },
  { id: "pool_sn", label: "Surname", icon: "👤", category: "Names", expression: "pool(surnames.dutch)", description: "Random Dutch surname" },
  { id: "pool_city", label: "City", icon: "🏙️", category: "Places", expression: "pool(cities.netherlands)", description: "Random NL city" },
  { id: "pool_country", label: "Country", icon: "🌍", category: "Places", expression: "pool(countries.iso)", description: "Random country code" },
  // Numbers
  { id: "seq", label: "seq()", icon: "🔢", category: "Numbers", expression: "seq()", description: "1, 2, 3, 4..." },
  { id: "random", label: "random(min,max)", icon: "🎲", category: "Numbers", expression: "random(1, 100)", description: "Random integer", editable: true, editHint: "Set min and max" },
  { id: "lookup", label: "lookup(table)", icon: "🔍", category: "Numbers", expression: "lookup(NATIONALITY)", description: "Valid ref table ID", editable: true, editHint: "Set the reference table name" },
  // Dates
  { id: "dateRange", label: "dateRange()", icon: "📅", category: "Dates", expression: "dateRange(2020-01-01, 2025-12-31)", description: "Random date in range", editable: true, editHint: "Set start and end dates" },
  { id: "ageRange", label: "ageRange()", icon: "🎂", category: "Dates", expression: "ageRange(18, 65)", description: "DOB from age range", editable: true, editHint: "Set min and max age" },
  // Distribution
  { id: "weighted", label: "weighted()", icon: "⚖️", category: "Distribution", expression: "weighted(Male:51|Female:49)", description: "Weighted random pick", editable: true, editHint: "Set options with weights" },
  { id: "pick", label: "pick()", icon: "🔄", category: "Distribution", expression: "pick(A|B|C)", description: "Rotate through values", editable: true, editHint: "Set pipe-separated values" },
  // Special
  { id: "newguid", label: "newguid()", icon: "🆔", category: "Special", expression: "newguid()", description: "Unique GUID" },
  { id: "literal", label: "literal('...')", icon: "📌", category: "Special", expression: "literal('value')", description: "Fixed constant", editable: true, editHint: "Set the fixed value" },
  { id: "email", label: "email()", icon: "📧", category: "Special", expression: "email(pool(firstNames.male), pool(surnames.dutch), pool(emailDomains))", description: "Generated email" },
  // Combinators
  { id: "text_sep", label: "' '", icon: "⎵", category: "Glue", expression: "' '", description: "Space separator" },
  { id: "comma_sep", label: "', '", icon: ",", category: "Glue", expression: "', '", description: "Comma separator" },
  { id: "dash_sep", label: "'-'", icon: "-", category: "Glue", expression: "'-'", description: "Dash separator" },
  { id: "custom_text", label: "'...'", icon: "✏️", category: "Glue", expression: "'text'", description: "Custom text", editable: true, editHint: "Enter your text" },
];

let partIdCounter = 0;
function nextPartId() {
  return `part_${++partIdCounter}_${Date.now()}`;
}

type ContextVar = {
  name: string;
  source: string;
  generator: string | null;
  example: string | null;
};

type Props = {
  fieldKey: string;
  dataType: string;
  currentExpression: string | null;
  originalValue: string;
  availableContextVars?: ContextVar[];
  onSave: (expression: string) => void;
  onClose: () => void;
};

type EvaluateResponse = {
  result?: string;
  error?: string;
};

function parseExpressionParts(expression: string | null): ExpressionPart[] {
  if (!expression) return [];

  const concatMatch = expression.match(/^concat\((.+)\)$/);
  if (concatMatch) {
    const inner = concatMatch[1];
    const parsed = splitConcatArgs(inner);
    return parsed.map((expr) => ({
      id: nextPartId(),
      type: expr.startsWith("'") ? "literal" : "function",
      expression: expr.trim(),
      label: expr.trim(),
    }));
  }

  return [{
    id: nextPartId(),
    type: expression.startsWith("'") ? "literal" : "function",
    expression,
    label: expression,
  }];
}

export default function ExpressionBuilder({ fieldKey, dataType, currentExpression, originalValue, availableContextVars, onSave, onClose }: Props) {
  const [parts, setParts] = useState<ExpressionPart[]>(() => parseExpressionParts(currentExpression));
  const [rawExpression, setRawExpression] = useState(currentExpression || "");
  const [mode, setMode] = useState<"visual" | "raw">("visual");
  const [previews, setPreviews] = useState<PreviewSample[]>([]);
  const [previewLoading, setPreviewLoading] = useState(false);
  const [previewError, setPreviewError] = useState<string | null>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const fetchPreviews = useCallback(async (expression: string) => {
    setPreviewLoading(true);
    setPreviewError(null);
    const samples: PreviewSample[] = [];

    try {
      const contextJson = JSON.stringify({
        [fieldKey.toLowerCase()]: originalValue || "",
        firstname: "Jan",
        surname: "De Jong",
        gender: "Male",
        dateofbirth: "1990-01-15",
        personguid: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
      });

      const promises = [1, 2, 3, 4, 5].map(async (idx) => {
        try {
          const res = await fetch("/api/generator/evaluate", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ expression, itemIndex: idx, contextJson }),
          });
          if (!res.ok) {
            const err = (await res.json()) as EvaluateResponse;
            return { index: idx, value: null, error: err.error || "Error" };
          }
          const json = (await res.json()) as EvaluateResponse;
          return { index: idx, value: json.result || null };
        } catch {
          return { index: idx, value: null, error: "Network error" };
        }
      });

      const results = await Promise.all(promises);
      samples.push(...results);
    } catch {
      setPreviewError("Failed to generate preview");
    }

    setPreviews(samples);
    setPreviewLoading(false);
  }, [fieldKey, originalValue]);

  // Build expression from parts
  const builtExpression = useCallback(() => {
    if (mode === "raw") return rawExpression;
    if (parts.length === 0) return "";
    if (parts.length === 1) return parts[0].expression;
    return `concat(${parts.map((p) => p.expression).join(", ")})`;
  }, [parts, rawExpression, mode]);

  // Debounced live preview
  useEffect(() => {
    const expr = builtExpression();
    if (!expr) {
      return;
    }

    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => {
      void fetchPreviews(expr);
    }, 400);

    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [builtExpression, fetchPreviews]);

  function addPart(templateId: string) {
    const template = EXPRESSION_TEMPLATES.find((t) => t.id === templateId);
    if (!template) return;

    let expr = template.expression;
    // Replace FIELD placeholder with actual field key
    if (expr.includes("FIELD")) {
      expr = expr.replace("FIELD", fieldKey.toLowerCase());
    }

    setParts((prev) => [
      ...prev,
      {
        id: nextPartId(),
        type: expr.startsWith("'") ? "literal" : "function",
        expression: expr,
        label: template.label,
      },
    ]);
  }

  function removePart(partId: string) {
    setParts((prev) => prev.filter((p) => p.id !== partId));
  }

  function updatePartExpression(partId: string, newExpr: string) {
    setParts((prev) =>
      prev.map((p) => (p.id === partId ? { ...p, expression: newExpr, label: newExpr } : p))
    );
  }

  function movePart(partId: string, direction: -1 | 1) {
    setParts((prev) => {
      const idx = prev.findIndex((p) => p.id === partId);
      if (idx < 0) return prev;
      const newIdx = idx + direction;
      if (newIdx < 0 || newIdx >= prev.length) return prev;
      const next = [...prev];
      [next[idx], next[newIdx]] = [next[newIdx], next[idx]];
      return next;
    });
  }

  function handleSave() {
    const expr = mode === "raw" ? rawExpression.trim() : builtExpression();
    if (expr) {
      onSave(expr);
    }
    onClose();
  }

  // Group templates by category
  const categories = Array.from(new Set(EXPRESSION_TEMPLATES.map((t) => t.category)));

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/40 backdrop-blur-sm" onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}>
      <div className="w-[720px] max-h-[85vh] bg-white rounded-2xl shadow-2xl flex flex-col overflow-hidden" onClick={(e) => e.stopPropagation()}>
        {/* Header */}
        <div className="flex items-center justify-between px-5 py-3 border-b border-zinc-200 bg-zinc-50">
          <div>
            <h2 className="text-sm font-bold text-zinc-900">Expression Builder</h2>
            <div className="text-xs text-zinc-500 mt-0.5">
              Field: <span className="font-mono font-semibold text-zinc-700">{fieldKey}</span>
              <span className="mx-1.5">•</span>
              Type: <span className="font-mono text-zinc-600">{dataType}</span>
              {originalValue && (
                <>
                  <span className="mx-1.5">•</span>
                  Original: <span className="font-mono text-zinc-600">{originalValue.length > 30 ? originalValue.substring(0, 30) + "..." : originalValue}</span>
                </>
              )}
            </div>
          </div>
          <div className="flex items-center gap-2">
            <div className="flex bg-zinc-200 rounded-lg p-0.5">
              <button
                type="button"
                onClick={() => setMode("visual")}
                className={`px-3 py-1 rounded-md text-xs font-medium transition-colors ${mode === "visual" ? "bg-white text-zinc-900 shadow-sm" : "text-zinc-600 hover:text-zinc-900"}`}
              >
                Visual
              </button>
              <button
                type="button"
                onClick={() => { setMode("raw"); setRawExpression(builtExpression()); }}
                className={`px-3 py-1 rounded-md text-xs font-medium transition-colors ${mode === "raw" ? "bg-white text-zinc-900 shadow-sm" : "text-zinc-600 hover:text-zinc-900"}`}
              >
                Raw
              </button>
            </div>
            <button type="button" onClick={onClose} className="text-zinc-400 hover:text-zinc-600 text-lg leading-none px-1">✕</button>
          </div>
        </div>

        <div className="flex flex-1 min-h-0 overflow-hidden">
          {/* Left: Expression palette */}
          <div className="w-[240px] border-r border-zinc-200 overflow-y-auto bg-zinc-50/50 p-2">
            {/* Available context variables - grouped by component */}
            {availableContextVars && availableContextVars.length > 0 && (() => {
              // Group context vars by component
              const grouped = availableContextVars.reduce((acc, cv) => {
                const component = cv.source.split('.')[0] || 'other';
                if (!acc[component]) acc[component] = [];
                acc[component].push(cv);
                return acc;
              }, {} as Record<string, typeof availableContextVars>);
              
              return (
                <div className="mb-3 pb-2 border-b border-zinc-200">
                  <div className="text-[9px] font-bold text-blue-600 uppercase tracking-wider px-1 py-0.5 bg-blue-50 rounded mb-1">
                    Available ctx() variables
                  </div>
                  <div className="text-[10px] text-zinc-500 px-1 mb-1">Click to insert a reference to another field&apos;s value</div>
                  {Object.entries(grouped).map(([component, vars]) => (
                    <div key={component} className="mb-2">
                      <div className="text-[9px] font-semibold text-zinc-600 uppercase tracking-wide px-1 py-0.5 bg-zinc-100 rounded mb-0.5">
                        {component}
                      </div>
                      {vars.map((cv) => (
                        <button
                          key={cv.name}
                          type="button"
                          onClick={() => {
                            setParts((prev) => [
                              ...prev,
                              {
                                id: nextPartId(),
                                type: "function",
                                expression: `ctx(${cv.name})`,
                                label: `ctx(${cv.name})`,
                              },
                            ]);
                          }}
                          className={`flex items-center gap-1.5 w-full rounded px-1.5 py-1 text-left text-xs hover:bg-blue-50 transition-all group ${
                            cv.name.toLowerCase() === fieldKey.toLowerCase() ? "opacity-40" : ""
                          }`}
                          title={`From ${cv.source}${cv.generator ? ` (${cv.generator})` : ""}${cv.example ? ` — e.g. ${cv.example}` : ""}`}
                        >
                          <span className="text-xs flex-shrink-0 text-blue-500">ctx</span>
                          <div className="flex-1 min-w-0">
                            <div className="font-mono text-[11px] text-blue-700 truncate">{cv.name}</div>
                            {cv.example && <div className="text-[9px] text-zinc-400 truncate">{cv.example}</div>}
                          </div>
                          <span className="text-zinc-300 group-hover:text-blue-500 text-xs">+</span>
                        </button>
                      ))}
                    </div>
                  ))}
                </div>
              );
            })()}

            <div className="text-[10px] font-bold text-zinc-500 uppercase tracking-wider px-1 mb-1">
              Generators
            </div>
            {categories.map((cat) => {
              const items = EXPRESSION_TEMPLATES.filter((t) => t.category === cat);
              return (
                <div key={cat} className="mb-2">
                  <div className="text-[9px] font-bold text-zinc-400 uppercase tracking-wider px-1 py-0.5">{cat}</div>
                  {items.map((t) => (
                    <button
                      key={t.id}
                      type="button"
                      onClick={() => addPart(t.id)}
                      className="flex items-center gap-1.5 w-full rounded px-1.5 py-1 text-left text-xs hover:bg-white hover:shadow-sm transition-all group"
                      title={t.description}
                    >
                      <span className="text-xs flex-shrink-0">{t.icon}</span>
                      <div className="flex-1 min-w-0">
                        <div className="font-mono text-[11px] text-zinc-700 truncate">{t.label}</div>
                      </div>
                      <span className="text-zinc-300 group-hover:text-blue-500 text-xs">+</span>
                    </button>
                  ))}
                </div>
              );
            })}
          </div>

          {/* Right: Builder + Preview */}
          <div className="flex-1 flex flex-col min-h-0 overflow-hidden">
            {/* Expression area */}
            <div className="flex-1 overflow-y-auto p-4">
              {mode === "visual" ? (
                <div>
                  <div className="text-[10px] font-bold text-zinc-500 uppercase tracking-wider mb-2">
                    Expression parts {parts.length > 1 && <span className="text-zinc-400 normal-case font-normal">(will be wrapped in concat())</span>}
                  </div>

                  {parts.length === 0 ? (
                    <div className="rounded-lg border-2 border-dashed border-zinc-200 p-6 text-center">
                      <div className="text-zinc-400 text-sm">Click items from the palette to build your expression</div>
                      <div className="text-zinc-300 text-xs mt-1">Parts will be concatenated in order</div>
                    </div>
                  ) : (
                    <div className="space-y-1.5">
                      {parts.map((part, idx) => (
                        <div key={part.id} className="flex items-center gap-1.5 group">
                          {/* Reorder buttons */}
                          <div className="flex flex-col gap-0.5 opacity-0 group-hover:opacity-100 transition-opacity">
                            <button type="button" onClick={() => movePart(part.id, -1)} disabled={idx === 0}
                              className="text-[9px] text-zinc-400 hover:text-zinc-700 disabled:invisible leading-none">▲</button>
                            <button type="button" onClick={() => movePart(part.id, 1)} disabled={idx === parts.length - 1}
                              className="text-[9px] text-zinc-400 hover:text-zinc-700 disabled:invisible leading-none">▼</button>
                          </div>

                          {/* Part index */}
                          <div className="text-[10px] text-zinc-400 w-4 text-center flex-shrink-0">{idx + 1}</div>

                          {/* Editable expression */}
                          <input
                            type="text"
                            value={part.expression}
                            onChange={(e) => updatePartExpression(part.id, e.target.value)}
                            className="flex-1 rounded border border-zinc-200 bg-white px-2 py-1.5 text-xs font-mono
                                       focus:border-blue-400 focus:outline-none focus:ring-1 focus:ring-blue-400
                                       hover:border-zinc-300 transition-colors"
                          />

                          {/* Remove */}
                          <button
                            type="button"
                            onClick={() => removePart(part.id)}
                            className="text-zinc-300 hover:text-red-500 text-xs opacity-0 group-hover:opacity-100 transition-all px-1"
                            title="Remove"
                          >
                            ✕
                          </button>
                        </div>
                      ))}
                    </div>
                  )}

                  {/* Resulting expression */}
                  {parts.length > 0 && (
                    <div className="mt-3 rounded-lg bg-zinc-900 p-3">
                      <div className="text-[10px] font-bold text-zinc-500 uppercase tracking-wider mb-1">Resulting expression</div>
                      <code className="text-xs text-green-400 font-mono break-all">{builtExpression()}</code>
                    </div>
                  )}
                </div>
              ) : (
                /* Raw mode */
                <div>
                  <div className="text-[10px] font-bold text-zinc-500 uppercase tracking-wider mb-2">Raw expression</div>
                  <textarea
                    value={rawExpression}
                    onChange={(e) => setRawExpression(e.target.value)}
                    rows={4}
                    className="w-full rounded-lg border border-zinc-300 p-3 text-xs font-mono focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 resize-y"
                    placeholder="Enter your generator expression..."
                    spellCheck={false}
                  />
                </div>
              )}
            </div>

            {/* Preview panel */}
            <div className="border-t border-zinc-200 bg-zinc-50 p-3 flex-shrink-0">
              <div className="flex items-center gap-2 mb-2">
                <div className="text-[10px] font-bold text-zinc-500 uppercase tracking-wider">Live Preview</div>
                {previewLoading && <div className="text-[10px] text-blue-500 animate-pulse">generating...</div>}
                {previewError && <div className="text-[10px] text-red-500">{previewError}</div>}
              </div>

              {previews.length > 0 ? (
                <div className="flex gap-1.5 flex-wrap">
                  {previews.map((s) => (
                    <div key={s.index} className={`rounded px-2 py-1 text-xs font-mono ${s.error ? "bg-red-100 text-red-700" : "bg-white border border-zinc-200 text-zinc-800"}`}>
                      {s.error ? (
                        <span className="text-[10px]" title={s.error}>Error</span>
                      ) : (
                        <span title={s.value || "null"}>{s.value && s.value.length > 25 ? s.value.substring(0, 25) + "..." : s.value || <span className="text-zinc-400 italic">null</span>}</span>
                      )}
                    </div>
                  ))}
                </div>
              ) : (
                <div className="text-xs text-zinc-400 italic">Add expression parts to see a preview</div>
              )}
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between px-5 py-3 border-t border-zinc-200 bg-white">
          <button type="button" onClick={onClose} className="rounded-lg border border-zinc-300 px-4 py-1.5 text-xs font-medium text-zinc-700 hover:bg-zinc-50 transition-colors">
            Cancel
          </button>
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={() => { setParts([]); setRawExpression(""); setPreviews([]); }}
              className="rounded-lg border border-zinc-300 px-4 py-1.5 text-xs font-medium text-zinc-700 hover:bg-zinc-50 transition-colors"
            >
              Clear
            </button>
            <button
              type="button"
              onClick={handleSave}
              disabled={!builtExpression()}
              className="rounded-lg bg-blue-600 px-5 py-1.5 text-xs font-medium text-white hover:bg-blue-700 disabled:opacity-40 transition-colors"
            >
              Save Expression
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

/**
 * Split concat() arguments respecting nested parentheses and quoted strings.
 */
function splitConcatArgs(inner: string): string[] {
  const result: string[] = [];
  let depth = 0;
  let inQuote = false;
  let current = "";

  for (let i = 0; i < inner.length; i++) {
    const ch = inner[i];

    if (ch === "'" && (i === 0 || inner[i - 1] !== "\\")) {
      inQuote = !inQuote;
      current += ch;
    } else if (!inQuote && ch === "(") {
      depth++;
      current += ch;
    } else if (!inQuote && ch === ")") {
      depth--;
      current += ch;
    } else if (!inQuote && depth === 0 && ch === ",") {
      result.push(current.trim());
      current = "";
    } else {
      current += ch;
    }
  }

  if (current.trim()) {
    result.push(current.trim());
  }

  return result;
}
