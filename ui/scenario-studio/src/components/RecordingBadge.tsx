import { getActiveRunId } from "@/lib/recording";

export async function RecordingBadge() {
  const runId = await getActiveRunId();

  if (!runId) return null;

  return (
    <div className="flex items-center gap-2 rounded-full border border-red-500/20 bg-red-50 px-3 py-1 text-sm text-red-700">
      <span className="relative flex h-2.5 w-2.5">
        <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-red-500 opacity-60" />
        <span className="relative inline-flex h-2.5 w-2.5 rounded-full bg-red-500" />
      </span>
      <span className="font-medium">Recording</span>
      <span className="font-mono text-xs text-red-700/80">{runId}</span>
    </div>
  );
}
