#!/usr/bin/env bash
set -euo pipefail

if ! command -v az >/dev/null 2>&1; then
  echo "Error: Azure CLI (az) is not installed." >&2
  exit 1
fi

: "${AZ_RESOURCE_GROUP:?Set AZ_RESOURCE_GROUP}"
: "${AZ_LOCATION:?Set AZ_LOCATION, e.g. eastus}"
: "${WORKFLOW_NAME:?Set WORKFLOW_NAME}"
: "${TELEGRAM_BOT_TOKEN:?Set TELEGRAM_BOT_TOKEN}"
: "${EXCEL_FILE_ID:?Set EXCEL_FILE_ID}"
: "${EXCEL_CONNECTION_ID:?Set EXCEL_CONNECTION_ID (resource id of Microsoft.Web/connections/excelonlinebusiness)}"

ONE_DRIVE_DRIVE_ID="${ONE_DRIVE_DRIVE_ID:-me}"
EXCEL_TABLE_ID="${EXCEL_TABLE_ID:-ExpensesTable}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> Ensuring resource group exists"
az group create --name "$AZ_RESOURCE_GROUP" --location "$AZ_LOCATION" 1>/dev/null

echo "==> Deploying Logic App"
az deployment group create \
  --resource-group "$AZ_RESOURCE_GROUP" \
  --template-file "$REPO_ROOT/infra/main.bicep" \
  --parameters \
    location="$AZ_LOCATION" \
    workflowName="$WORKFLOW_NAME" \
    telegramBotToken="$TELEGRAM_BOT_TOKEN" \
    oneDriveDriveId="$ONE_DRIVE_DRIVE_ID" \
    excelFileId="$EXCEL_FILE_ID" \
    excelTableId="$EXCEL_TABLE_ID" \
    excelConnectionId="$EXCEL_CONNECTION_ID" \
  --query properties.outputs -o json

echo "==> Fetching callback URL for HTTP trigger"
TRIGGER_URL=$(az rest \
  --method post \
  --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$AZ_RESOURCE_GROUP/providers/Microsoft.Logic/workflows/$WORKFLOW_NAME/triggers/When_a_HTTP_request_is_received/listCallbackUrl?api-version=2019-05-01" \
  --query value -o tsv)

echo "Trigger URL:"
echo "$TRIGGER_URL"

echo "==> Registering Telegram webhook"
curl -sS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/setWebhook" \
  -H "Content-Type: application/json" \
  -d "{\"url\":\"${TRIGGER_URL}\"}" | jq .

echo "Deployment complete. Send /help to your bot to test."
