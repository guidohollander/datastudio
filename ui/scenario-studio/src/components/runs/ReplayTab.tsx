import ReplayWizard from "../replay/ReplayWizard";

export default function ReplayTab({ runId }: { runId: string }) {
  return (
    <div className="space-y-6">
      {/* Info Banner */}
      <div className="rounded-2xl border border-purple-200 bg-purple-50 p-6">
        <div className="flex items-start gap-4">
          <div className="flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-full bg-purple-100">
            <svg
              className="h-5 w-5 text-purple-600"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
          </div>
          <div className="flex-1">
            <h3 className="text-sm font-semibold text-purple-900">Replay Wizard</h3>
            <p className="mt-1 text-sm text-purple-800">
              Configure data variability, transformations, and field generators. The wizard will
              guide you through: reviewing captured data, configuring distributions and
              generators, previewing results, and executing the replay.
            </p>
            <div className="mt-3">
              <a
                href={`/contract/${runId}`}
                className="inline-flex items-center gap-2 rounded-lg bg-white px-4 py-2 text-sm font-medium text-purple-900 shadow-sm hover:bg-purple-100 transition-colors border border-purple-200"
              >
                <span>📋</span>
                <span>View Contract Documentation</span>
              </a>
            </div>
          </div>
        </div>
      </div>

      {/* Replay Wizard */}
      <div className="rounded-2xl border border-purple-500/20 bg-white p-6">
        <ReplayWizard runId={runId} />
      </div>
    </div>
  );
}
