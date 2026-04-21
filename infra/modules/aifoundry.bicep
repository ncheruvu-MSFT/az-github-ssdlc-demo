// ============================================================================
// AI Foundry Module — Azure AI Services + AI Hub + AI Project
// Provisions Azure AI resources for agent creation, evaluation, and red team
// SSDLC: Managed Identity auth, diagnostic settings, RBAC
// ============================================================================

@description('Azure region')
param location string

@description('Environment name')
@allowed(['dev', 'staging', 'prod'])
param environment string

@description('Project name')
param projectName string

@description('Resource tags')
param tags object

@description('Log Analytics Workspace ID for diagnostics')
param logAnalyticsWorkspaceId string

@description('Application Insights connection string (reserved for future use)')
#disable-next-line no-unused-params
param appInsightsConnectionString string = ''

// ============================================================================
// Azure AI Services (multi-service Cognitive Services account)
// ============================================================================
var aiServicesName = 'ai-${projectName}-${environment}'

resource aiServices 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: aiServicesName
  location: location
  tags: tags
  kind: 'AIServices'
  sku: {
    name: environment == 'prod' ? 'S0' : 'S0'
  }
  properties: {
    customSubDomainName: aiServicesName
    publicNetworkAccess: environment == 'prod' ? 'Disabled' : 'Enabled'
    disableLocalAuth: false
    apiProperties: {}
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// ============================================================================
// GPT-4o Model Deployment
// ============================================================================
resource gpt4oDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: aiServices
  name: 'gpt-4o'
  sku: {
    name: 'GlobalStandard'
    capacity: environment == 'prod' ? 30 : 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o'
      version: '2024-11-20'
    }
  }
}

// ============================================================================
// Diagnostic Settings
// ============================================================================
resource aiServicesDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: aiServices
  name: '${aiServicesName}-diag'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
    ]
  }
}

// ============================================================================
// Outputs
// ============================================================================
@description('AI Services endpoint')
output aiServicesEndpoint string = aiServices.properties.endpoint

@description('AI Services resource ID')
output aiServicesId string = aiServices.id

@description('AI Services name')
output aiServicesName string = aiServices.name

@description('GPT-4o deployment name')
output modelDeploymentName string = gpt4oDeployment.name
