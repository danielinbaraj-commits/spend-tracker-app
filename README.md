# Spend Tracker (Telegram + Azure Logic Apps + Excel on OneDrive)

This repo contains a ready-to-import Azure Logic App workflow that lets you track expenses from Telegram and save them into an Excel table stored in OneDrive.

## Architecture

1. You send a message to your Telegram bot, e.g.:
   - `/add 12.50 Food Lunch`
   - `/help`
2. Telegram calls your Logic App webhook URL.
3. Logic App parses the command.
4. Logic App writes a new row into an Excel table in OneDrive.
5. Logic App sends a confirmation message back to Telegram.

## Repository contents

- `logicapp/workflow.json` – Logic App workflow definition (Consumption-style JSON).
- `excel/spend-tracker-template.csv` – starter data shape for your Excel table.

---

## 1) Create Telegram bot

1. Open Telegram and message `@BotFather`.
2. Run `/newbot` and finish setup.
3. Save your bot token (looks like `123456:ABC-DEF...`).

---

## 2) Create Excel file in OneDrive

1. Create a file in OneDrive named `SpendTracker.xlsx`.
2. Create a worksheet named `Expenses`.
3. Add an Excel **Table** (Insert -> Table), named exactly: `ExpensesTable`.
4. Use these columns in row 1:

- `Date`
- `Amount`
- `Category`
- `Note`
- `ChatId`
- `RawCommand`

You can copy from `excel/spend-tracker-template.csv`.

---

## 3) Deploy Logic App

### Option A: Portal designer (quickest)

1. Create a Logic App (Consumption).
2. Open **Code view**.
3. Paste the content from `logicapp/workflow.json`.
4. Save.

### Option B: ARM/Bicep integration

Use `logicapp/workflow.json` as the workflow definition for your Logic App resource.

---

## 4) Configure workflow parameters

Set these Logic App parameters in the workflow:

- `telegramBotToken` – your Telegram bot token.
- `oneDriveDriveId` – OneDrive drive id (or keep default `me` if your connector supports it).
- `excelFileId` – file id of `SpendTracker.xlsx`.
- `excelTableId` – table id/name (`ExpensesTable`).

Also ensure your API connection parameter `$connections` points to a valid `excelonlinebusiness` connection.

---

## 5) Register Telegram webhook

After saving the Logic App, copy the HTTP trigger URL and run:

```bash
curl -X POST "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{"url":"<YOUR_LOGIC_APP_TRIGGER_URL>"}'
```

Test:

- Send `/help`
- Send `/add 9.99 Coffee Cappuccino`

---

## Supported bot commands

- `/add <amount> <category> <note...>`
  - Example: `/add 25.40 Transport Metro card`
- `/help`

If the format is invalid, bot responds with usage instructions.

---

## Notes

- The workflow accepts Telegram update payloads via webhook.
- For production, rotate your bot token regularly and restrict Logic App access as needed.
- If you want summaries (`/summary` daily/monthly), add a second flow that reads rows from Excel and aggregates totals.
