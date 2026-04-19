import UMLSequenceDiagram from "./UMLSequenceDiagram";
import RelationshipGraphViewer from "./RelationshipGraphViewer";
import RunRelationshipsClient from "./RunRelationshipsClient";

export default function AnalysisTab({ runId }: { runId: string }) {
  return (
    <div className="space-y-6">
      {/* UML Sequence Diagram */}
      <div className="rounded-2xl border border-indigo-500/20 bg-indigo-50 p-6">
        <div className="mb-4">
          <h2 className="text-lg font-semibold text-indigo-900">UML Sequence Diagram</h2>
          <p className="mt-1 text-sm text-indigo-900/70">
            Standard UML sequence diagram showing write order, lifelines, activation boxes, and
            FK message flows. Shows exact replay execution order.
          </p>
        </div>
        <UMLSequenceDiagram runId={runId} />
      </div>

      {/* Relationship Graph */}
      <div className="rounded-2xl border border-blue-500/20 bg-blue-50 p-6">
        <div className="mb-4">
          <h2 className="text-lg font-semibold text-blue-900">Relationship Graph</h2>
          <p className="mt-1 text-sm text-blue-900/70">
            Visual representation of captured rows and their FK relationships. Zoom and pan to
            explore.
          </p>
        </div>
        <RelationshipGraphViewer runId={runId} />
      </div>

      {/* Discovered Relationships */}
      <div className="rounded-2xl border border-emerald-500/20 bg-emerald-50 p-6">
        <div className="mb-4">
          <h2 className="text-lg font-semibold text-emerald-900">
            Discovered Relationships
          </h2>
          <p className="mt-1 text-sm text-emerald-900/70">
            Foreign key relationships detected between captured tables
          </p>
        </div>
        <RunRelationshipsClient runId={runId} />
      </div>
    </div>
  );
}
