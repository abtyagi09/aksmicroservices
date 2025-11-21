targetScope = 'resourceGroup'

@description('Environment name (dev, test, prod)')
@allowed(['dev', 'test', 'prod'])
param environment string = 'dev'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Unique suffix for resource names')
param uniqueSuffix string = substring(uniqueString(resourceGroup().id), 0, 6)

@description('Administrator username for SQL Managed Instance')
param sqlAdminUsername string

@description('Administrator password for SQL Managed Instance')
@secure()
param sqlAdminPassword string



@description('API Management publisher email')
param apimPublisherEmail string

@description('API Management publisher name')
param apimPublisherName string

// Variables
var resourcePrefix = 'fb-${environment}-${uniqueSuffix}'
var vnetName = '${resourcePrefix}-vnet'
var aksName = '${resourcePrefix}-aks'
var sqlMiName = '${resourcePrefix}-sqlmi'
var acrName = replace('${resourcePrefix}acr', '-', '')
var keyVaultName = '${resourcePrefix}-kv'
var appInsightsName = '${resourcePrefix}-ai'
var logAnalyticsName = '${resourcePrefix}-la'
var apimName = '${resourcePrefix}-apim'
var serviceBusName = replace('${resourcePrefix}-sb', '-', '')
var storageAccountName = replace('${resourcePrefix}st', '-', '')

// Virtual Network
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-09-01' = {
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
        name: 'aks-subnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
          serviceEndpoints: [
            {
              service: 'Microsoft.Sql'
            }
            {
              service: 'Microsoft.Storage'
            }
            {
              service: 'Microsoft.KeyVault'
            }
          ]
        }
      }
      {
        name: 'sqlmi-subnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
          delegations: [
            {
              name: 'Microsoft.Sql.managedInstances'
              properties: {
                serviceName: 'Microsoft.Sql/managedInstances'
              }
            }
          ]
        }
      }
      {
        name: 'apim-subnet'
        properties: {
          addressPrefix: '10.0.3.0/24'
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
            {
              service: 'Microsoft.Sql'
            }
          ]
        }
      }
      {
        name: 'private-endpoints-subnet'
        properties: {
          addressPrefix: '10.0.4.0/24'
          privateLinkServiceNetworkPolicies: 'Disabled'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

// Network Security Groups
resource aksNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${resourcePrefix}-aks-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPS'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '443'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowHTTP'
        properties: {
          priority: 110
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '80'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          access: 'Deny'
          direction: 'Inbound'
          destinationPortRange: '*'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// Log Analytics Workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 90
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Azure Container Registry
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: true
    networkRuleSet: {
      defaultAction: 'Allow'
    }
    policies: {
      quarantinePolicy: {
        status: 'enabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'enabled'
      }
      retentionPolicy: {
        days: 30
        status: 'enabled'
      }
    }
    encryption: {
      status: 'disabled'
    }
    dataEndpointEnabled: false
    publicNetworkAccess: 'Enabled'
    zoneRedundancy: 'Enabled'
  }
}

// Azure Kubernetes Service
resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-02-01' = {
  name: aksName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: '${resourcePrefix}-aks'
    agentPoolProfiles: [
      {
        name: 'systemnp'
        count: 3
        vmSize: 'Standard_D4s_v3'
        osType: 'Linux'
        mode: 'System'
        vnetSubnetID: virtualNetwork.properties.subnets[0].id
        enableAutoScaling: true
        minCount: 3
        maxCount: 10
        nodeTaints: [
          'CriticalAddonsOnly=true:NoSchedule'
        ]
      }
      {
        name: 'workernp'
        count: 3
        vmSize: 'Standard_D8s_v3'
        osType: 'Linux'
        mode: 'User'
        vnetSubnetID: virtualNetwork.properties.subnets[0].id
        enableAutoScaling: true
        minCount: 3
        maxCount: 20
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      serviceCidr: '10.10.0.0/16'
      dnsServiceIP: '10.10.0.10'
    }
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalytics.id
        }
      }
      azurepolicy: {
        enabled: true
      }
      azureKeyvaultSecretsProvider: {
        enabled: true
        config: {
          enableSecretRotation: 'true'
          rotationPollInterval: '2m'
        }
      }
    }
    autoScalerProfile: {
      'balance-similar-node-groups': 'false'
      expander: 'random'
      'max-empty-bulk-delete': '10'
      'max-graceful-termination-sec': '600'
      'max-node-provision-time': '15m'
      'max-total-unready-percentage': '45'
      'new-pod-scale-up-delay': '0s'
      'ok-total-unready-count': '3'
      'scale-down-delay-after-add': '10m'
      'scale-down-delay-after-delete': '10s'
      'scale-down-delay-after-failure': '3m'
      'scale-down-unneeded-time': '10m'
      'scale-down-unready-time': '20m'
      'scale-down-utilization-threshold': '0.5'
      'scan-interval': '10s'
      'skip-nodes-with-local-storage': 'false'
      'skip-nodes-with-system-pods': 'true'
    }
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }
  }
}

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'premium'
    }
    tenantId: tenant().tenantId
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: [
        {
          id: virtualNetwork.properties.subnets[0].id
          ignoreMissingVnetServiceEndpoint: false
        }
      ]
    }
    accessPolicies: [
      {
        tenantId: tenant().tenantId
        objectId: aksCluster.identity.principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
          certificates: [
            'get'
            'list'
          ]
          keys: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
}

// SQL Managed Instance
resource sqlManagedInstance 'Microsoft.Sql/managedInstances@2023-08-01-preview' = {
  name: sqlMiName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'GP_Gen5'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 8
  }
  properties: {
    subnetId: virtualNetwork.properties.subnets[1].id
    administratorLogin: sqlAdminUsername
    administratorLoginPassword: sqlAdminPassword
    vCores: 8
    storageSizeInGB: 256
    licenseType: 'LicenseIncluded'
    publicDataEndpointEnabled: false
    proxyOverride: 'Proxy'
    timezoneId: 'UTC'
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    minimalTlsVersion: '1.2'
    requestedBackupStorageRedundancy: 'Zone'
    zoneRedundant: true
    maintenanceConfigurationId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Maintenance/publicMaintenanceConfigurations/SQL_Default'
  }
}

