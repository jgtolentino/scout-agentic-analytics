import sql from "mssql";

let poolPromise: Promise<sql.ConnectionPool> | null = null;

export function getPool() {
  if (process.env.DAL_MODE === "mock") {
    // in mock mode we never open SQL connections
    return null;
  }
  if (!poolPromise) {
    // Only create pool configuration if environment variables are available
    if (!process.env.AZURE_SQL_SERVER) {
      throw new Error("AZURE_SQL_SERVER environment variable not set");
    }
    const cfg: sql.config = {
      server: process.env.AZURE_SQL_SERVER,
      database: process.env.AZURE_SQL_DATABASE!,
      user: process.env.AZURE_SQL_USER!,
      password: process.env.AZURE_SQL_PASSWORD!,
      options: { encrypt: true, trustServerCertificate: false }
    };
    const pool = new sql.ConnectionPool(cfg);
    poolPromise = pool.connect()
      .then(p => {
        p.on("error", err => console.error("[mssql] pool error", err));
        return p;
      })
      .catch(e => {
        poolPromise = null;
        throw e;
      });
  }
  return poolPromise;
}

export async function withTenantContext(pool: sql.ConnectionPool, tenantCode?: string) {
  if (!tenantCode) return;
  // Optional: if you use RLS with SESSION_CONTEXT
  await pool.request()
    .input("key", sql.NVarChar(128), "TenantCode")
    .input("val", sql.NVarChar(128), tenantCode)
    .query("EXEC sys.sp_set_session_context @key=@key, @value=@val;");
}