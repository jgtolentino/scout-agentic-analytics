import azure.functions as func, json
from ..shared.db import query
def main(req: func.HttpRequest) -> func.HttpResponse:
    brand=req.params.get("brand")
    store=req.params.get("store")
    sql="SELECT TOP 100 * FROM dbo.vw_transactions WITH (NOEXPAND) WHERE (@brand IS NULL OR brand=@brand) AND (@store IS NULL OR store=@store) ORDER BY transaction_date DESC"
    rows=query(sql, brand, store)
    return func.HttpResponse(json.dumps({"count":len(rows),"rows":rows}, default=str), mimetype="application/json")
