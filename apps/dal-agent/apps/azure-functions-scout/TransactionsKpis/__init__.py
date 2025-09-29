import azure.functions as func, json
from ..shared.db import query
def main(req: func.HttpRequest) -> func.HttpResponse:
    sql = """
      SELECT
        COUNT(*) AS tx_count,
        SUM(revenue) AS revenue,
        SUM(quantity) AS units,
        COUNT(DISTINCT store) AS stores
      FROM dbo.vw_transactions WITH (NOEXPAND)
    """
    rows=query(sql)
    return func.HttpResponse(json.dumps(rows[0] if rows else {}, default=str), mimetype="application/json")
