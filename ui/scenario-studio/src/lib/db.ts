import "server-only";
import sql from "mssql";

type ProcResult<T extends Record<string, unknown>> = {
  recordset: T[];
  recordsets: T[][];
  output: Record<string, unknown>;
  returnValue: number;
};

type SqlRequest = {
  input: (name: string, value: unknown) => unknown;
  execute: (procName: string) => Promise<unknown>;
  query: (sqlText: string) => Promise<unknown>;
};

type SqlPool = {
  request: () => SqlRequest;
};

type SqlModule = {
  ConnectionPool: new (cfg: unknown) => {
    connect: () => Promise<unknown>;
  };
};

let poolPromise: Promise<unknown> | null = null;

function unquote(v: string) {
  if (v.length >= 2) {
    const a = v[0];
    const b = v[v.length - 1];
    if ((a === '"' && b === '"') || (a === "'" && b === "'")) {
      return v.slice(1, -1);
    }
  }
  return v;
}

function getConfig(): Record<string, unknown> {
  const server = unquote(process.env.SQLSERVER ?? "localhost,1433");
  const database = unquote(process.env.SQLDATABASE ?? "gd_mts");
  const user = unquote(process.env.SQLUSER ?? "sa");
  const password = unquote(process.env.SQLPASSWORD ?? "");

  const [host, portStr] = server.split(",");
  const port = portStr ? Number(portStr) : 1433;

  return {
    server: host,
    port,
    database,
    user,
    password,
    options: {
      encrypt: false,
      trustServerCertificate: true,
    },
    pool: {
      max: 10,
      min: 0,
      idleTimeoutMillis: 30_000,
    },
    requestTimeout: 120_000,
  };
}

export async function getPool() {
  if (!poolPromise) {
    const mod = sql as unknown as SqlModule;
    poolPromise = new mod.ConnectionPool(getConfig()).connect().catch((e) => {
      poolPromise = null;
      throw e;
    });
  }
  return poolPromise;
}

export async function execProc<T extends Record<string, unknown> = Record<string, unknown>>(
  procName: string,
  input?: Record<string, unknown>,
) {
  const pool = (await getPool()) as unknown as SqlPool;
  const req = pool.request();

  if (input) {
    for (const [k, v] of Object.entries(input)) {
      req.input(k, v as unknown);
    }
  }

  const res = await req.execute(procName);
  return res as unknown as ProcResult<T>;
}

export async function execQuery<T extends Record<string, unknown> = Record<string, unknown>>(
  sqlText: string,
  input?: Record<string, unknown>,
) {
  const pool = (await getPool()) as unknown as SqlPool;
  const req = pool.request();

  if (input) {
    for (const [k, v] of Object.entries(input)) {
      req.input(k, v as unknown);
    }
  }

  const res = await req.query(sqlText);
  return res as unknown as ProcResult<T>;
}

export { sql };
