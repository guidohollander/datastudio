"use client";

import { useState, useRef, useEffect } from "react";
import ExpressionBuilder from "./ExpressionBuilder";

type GeneratorOption = {
  id: string;
  label: string;
  icon: string;
  description: string;
  category: "keep" | "randomize" | "generate" | "fixed";
  buildExpression: (params: Record<string, string>) => string;
  params?: { key: string; label: string; placeholder: string; defaultValue?: string }[];
  applicableTypes?: string[];
};

const GENERATOR_OPTIONS: GeneratorOption[] = [
  {
    id: "ctx",
    label: "Keep original",
    icon: "📋",
    description: "Use the captured value (consistent across components)",
    category: "keep",
    buildExpression: (p) => `ctx(${p.field || "field"})`,
  },
  {
    id: "literal",
    label: "Fixed value",
    icon: "📌",
    description: "Use the same fixed value for every replay",
    category: "fixed",
    buildExpression: (p) => `literal('${(p.value || "").replace(/'/g, "''")}')`,
    params: [{ key: "value", label: "Value", placeholder: "Enter fixed value" }],
  },
  {
    id: "pool_firstname_male",
    label: "Random first name (male)",
    icon: "👨",
    description: "Pick from a pool of male first names",
    category: "randomize",
    buildExpression: () => "pool(firstNames.male)",
    applicableTypes: ["nvarchar", "varchar"],
  },
  {
    id: "pool_firstname_female",
    label: "Random first name (female)",
    icon: "👩",
    description: "Pick from a pool of female first names",
    category: "randomize",
    buildExpression: () => "pool(firstNames.female)",
    applicableTypes: ["nvarchar", "varchar"],
  },
  {
    id: "pool_surname",
    label: "Random surname",
    icon: "👤",
    description: "Pick from a pool of Dutch surnames",
    category: "randomize",
    buildExpression: () => "pool(surnames.dutch)",
    applicableTypes: ["nvarchar", "varchar"],
  },
  {
    id: "pool_city",
    label: "Random city",
    icon: "🏙️",
    description: "Pick from Dutch cities",
    category: "randomize",
    buildExpression: () => "pool(cities.netherlands)",
    applicableTypes: ["nvarchar", "varchar"],
  },
  {
    id: "pool_country",
    label: "Random country",
    icon: "🌍",
    description: "Pick from ISO country codes",
    category: "randomize",
    buildExpression: () => "pool(countries.iso)",
    applicableTypes: ["nvarchar", "varchar"],
  },
  {
    id: "weighted",
    label: "Weighted random",
    icon: "⚖️",
    description: "Pick values with custom probability weights",
    category: "randomize",
    buildExpression: (p) => `weighted(${p.options || "A:50|B:50"})`,
    params: [{ key: "options", label: "Options", placeholder: "Male:51|Female:49", defaultValue: "Male:51|Female:49" }],
  },
  {
    id: "pick",
    label: "Rotate values",
    icon: "🔄",
    description: "Cycle through a list of values in order",
    category: "randomize",
    buildExpression: (p) => `pick(${p.options || "A|B"})`,
    params: [{ key: "options", label: "Values (pipe-separated)", placeholder: "Value1|Value2|Value3" }],
  },
  {
    id: "random",
    label: "Random number",
    icon: "🎲",
    description: "Random integer within a range",
    category: "randomize",
    buildExpression: (p) => `random(${p.min || "1"}, ${p.max || "100"})`,
    params: [
      { key: "min", label: "Min", placeholder: "1", defaultValue: "1" },
      { key: "max", label: "Max", placeholder: "100", defaultValue: "100" },
    ],
    applicableTypes: ["bigint", "int", "smallint", "tinyint", "numeric", "decimal"],
  },
  {
    id: "dateRange",
    label: "Random date",
    icon: "📅",
    description: "Random date within a range",
    category: "randomize",
    buildExpression: (p) => `dateRange(${p.start || "2020-01-01"}, ${p.end || "2025-12-31"})`,
    params: [
      { key: "start", label: "Start date", placeholder: "2020-01-01", defaultValue: "2020-01-01" },
      { key: "end", label: "End date", placeholder: "2025-12-31", defaultValue: "2025-12-31" },
    ],
    applicableTypes: ["date", "datetime", "datetime2", "smalldatetime"],
  },
  {
    id: "ageRange",
    label: "Age-based DOB",
    icon: "🎂",
    description: "Generate date of birth for a given age range",
    category: "randomize",
    buildExpression: (p) => `ageRange(${p.min || "18"}, ${p.max || "65"})`,
    params: [
      { key: "min", label: "Min age", placeholder: "18", defaultValue: "18" },
      { key: "max", label: "Max age", placeholder: "65", defaultValue: "65" },
    ],
    applicableTypes: ["date", "datetime", "datetime2"],
  },
  {
    id: "newguid",
    label: "New GUID",
    icon: "🆔",
    description: "Generate a unique GUID for each replay",
    category: "generate",
    buildExpression: () => "newguid()",
    applicableTypes: ["uniqueidentifier"],
  },
  {
    id: "seq",
    label: "Sequential number",
    icon: "🔢",
    description: "1, 2, 3, 4, 5...",
    category: "generate",
    buildExpression: () => "seq()",
  },
  {
    id: "lookup",
    label: "Lookup reference",
    icon: "🔍",
    description: "Pick a valid value from a reference/lookup table",
    category: "randomize",
    buildExpression: (p) => `lookup(${p.table || "NATIONALITY"})`,
    params: [{ key: "table", label: "Reference table name", placeholder: "NATIONALITY" }],
    applicableTypes: ["bigint", "int", "smallint"],
  },
  {
    id: "concat",
    label: "Concatenate",
    icon: "🔗",
    description: "Combine multiple values or expressions",
    category: "generate",
    buildExpression: (p) => `concat(${p.expression || "'prefix_', seq()"})`,
    params: [{ key: "expression", label: "Expression parts", placeholder: "'User ', seq()" }],
  },
  {
    id: "custom",
    label: "Custom expression",
    icon: "✏️",
    description: "Write your own generator expression",
    category: "generate",
    buildExpression: (p) => p.expression || "",
    params: [{ key: "expression", label: "Expression", placeholder: "e.g., pool(firstNames.male)" }],
  },
];

