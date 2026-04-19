"use client";

import { useEffect, useState, useCallback } from "react";
import ReactFlow, {
  Node,
  Edge,
  Controls,
  Background,
  useNodesState,
  useEdgesState,
  MarkerType,
  Panel,
  NodeProps,
  Position,
  Handle,
} from "reactflow";
import "reactflow/dist/style.css";

function CustomNode({ data }: NodeProps<NodeData>) {
  return (
    <>
      <Handle type="target" position={Position.Top} />
      <div className="px-3 py-2">
        <div className="font-mono text-xs font-semibold text-zinc-900">{data.table}</div>
        <div className="mt-1 text-xs text-zinc-700">
          {data.pkColumn}: {data.pkValue}
        </div>
        <div className="mt-1 rounded bg-white/50 px-1.5 py-0.5 text-[10px] text-zinc-600">
          Level {data.level}
        </div>
      </div>
      <Handle type="source" position={Position.Bottom} />
    </>
  );
}

const nodeTypes = {
  custom: CustomNode,
};

type Relationship = {
  RelationshipID: number;
  ParentTable: string;
  ParentColumn: string;
  ChildTable: string;
  ChildColumn: string;
  Source: string;
  Notes: string | null;
};

type CapturedRow = {
  PkColumn: string;
  PkValue: number;
  CapturedAt: string;
  RowJson: string;
};

type CapturedData = Record<
  string,
  {
    dependencyLevel: number;
    rows: CapturedRow[];
  }
>;

type NodeData = {
  table: string;
  pkColumn: string;
  pkValue: number;
  level: number;
  rowJson: string;
  label?: string;
};

