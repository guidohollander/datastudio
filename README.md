# Scenario Studio

Scenario Studio is a SQL-first framework for capturing Be Informed database scenarios, deriving reusable contracts from those captures, and replaying them at scale with referential integrity intact.

The web frontend in [`ui/scenario-studio`](C:/dev/db/snapshot/ui/scenario-studio) is the operator surface. The core business logic lives in SQL Server stored procedures under [`sql/dbo/procedures`](C:/dev/db/snapshot/sql/dbo/procedures).

## What This Repository Contains

- `sql/dbo/tables`: canonical table definitions for the Scenario Studio framework
- `sql/dbo/procedures`: canonical stored procedure definitions for capture, contract generation, replay, and validation
- `ui/scenario-studio`: Next.js frontend and API routes that orchestrate the SQL layer
- `samples`: example contract and replay payloads
- top-level `*.sql` and `*.md` files: diagnostics, experiments, analyses, and briefing material

## Core Workflow

1. Start a migration scenario run.
2. Perform the business action in the target Be Informed application.
3. End the run and capture inserts, updates, and deletes.
4. Generate a domain contract from the captured rows.
5. Configure field generators and exclusions.
6. Replay the scenario at scale.
7. Validate replay results through SQL and the frontend.

## Local Development

Prerequisites:

- SQL Server reachable at `localhost,1433`
- target database available, typically `gd_mts`
- Node.js 20+ recommended
- npm installed

Environment:

- root example: [`.env.example`](C:/dev/db/snapshot/.env.example)
- UI example: [`ui/scenario-studio/.env.local.example`](C:/dev/db/snapshot/ui/scenario-studio/.env.local.example)

Frontend startup:

```powershell
cd C:\dev\db\snapshot\ui\scenario-studio
npm install
npm run dev
```

The UI runs at `http://localhost:3000`.

## SQL Access

Use `sqlcmd` as the primary development and inspection path. This repository assumes direct SQL Server access rather than an abstraction layer.

Example:

```powershell
sqlcmd -S localhost,1433 -U sa -P "<password>" -d gd_mts -Q "EXEC dbo.GetScenarios"
```

## Browser Control

Codex is configured with the official Chrome DevTools MCP. That enables browser inspection, DOM snapshots, JavaScript execution, network inspection, screenshots, and click/navigation control while developing the frontend.

If MCP config changes are made, restart Codex to reload them.

## Key Entry Points

- SQL capture start: [dbo_StartMigrationScenarioRun.sql](C:/dev/db/snapshot/sql/dbo/procedures/dbo_StartMigrationScenarioRun.sql)
- SQL capture end: [dbo_EndMigrationScenarioRun.sql](C:/dev/db/snapshot/sql/dbo/procedures/dbo_EndMigrationScenarioRun.sql)
- contract generation: [dbo_GenerateContractFromCapture.sql](C:/dev/db/snapshot/sql/dbo/procedures/dbo_GenerateContractFromCapture.sql)
- contract JSON export: [dbo_GenerateDomainContractJson.sql](C:/dev/db/snapshot/sql/dbo/procedures/dbo_GenerateDomainContractJson.sql)
- replay engine: [dbo_ReplayScenarioRun.sql](C:/dev/db/snapshot/sql/dbo/procedures/dbo_ReplayScenarioRun.sql)
- frontend DB bridge: [db.ts](C:/dev/db/snapshot/ui/scenario-studio/src/lib/db.ts)

## Recommended Next Work

- consolidate and simplify the frontend navigation flow
- add stronger SQL verification scripts around replay correctness
- add richer UI views for contract editing and replay diagnostics
- normalize the top-level analysis scripts into a clearer `docs/` and `scripts/` structure
