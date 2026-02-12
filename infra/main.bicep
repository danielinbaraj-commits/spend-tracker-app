@description('Azure region for the Logic App resource')
param location string = resourceGroup().location

@description('Name of the Logic App workflow')
param workflowName string

@description('Telegram bot token from BotFather')
@secure()
param telegramBotToken string

@description('OneDrive drive id. Use "me" for signed-in account in most setups')
param oneDriveDriveId string = 'me'

@description('OneDrive Excel file id for SpendTracker.xlsx')
param excelFileId string

@description('Excel table name/id in the workbook')
param excelTableId string = 'ExpensesTable'

@description('Resource ID of an existing excelonlinebusiness API connection')
param excelConnectionId string

var workflowDefinition = loadJsonContent('../logicapp/workflow.json')

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: workflowName
  location: location
  properties: {
    state: 'Enabled'
    definition: workflowDefinition
    parameters: {
      telegramBotToken: {
        value: telegramBotToken
      }
      oneDriveDriveId: {
        value: oneDriveDriveId
      }
      excelFileId: {
        value: excelFileId
      }
      excelTableId: {
        value: excelTableId
      }
      '$connections': {
        value: {
          excelonlinebusiness: {
            connectionId: excelConnectionId
            connectionName: last(split(excelConnectionId, '/'))
            id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'excelonlinebusiness')
          }
        }
      }
    }
  }
}

output logicAppResourceId string = logicApp.id
output logicAppName string = logicApp.name
