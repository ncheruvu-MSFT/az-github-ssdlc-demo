// ============================================================================
// Azure Enterprise SSDLC Demo - Main Infrastructure
// Uses Azure Verified Modules (AVM) for all resources
// ============================================================================

targetScope = 'subscription'

@description('Environment name (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environment string

@description('Primary Azure region')
param location string = 'australiaeast'

@description('Project name prefix')
param projectName string = 'ssdlcdemo'

@description('Container image for ACA')
param containerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('Python API container image')
param pythonApiImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('ACR name for container image pull authentication (leave empty to skip ACR config)')
param acrName string = ''

// ============================================================================
// Variables
// ============================================================================
var resourceGroupName = 'rg-${projectName}-${environment}'
var tags = {
  Environment: environment
  Project: projectName
  ManagedBy: 'Bicep-AVM'
  SecurityLevel: 'Enterprise'
}

// ============================================================================
// Resource Group
// ============================================================================
resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// ============================================================================
// Module Deployments
// ============================================================================

// Networking (VNet with subnets for private endpoints)
module networking 'modules/networking.bicep' = {
  scope: rg
  name: 'networking-${environment}'
  params: {
    location: location
    environment: environment
    projectName: projectName
    tags: tags
  }
}

// Key Vault for secrets management
module keyVault 'modules/keyvault.bicep' = {
  scope: rg
  name: 'keyvault-${environment}'
  params: {
    location: location
    environment: environment
    projectName: projectName
    tags: tags
    vnetId: networking.outputs.vnetId
    privateEndpointSubnetId: networking.outputs.privateEndpointSubnetId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

// Service Bus for enterprise messaging
module serviceBus 'modules/servicebus.bicep' = {
  scope: rg
  name: 'servicebus-${environment}'
  params: {
    location: location
    environment: environment
    projectName: projectName
    tags: tags
    vnetId: networking.outputs.vnetId
    privateEndpointSubnetId: networking.outputs.privateEndpointSubnetId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

// Monitoring (Log Analytics + Application Insights)
module monitoring 'modules/monitoring.bicep' = {
  scope: rg
  name: 'monitoring-${environment}'
  params: {
    location: location
    environment: environment
    projectName: projectName
    tags: tags
  }
}

// ACR Pull Identity + Role Assignment (in shared resource group)
module acrAccess 'modules/acr-access.bicep' = if (!empty(acrName)) {
  scope: resourceGroup('rg-${projectName}-shared')
  name: 'acr-access-${environment}'
  params: {
    location: location
    environment: environment
    projectName: projectName
    tags: tags
    acrName: acrName
  }
}

// Azure Function App (C# Hello World + Durable Functions)
module functionApp 'modules/functionapp.bicep' = {
  scope: rg
  name: 'functionapp-${environment}'
  params: {
    location: location
    environment: environment
    projectName: projectName
    tags: tags
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    appInsightsInstrumentationKey: monitoring.outputs.appInsightsInstrumentationKey
    serviceBusConnectionString: serviceBus.outputs.connectionString
    subnetId: networking.outputs.functionAppSubnetId
    keyVaultName: keyVault.outputs.keyVaultName
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

// Container Apps (C# Hello World + Python API)
// Construct ACR values deterministically to avoid null-ref on conditional module outputs
var acrLoginServerValue = !empty(acrName) ? '${acrName}.azurecr.io' : ''
var acrPullIdentityIdValue = !empty(acrName)
  ? resourceId('rg-${projectName}-shared', 'Microsoft.ManagedIdentity/userAssignedIdentities', 'id-acr-pull-${projectName}-${environment}')
  : ''

module containerApp 'modules/containerapp.bicep' = {
  scope: rg
  name: 'containerapp-${environment}'
  dependsOn: [acrAccess]
  params: {
    location: location
    environment: environment
    projectName: projectName
    tags: tags
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    containerImage: containerImage
    pythonApiImage: pythonApiImage
    infrastructureSubnetId: networking.outputs.acaSubnetId
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    acrLoginServer: acrLoginServerValue
    acrPullIdentityId: acrPullIdentityIdValue
  }
}

// ============================================================================
// Outputs
// ============================================================================
output resourceGroupName string = rg.name
output functionAppName string = functionApp.outputs.functionAppName
output functionAppUrl string = functionApp.outputs.functionAppUrl
output containerAppUrl string = containerApp.outputs.helloWorldUrl
output pythonApiUrl string = containerApp.outputs.pythonApiUrl
output keyVaultName string = keyVault.outputs.keyVaultName
output serviceBusNamespace string = serviceBus.outputs.namespaceName
