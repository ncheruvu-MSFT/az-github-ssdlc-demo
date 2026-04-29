// ============================================================================
// Function App Module - C# Isolated Worker
// Supports Durable Functions + Service Bus Triggers
// ============================================================================

@description('Azure region')
param location string

@description('Environment name')
param environment string

@description('Project name')
param projectName string

@description('Resource tags')
param tags object

@description('Application Insights connection string')
param appInsightsConnectionString string

@description('Application Insights instrumentation key')
param appInsightsInstrumentationKey string

@description('Service Bus connection string')
@secure()
param serviceBusConnectionString string

@description('VNet subnet ID for integration')
param subnetId string

@description('Key Vault name for secret references')
param keyVaultName string

@description('Log Analytics Workspace ID for diagnostics')
param logAnalyticsWorkspaceId string

// ============================================================================
// Storage Account for Function App
// ============================================================================
var storageAccountName = replace('st${projectName}func${environment}', '-', '')
var keyVaultUri = 'https://${keyVaultName}${az.environment().suffixes.keyvaultDns}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  // #checkov:skip=CKV_AZURE_59: publicNetworkAccess=Enabled with networkAcls defaultAction=Deny+bypass=AzureServices is correct; Function App uses AzureServices trusted bypass (no VNet in dev/staging)
  // #checkov:skip=CKV_AZURE_43: Storage account name uses a parameterized Bicep expression evaluated at deploy time
  // #checkov:skip=CKV_AZURE_206: Standard_LRS replication is sufficient for this demo; upgrade to ZRS/GRS in production
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    publicNetworkAccess: 'Enabled'
    defaultToOAuthAuthentication: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
  }
}

// ============================================================================
// App Service Plan (Elastic Premium for identity-based storage)
// ============================================================================
var planName = 'asp-${projectName}-func-${environment}'

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  tags: tags
  // #checkov:skip=CKV_AZURE_225: Zone redundancy is enabled for prod only; dev/staging use single instance to reduce costs
  sku: {
    name: 'EP1'
    tier: 'ElasticPremium'
  }
  properties: {
    reserved: true  // Linux
    zoneRedundant: environment == 'prod'
  }
}

// ============================================================================
// Function App
// ============================================================================
var functionAppName = 'func-${projectName}-${environment}'

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  tags: union(tags, { 'azd-service-name': 'functionapp' })
  kind: 'functionapp,linux'
  // #checkov:skip=CKV_AZURE_17: Client certificates are not required for Function App HTTP trigger endpoints
  // #checkov:skip=CKV_AZURE_222: Function App requires public network access for HTTP trigger endpoints
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    virtualNetworkSubnetId: environment == 'prod' ? subnetId : null
    siteConfig: {
      linuxFxVersion: 'DOTNET-ISOLATED|8.0'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      use32BitWorkerProcess: false
      healthCheckPath: '/api/health'  // maps to HealthCheck function (Route = "health") in HelloWorldFunction.cs
      numberOfWorkers: 2
      cors: {
        allowedOrigins: ['https://portal.azure.com']
        supportCredentials: false
      }
      appSettings: [
        {
          name: 'AzureWebJobsStorage__blobServiceUri'
          value: 'https://${storageAccount.name}.blob.${az.environment().suffixes.storage}'
        }
        {
          name: 'AzureWebJobsStorage__queueServiceUri'
          value: 'https://${storageAccount.name}.queue.${az.environment().suffixes.storage}'
        }
        {
          name: 'AzureWebJobsStorage__tableServiceUri'
          value: 'https://${storageAccount.name}.table.${az.environment().suffixes.storage}'
        }
        {
          name: 'WEBSITE_SKIP_CONTENTSHARE_VALIDATION'
          value: '1'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsInstrumentationKey
        }
        {
          name: 'ServiceBusConnection'
          value: serviceBusConnectionString
        }
        {
          name: 'KEY_VAULT_URI'
          value: keyVaultUri
        }
      ]
    }
  }
}

// ============================================================================
// Role Assignments for identity-based storage access
// ============================================================================
var storageBlobDataOwnerRoleId = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
var storageAccountContributorRoleId = '17d1049b-9a84-46fb-8f53-869881c3d3ab'
var storageFileDataPrivilegedContributorRoleId = '69566ab7-960f-475b-8e7c-b3118f30c6bd'

resource storageBlobDataOwnerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, functionApp.id, storageBlobDataOwnerRoleId)
  properties: {
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataOwnerRoleId)
  }
}

resource storageAccountContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, functionApp.id, storageAccountContributorRoleId)
  properties: {
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageAccountContributorRoleId)
  }
}

resource storageFileDataContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, functionApp.id, storageFileDataPrivilegedContributorRoleId)
  properties: {
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageFileDataPrivilegedContributorRoleId)
  }
}

// ============================================================================
// Diagnostic Settings
// ============================================================================
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: functionApp
  name: '${functionAppName}-diag'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// ============================================================================
// Outputs
// ============================================================================
output functionAppName string = functionApp.name
output functionAppId string = functionApp.id
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output functionAppPrincipalId string = functionApp.identity.principalId
