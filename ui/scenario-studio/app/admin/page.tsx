import { AppLink } from "@/lib/links";
import AdminCleanupClient from "@/components/admin/AdminCleanupClient";

export default function AdminPage() {
  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Admin</h1>
          <p className="mt-1 text-sm text-zinc-600">Maintenance actions for the framework.</p>
        </div>
        <AppLink
          href="/runs"
          target="_self"
          className="rounded-xl border border-black/10 bg-white px-4 py-2 text-sm text-zinc-900 shadow-sm hover:bg-zinc-50"
        >
          Back to runs
        </AppLink>
      </div>

      <AdminCleanupClient />
    </div>
  );
}
