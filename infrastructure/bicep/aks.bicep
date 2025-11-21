param location string = resourceGroup().location
param environment string = 'dev'
param uniqueSuffix string = substring(uniqueString(resourceGroup().id), 0, 6)
param vnetId string
param acrName string

var resourcePrefix = 'fb-${environment}-${uniqueSuffix}'

// Get VNet resource
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: 'fb-dev-ygfwoi-vnet'
}

// Get ACR resource
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' existing = {
  name: acrName
}

// Azure Kubernetes Service
resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-02-01' = {
  name: '${resourcePrefix}-aks'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: '${resourcePrefix}-aks'
    agentPoolProfiles: [
      {
        name: 'systemnp'
        count: 2
        vmSize: 'Standard_B2s'
        osType: 'Linux'
        mode: 'System'
        vnetSubnetID: '${vnetId}/subnets/aks-subnet'
      }
      {
        name: 'workernp'
        count: 2
        vmSize: 'Standard_B2ms'
        osType: 'Linux'
        mode: 'User'
        vnetSubnetID: '${vnetId}/subnets/aks-subnet'
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
      serviceCidr: '10.10.0.0/16'
      dnsServiceIP: '10.10.0.10'
    }
  }
}

// RBAC assignment for ACR pull
resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: containerRegistry
  name: guid(containerRegistry.id, aksCluster.id, 'acrpull')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: aksCluster.properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
}

output aksClusterName string = aksCluster.name
output aksClusterFqdn string = aksCluster.properties.fqdn
output aksClusterResourceId string = aksCluster.id