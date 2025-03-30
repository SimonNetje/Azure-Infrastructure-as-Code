@description('Container group name')
param containerName string = 'sg-crudapp'

@description('Region of deployment')
param location string = resourceGroup().location

@description('ACR image with tag')
param acrImage string = 'simonacr2025.azurecr.io/mycrudapp:latest'

@description('Container port')
param appPort int = 80

@description('CPU allocation')
param cpu int = 1

@description('Memory allocation in GB')
param memory int = 2

@description('Restart policy')
@allowed([
  'Always'
  'OnFailure'
  'Never'
])
param restart string = 'Always'

@description('ACR login username')
param acrUser string = 'simonacr2025'

@description('ACR login password')
@secure()
param acrPass string

@description('Virtual Network Name')
param vnetName string = 'sg-vnet'

@description('Subnet Name')
param subnetName string = 'sg-subnet'

@description('Network Security Group Name')
param nsgName string = 'sg-nsg'

// Log Analytics workspace for logging
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'sglogs'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

// Virtual network
resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.0.0.0/24'
          delegations: [
            {
              name: 'aciDelegation'
              properties: {
                serviceName: 'Microsoft.ContainerInstance/containerGroups'
              }
            }
          ]
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

// NSG to allow only HTTP (port 80) inbound
resource nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTP-Inbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
    ]
  }
}

// Container group deployment
resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: containerName
  location: location
  properties: {
    osType: 'Linux'
    restartPolicy: restart
    containers: [
      {
        name: containerName
        properties: {
          image: acrImage
          ports: [
            {
              port: appPort
              protocol: 'Tcp'
            }
          ]
          resources: {
            requests: {
              cpu: cpu
              memoryInGB: memory
            }
          }
        }
      }
    ]
    imageRegistryCredentials: [
      {
        server: 'simonacr2025.azurecr.io'
        username: acrUser
        password: acrPass
      }
    ]
    ipAddress: {
      type: 'Public'
      ports: [
        {
          port: appPort
          protocol: 'Tcp'
        }
      ]
    }
    diagnostics: {
      logAnalytics: {
        workspaceId: logWorkspace.properties.customerId
        workspaceKey: logWorkspace.listKeys().primarySharedKey
      }
    }
  }
}

// Outputs
output containerIP string = containerGroup.properties.ipAddress.ip
output vnetId string = vnet.id
output subnetId string = vnet.properties.subnets[0].id
output nsgId string = nsg.id
output logWorkspace string = logWorkspace.name
