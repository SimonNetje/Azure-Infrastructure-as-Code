param acrName string
param location string = resourceGroup().location

resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}
  resource acrToken 'Microsoft.ContainerRegistry/registries/tokens@2022-12-01' = {
    name: 'tokensg'
    parent: acr 
    properties: {
      scopeMapId: resourceId('Microsoft.ContainerRegistry/registries/scopeMaps', acrName, '_repositories_pull')
      status: 'enabled'
    }
}

output loginServer string = acr.properties.loginServer
output acrNameOut string = acr.name
