@description('Azure Redis Cache deployment for Scout v7')

// Parameters
@description('Redis Cache name')
param redisCacheName string

@description('Azure region')
param location string

@description('Resource tags')
param tags object

@description('Environment name')
param environment string

@description('Redis SKU name')
@allowed(['Basic', 'Standard', 'Premium'])
param skuName string

@description('Key Vault resource ID for storing connection strings')
param keyVaultResourceId string

// Variables
var redisConfig = skuName == 'Premium' ? {
  family: 'P'
  capacity: environment == 'prod' ? 2 : 1
  enableNonSslPort: false
  redisConfiguration: {
    'maxmemory-policy': 'allkeys-lru'
    'maxmemory-reserved': '50'
    'maxfragmentationmemory-reserved': '50'
    'notify-keyspace-events': 'Ex'
  }
  tenantSettings: {}
  shardCount: environment == 'prod' ? 2 : 1
  subnetId: '' // Will be set if VNet is deployed
  zones: environment == 'prod' ? ['1', '2'] : []
} : skuName == 'Standard' ? {
  family: 'C'
  capacity: environment == 'prod' ? 2 : 1
  enableNonSslPort: false
  redisConfiguration: {
    'maxmemory-policy': 'allkeys-lru'
    'notify-keyspace-events': 'Ex'
  }
  tenantSettings: {}
} : {
  family: 'C'
  capacity: 0
  enableNonSslPort: false
  redisConfiguration: {
    'maxmemory-policy': 'allkeys-lru'
  }
  tenantSettings: {}
}

// Redis Cache
resource redisCache 'Microsoft.Cache/redis@2023-08-01' = {
  name: redisCacheName
  location: location
  tags: tags
  properties: {
    sku: {
      name: skuName
      family: redisConfig.family
      capacity: redisConfig.capacity
    }
    enableNonSslPort: redisConfig.enableNonSslPort
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    redisConfiguration: redisConfig.redisConfiguration
    tenantSettings: redisConfig.tenantSettings
    shardCount: skuName == 'Premium' ? redisConfig.shardCount : null
    subnetId: skuName == 'Premium' && redisConfig.subnetId != '' ? redisConfig.subnetId : null
    zones: skuName == 'Premium' ? redisConfig.zones : null
    redisVersion: '6'
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Private Endpoint for Premium tier in production
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = if (skuName == 'Premium' && environment == 'prod') {
  name: '${redisCacheName}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: '' // Will be set if VNet is deployed
    }
    privateLinkServiceConnections: [
      {
        name: '${redisCacheName}-pe-connection'
        properties: {
          privateLinkServiceId: redisCache.id
          groupIds: [
            'redisCache'
          ]
        }
      }
    ]
  }
}

// Firewall Rules for Standard/Basic tiers
resource firewallRule 'Microsoft.Cache/redis/firewallRules@2023-08-01' = if (skuName != 'Premium') {
  parent: redisCache
  name: 'AllowAzureServices'
  properties: {
    startIP: '0.0.0.0'
    endIP: '0.0.0.0'
  }
}

// Access Policy for managed identity access
resource accessPolicy 'Microsoft.Cache/redis/accessPolicies@2023-08-01' = {
  parent: redisCache
  name: 'scout-app-access'
  properties: {
    accessPolicyName: 'scout-app-access'
    permissions: '+@all +info +client-list +config-get +hello +ping +echo +monitor +command'
    principalId: '' // Will be set to App Service managed identity
    principalIdDisplayName: 'Scout App Service'
    principalType: 'ServicePrincipal'
  }
}

// Diagnostic Settings
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: redisCache
  name: '${redisCacheName}-diagnostics'
  properties: {
    workspaceId: '' // Will be set if Log Analytics workspace is provided
    logs: [
      {
        category: 'ConnectedClientList'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
    ]
  }
}

// Backup Configuration for Premium tier
resource redisPatchSchedule 'Microsoft.Cache/redis/patchSchedules@2023-08-01' = if (skuName == 'Premium') {
  parent: redisCache
  name: 'default'
  properties: {
    scheduleEntries: [
      {
        dayOfWeek: 'Sunday'
        startHourUtc: 2
        maintenanceWindow: 'PT5H'
      }
    ]
  }
}

// Data persistence for Premium tier
resource redisPersistence 'Microsoft.Cache/redis@2023-08-01' = if (skuName == 'Premium' && environment == 'prod') {
  name: redisCacheName
  location: location
  tags: tags
  properties: {
    sku: {
      name: skuName
      family: redisConfig.family
      capacity: redisConfig.capacity
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    redisConfiguration: union(redisConfig.redisConfiguration, {
      'rdb-backup-enabled': 'true'
      'rdb-backup-frequency': '60'
      'rdb-backup-max-snapshot-count': '1'
      'rdb-storage-connection-string': '' // Will be set to storage account connection string
    })
  }
  dependsOn: [
    redisCache
  ]
}

// Store Redis connection strings in Key Vault
module redisConnectionStringSecret 'keyvault-secret.bicep' = {
  name: 'redisConnectionStringSecret'
  params: {
    keyVaultName: last(split(keyVaultResourceId, '/'))
    secretName: 'scout-redis-connection-string'
    secretValue: '${redisCache.properties.hostName}:${redisCache.properties.sslPort},password=${redisCache.listKeys().primaryKey},ssl=True,abortConnect=False'
  }
}

module redisPasswordSecret 'keyvault-secret.bicep' = {
  name: 'redisPasswordSecret'
  params: {
    keyVaultName: last(split(keyVaultResourceId, '/'))
    secretName: 'scout-redis-password'
    secretValue: redisCache.listKeys().primaryKey
  }
}

// Outputs
@description('Redis Cache resource ID')
output redisCacheId string = redisCache.id

@description('Redis Cache name')
output redisCacheName string = redisCache.name

@description('Redis Cache hostname')
output redisHostname string = redisCache.properties.hostName

@description('Redis Cache port')
output redisPort int = redisCache.properties.port

@description('Redis Cache SSL port')
output redisSslPort int = redisCache.properties.sslPort

@description('Redis Cache primary key')
output redisPrimaryKey string = redisCache.listKeys().primaryKey

@description('Redis Cache connection string')
output connectionString string = '${redisCache.properties.hostName}:${redisCache.properties.sslPort},password=${redisCache.listKeys().primaryKey},ssl=True,abortConnect=False'

@description('Redis Cache managed identity principal ID')
output redisPrincipalId string = redisCache.identity.principalId

@description('Redis Cache configuration summary')
output configurationSummary object = {
  sku: skuName
  family: redisConfig.family
  capacity: redisConfig.capacity
  tlsVersion: '1.2'
  nonSslPort: redisConfig.enableNonSslPort
  maxMemoryPolicy: redisConfig.redisConfiguration['maxmemory-policy']
  persistence: skuName == 'Premium' && environment == 'prod'
  clustering: skuName == 'Premium' && redisConfig.shardCount > 1
  privateEndpoint: skuName == 'Premium' && environment == 'prod'
}