function detectCurrentGenerator(gen: string | null, fieldKey: string): { optionId: string; params: Record<string, string> } {
  if (!gen) return { optionId: "ctx", params: { field: fieldKey } };

  const trimmed = gen.trim();

  // Check if it's ctx(fieldname) - which means "keep original"
  const ctxMatch = trimmed.match(/^ctx\(([^)]+)\)$/);
  if (ctxMatch) {
    const ctxField = ctxMatch[1].trim();
    // If it references the same field, it's "keep original"
    if (ctxField.toLowerCase() === fieldKey.toLowerCase()) {
      return { optionId: "ctx", params: { field: fieldKey } };
    }
    // Otherwise it's a custom ctx reference to another field
    return { optionId: "custom", params: { expression: trimmed } };
  }
  
  if (trimmed === "newguid()") return { optionId: "newguid", params: {} };
  if (trimmed === "seq()") return { optionId: "seq", params: {} };
  if (trimmed === "pool(firstNames.male)") return { optionId: "pool_firstname_male", params: {} };
  if (trimmed === "pool(firstNames.female)") return { optionId: "pool_firstname_female", params: {} };
  if (trimmed === "pool(surnames.dutch)") return { optionId: "pool_surname", params: {} };
  if (trimmed === "pool(cities.netherlands)") return { optionId: "pool_city", params: {} };
  if (trimmed === "pool(countries.iso)") return { optionId: "pool_country", params: {} };

  const literalMatch = trimmed.match(/^literal\('(.*)'\)$/);
  if (literalMatch) return { optionId: "literal", params: { value: literalMatch[1].replace(/''/g, "'") } };

  const weightedMatch = trimmed.match(/^weighted\((.+)\)$/);
  if (weightedMatch) return { optionId: "weighted", params: { options: weightedMatch[1] } };

  const pickMatch = trimmed.match(/^pick\((.+)\)$/);
  if (pickMatch) return { optionId: "pick", params: { options: pickMatch[1] } };

  const randomMatch = trimmed.match(/^random\((\d+),\s*(\d+)\)$/);
  if (randomMatch) return { optionId: "random", params: { min: randomMatch[1], max: randomMatch[2] } };

  const dateRangeMatch = trimmed.match(/^dateRange\((.+),\s*(.+)\)$/);
  if (dateRangeMatch) return { optionId: "dateRange", params: { start: dateRangeMatch[1].trim(), end: dateRangeMatch[2].trim() } };

  const ageRangeMatch = trimmed.match(/^ageRange\((\d+),\s*(\d+)\)$/);
  if (ageRangeMatch) return { optionId: "ageRange", params: { min: ageRangeMatch[1], max: ageRangeMatch[2] } };

  const lookupMatch = trimmed.match(/^lookup\((.+)\)$/);
  if (lookupMatch) return { optionId: "lookup", params: { table: lookupMatch[1] } };

  const concatMatch = trimmed.match(/^concat\((.+)\)$/);
  if (concatMatch) return { optionId: "concat", params: { expression: concatMatch[1] } };

  return { optionId: "custom", params: { expression: trimmed } };
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
  currentGen: string | null;
  originalValue: string;
  availableContextVars?: ContextVar[];
  onChange: (expression: string) => void;
};

