// ============================================================================
// Service Bus Module - Enterprise Service Hub Pattern
// Premium tier with private endpoint for enterprise messaging
// ============================================================================

@description('Azure region')
param location string

@description('Environment name')
param environment string

@description('Project name')
param projectName string

@description('Resource tags')
param tags object

@description('VNet ID for private endpoint')
param vnetId string

@description('Subnet ID for private endpoint')
param privateEndpointSubnetId string

// ============================================================================
// Service Bus Namespace - Enterprise Service Hub
// ============================================================================
var serviceBusName = 'sb-${projectName}-${environment}'

resource serviceBus 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: serviceBusName
  location: location
  tags: tags
  sku: {
    name: environment == 'prod' ? 'Premium' : 'Standard'
    tier: environment == 'prod' ? 'Premium' : 'Standard'
    capacity: environment == 'prod' ? 1 : 0
  }
  properties: {
    minimumTlsVersion: '1.2'
    publicNetworkAccess: environment == 'prod' ? 'Disabled' : 'Enabled'
    disableLocalAuth: true   // Force Azure AD auth only
    zoneRedundant: environment == 'prod'
  }
}

// Queues - Enterprise Patterns
resource orderQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: serviceBus
  name: 'orders'
  properties: {
    maxDeliveryCount: 10
    lockDuration: 'PT5M'
    defaultMessageTimeToLive: 'P14D'
    deadLetteringOnMessageExpiration: true
    requiresDuplicateDetection: true
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    enablePartitioning: false
    maxSizeInMegabytes: 5120
  }
}

resource notificationQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: serviceBus
  name: 'notifications'
  properties: {
    maxDeliveryCount: 5
    lockDuration: 'PT2M'
    defaultMessageTimeToLive: 'P7D'
    deadLetteringOnMessageExpiration: true
    maxSizeInMegabytes: 1024
  }
}

// Topics - Pub/Sub Pattern
resource eventsTopic 'Microsoft.ServiceBus/namespaces/topics@2022-10-01-preview' = {
  parent: serviceBus
  name: 'events'
  properties: {
    defaultMessageTimeToLive: 'P14D'
    maxSizeInMegabytes: 5120
    requiresDuplicateDetection: true
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    enablePartitioning: false
  }
}

resource auditSubscription 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: eventsTopic
  name: 'audit-log'
  properties: {
    maxDeliveryCount: 10
    lockDuration: 'PT5M'
    deadLetteringOnMessageExpiration: true
    defaultMessageTimeToLive: 'P30D'
  }
}

resource processingSubscription 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: eventsTopic
  name: 'event-processing'
  properties: {
    maxDeliveryCount: 10
    lockDuration: 'PT5M'
    deadLetteringOnMessageExpiration: true
  }
}

// Private DNS Zone for Service Bus (prod only)
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (environment == 'prod') {
  name: 'privatelink.servicebus.windows.net'
  location: 'global'
  tags: tags
}

resource vnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (environment == 'prod') {
  parent: privateDnsZone
  name: '${serviceBusName}-vnet-link'
  location: 'global'
  properties: {
    virtualNetwork: { id: vnetId }
    registrationEnabled: false
  }
}

// Private Endpoint (prod only)
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = if (environment == 'prod') {
  name: 'pe-${serviceBusName}'
  location: location
  tags: tags
  properties: {
    subnet: { id: privateEndpointSubnetId }
    privateLinkServiceConnections: [
      {
        name: 'pe-${serviceBusName}'
        properties: {
          privateLinkServiceId: serviceBus.id
          groupIds: ['namespace']
        }
      }
    ]
  }
}

// Authorization Rules
resource sendRule 'Microsoft.ServiceBus/namespaces/authorizationRules@2022-10-01-preview' = {
  parent: serviceBus
  name: 'SendOnly'
  properties: {
    rights: ['Send']
  }
}

resource listenRule 'Microsoft.ServiceBus/namespaces/authorizationRules@2022-10-01-preview' = {
  parent: serviceBus
  name: 'ListenOnly'
  properties: {
    rights: ['Listen']
  }
}

// Diagnostic settings
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: serviceBus
  name: '${serviceBusName}-diag'
  properties: {
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
output namespaceName string = serviceBus.name
output namespaceId string = serviceBus.id
output connectionString string = sendRule.listKeys().primaryConnectionString
