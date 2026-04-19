import { redirect } from "next/navigation";
import { getActiveRunId } from "@/lib/recording";

export default async function CapturePage() {
  const runId = await getActiveRunId();

  if (runId) {
    redirect(`/runs/${encodeURIComponent(runId)}`);
  }

  redirect("/runs");
}
