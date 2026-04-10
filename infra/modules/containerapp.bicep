// ============================================================================
// Container Apps Module - C# Hello World + Python API
// Azure Container Apps Environment with multiple apps
// ============================================================================

@description('Azure region')
param location string

@description('Environment name')
param environment string

@description('Project name')
param projectName string

@description('Resource tags')
param tags object

@description('Log Analytics Workspace ID')
param logAnalyticsWorkspaceId string

@description('C# Container image')
param containerImage string

@description('Python API container image')
param pythonApiImage string

@description('VNet subnet ID for ACA Environment')
param infrastructureSubnetId string

@description('Application Insights connection string')
param appInsightsConnectionString string

// ============================================================================
// Container Apps Environment
// ============================================================================
var envName = 'cae-${projectName}-${environment}'

resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: envName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: reference(logAnalyticsWorkspaceId, '2023-09-01').customerId
        sharedKey: listKeys(logAnalyticsWorkspaceId, '2023-09-01').primarySharedKey
      }
    }
    vnetConfiguration: {
      infrastructureSubnetId: infrastructureSubnetId
      internal: false
    }
    zoneRedundant: environment == 'prod'
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
  }
}

// ============================================================================
// C# Hello World Container App
// ============================================================================
var helloWorldAppName = 'ca-hello-${projectName}-${environment}'

resource helloWorldApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: helloWorldAppName
  location: location
  tags: union(tags, { 'azd-service-name': 'containerapp-hello' })
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    managedEnvironmentId: containerAppEnvironment.id
    workloadProfileName: 'Consumption'
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
        transport: 'http'
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
        corsPolicy: {
          allowedOrigins: ['https://portal.azure.com']
          allowedMethods: ['GET', 'POST']
          allowedHeaders: ['*']
          maxAge: 3600
        }
      }
      activeRevisionsMode: 'Single'
    }
    template: {
      containers: [
        {
          name: 'hello-world'
          image: containerImage
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'ASPNETCORE_ENVIRONMENT'
              value: environment == 'prod' ? 'Production' : 'Development'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsightsConnectionString
            }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 8080
              }
              periodSeconds: 30
              failureThreshold: 3
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health/ready'
                port: 8080
              }
              periodSeconds: 10
              failureThreshold: 3
            }
          ]
        }
      ]
      scale: {
        minReplicas: environment == 'prod' ? 2 : 0
        maxReplicas: environment == 'prod' ? 10 : 3
        rules: [
          {
            name: 'http-scale'
            http: {
              metadata: {
                concurrentRequests: '50'
              }
            }
          }
        ]
      }
    }
  }
}

// ============================================================================
// Python API Container App
// ============================================================================
var pythonApiAppName = 'ca-pyapi-${projectName}-${environment}'

resource pythonApiApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: pythonApiAppName
  location: location
  tags: union(tags, { 'azd-service-name': 'containerapp-pyapi' })
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    managedEnvironmentId: containerAppEnvironment.id
    workloadProfileName: 'Consumption'
    configuration: {
      ingress: {
        external: true
        targetPort: 8000
        transport: 'http'
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      activeRevisionsMode: 'Single'
    }
    template: {
      containers: [
        {
          name: 'python-api'
          image: pythonApiImage
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'ENVIRONMENT'
              value: environment
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsightsConnectionString
            }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 8000
              }
              periodSeconds: 30
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: 8000
              }
              periodSeconds: 10
            }
          ]
        }
      ]
      scale: {
        minReplicas: environment == 'prod' ? 2 : 0
        maxReplicas: environment == 'prod' ? 10 : 3
        rules: [
          {
            name: 'http-scale'
            http: {
              metadata: {
                concurrentRequests: '50'
              }
            }
          }
        ]
      }
    }
  }
}

// ============================================================================
// Outputs
// ============================================================================
output environmentId string = containerAppEnvironment.id
output helloWorldUrl string = 'https://${helloWorldApp.properties.configuration.ingress.fqdn}'
output pythonApiUrl string = 'https://${pythonApiApp.properties.configuration.ingress.fqdn}'
output helloWorldPrincipalId string = helloWorldApp.identity.principalId
output pythonApiPrincipalId string = pythonApiApp.identity.principalId
