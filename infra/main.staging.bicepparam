using './main.bicep'

param environment = 'staging'
param location = 'australiaeast'
param projectName = 'ssdlcdemo'
param containerImage = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
param pythonApiImage = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
