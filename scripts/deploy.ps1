param(
  [Parameter(Mandatory = $false)]
  [string]$AzResourceGroup = $env:AZ_RESOURCE_GROUP,

  [Parameter(Mandatory = $false)]
  [string]$AzLocation = $env:AZ_LOCATION,

  [Parameter(Mandatory = $false)]
  [string]$WorkflowName = $env:WORKFLOW_NAME,

  [Parameter(Mandatory = $false)]
  [string]$TelegramBotToken = $env:TELEGRAM_BOT_TOKEN,

  [Parameter(Mandatory = $false)]
  [string]$ExcelFileId = $env:EXCEL_FILE_ID,

  [Parameter(Mandatory = $false)]
  [string]$ExcelConnectionId = $env:EXCEL_CONNECTION_ID,

  [Parameter(Mandatory = $false)]
  [string]$OneDriveDriveId = $(if ($env:ONE_DRIVE_DRIVE_ID) { $env:ONE_DRIVE_DRIVE_ID } else { 'me' }),

  [Parameter(Mandatory = $false)]
  [string]$ExcelTableId = $(if ($env:EXCEL_TABLE_ID) { $env:EXCEL_TABLE_ID } else { 'ExpensesTable' })
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
  throw 'Azure CLI (az) is not installed. Install from https://aka.ms/installazurecliwindows'
}

$missing = @()
if ([string]::IsNullOrWhiteSpace($AzResourceGroup)) { $missing += 'AZ_RESOURCE_GROUP / -AzResourceGroup' }
if ([string]::IsNullOrWhiteSpace($AzLocation)) { $missing += 'AZ_LOCATION / -AzLocation' }
if ([string]::IsNullOrWhiteSpace($WorkflowName)) { $missing += 'WORKFLOW_NAME / -WorkflowName' }
if ([string]::IsNullOrWhiteSpace($TelegramBotToken)) { $missing += 'TELEGRAM_BOT_TOKEN / -TelegramBotToken' }
if ([string]::IsNullOrWhiteSpace($ExcelFileId)) { $missing += 'EXCEL_FILE_ID / -ExcelFileId' }
if ([string]::IsNullOrWhiteSpace($ExcelConnectionId)) { $missing += 'EXCEL_CONNECTION_ID / -ExcelConnectionId' }

if ($missing.Count -gt 0) {
  throw ("Missing required values:`n- " + ($missing -join "`n- "))
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir '..')
$templateFile = Join-Path $repoRoot 'infra/main.bicep'

Write-Host '==> Ensuring resource group exists'
az group create --name $AzResourceGroup --location $AzLocation | Out-Null

Write-Host '==> Deploying Logic App'
az deployment group create `
  --resource-group $AzResourceGroup `
  --template-file $templateFile `
  --parameters `
    location=$AzLocation `
    workflowName=$WorkflowName `
    telegramBotToken=$TelegramBotToken `
    oneDriveDriveId=$OneDriveDriveId `
    excelFileId=$ExcelFileId `
    excelTableId=$ExcelTableId `
    excelConnectionId=$ExcelConnectionId `
  --query properties.outputs -o json

$subscriptionId = az account show --query id -o tsv
$callbackUrlApi = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$AzResourceGroup/providers/Microsoft.Logic/workflows/$WorkflowName/triggers/When_a_HTTP_request_is_received/listCallbackUrl?api-version=2019-05-01"

Write-Host '==> Fetching callback URL for HTTP trigger'
$triggerUrl = az rest --method post --url $callbackUrlApi --query value -o tsv

Write-Host 'Trigger URL:'
Write-Host $triggerUrl

Write-Host '==> Registering Telegram webhook'
$body = @{ url = $triggerUrl } | ConvertTo-Json -Compress
Invoke-RestMethod `
  -Method Post `
  -Uri "https://api.telegram.org/bot$TelegramBotToken/setWebhook" `
  -ContentType 'application/json' `
  -Body $body | ConvertTo-Json -Depth 8

Write-Host 'Deployment complete. Send /help to your bot to test.'
