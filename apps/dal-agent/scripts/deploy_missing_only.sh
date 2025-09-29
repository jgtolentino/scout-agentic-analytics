#!/usr/bin/env bash
set -euo pipefail

need(){ command -v "$1" >/dev/null 2>&1 || { echo "Missing tool: $1" >&2; exit 1; }; }
need az
log(){ printf "\033[1;34m[%s]\033[0m %s\n" "$(date +'%F %T')" "$*"; }
ok(){  printf "\033[1;32m✓\033[0m %s\n" "$*"; }
skp(){ printf "\033[1;33m⤼\033[0m %s\n" "$*"; }

RG="${RG:?}"
LOC="${LOC:?}"
KV_NAME="${KV_NAME:?}"
ACR_NAME="${ACR_NAME:?}"
STORAGE_NAME="${STORAGE_NAME:?}"
APPINS_NAME="${APPINS_NAME:?}"
MI_NAME="${MI_NAME:?}"
PLAN_NAME="${PLAN_NAME:?}"
FUNCAPP_NAME="${FUNCAPP_NAME:?}"
ADF_NAME="${ADF_NAME:?}"
SEARCH_NAME="${SEARCH_NAME:?}"
IMAGE_TAG="${IMAGE_TAG:?}"

AZ_SUB="${AZ_SUB:?}"
SQL_SERVER_FQDN="${SQL_SERVER_FQDN:?}"
SQL_DB="${SQL_DB:?}"
OPENAI_ENDPOINT="${OPENAI_ENDPOINT:?}"

# Login context
az account set --subscription "$AZ_SUB" >/dev/null

# Helper: create-if-missing (show_cmd; create_cmd)
ensure() {
  local what="$1"; shift
  local show_cmd="$1"; shift
  local create_cmd="$1"; shift
  if eval "$show_cmd" >/dev/null 2>&1; then
    skp "$what exists - skip create"
  else
    log "Creating $what..."
    eval "$create_cmd"
    ok "$what created"
  fi
}

log "Ensuring Resource Group"
ensure "Resource Group $RG" \
  "az group show -n \"$RG\" -o none" \
  "az group create -n \"$RG\" -l \"$LOC\" -o none"

log "Ensuring Key Vault (global-unique name)"
if az keyvault show -n "$KV_NAME" >/dev/null 2>&1; then
  skp "Key Vault $KV_NAME exists - skip create"
else
  az keyvault create -g "$RG" -n "$KV_NAME" -l "$LOC" --enable-rbac-authorization true -o none
  ok "Key Vault $KV_NAME created"
fi

log "Ensuring Application Insights"
ensure "App Insights $APPINS_NAME" \
  "az monitor app-insights component show -g \"$RG\" -a \"$APPINS_NAME\" -o none" \
  "az monitor app-insights component create -g \"$RG\" -l \"$LOC\" -a \"$APPINS_NAME\" --application-type web --kind web -o none"

log "Ensuring Storage Account"
ensure "Storage $STORAGE_NAME" \
  "az storage account show -g \"$RG\" -n \"$STORAGE_NAME\" -o none" \
  "az storage account create -g \"$RG\" -n \"$STORAGE_NAME\" -l \"$LOC\" --sku Standard_LRS -o none"

log "Ensuring ACR"
ensure "ACR $ACR_NAME" \
  "az acr show -g \"$RG\" -n \"$ACR_NAME\" -o none" \
  "az acr create -g \"$RG\" -n \"$ACR_NAME\" --sku Basic -l \"$LOC\" -o none"

log "Ensuring User-Assigned Managed Identity"
ensure "Managed Identity $MI_NAME" \
  "az identity show -g \"$RG\" -n \"$MI_NAME\" -o none" \
  "az identity create -g \"$RG\" -n \"$MI_NAME\" -o none"

log "Ensuring Function Plan"
ensure "Function Plan $PLAN_NAME" \
  "az functionapp plan show -g \"$RG\" -n \"$PLAN_NAME\" -o none" \
  "az functionapp plan create -g \"$RG\" -n \"$PLAN_NAME\" --location \"$LOC\" --min-instances 1 --max-burst 20 --sku EP1 --is-linux -o none"

log "Importing/Ensuring container in ACR (if missing)"
# If image not present in ACR, import from source
if ! az acr repository show -n "$ACR_NAME" --image scout-functions:prod >/dev/null 2>&1; then
  az acr import -n "$ACR_NAME" --source "$IMAGE_TAG" --image "scout-functions:prod" >/dev/null 2>&1 || {
    az acr login -n "$ACR_NAME" >/dev/null
    docker pull "$IMAGE_TAG"
    ACR_LOGIN_SERVER="$(az acr show -n "$ACR_NAME" --query loginServer -o tsv)"
    docker tag "$IMAGE_TAG" "$ACR_LOGIN_SERVER/scout-functions:prod"
    docker push "$ACR_LOGIN_SERVER/scout-functions:prod"
  }
  ok "ACR image ensured"
