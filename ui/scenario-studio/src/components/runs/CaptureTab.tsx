import RunCapturePanelClient from "./RunCapturePanelClient";
import CapturedDataViewer from "./CapturedDataViewer";

export default function CaptureTab({
  runId,
  isEnded,
}: {
  runId: string;
  isEnded: boolean;
}) {
  return (
    <div className="space-y-6">
      {/* Capture Controls */}
      <div className="rounded-2xl border border-black/10 bg-white p-6 shadow-sm">
        <div className="mb-4">
          <h2 className="text-lg font-semibold text-zinc-900">Capture Controls</h2>
          <p className="mt-1 text-sm text-zinc-600">
            Start a capture session to record database changes
          </p>
        </div>
        <RunCapturePanelClient runId={runId} isEnded={isEnded} />
      </div>

      {/* Captured Data */}
      {isEnded && (
        <div className="rounded-2xl border border-black/10 bg-white p-6 shadow-sm">
          <div className="mb-4">
            <h2 className="text-lg font-semibold text-zinc-900">Captured Data</h2>
            <p className="mt-1 text-sm text-zinc-600">
              Tables ordered by dependency level (parents first). Click to expand and view
              captured rows.
            </p>
          </div>
          <CapturedDataViewer runId={runId} />
        </div>
      )}

      {!isEnded && (
        <div className="rounded-2xl border border-zinc-200 bg-zinc-50 p-8 text-center">
          <div className="text-sm text-zinc-600">
            End the capture to view captured data and proceed to analysis and replay.
          </div>
        </div>
      )}
    </div>
  );
}
