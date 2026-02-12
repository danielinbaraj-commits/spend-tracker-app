# Spend Tracker (Telegram + Azure Logic Apps + Excel on OneDrive)

This repository provides a deployable spend tracker that captures Telegram bot commands and writes expense rows into an Excel table in OneDrive.

## Architecture

1. User sends a Telegram message like `/add 12.50 Food Lunch`.
2. Telegram webhook calls Azure Logic App HTTP trigger.
3. Logic App parses command and validates arguments.
4. Logic App inserts a row into Excel table (`ExpensesTable`) through `excelonlinebusiness` connector.
5. Logic App replies in Telegram.

## Files

- `logicapp/workflow.json` – workflow definition.
- `infra/main.bicep` – deploys Logic App and wires runtime parameters.
- `infra/parameters.example.json` – example deployment parameters.
- `scripts/deploy.sh` – one-command deploy + webhook registration.
- `excel/spend-tracker-template.csv` – starter Excel table columns and sample row.

---

## Prerequisites

- Azure subscription.
- Azure CLI (`az`) logged in: `az login`.
- Telegram bot token from `@BotFather`.
- OneDrive Excel file with an `ExpensesTable` table.
- Existing `excelonlinebusiness` API connection in Azure (authorized to your OneDrive account).

> Why existing connection first? The Excel connector requires an authenticated OAuth connection. This is easiest to create once in the Azure portal, then reuse the connection resource id in deployment.

---

## 1) Create Telegram Bot

1. Open Telegram and chat with `@BotFather`.
2. Run `/newbot`.
3. Save bot token.

---

## 2) Create Excel file/table in OneDrive

1. Create `SpendTracker.xlsx`.
2. Create worksheet `Expenses`.
3. Create table named exactly `ExpensesTable`.
4. Columns (header row):
   - `Date`
   - `Amount`
   - `Category`
   - `Note`
   - `ChatId`
   - `RawCommand`

You can copy headers from `excel/spend-tracker-template.csv`.

---

## 3) Create Excel API connection in Azure (one time)

In Azure Portal:

1. Go to **API connections**.
2. Create connection for **Excel Online (Business)**.
3. Authenticate with the same OneDrive account that owns `SpendTracker.xlsx`.
4. Copy resource id, for example:

`/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Web/connections/excelonlinebusiness-1`

---

## 4) Deploy Logic App

### Quick deploy (recommended)

Set environment variables:

```bash
export AZ_RESOURCE_GROUP="<resource-group>"
export AZ_LOCATION="eastus"
export WORKFLOW_NAME="spend-tracker-la"
export TELEGRAM_BOT_TOKEN="<telegram-token>"
export EXCEL_FILE_ID="<excel-file-id>"
export EXCEL_CONNECTION_ID="/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Web/connections/<excel-connection-name>"
# Optional:
# export ONE_DRIVE_DRIVE_ID="me"
# export EXCEL_TABLE_ID="ExpensesTable"
```

Run:

```bash
./scripts/deploy.sh
```

This script:

- creates/uses the resource group,
- deploys `infra/main.bicep`,
- fetches Logic App callback URL,
- registers Telegram webhook automatically.

### Manual deploy

```bash
az deployment group create \
  --resource-group <resource-group> \
  --template-file infra/main.bicep \
  --parameters @infra/parameters.example.json
```

Then get callback URL from Logic App trigger and set webhook:

```bash
curl -X POST "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{"url":"<YOUR_LOGIC_APP_TRIGGER_URL>"}'
```

---

## Supported commands

- `/add <amount> <category> <note...>`
  - Example: `/add 25.40 Transport Metro card`
- `/help`
- `/start`

If `/add` format is invalid, bot replies with usage.

---

## Notes

- Amount is currently stored as provided text value from Telegram command.
- For reporting (`/summary` monthly), add another workflow that reads and aggregates Excel rows.
- Keep bot token secure and rotate if exposed.
