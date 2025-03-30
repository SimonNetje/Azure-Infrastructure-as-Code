# Azure-Infrastructure-as-Code

# Introduction

This assignment was about deploying a Flask CRUD app to Azure using Infrastructure-as-Code (IaC). I used bicep to define the infrastructure and deployed everything using Azure CLI. The goal of this was to containerize the app, push it to Azure Container Registry, and deploy it using Azure Container Instances with logging and best practices.

# Overview of what I have built

- Azure Container Registry (ACR)
- Azure Container Instance (ACI)
- Log Analytics Workspace
- Virtual Network and Subnet (defined, not deployed)
- Public IP for the app

# Diagram
![azurediagram drawio](https://github.com/user-attachments/assets/74dd350e-ff85-4dd6-a15f-c22837acd7e2)

# Required before beginning
- Azure CLI installed
- Docker installed and running
- Azure subscription + ACR created


# Bicep files used

###### main.bicep

main.bicep defines the container group deployment and all network/log settings.

```
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
```

###### acr.bicep

acr.bicep provisions the container registry with admin access enabled.

```
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
```

###### network.bicep

network.bicep (if used separately) would create a virtual network and subnet.

```
@description('Name of the Virtual Network')
param vnetName string

@description('Name of the Subnet to create in the VNet')
param subnetName string

@description('Region to deploy to')
param location string = resourceGroup().location

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
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
        }
      }
    ]
  }
}

output subnetId string = vnet.properties.subnets[0].id
```
# Create the Resource Group
Before deploying, create the resource group where all resources will live and create your Azure Container Registry (ACR):
```
az group create --name rg-sg --location westeurope
az acr create --name simonacr2025 --resource-group rg-sg --sku Basic --admin-enabled true
```

# Dockerfile

I used the same Dockerfile from the previous assignment. After building the image locally, I tagged and pushed it to my own Azure Container Registry.



```
docker build -t simonacr2025.azurecr.io/mycrudapp:latest .
```
![dockerimage](https://github.com/user-attachments/assets/be8d1410-52bc-4fa9-b63e-e4f7243b1a0c)


```
az acr login --name simonacr2025
docker push simonacr2025.azurecr.io/mycrudapp:latest
```
Dockerfile
```
FROM python:3.9

WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . .

RUN apt-get update && apt-get install -y libpq-dev gcc

RUN python3 -m venv venv

RUN /bin/bash -c "source venv/bin/activate && pip install --upgrade pip && pip install -r requirements.txt"

ENV FLASK_APP=crudapp.py
ENV FLASK_RUN_HOST=0.0.0.0

RUN /bin/bash -c "source venv/bin/activate && flask db init && flask db migrate -m 'entries table' && flask db upgrade"

EXPOSE 80

CMD ["/bin/bash", "-c", "source venv/bin/activate && flask run --host=0.0.0.0 --port=80"]
```

# Deploy the ACR using Bicep

```
az deployment group create --resource-group rg-sg --template-file acr.bicep --parameters acrName="simonacr2025"
```

# Get ACR Password

I retrieved my ACR admin password using:
```
az acr credential show --name simonacr2025 --query "passwords[0].value" -o tsv
```
![image](https://github.com/user-attachments/assets/156740a1-c2e1-4489-887c-a10c75e7703d)


# Deploy the App Container

I deployed the container group using my main.bicep file. I passed the ACR password as a secure parameter:

```
az deployment group create --resource-group rg-sg --template-file main.bicep --parameters acrPass="YOUR_ACR_PASSWORD"
```

# Get public IP
```
az container show --resource-group rg-sg --name sg-crudapp --query ipAddress.ip -o tsv
```


# Best practices implemented
-  App exposed on HTTP port 80
-  Container image pulled securely
-  Logs sent to Azure monitor
-  Code-based infrastructure (Bicep)

# Verification and Debugging

check if container is running:
```
az container show --resource-group rg-sg --name sg-crudapp --output table
```
![image](https://github.com/user-attachments/assets/c84be927-42fd-49c4-81ae-c6240ecefbae)


view logs (CLI):
```
az container logs --resource-group rg-sg --name sg-crudapp
```
![image](https://github.com/user-attachments/assets/66ff0e6f-709c-4fd9-950e-82973e851580)


restart container:
```
az container restart --resource-group rg-sg --name sg-crudapp
```

check docker image in ACR:
```
az acr repository list --name simonacr2025 -o table
az acr repository show-tags --name simonacr2025 --repository mycrudapp -o table
```
![image](https://github.com/user-attachments/assets/49d4dbb0-1527-4332-880e-adcce0fdfe27)


# Clean Up Resources
```
az group delete --name rg-sg --yes --no-wait
```


# Extra Notes

I ran into deployment errors with image accessibility and fixed them by:
- Assigning proper roles using Azure CLI
- Verifying container logs through Log Analytics
- Retagging and pushing the image again from Docker

These helped reinforce how authentication and networking work in Azure deployments.

# Result
![image](https://github.com/user-attachments/assets/ab47b7e7-5720-4bc6-bc5b-1b04f8d24526)


# Conclusion
This project helped me understand full containerized deployments in Azure using Infrastructure-as-Code, including networking, logging, and secure image management