export default function RelationshipGraphViewer({ runId }: { runId: string }) {
  const [nodes, setNodes, onNodesChange] = useNodesState([]);
  const [edges, setEdges, onEdgesChange] = useEdgesState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedNode, setSelectedNode] = useState<NodeData | null>(null);
  const [highlightedNodeIds, setHighlightedNodeIds] = useState<Set<string>>(new Set());
  const [highlightedEdgeIds, setHighlightedEdgeIds] = useState<Set<string>>(new Set());

  const onNodeClick = useCallback((_event: React.MouseEvent, node: Node) => {
    setSelectedNode(node.data as NodeData);
    
    // Find all connected edges and nodes
    const connectedEdgeIds = new Set<string>();
    const connectedNodeIds = new Set<string>([node.id]);
    
    edges.forEach(edge => {
      if (edge.source === node.id || edge.target === node.id) {
        connectedEdgeIds.add(edge.id);
        connectedNodeIds.add(edge.source);
        connectedNodeIds.add(edge.target);
      }
    });
    
    setHighlightedNodeIds(connectedNodeIds);
    setHighlightedEdgeIds(connectedEdgeIds);
  }, [edges]);

  async function loadGraph() {
    setLoading(true);
    setError(null);
    try {
      const [relsRes, dataRes] = await Promise.all([
        fetch(`/api/runs/${encodeURIComponent(runId)}/relationships`),
        fetch(`/api/runs/${encodeURIComponent(runId)}/captured-data`),
      ]);

      const relsJson = (await relsRes.json()) as { relationships?: Relationship[]; tableOrder?: unknown[]; error?: string };
      const dataJson = (await dataRes.json()) as { capturedData?: CapturedData; error?: string };

      if (!relsRes.ok) throw new Error(relsJson.error ?? "Failed to load relationships");
      if (!dataRes.ok) throw new Error(dataJson.error ?? "Failed to load captured data");

      const relationships = relsJson.relationships ?? [];
      const capturedData = dataJson.capturedData ?? {};

      console.log("Raw relationships data:", relationships);
      console.log("Raw captured data tables:", Object.keys(capturedData));
      console.log("First relationship:", relationships[0]);

      // Build nodes from captured rows with improved spacing
      const nodeList: Node<NodeData>[] = [];
      const nodeWidth = 240;
      const nodeHeight = 80;
      const horizontalSpacing = 400; // Large horizontal spacing
      const verticalSpacing = 250; // Large vertical spacing
      
      // Group nodes by dependency level
      const nodesByLevel = new Map<number, Array<{ table: string; row: CapturedRow }>>();
      for (const table of Object.keys(capturedData)) {
        const tableData = capturedData[table];
        for (const row of tableData.rows) {
          const level = tableData.dependencyLevel;
          if (!nodesByLevel.has(level)) {
            nodesByLevel.set(level, []);
          }
          nodesByLevel.get(level)!.push({ table, row });
        }
      }

      // Position nodes with maximum spacing to avoid overlap
      let yOffset = 0;
      for (const [, items] of Array.from(nodesByLevel.entries()).sort((a, b) => a[0] - b[0])) {
        const nodesInLevel = items.length;
        const totalWidth = nodesInLevel * horizontalSpacing;
        let xOffset = -totalWidth / 2; // Center horizontally
        
        items.forEach((item) => {
          const nodeId = `${item.table}-${item.row.PkValue}`;
          const tableData = capturedData[item.table];
          
          const node: Node<NodeData> = {
            id: nodeId,
            type: "custom",
            position: { x: xOffset, y: yOffset },
            sourcePosition: Position.Bottom,
            targetPosition: Position.Top,
            data: {
              table: item.table,
              pkColumn: item.row.PkColumn,
              pkValue: item.row.PkValue,
              level: tableData.dependencyLevel,
              rowJson: item.row.RowJson,
              label: `${item.table}\n${item.row.PkColumn}: ${item.row.PkValue}`,
            },
            style: {
              background: getLevelColor(tableData.dependencyLevel),
              border: "2px solid #333",
              borderRadius: "8px",
              padding: "12px",
              fontSize: "11px",
              width: nodeWidth,
              minHeight: nodeHeight,
            },
          };

          nodeList.push(node);
          xOffset += horizontalSpacing;
        });
        
        yOffset += verticalSpacing;
      }

      // Build edges from relationships
      const edgeList: Edge[] = [];
      console.log("Building edges from relationships:", relationships.length);
      
      for (const rel of relationships) {
        const parentTable = rel.ParentTable;
        const childTable = rel.ChildTable;
        const childColumn = rel.ChildColumn;
        const parentColumn = rel.ParentColumn;

        console.log(`Processing relationship: ${parentTable}.${parentColumn} <- ${childTable}.${childColumn}`);

        // Find all captured rows for parent and child tables
        const parentRows = capturedData[parentTable]?.rows ?? [];
        const childRows = capturedData[childTable]?.rows ?? [];
        const parentPKColumns = parentRows.map(r => `${r.PkColumn}=${r.PkValue}`);
        
        console.log(`  Parent table ${parentTable} has ${parentRows.length} rows:`);
        console.log(`    PKs: [${parentPKColumns.join(', ')}]`);
        console.log(`  Child table ${childTable} has ${childRows.length} rows`);

        for (const childRow of childRows) {
          let parsedJson: Record<string, unknown> = {};
          try {
            parsedJson = JSON.parse(childRow.RowJson) as Record<string, unknown>;
          } catch {
            console.log(`  Failed to parse JSON for ${childTable} row ${childRow.PkValue}`);
            continue;
          }

          console.log(`  Checking ${childTable} row ${childRow.PkValue}, looking for FK column "${childColumn}"`);
          console.log(`    Available columns:`, Object.keys(parsedJson));

          // Get FK value - try exact match first, then case-insensitive
          let fkValue = parsedJson[childColumn];
          let actualColumnName = childColumn;
          
          if (fkValue == null) {
            // Try case-insensitive match
            const key = Object.keys(parsedJson).find(k => k.toUpperCase() === childColumn.toUpperCase());
            if (key) {
              fkValue = parsedJson[key];
              actualColumnName = key;
              console.log(`    Found FK column with different case: "${key}" (looking for "${childColumn}")`);
            }
          }

          if (fkValue == null) {
            console.log(`    ✗ No FK value found for ${childColumn} in ${childTable} row ${childRow.PkValue}`);
            continue;
          }

          console.log(`    FK column "${actualColumnName}" has value:`, fkValue, `(type: ${typeof fkValue})`);

          // Convert FK value to number for comparison
          const fkValueNum = typeof fkValue === 'string' ? parseInt(fkValue, 10) : Number(fkValue);
          if (isNaN(fkValueNum)) {
            console.log(`  FK value ${fkValue} is not a valid number`);
            continue;
          }

          // Find parent row with matching parent column value (parse JSON to check)
          console.log(`    Searching for parent ${parentTable} where ${parentColumn}=${fkValueNum}`);
          console.log(`    Parent rows available:`, parentRows.map(r => `${r.PkColumn}=${r.PkValue}`));
          
          const parentRow = parentRows.find((r) => {
            try {
              const parentJson = JSON.parse(r.RowJson) as Record<string, unknown>;
              // Try exact match first
              let parentColValue = parentJson[parentColumn];
              if (parentColValue == null) {
                // Try case-insensitive match
                const key = Object.keys(parentJson).find(k => k.toUpperCase() === parentColumn.toUpperCase());
                if (key) {
                  parentColValue = parentJson[key];
                }
              }
              // Convert to number for comparison
              const parentColNum = typeof parentColValue === 'string' ? parseInt(parentColValue, 10) : Number(parentColValue);
              return parentColNum === fkValueNum;
            } catch {
              return false;
            }
          });

          if (parentRow) {
            const sourceId = `${parentTable}-${parentRow.PkValue}`;
            const targetId = `${childTable}-${childRow.PkValue}`;

            console.log(`    ✓ MATCH FOUND! Creating edge: ${sourceId} -> ${targetId} (${childColumn}=${fkValueNum})`);

            edgeList.push({
              id: `${sourceId}-${targetId}-${rel.RelationshipID}-${childColumn}`,
              source: sourceId,
              target: targetId,
              label: `${childColumn}\n= ${fkValueNum}`,
              type: "smoothstep",
              animated: true,
              style: { stroke: "#666", strokeWidth: 2 },
              markerEnd: {
                type: MarkerType.ArrowClosed,
                color: "#666",
              },
              labelStyle: { fontSize: 10, fill: "#666", fontWeight: 600 },
              labelBgStyle: { fill: "#fff", fillOpacity: 0.9 },
            });
          } else {
            console.log(`  ✗ No parent row found in ${parentTable} with PK=${fkValueNum}`);
          }
        }
      }

      console.log(`Created ${edgeList.length} edges:`, edgeList.map(e => `${e.source} -> ${e.target}`));
      console.log(`Node IDs available:`, nodeList.map(n => n.id));
      
      // Verify all edge sources and targets exist as nodes
      const nodeIds = new Set(nodeList.map(n => n.id));
      const invalidEdges = edgeList.filter(e => !nodeIds.has(e.source) || !nodeIds.has(e.target));
      if (invalidEdges.length > 0) {
        console.error(`⚠️ ${invalidEdges.length} edges reference non-existent nodes:`, invalidEdges);
      }
      
      // Set both nodes and edges - ReactFlow will handle them together
      console.log(`Setting ${nodeList.length} nodes and ${edgeList.length} edges...`);
      
      setNodes(nodeList);
      setEdges(edgeList);
      
      // Clear highlights when data changes
      setHighlightedNodeIds(new Set());
      setHighlightedEdgeIds(new Set());
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to load graph");
      setNodes([]);
      setEdges([]);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadGraph();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [runId]);

  if (loading) {
    return <div className="text-sm text-zinc-600">Loading relationship graph...</div>;
  }

  if (error) {
    return <div className="rounded-xl bg-red-50 px-4 py-3 text-sm text-red-900">{error}</div>;
  }

  if (nodes.length === 0) {
    return <div className="text-sm text-zinc-600">No captured data to visualize.</div>;
  }

  // Apply highlighting styles to nodes and edges
  const highlightedNodes = nodes.map(node => ({
    ...node,
    style: {
      ...node.style,
      opacity: highlightedNodeIds.size > 0 ? (highlightedNodeIds.has(node.id) ? 1 : 0.3) : 1,
      border: highlightedNodeIds.has(node.id) ? "3px solid #3b82f6" : node.style?.border,
    },
  }));

  const highlightedEdges = edges.map(edge => ({
    ...edge,
    style: {
      ...edge.style,
      opacity: highlightedEdgeIds.size > 0 ? (highlightedEdgeIds.has(edge.id) ? 1 : 0.2) : 1,
      strokeWidth: highlightedEdgeIds.has(edge.id) ? 3 : 2,
    },
    animated: highlightedEdgeIds.has(edge.id),
  }));

  return (
    <div className="space-y-3">
      <div className="h-[600px] rounded-xl border border-black/10 bg-white">
        <ReactFlow
          nodes={highlightedNodes}
          edges={highlightedEdges}
          onNodesChange={onNodesChange}
          onEdgesChange={onEdgesChange}
          onNodeClick={onNodeClick}
          nodeTypes={nodeTypes}
          fitView
          attributionPosition="bottom-left"
        >
          <Background />
          <Controls />
          <Panel position="top-right" className="rounded-lg bg-white p-2 text-xs text-zinc-600 shadow-sm">
            {nodes.length} nodes, {edges.length} relationships
            {highlightedNodeIds.size > 0 && (
              <button
                onClick={() => {
                  setHighlightedNodeIds(new Set());
                  setHighlightedEdgeIds(new Set());
                  setSelectedNode(null);
                }}
                className="ml-3 rounded bg-blue-500 px-2 py-1 text-white hover:bg-blue-600"
              >
                Clear
              </button>
            )}
          </Panel>
        </ReactFlow>
      </div>

      {selectedNode && (
        <div className="rounded-xl border border-black/10 bg-white p-4">
          <div className="mb-2 flex items-center justify-between">
            <div>
              <div className="font-mono text-sm font-medium text-zinc-900">{selectedNode.table}</div>
              <div className="mt-1 text-xs text-zinc-600">
                {selectedNode.pkColumn} = {selectedNode.pkValue} • Level {selectedNode.level}
              </div>
            </div>
            <button
              onClick={() => setSelectedNode(null)}
              className="rounded-lg px-2 py-1 text-xs text-zinc-600 hover:bg-zinc-100"
            >
              Close
            </button>
          </div>
          <pre className="overflow-auto rounded-lg border border-black/10 bg-zinc-50 p-3 text-xs text-zinc-800">
            {JSON.stringify(JSON.parse(selectedNode.rowJson), null, 2)}
          </pre>
        </div>
      )}
    </div>
  );
}

function getLevelColor(level: number): string {
  const colors = [
    "#e0f2fe", // sky-100
    "#ddd6fe", // violet-100
    "#fce7f3", // pink-100
    "#fef3c7", // amber-100
    "#d1fae5", // emerald-100
    "#e5e7eb", // gray-200
  ];
  return colors[level % colors.length];
}
