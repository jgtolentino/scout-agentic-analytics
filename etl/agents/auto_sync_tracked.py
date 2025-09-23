#!/usr/bin/env python3
"""
Auto-sync worker with:
- Change Tracking windowed exports
- Task framework registration & run journaling
- SI-only timestamp policy
- Canonical Tx ID normalization (lower, no hyphens)
- TASK_OVERRIDE one-shot modes
- Lightweight /healthz HTTP endpoint for k8s probes

Env:
  AZSQL_HOST, AZSQL_DB, AZSQL_USER_WRITER, AZSQL_PASS_WRITER
  AZURE_SQL_ODBC (optional odbc extras)
  OUTDIR, SYNC_INTERVAL, LOG_LEVEL
  TASK_OVERRIDE = { PARITY_CHECK | EXPORT_ONCE | SYNC_ONCE }
  HEALTHZ_PORT (default 8080)
"""

import os, sys, time, json, threading, signal, logging
from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime, timedelta
import pandas as pd
import pyodbc
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type

LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
logging.basicConfig(level=LOG_LEVEL, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("autosync")

HEALTHZ_PORT = int(os.getenv("HEALTHZ_PORT", "8080"))
RUNNING = True

# ---------- Healthz server ----------
class _Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/healthz":
            self.send_response(200)
            self.send_header("content-type","text/plain")
            self.end_headers()
            self.wfile.write(b"ok")
        else:
            self.send_response(404)
            self.end_headers()
    def log_message(self, *args):  # quiet logs
        return

def start_healthz():
    srv = HTTPServer(("0.0.0.0", HEALTHZ_PORT), _Handler)
    t = threading.Thread(target=srv.serve_forever, daemon=True)
    t.start()
    log.info(f"/healthz started on :{HEALTHZ_PORT}")

# ---------- DB helpers ----------
def _conn_str():
    host = os.environ["AZSQL_HOST"]
    db   = os.environ["AZSQL_DB"]
    user = os.environ["AZSQL_USER_WRITER"]
    pwd  = os.environ["AZSQL_PASS_WRITER"]
    odbc = os.getenv("AZURE_SQL_ODBC", "DRIVER={ODBC Driver 18 for SQL Server};Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;")
    return f"{odbc}SERVER={host};DATABASE={db};UID={user};PWD={pwd}"

def get_conn():
    return pyodbc.connect(_conn_str())

@retry(reraise=True,
       stop=stop_after_attempt(3),
       wait=wait_exponential(multiplier=1, min=1, max=10),
       retry=retry_if_exception_type(pyodbc.Error))
def exec_scalar(sql, params=()):
    with get_conn() as cx:
        cur = cx.cursor()
        cur.execute(sql, params)
        row = cur.fetchone()
        return row[0] if row else None

def exec_nonquery(sql, params=()):
    with get_conn() as cx:
        cur = cx.cursor()
        cur.execute(sql, params)
        cx.commit()

def exec_proc(proc_tsql, params=()):
    with get_conn() as cx:
        cur = cx.cursor()
        cur.execute(proc_tsql, params)
        try:
            rows = cur.fetchall()
        except pyodbc.ProgrammingError:
            rows = []
        cx.commit()
        return rows

# ---------- Task framework wrappers ----------
def task_start(task_code, note=None):
    tsql = """
    DECLARE @t TABLE(run_id BIGINT);
    INSERT INTO @t EXEC system.sp_task_start @task_code=?, @pid=CONVERT(nvarchar(100),@@SPID), @host=HOST_NAME(), @note=?;
    SELECT run_id FROM @t;
    """
    with get_conn() as cx:
        cur = cx.cursor()
        cur.execute(tsql, (task_code, note))
        rid = cur.fetchone()[0]
        cx.commit()
        return rid

def task_finish(run_id, note=None, artifacts=None):
    exec_proc("EXEC system.sp_task_finish @run_id=?, @note=?, @artifacts_json=?",
              (run_id, note, json.dumps(artifacts or {})))

def task_fail(run_id, err):
    exec_proc("EXEC system.sp_task_fail @run_id=?, @error_message=?",
              (run_id, str(err)[:4000]))

# ---------- Canonical normalization (DB enforces too; this is defensive) ----------
def norm_canon(txid: str) -> str:
    if not txid: return None
    return txid.replace("-", "").lower()

# ---------- Core jobs ----------
def run_parity_once(days_back=30):
    rid = task_start("PARITY_CHECK", f"days_back={days_back}")
    try:
        exec_proc("EXEC dbo.sp_parity_flat_vs_crosstab @days_back=?", (days_back,))
        task_finish(rid, "parity ok")
        log.info("Parity check finished OK")
    except Exception as e:
        task_fail(rid, e)
        log.exception("Parity check failed")
        sys.exit(2)

def export_changes_once():
    """
    Exports delta window using Change Tracking on silver.Transactions
    Assumes DB objects from 025-028 migrations are present.
    """
    rid = task_start("AUTO_SYNC_FLAT", "one-shot export")
    try:
        # Ask DB to do the heavy lifting (keeps logic centralized):
        rows = exec_proc("EXEC system.sp_task_export_flat_delta @task_run_id=?", (rid,))
        # The proc logs artifacts; still return a summary
        cnt = rows[0][0] if rows and rows[0] and isinstance(rows[0][0], int) else None
        task_finish(rid, f"export ok ({cnt} rows)" if cnt is not None else "export ok")
        log.info("One-shot export ok")
    except Exception as e:
        task_fail(rid, e)
        log.exception("Export failed")
        sys.exit(2)

def sync_loop(interval_sec=60):
    log.info(f"Starting continuous sync loop every {interval_sec}s")
    while RUNNING:
        rid = task_start("AUTO_SYNC_FLAT", "ct-cycle")
        try:
            exec_proc("EXEC system.sp_task_export_flat_delta @task_run_id=?", (rid,))
            task_finish(rid, "cycle ok")
        except Exception as e:
            task_fail(rid, e)
            log.exception("cycle failed")
        # sleep with interrupt awareness
        for _ in range(int(interval_sec)):
            if not RUNNING: break
            time.sleep(1)

# ---------- Signal handling ----------
def _sigterm(_sig, _frm):
    global RUNNING
    RUNNING = False
    log.info("shutdown signal received")

# ---------- main ----------
def main():
    start_healthz()
    signal.signal(signal.SIGTERM, _sigterm)
    signal.signal(signal.SIGINT, _sigterm)

    override = os.getenv("TASK_OVERRIDE", "").strip().upper()
    interval = int(os.getenv("SYNC_INTERVAL", "60"))

    if override == "PARITY_CHECK":
        run_parity_once(days_back=int(os.getenv("PARITY_DAYS_BACK","30")))
        return
    if override == "EXPORT_ONCE":
        export_changes_once()
        return
    if override == "SYNC_ONCE":
        # run single CT cycle then exit
        rid = task_start("AUTO_SYNC_FLAT", "single-cycle")
        try:
            exec_proc("EXEC system.sp_task_export_flat_delta @task_run_id=?", (rid,))
            task_finish(rid, "single-cycle ok")
        except Exception as e:
            task_fail(rid, e)
            log.exception("single-cycle failed")
            sys.exit(2)
        return

    # default: continuous loop
    sync_loop(interval)

if __name__ == "__main__":
    main()