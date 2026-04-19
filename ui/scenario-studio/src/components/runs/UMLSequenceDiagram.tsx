"use client";

import { useCallback, useEffect, useRef, useState } from "react";

type SequenceStep = {
  stepNumber: number;
  action: string;
  tableName: string;
  pkColumn: string;
  pkValue: number;
  changeType: string | null;
  dependencyLevel: number;
  foreignKeys: Array<{ column: string; referencesTable: string; referencesValue: number | null }>;
  typeInfo?: string;
};

export default function UMLSequenceDiagram({ runId }: { runId: string }) {
  const [steps, setSteps] = useState<SequenceStep[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [zoom, setZoom] = useState(1);
  const [pan, setPan] = useState({ x: 0, y: 0 });
  const [isDragging, setIsDragging] = useState(false);
  const [dragStart, setDragStart] = useState({ x: 0, y: 0 });
  const svgRef = useRef<SVGSVGElement>(null);

  const loadSequence = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(`/api/runs/${encodeURIComponent(runId)}/sequence`);
      const json = (await res.json()) as { steps?: SequenceStep[]; error?: string };
      if (!res.ok) throw new Error(json.error ?? "Failed to load sequence");
      setSteps(json.steps ?? []);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to load sequence");
    } finally {
      setLoading(false);
    }
  }, [runId]);

  useEffect(() => {
    void loadSequence();
  }, [loadSequence]);

  const handleWheel = (e: React.WheelEvent) => {
    e.preventDefault();
    const delta = e.deltaY > 0 ? 0.9 : 1.1;
    setZoom((prev) => Math.min(Math.max(prev * delta, 0.1), 5));
  };

  const handleMouseDown = (e: React.MouseEvent) => {
    if (e.button === 0) {
      setIsDragging(true);
      setDragStart({ x: e.clientX - pan.x, y: e.clientY - pan.y });
    }
  };

  const handleMouseMove = (e: React.MouseEvent) => {
    if (isDragging) {
      setPan({
        x: e.clientX - dragStart.x,
        y: e.clientY - dragStart.y,
      });
    }
  };

  const handleMouseUp = () => {
    setIsDragging(false);
  };

  const handleZoomIn = () => {
    setZoom((prev) => Math.min(prev * 1.2, 5));
  };

  const handleZoomOut = () => {
    setZoom((prev) => Math.max(prev / 1.2, 0.1));
  };

  const handleReset = () => {
    setZoom(1);
    setPan({ x: 0, y: 0 });
  };

  if (loading) {
    return <div className="text-sm text-zinc-600">Loading UML sequence diagram...</div>;
  }

  if (error) {
    return <div className="text-sm text-red-600">Error: {error}</div>;
  }

  if (steps.length === 0) {
    return <div className="text-sm text-zinc-600">No data captured yet.</div>;
  }

  // Get unique tables (actors/participants)
  const tables = Array.from(new Set(steps.map((s) => s.tableName))).sort();
  const tableWidth = 220;
  const tableSpacing = 40;
  const headerHeight = 100;
  const stepHeight = 90;
  const totalWidth = Math.max(1400, tables.length * (tableWidth + tableSpacing) + 60);
  const totalHeight = headerHeight + steps.length * stepHeight + 120;

  // Group steps by table type for visual organization
  const groupedSteps: Array<{ groupName: string; steps: SequenceStep[]; color: string }> = [];
  let currentGroup: { groupName: string; steps: SequenceStep[]; color: string } | null = null;

  steps.forEach((step) => {
    let groupName = "Business Tables";
    let color = "#dbeafe"; // blue-100

    if (step.tableName === "CMFCASE") {
      groupName = "CMFCASE";
      color = "#fef3c7"; // yellow-100
    } else if (step.tableName === "CMFRECORD") {
      groupName = "CMFRECORD";
      color = "#fce7f3"; // pink-100
    }

    if (!currentGroup || currentGroup.groupName !== groupName) {
      currentGroup = { groupName, steps: [], color };
      groupedSteps.push(currentGroup);
    }
    currentGroup.steps.push(step);
  });

  return (
    <div className="relative w-full overflow-hidden rounded-xl border border-zinc-200 bg-pink-50">
      {/* Zoom Controls */}
      <div className="absolute right-4 top-4 z-10 flex flex-col gap-2 rounded-lg border border-zinc-200 bg-white p-2 shadow-md">
        <button
          onClick={handleZoomIn}
          className="rounded px-3 py-1.5 text-sm font-medium text-zinc-700 hover:bg-zinc-100"
          title="Zoom In"
        >
          +
        </button>
        <button
          onClick={handleZoomOut}
          className="rounded px-3 py-1.5 text-sm font-medium text-zinc-700 hover:bg-zinc-100"
          title="Zoom Out"
        >
          −
        </button>
        <button
          onClick={handleReset}
          className="rounded px-3 py-1.5 text-xs font-medium text-zinc-700 hover:bg-zinc-100"
          title="Reset View"
        >
          Reset
        </button>
        <div className="border-t border-zinc-200 pt-2 text-center text-xs text-zinc-500">
          {Math.round(zoom * 100)}%
        </div>
      </div>

      <svg
        ref={svgRef}
        width="100%"
        height="800"
        className="cursor-move font-sans"
        onWheel={handleWheel}
        onMouseDown={handleMouseDown}
        onMouseMove={handleMouseMove}
        onMouseUp={handleMouseUp}
        onMouseLeave={handleMouseUp}
      >
        <g transform={`translate(${pan.x}, ${pan.y}) scale(${zoom})`}>
        <defs>
          <marker
            id="arrowhead"
            markerWidth="10"
            markerHeight="10"
            refX="9"
            refY="3"
            orient="auto"
          >
            <polygon points="0 0, 10 3, 0 6" fill="#3b82f6" />
          </marker>
          <marker
            id="arrowhead-green"
            markerWidth="10"
            markerHeight="10"
            refX="9"
            refY="3"
            orient="auto"
          >
            <polygon points="0 0, 10 3, 0 6" fill="#22c55e" />
          </marker>
          <marker
            id="arrowhead-red"
            markerWidth="10"
            markerHeight="10"
            refX="9"
            refY="3"
            orient="auto"
          >
            <polygon points="0 0, 10 3, 0 6" fill="#ef4444" />
          </marker>
        </defs>

        {/* Draw participants (table headers) */}
        {tables.map((table, idx) => {
          const x = 20 + idx * (tableWidth + tableSpacing);
          const centerX = x + tableWidth / 2;

          return (
            <g key={table}>
              {/* Participant box */}
              <rect
                x={x}
                y={20}
                width={tableWidth}
                height={60}
                fill="#fce7f3"
                stroke="#3b82f6"
                strokeWidth="3"
                rx="6"
              />
              <text
                x={centerX}
                y={55}
                textAnchor="middle"
                fontSize="15"
                fontWeight="700"
                fill="#18181b"
              >
                {table}
              </text>

              {/* Lifeline */}
              <line
                x1={centerX}
                y1={80}
                x2={centerX}
                y2={totalHeight - 20}
                stroke="#d4d4d8"
                strokeWidth="2"
                strokeDasharray="8,4"
              />
            </g>
          );
        })}

        {/* Draw sequence steps with grouping */}
        {(() => {
          let absoluteIdx = 0;
          return groupedSteps.map((group, groupIdx) => {
            const groupStartY = headerHeight + absoluteIdx * stepHeight;
            const groupHeight = group.steps.length * stepHeight;

            return (
              <g key={groupIdx}>
                {/* Group background */}
                <rect
                  x="0"
                  y={groupStartY - 10}
                  width={totalWidth}
                  height={groupHeight + 20}
                  fill={group.color}
                  fillOpacity="0.15"
                />

                {/* Group label - much more prominent */}
                <rect
                  x="15"
                  y={groupStartY - 8}
                  width={200}
                  height={35}
                  fill={group.color}
                  stroke="#18181b"
                  strokeWidth="2"
                  rx="6"
                />
                <text
                  x="115"
                  y={groupStartY + 18}
                  textAnchor="middle"
                  fontSize="14"
                  fontWeight="700"
                  fill="#18181b"
                  letterSpacing="0.5"
                >
                  ▸ {group.groupName}
                </text>

                {/* Steps within group */}
                {group.steps.map((step) => {
                  const y = headerHeight + absoluteIdx * stepHeight;
                  absoluteIdx++;
                  const sourceTableIdx = tables.indexOf(step.tableName);
                  const sourceX = 20 + sourceTableIdx * (tableWidth + tableSpacing) + tableWidth / 2;

                  // Determine color based on action
                  const color =
                    step.action === "INSERT"
                      ? "#22c55e"
                      : step.action === "UPDATE"
                      ? "#eab308"
                      : "#ef4444";
                  return (
                    <g key={step.stepNumber}>
              {/* Activation box */}
              <rect
                x={sourceX - 10}
                y={y}
                width={20}
                height={50}
                fill={color}
                fillOpacity="0.25"
                stroke={color}
                strokeWidth="3"
              />

              {/* Step number */}
              <circle cx={sourceX - 50} cy={y + 25} r="18" fill="#3b82f6" stroke="#1e40af" strokeWidth="2" />
              <text
                x={sourceX - 50}
                y={y + 31}
                textAnchor="middle"
                fontSize="13"
                fontWeight="700"
                fill="white"
              >
                {step.stepNumber}
              </text>

              {/* Action label */}
              <rect
                x={sourceX + 25}
                y={y + 5}
                width={step.typeInfo ? 160 : 120}
                height={step.typeInfo ? 50 : 38}
                fill="#fce7f3"
                stroke={color}
                strokeWidth="2.5"
                rx="6"
              />
              <text
                x={sourceX + (step.typeInfo ? 105 : 85)}
                y={y + 22}
                textAnchor="middle"
                fontSize="13"
                fontWeight="700"
                fill={color}
              >
                {step.action}
              </text>
              <text
                x={sourceX + (step.typeInfo ? 105 : 85)}
                y={y + 36}
                textAnchor="middle"
                fontSize="10"
                fill="#71717a"
              >
                {step.pkColumn}={step.pkValue}
              </text>
              {step.typeInfo && (
                <text
                  x={sourceX + 105}
                  y={y + 48}
                  textAnchor="middle"
                  fontSize="9"
                  fontWeight="700"
                  fill="#3b82f6"
                >
                  [{step.typeInfo}]
                </text>
              )}

              {/* Foreign key arrows - only show key relationships (CMFCASE/CMFRECORD) */}
              {step.foreignKeys
                .filter(fk => fk.referencesTable === 'CMFCASE' || fk.referencesTable === 'CMFRECORD')
                .map((fk, fkIdx) => {
                const targetTableIdx = tables.indexOf(fk.referencesTable);
                if (targetTableIdx === -1) return null;

                const targetX =
                  20 + targetTableIdx * (tableWidth + tableSpacing) + tableWidth / 2;
                const arrowY = y + 25 + fkIdx * 12;

                return (
                  <g key={fkIdx}>
                    <line
                      x1={sourceX}
                      y1={arrowY}
                      x2={targetX}
                      y2={arrowY}
                      stroke="#3b82f6"
                      strokeWidth="2.5"
                      markerEnd="url(#arrowhead)"
                      strokeDasharray="6,4"
                    />
                    <text
                      x={(sourceX + targetX) / 2}
                      y={arrowY - 6}
                      textAnchor="middle"
                      fontSize="11"
                      fontWeight="600"
                      fill="#3b82f6"
                    >
                      {fk.column}={fk.referencesValue ?? "NULL"}
                    </text>
                  </g>
                );
              })}
                  </g>
                );
              })}
              </g>
            );
          });
        })()}

        {/* Legend */}
        <g transform={`translate(20, ${totalHeight - 60})`}>
          <rect x="0" y="0" width={totalWidth - 40} height="50" fill="#f9fafb" stroke="#e5e7eb" rx="4" />
          <text x="10" y="18" fontSize="11" fontWeight="600" fill="#18181b">
            Legend:
          </text>
          
          <circle cx="80" cy="13" r="8" fill="#22c55e" fillOpacity="0.2" stroke="#22c55e" strokeWidth="2" />
          <text x="95" y="18" fontSize="10" fill="#71717a">INSERT</text>

          <circle cx="160" cy="13" r="8" fill="#eab308" fillOpacity="0.2" stroke="#eab308" strokeWidth="2" />
          <text x="175" y="18" fontSize="10" fill="#71717a">UPDATE</text>

          <circle cx="240" cy="13" r="8" fill="#ef4444" fillOpacity="0.2" stroke="#ef4444" strokeWidth="2" />
          <text x="255" y="18" fontSize="10" fill="#71717a">DELETE</text>

          <line x1="340" y1="13" x2="380" y2="13" stroke="#3b82f6" strokeWidth="1.5" strokeDasharray="3,3" markerEnd="url(#arrowhead)" />
          <text x="390" y="18" fontSize="10" fill="#71717a">FK Reference</text>

          <line x1="500" y1="13" x2="520" y2="13" stroke="#d4d4d8" strokeWidth="2" strokeDasharray="5,5" />
          <text x="530" y="18" fontSize="10" fill="#71717a">Lifeline</text>

          <text x="10" y="38" fontSize="9" fill="#71717a">
            Solid boxes = activation (table being written to) • Dashed arrows = foreign key references • Scroll to zoom • Drag to pan
          </text>
        </g>
        </g>
      </svg>
    </div>
  );
}