// Service Bus Namespace
resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: serviceBusName
  location: location
  sku: {
    name: 'Premium'
    tier: 'Premium'
    capacity: 1
  }
  properties: {
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
    zoneRedundant: true
    encryption: {
      keySource: 'Microsoft.KeyVault'
    }
  }
  
  resource memberQueue 'queues@2022-10-01-preview' = {
    name: 'member-events'
    properties: {
      maxSizeInMegabytes: 1024
      defaultMessageTimeToLive: 'P14D'
      duplicateDetectionHistoryTimeWindow: 'PT10M'
      enableBatchedOperations: true
      deadLetteringOnMessageExpiration: true
      enablePartitioning: false
      requiresDuplicateDetection: true
      supportOrdering: true
    }
  }
  
  resource loanQueue 'queues@2022-10-01-preview' = {
    name: 'loan-events'
    properties: {
      maxSizeInMegabytes: 1024
      defaultMessageTimeToLive: 'P14D'
      duplicateDetectionHistoryTimeWindow: 'PT10M'
      enableBatchedOperations: true
      deadLetteringOnMessageExpiration: true
      enablePartitioning: false
      requiresDuplicateDetection: true
      supportOrdering: true
    }
  }
  
  resource paymentQueue 'queues@2022-10-01-preview' = {
    name: 'payment-events'
    properties: {
      maxSizeInMegabytes: 1024
      defaultMessageTimeToLive: 'P14D'
      duplicateDetectionHistoryTimeWindow: 'PT10M'
      enableBatchedOperations: true
      deadLetteringOnMessageExpiration: true
      enablePartitioning: false
      requiresDuplicateDetection: true
      supportOrdering: true
    }
  }
  
  resource fraudTopic 'topics@2022-10-01-preview' = {
    name: 'fraud-alerts'
    properties: {
      maxSizeInMegabytes: 1024
      defaultMessageTimeToLive: 'P14D'
      duplicateDetectionHistoryTimeWindow: 'PT10M'
      enableBatchedOperations: true
      enablePartitioning: false
      requiresDuplicateDetection: true
      supportOrdering: true
    }
  }
}

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_ZRS'
  }
  kind: 'StorageV2'
  properties: {
    defaultToOAuthAuthentication: false
    allowCrossTenantReplication: false
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: [
        {
          id: virtualNetwork.properties.subnets[0].id
          action: 'Allow'
          state: 'Succeeded'
        }
      ]
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      requireInfrastructureEncryption: true
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
}

// Storage Containers
resource documentContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${storageAccount.name}/default/loan-documents'
  properties: {
    publicAccess: 'None'
    metadata: {}
  }
}

resource backupContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${storageAccount.name}/default/database-backups'
  properties: {
    publicAccess: 'None'
    metadata: {}
  }
}

// API Management
resource apiManagement 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: apimName
  location: location
  sku: {
    name: 'Premium'
    capacity: 2
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Ssl30': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TripleDes168': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'False'
    }
    virtualNetworkType: 'Internal'
    virtualNetworkConfiguration: {
      subnetResourceId: virtualNetwork.properties.subnets[2].id
    }
    apiVersionConstraint: {
      minApiVersion: '2021-08-01'
    }
    restore: false
    developerPortalStatus: 'Enabled'
  }
}

// RBAC Assignments
resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: containerRegistry
  name: guid(containerRegistry.id, aksCluster.id, 'acrpull')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: aksCluster.properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
}

// Key Vault Secrets
resource sqlConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'sql-connection-string'
  properties: {
    value: 'Server=${sqlManagedInstance.properties.fullyQualifiedDomainName},1433;Database=FarmersBank;User Id=${sqlAdminUsername};Password=${sqlAdminPassword};Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

resource serviceBusConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'servicebus-connection-string'
  properties: {
    value: serviceBusNamespace.listKeys().primaryConnectionString
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

resource storageConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'storage-connection-string'
  properties: {
    value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

resource appInsightsKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'appinsights-instrumentation-key'
  properties: {
    value: appInsights.properties.InstrumentationKey
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// Outputs
output resourceGroupName string = resourceGroup().name
output vnetName string = virtualNetwork.name
output aksClusterName string = aksCluster.name
output sqlManagedInstanceName string = sqlManagedInstance.name
output containerRegistryName string = containerRegistry.name
output keyVaultName string = keyVault.name
output apiManagementName string = apiManagement.name
output serviceBusNamespaceName string = serviceBusNamespace.name
output storageAccountName string = storageAccount.name
output appInsightsName string = appInsights.name
output logAnalyticsWorkspaceName string = logAnalytics.name

output aksClusterFqdn string = aksCluster.properties.fqdn
output apiManagementGatewayUrl string = 'https://${apiManagement.properties.gatewayUrl}'
output sqlManagedInstanceFqdn string = sqlManagedInstance.properties.fullyQualifiedDomainName
output containerRegistryLoginServer string = containerRegistry.properties.loginServer