param location string = resourceGroup().location
var synapseWorkspaceName = substring('serengetidatalab${uniqueString(resourceGroup().id)}', 0, 24)
var storageAccountName = substring('serengetistore${uniqueString(resourceGroup().id)}', 0, 24)
var fileSystemName = 'synapsedef'
var vaultName = substring('serengetikeyvault${uniqueString(resourceGroup().id)}', 0, 24)
var amlWorkspaceName = 'SerengetiAML${uniqueString(resourceGroup().id)}'
var appInsightsName = 'serengetiAppInsights${uniqueString(resourceGroup().id)}'
var logAnalyticsName = 'serengetiLogAnalytics${uniqueString(resourceGroup().id)}'
var containerRegistryName = 'serengetiContainers${uniqueString(resourceGroup().id)}'
var amlStorageName = substring('amlStorage${uniqueString(resourceGroup().id)}', 0, 24)


param sqlAdministratorLogin string = 'sqladminuser'

@secure()
param sqlAdministratorLoginPassword string 

module defaultSynapseDataLake 'datalake.bicep' = {
  name: 'defaultSynapseDataLake${uniqueString(resourceGroup().id)}'
  params: {
    location: location
    storageAccountName: storageAccountName
  }
}

module synapseWorkspace 'synapse.bicep' = {
  name: 'synapseWorkspace'
  params: {
    location: location
    synapseWorkspaceName: synapseWorkspaceName
    fileSystemName: fileSystemName
    storageAccountUrl: defaultSynapseDataLake.outputs.accountUrl
    storageResourceId: defaultSynapseDataLake.outputs.resourceId
    sqlAdministratorLogin: sqlAdministratorLogin
    sqlAdministratorLoginPassword: sqlAdministratorLoginPassword
  }
}



resource SerengetiVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' = {
  name: vaultName
  location: location
  properties: {
    enableSoftDelete: false
    tenantId: subscription().tenantId
    sku: {
      name: 'standard'
      family: 'A'
    }
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: synapseWorkspace.outputs.synapseManagedIdentityId
        permissions: {
          keys: [
            'get'
          ]
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
    enabledForTemplateDeployment: true
  }
}

// Create a secret
resource passwordSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${SerengetiVault.name}/SqlPoolPassword'
  properties: {
    value: sqlAdministratorLoginPassword
    contentType: 'text/plain'
  }
}

resource AccessKeySecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${SerengetiVault.name}/ADLS-AccessKey'
  properties: {
    value: defaultSynapseDataLake.outputs.storageAccountKey
    contentType: 'text/plain'
  }
}

resource dedicatedSqlPoolConnectionString 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${SerengetiVault.name}/DedicatedPool-ConnectionString'
  properties: {
    value: 'Server=tcp:${synapseWorkspace.outputs.synapseWorkspaceName}.sql.azuresynapse.net,1433;Initial Catalog=${synapseWorkspace.outputs.synapseDedicatedSqlPoolName};Persist Security Info=False;User ID=${sqlAdministratorLogin};Password=${sqlAdministratorLoginPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=300;'
    contentType: 'text/plain'
  }
}

resource DataLakeConnectionString 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${SerengetiVault.name}/ADLS-ConnectionString'
  properties: {
    value: 'DefaultEndpointsProtocol=https;AccountName=${defaultSynapseDataLake.outputs.storageAccountName};AccountKey=${defaultSynapseDataLake.outputs.storageAccountKey};EndpointSuffix=core.windows.net'
    contentType: 'text/plain'   
  }
}


module amlWorkspace 'azureml.bicep' = {
  name: 'amlWorkspace'
  params: {
    location: location
    amlWorkspaceName: amlWorkspaceName
    appInsightsName: appInsightsName
    logAnalyticsName: logAnalyticsName
    keyVaultId: SerengetiVault.id
    containerRegistryName: containerRegistryName
    synapseSparkPoolId: synapseWorkspace.outputs.synapsePoolId
    synapseWorkspaceId: synapseWorkspace.outputs.synapseWorkspaceId
    amlStorageName: amlStorageName
  }
}







