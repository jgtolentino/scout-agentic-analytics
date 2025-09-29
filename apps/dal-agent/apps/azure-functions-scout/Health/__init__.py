import azure.functions as func, json, os
def main(req: func.HttpRequest) -> func.HttpResponse:
    data = {"ok": True, "service":"fn-scout-readonly","env":{"SQL__SERVER": bool(os.environ.get("SQL__SERVER"))}}
    return func.HttpResponse(json.dumps(data), mimetype="application/json")
