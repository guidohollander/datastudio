import { execQuery } from "@/lib/db";
import { AppLink } from "@/lib/links";
import ScenarioDetailClient from "@/components/scenarios/ScenarioDetailClient";

type Scenario = {
  ScenarioID: number;
  Name: string;
  CreatedAt: string;
  Notes: string | null;
};

async function getScenario(id: number): Promise<Scenario | null> {
  const result = await execQuery<Scenario>(
    `SELECT ScenarioID, Name, CreatedAt, Notes FROM dbo.MigrationScenario WHERE ScenarioID = @ScenarioID;`,
    { ScenarioID: id },
  );
  return result.recordset?.[0] ?? null;
}

export default async function ScenarioDetailPage({ params }: { params: Promise<{ scenarioId: string }> }) {
  const { scenarioId } = await params;
  const sid = Number(scenarioId);

  if (!Number.isFinite(sid)) {
    return <div className="p-6 text-red-500">Invalid scenario ID</div>;
  }

  const scenario = await getScenario(sid);
  if (!scenario) {
    return <div className="p-6 text-red-500">Scenario not found</div>;
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">{scenario.Name}</h1>
          <p className="mt-1 text-sm text-zinc-600">
            #{scenario.ScenarioID} • Created {new Date(scenario.CreatedAt).toLocaleDateString()}
          </p>
          {scenario.Notes ? <p className="mt-2 text-sm text-zinc-700">{scenario.Notes}</p> : null}
        </div>
        <AppLink
          href="/scenarios"
          target="_self"
          className="rounded-xl border border-black/10 bg-white px-4 py-2 text-sm text-zinc-900 shadow-sm hover:bg-zinc-50"
        >
          Back to scenarios
        </AppLink>
      </div>

      <ScenarioDetailClient scenarioId={sid} scenarioName={scenario.Name} />
    </div>
  );
}