else
  skp "ACR image scout-functions:prod exists"
fi

log "Ensuring Function App"
if az functionapp show -g "$RG" -n "$FUNCAPP_NAME" >/dev/null 2>&1; then
  skp "Function App exists - updating container & settings"
  ACR_LOGIN_SERVER="$(az acr show -n "$ACR_NAME" --query loginServer -o tsv)"
  az functionapp config container set -g "$RG" -n "$FUNCAPP_NAME" \
    --docker-custom-image-name "$ACR_LOGIN_SERVER/scout-functions:prod" >/dev/null
else
  ACR_LOGIN_SERVER="$(az acr show -n "$ACR_NAME" --query loginServer -o tsv)"
  MI_ID="$(az identity show -g \"$RG\" -n \"$MI_NAME\" --query id -o tsv)"
  az functionapp create -g "$RG" -n "$FUNCAPP_NAME" -p "$PLAN_NAME" \
    -s "$STORAGE_NAME" --functions-version 4 --assign-identity "$MI_ID" \
    --runtime dotnet --deployment-container-image-name "$ACR_LOGIN_SERVER/scout-functions:prod" -o none
  ok "Function App $FUNCAPP_NAME created"
  # grant AcrPull
  PRINCIPAL_ID="$(az webapp identity show -g \"$RG\" -n \"$FUNCAPP_NAME\" --query principalId -o tsv)"
  az role assignment create --assignee-object-id "$PRINCIPAL_ID" \
    --role "AcrPull" \
    --scope "$(az acr show -n \"$ACR_NAME\" --query id -o tsv)" >/dev/null 2>&1 || true
fi

# App settings (KV ref pattern; won't leak values)
APPINS_KEY="$(az monitor app-insights component show -g "$RG" -a "$APPINS_NAME" --query instrumentationKey -o tsv)"
az functionapp config appsettings set -g "$RG" -n "$FUNCAPP_NAME" --settings \
  "APPINSIGHTS_INSTRUMENTATIONKEY=$APPINS_KEY" \
  "OPENAI__ENDPOINT=$OPENAI_ENDPOINT" \
  "EMBED_MODEL=text-embedding-3-large" \
  "EMBED_DIM=1536" \
  "SQL__SERVER=$SQL_SERVER_FQDN" \
  "SQL__DATABASE=$SQL_DB" \
  "SQL__AUTH_MODE=ManagedIdentity" \
  >/dev/null

log "Ensuring Azure AI Search service"
ensure "AI Search $SEARCH_NAME" \
  "az search service show -g \"$RG\" -n \"$SEARCH_NAME\" -o none" \
  "az search service create -g \"$RG\" -n \"$SEARCH_NAME\" -l \"$LOC\" --sku basic -o none"

# Ensure vector index exists (idempotent PUT)
SEARCH_KEY="$(az search admin-key show -g "$RG" -n "$SEARCH_NAME" --query primaryKey -o tsv)"
INDEX_DEF="$(cat <<JSON
{
  "name": "scout-rag",
  "fields": [
    {"name":"id","type":"Edm.String","key":true,"filterable":true,"sortable":true},
    {"name":"brand","type":"Edm.String","filterable":true,"facetable":true},
    {"name":"category","type":"Edm.String","filterable":true,"facetable":true},
    {"name":"store","type":"Edm.String","filterable":true,"facetable":true},
    {"name":"text","type":"Edm.String","searchable":true},
    {"name":"vector","type":"Collection(Edm.Single)","searchable":true,"vectorSearchDimensions":1536,"vectorSearchProfile":"vprof"}
  ],
  "vectorSearch":{"profiles":[{"name":"vprof","algorithm":"hnsw"}],"algorithms":[{"name":"hnsw","kind":"hnsw"}]}
}
JSON
)"
curl -fsS -X PUT -H "Content-Type: application/json" -H "api-key: $SEARCH_KEY" \
  --data "$INDEX_DEF" \
  "https://$SEARCH_NAME.search.windows.net/indexes/scout-rag?api-version=2024-05-01-preview" >/dev/null || true
ok "AI Search index ensured"

log "Ensuring Data Factory"
ensure "Data Factory $ADF_NAME" \
  "az datafactory show -g \"$RG\" -n \"$ADF_NAME\" -o none" \
  "az datafactory create -g \"$RG\" -n \"$ADF_NAME\" -l \"$LOC\" -o none"

ok "Missing-only deployment complete."