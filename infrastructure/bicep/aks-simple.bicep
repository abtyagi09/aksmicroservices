param location string = resourceGroup().location
param aksClusterName string = 'farmersbank-aks'
param nodeCount int = 2
param vmSize string = 'Standard_B2s'

// Get existing VNet
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: 'fb-dev-ygfwoi-vnet'
}

// Get existing ACR
resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' existing = {
  name: 'fbdevygfwoiacr'
}

// AKS Cluster
resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-02-01' = {
  name: aksClusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: aksClusterName
    enableRBAC: true
    agentPoolProfiles: [
      {
        name: 'nodepool1'
        count: nodeCount
        vmSize: vmSize
        osType: 'Linux'
        mode: 'System'
        vnetSubnetID: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'aks-subnet')
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
      serviceCidr: '172.16.0.0/16'
      dnsServiceIP: '172.16.0.10'
    }
  }
}

// Role assignment for ACR access
resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, aksCluster.id, 'acrpull')
  scope: acr
  properties: {
    principalId: aksCluster.properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
  }
}

output aksName string = aksCluster.name
output aksFqdn string = aksCluster.properties.fqdn