export default function GeneratorPicker({ fieldKey, dataType, currentGen, originalValue, availableContextVars, onChange }: Props) {
  const [isOpen, setIsOpen] = useState(false);
  const [selectedId, setSelectedId] = useState<string>(() => {
    return detectCurrentGenerator(currentGen, fieldKey).optionId;
  });
  const [params, setParams] = useState<Record<string, string>>(() => {
    return detectCurrentGenerator(currentGen, fieldKey).params;
  });
  const [builderOpen, setBuilderOpen] = useState(false);
  const popoverRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (popoverRef.current && !popoverRef.current.contains(e.target as Node)) {
        setIsOpen(false);
      }
    }
    if (isOpen) {
      document.addEventListener("mousedown", handleClickOutside);
      return () => document.removeEventListener("mousedown", handleClickOutside);
    }
  }, [isOpen]);

  const baseType = dataType.replace(/\(.*\)/, "").toLowerCase().trim();

  const applicableOptions = GENERATOR_OPTIONS.filter((opt) => {
    if (!opt.applicableTypes) return true;
    return opt.applicableTypes.includes(baseType);
  });

  const selectedOption = GENERATOR_OPTIONS.find((o) => o.id === selectedId);

  function applySelection(optId: string, paramValues?: Record<string, string>) {
    const opt = GENERATOR_OPTIONS.find((o) => o.id === optId);
    if (!opt) return;

    const finalParams = { ...(paramValues || params) };
    // For ctx, always use the fieldKey
    if (optId === "ctx") {
      finalParams.field = fieldKey;
    }
    const expression = opt.buildExpression(finalParams);
    onChange(expression);
    setIsOpen(false);
  }

  function handleQuickSelect(optId: string) {
    const opt = GENERATOR_OPTIONS.find((o) => o.id === optId);
    if (!opt) return;

    setSelectedId(optId);
    if (!opt.params || opt.params.length === 0) {
      // No params needed, apply immediately
      const newParams: Record<string, string> = optId === "ctx" ? { field: fieldKey } : {};
      setParams(newParams);
      applySelection(optId, newParams);
    } else {
      // Has params, show config
      const newParams: Record<string, string> = {};
      for (const p of opt.params) {
        newParams[p.key] = p.defaultValue || "";
      }
      setParams(newParams);
    }
  }

  const categoryColors: Record<string, string> = {
    keep: "bg-blue-50 text-blue-700 border-blue-200",
    randomize: "bg-green-50 text-green-700 border-green-200",
    generate: "bg-purple-50 text-purple-700 border-purple-200",
    fixed: "bg-zinc-50 text-zinc-700 border-zinc-200",
  };

  const categoryLabels: Record<string, string> = {
    keep: "Keep",
    randomize: "Randomize",
    generate: "Generate",
    fixed: "Fixed",
  };

  const selectedLabel = selectedOption
    ? `${selectedOption.icon} ${selectedOption.label}`
    : "Choose...";

  const isCtx = selectedId === "ctx";

  return (
    <div className="relative" ref={popoverRef}>
      {/* Trigger button */}
      <button
        type="button"
        onClick={() => setIsOpen(!isOpen)}
        className={`
          flex items-center gap-1.5 w-full rounded border px-2 py-1 text-xs text-left
          transition-colors hover:bg-zinc-50
          ${isCtx
            ? "border-blue-200 bg-blue-50/50 text-blue-700"
            : "border-zinc-300 bg-white text-zinc-800"
          }
        `}
      >
        <span className="flex-1 truncate font-medium">{selectedLabel}</span>
        <span className="text-zinc-400 text-[10px]">▼</span>
      </button>

      {/* Current expression display */}
      {currentGen && !isCtx && (
        <div className="mt-0.5 font-mono text-[10px] text-zinc-500 truncate" title={currentGen}>
          {currentGen}
        </div>
      )}

      {/* Popover */}
      {isOpen && (
        <div className="absolute left-0 top-full z-50 mt-1 w-[340px] rounded-lg border border-zinc-200 bg-white shadow-xl">
          {/* Quick picks header */}
          <div className="border-b border-zinc-100 p-2">
            <div className="text-[10px] font-semibold text-zinc-500 uppercase tracking-wider mb-1.5">
              Choose generator for <span className="text-zinc-800">{fieldKey}</span>
            </div>
            {originalValue && (
              <div className="text-[10px] text-zinc-500">
                Original: <span className="font-mono text-zinc-700">{originalValue.length > 40 ? originalValue.substring(0, 40) + "..." : originalValue}</span>
              </div>
            )}
          </div>

          {/* Options grouped by category */}
          <div className="max-h-[320px] overflow-y-auto p-1.5">
            {(["keep", "randomize", "generate", "fixed"] as const).map((cat) => {
              const catOptions = applicableOptions.filter((o) => o.category === cat);
              if (catOptions.length === 0) return null;
              return (
                <div key={cat} className="mb-1.5">
                  <div className={`text-[9px] font-bold uppercase tracking-wider px-2 py-0.5 rounded ${categoryColors[cat]}`}>
                    {categoryLabels[cat]}
                  </div>
                  {catOptions.map((opt) => (
                    <button
                      key={opt.id}
                      type="button"
                      onClick={() => handleQuickSelect(opt.id)}
                      className={`
                        flex items-center gap-2 w-full rounded px-2 py-1.5 text-left text-xs
                        transition-colors
                        ${selectedId === opt.id
                          ? "bg-blue-100 text-blue-900"
                          : "hover:bg-zinc-50 text-zinc-700"
                        }
                      `}
                    >
                      <span className="text-sm flex-shrink-0">{opt.icon}</span>
                      <div className="flex-1 min-w-0">
                        <div className="font-medium truncate">{opt.label}</div>
                        <div className="text-[10px] text-zinc-500 truncate">{opt.description}</div>
                      </div>
                      {selectedId === opt.id && <span className="text-blue-600 text-sm">✓</span>}
                    </button>
                  ))}
                </div>
              );
            })}
          </div>

          {/* Param configuration area */}
          {selectedOption?.params && selectedOption.params.length > 0 && (
            <div className="border-t border-zinc-100 p-2.5 bg-zinc-50/50">
              <div className="text-[10px] font-semibold text-zinc-600 mb-1.5">Configure {selectedOption.label}</div>
              <div className="space-y-1.5">
                {selectedOption.params.map((p) => (
                  <div key={p.key}>
                    <label className="text-[10px] text-zinc-600 font-medium">{p.label}</label>
                    <input
                      type="text"
                      value={params[p.key] || ""}
                      onChange={(e) => setParams((prev) => ({ ...prev, [p.key]: e.target.value }))}
                      placeholder={p.placeholder}
                      className="block w-full rounded border border-zinc-300 px-2 py-1 text-xs font-mono focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                    />
                  </div>
                ))}
              </div>
              <button
                type="button"
                onClick={() => applySelection(selectedId)}
                className="mt-2 w-full rounded bg-blue-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-blue-700 transition-colors"
              >
                Apply
              </button>
            </div>
          )}

          {/* Advanced builder link */}
          <div className="border-t border-zinc-100 p-2">
            <button
              type="button"
              onClick={() => { setIsOpen(false); setBuilderOpen(true); }}
              className="flex items-center gap-1.5 w-full rounded px-2 py-1.5 text-xs text-left text-purple-700 hover:bg-purple-50 transition-colors font-medium"
            >
              <span>🛠️</span>
              <span>Advanced Expression Builder...</span>
            </button>
          </div>
        </div>
      )}

      {/* Expression Builder Modal */}
      {builderOpen && (
        <ExpressionBuilder
          fieldKey={fieldKey}
          dataType={dataType}
          currentExpression={currentGen}
          originalValue={originalValue}
          availableContextVars={availableContextVars}
          onSave={(expression) => {
            onChange(expression);
            setBuilderOpen(false);
          }}
          onClose={() => setBuilderOpen(false)}
        />
      )}
    </div>
  );
}
