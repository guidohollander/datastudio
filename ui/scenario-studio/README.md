# Scenario Studio Frontend

This app is the operator interface for Scenario Studio. It is a Next.js frontend that orchestrates SQL Server stored procedures for:

- starting and ending scenario capture
- inspecting captured rows and inferred relationships
- generating domain contracts
- editing generator expressions
- replaying datasets
- validating replay outcomes

## Development

1. Copy `.env.local.example` to `.env.local` and fill in local credentials.
2. Install dependencies:

```bash
npm install
```

3. Start the dev server:

```bash
npm run dev
```

4. Open `http://localhost:3000`

## Useful Scripts

- `npm run dev`: start local development server
- `npm run build`: production build
- `npm run start`: run production build locally
- `npm run lint`: lint the application
- `npm run test:e2e`: run Playwright end-to-end tests

## Architecture Notes

- `app/api/*` contains HTTP routes that bridge the UI to SQL Server procedures.
- `src/lib/db.ts` contains the SQL connection helpers.
- `src/components/*` contains the workflow UI for capture, runs, replay, dataset editing, and admin cleanup.
- The SQL Server database is the system of record; the frontend is intentionally thin over the SQL layer.

## Browser-Driven Development

The repository is set up to work well with Chrome DevTools MCP, so an agent can:

- inspect rendered UI state
- click through workflows
- execute JavaScript in the page
- inspect network requests and console output
- validate UI changes during development

This is useful for richer frontend work where visual and interaction feedback matters.
