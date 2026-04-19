import { AppLink } from "@/lib/links";
import CreateScenarioClient from "@/components/scenarios/CreateScenarioClient";
import { execProc } from "@/lib/db";

type Scenario = {
  ScenarioID: number;
  Name: string;
  CreatedAt: string;
  Notes: string | null;
};

async function getScenarios(): Promise<Scenario[]> {
  const res = await execProc<Scenario>("dbo.GetScenarios");
  return res.recordset ?? [];
}

export default async function ScenariosPage() {
  const items = await getScenarios();

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Scenarios</h1>
          <p className="mt-1 text-sm text-zinc-600">Manage capture scenarios and their runs.</p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <AppLink
            href="/capture/start"
            className="rounded-xl bg-red-600 px-4 py-2 text-sm font-medium text-white hover:bg-red-700"
          >
            Start capture
          </AppLink>
          <CreateScenarioClient />
        </div>
      </div>

      <div className="overflow-hidden rounded-2xl border border-black/10 bg-white shadow-sm">
        <div className="border-b border-black/5 px-6 py-4">
          <div className="text-sm font-semibold text-zinc-900">Scenario list</div>
        </div>
        <div className="divide-y divide-black/5">
          {items.map((s) => (
            <AppLink
              key={s.ScenarioID}
              href={`/scenarios/${s.ScenarioID}`}
              target="_self"
              className="block px-6 py-4 hover:bg-zinc-50"
            >
              <div className="flex items-center justify-between gap-4">
                <div className="min-w-0">
                  <div className="truncate text-sm font-medium text-zinc-900">{s.Name}</div>
                  <div className="mt-1 truncate text-xs text-zinc-600">{s.Notes ?? ""}</div>
                </div>
                <div className="text-xs text-zinc-600">#{s.ScenarioID}</div>
              </div>
            </AppLink>
          ))}

          {items.length === 0 ? (
            <div className="px-6 py-6 text-sm text-zinc-600">No scenarios yet.</div>
          ) : null}
        </div>
      </div>
    </div>
  );
}
