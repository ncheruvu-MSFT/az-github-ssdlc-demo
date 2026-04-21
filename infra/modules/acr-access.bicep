// ============================================================================
// ACR Access Module - Managed Identity for Container App image pull
// Creates a User-Assigned MI and assigns AcrPull role on the ACR
// Deployed in the shared resource group alongside the ACR
// ============================================================================

@description('Azure region for the managed identity')
param location string

@description('Environment name')
param environment string

@description('Project name')
param projectName string

@description('Resource tags')
param tags object

@description('ACR name (must exist in the same resource group)')
param acrName string

// ============================================================================
// User-Assigned Managed Identity for ACR Pull
// ============================================================================
var identityName = 'id-acr-pull-${projectName}-${environment}'

resource acrPullIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
  tags: tags
}

// ============================================================================
// Reference existing ACR
// ============================================================================
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

// ============================================================================
// AcrPull Role Assignment
// ============================================================================
// AcrPull built-in role: 7f951dda-4ed3-4680-a7ca-43fe172d538d
var acrPullRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '7f951dda-4ed3-4680-a7ca-43fe172d538d'
)

resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acrPullIdentity.id, acr.id, '7f951dda-4ed3-4680-a7ca-43fe172d538d')
  scope: acr
  properties: {
    roleDefinitionId: acrPullRoleDefinitionId
    principalId: acrPullIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// Outputs
// ============================================================================
output identityId string = acrPullIdentity.id
output identityPrincipalId string = acrPullIdentity.properties.principalId
output acrLoginServer string = acr.properties.loginServer
