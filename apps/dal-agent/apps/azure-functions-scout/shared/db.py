import os, json, pyodbc

def _mi_conn():
    # Access token via Azure CLI managed identity path (Functions runtime handles token)
    # For local dev, fallback to SQL user/pass envs.
    raise RuntimeError("Managed Identity token path not wired in this stub. Use SQL auth fallback or replace with msal token.")

def _sql_conn():
    server=os.environ["SQL__SERVER"]
    db=os.environ["SQL__DATABASE"]
    user=os.environ.get("SQL__USER")
    pwd=os.environ.get("SQL__PASSWORD")
    if not user or not pwd:
        raise RuntimeError("SQL__USER/PASSWORD missing and MI stub not implemented in this sample.")
    cn = pyodbc.connect(f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={server};DATABASE={db};UID={user};PWD={pwd};Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;")
    return cn

def query(sql, *params):
    with _sql_conn() as cn:
        cur=cn.cursor()
        cur.execute(sql, params)
        cols=[c[0] for c in cur.description]
        rows=[dict(zip(cols, r)) for r in cur.fetchall()]
        return rows
