using './main.bicep'

param environment = 'prod'
param location = 'australiaeast'
param projectName = 'ssdlcdemo'
param containerImage = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
param pythonApiImage = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
param deployAIFoundry = true
