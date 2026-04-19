import "server-only";
import { cookies } from "next/headers";

export const ACTIVE_RUN_COOKIE = "ss_active_run_id";

export async function getActiveRunId() {
  const jar = await cookies();
  return jar.get(ACTIVE_RUN_COOKIE)?.value ?? null;
}
