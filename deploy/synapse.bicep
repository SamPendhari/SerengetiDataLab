param location string = resourceGroup().location
param synapseWorkspaceName string 
param fileSystemName string 
param storageAccountUrl string
param storageResourceId string
param sqlPoolName string = 'defdedicated'
param performanceLevel string = 'DW1000c'
param capacity int = 100
param sqlPoolTier string = 'Standard'
param sqlAdministratorLogin string
param mlsparkpoolName string = 'mlsparkpool'

@secure()
param sqlAdministratorLoginPassword string


resource synapseSerengeti 'Microsoft.Synapse/workspaces@2021-06-01' = {
  name: synapseWorkspaceName
  location: location

  properties: {
    defaultDataLakeStorage: {
      accountUrl: storageAccountUrl
      createManagedPrivateEndpoint: false
      filesystem: fileSystemName
      resourceId: storageResourceId
    }

    managedResourceGroupName: '${resourceGroup().name}-mrg'

    sqlAdministratorLogin: sqlAdministratorLogin
    sqlAdministratorLoginPassword: sqlAdministratorLoginPassword

  }

  identity: {
    type: 'SystemAssigned'
  }
}

resource dedicateSqlPool 'Microsoft.Synapse/workspaces/sqlPools@2021-06-01' = {
  name: sqlPoolName
  location: location
  sku: {
    capacity: capacity
    name: performanceLevel 
    tier: sqlPoolTier
  }
  parent: synapseSerengeti
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'

  }
}

resource mlPool 'Microsoft.Synapse/workspaces/bigDataPools@2021-06-01' = {
  location: location
  name: mlsparkpoolName
  parent: synapseSerengeti
  properties:{
    autoPause: {
      delayInMinutes: 15
      enabled: true
    }
    sparkVersion: '3.2'
    nodeSize: 'Medium'
    nodeSizeFamily: 'HardwareAcceleratedGPU'
    nodeCount: 3
    autoScale: {
      enabled: true
      minNodeCount: 3
      maxNodeCount: 10
    }
  }
}



// output resource id of the synapse workspace
output synapseWorkspaceId string = synapseSerengeti.id
output synapseManagedIdentityId string = synapseSerengeti.identity.principalId
