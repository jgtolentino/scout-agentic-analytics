@description('Azure SQL Server and Database deployment')

// Parameters
@description('SQL Server name')
param sqlServerName string

@description('SQL Database name')
param sqlDatabaseName string

@description('Azure region')
param location string

@description('Resource tags')
param tags object

@description('Environment name')
param environment string

@description('SQL Server administrator login')
param administratorLogin string

@description('SQL Server administrator password')
@secure()
param administratorLoginPassword string

@description('Key Vault resource ID for storing connection strings')
param keyVaultResourceId string

// Variables
var firewallRules = [
  {
    name: 'AllowAzureServices'
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
]

var databaseConfig = environment == 'prod' ? {
  tier: 'Standard'
  name: 'S2'
  capacity: 50
  maxSizeBytes: 268435456000 // 250 GB
} : environment == 'staging' ? {
  tier: 'Standard'
  name: 'S1'
  capacity: 20
  maxSizeBytes: 107374182400 // 100 GB
} : {
  tier: 'Basic'
  name: 'Basic'
  capacity: 5
  maxSizeBytes: 2147483648 // 2 GB
}

// SQL Server
resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: sqlServerName
  location: location
  tags: tags
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled' // Will be restricted via firewall rules
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// SQL Database
resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  tags: tags
  sku: {
    tier: databaseConfig.tier
    name: databaseConfig.name
    capacity: databaseConfig.capacity
  }
  properties: {
    maxSizeBytes: databaseConfig.maxSizeBytes
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    zoneRedundant: environment == 'prod'
    readScale: environment == 'prod' ? 'Enabled' : 'Disabled'
    requestedBackupStorageRedundancy: environment == 'prod' ? 'Geo' : 'Local'
    isLedgerOn: false
    availabilityZone: 'NoPreference'
  }
}

// Firewall Rules
resource firewallRule 'Microsoft.Sql/servers/firewallRules@2023-05-01-preview' = [for rule in firewallRules: {
  parent: sqlServer
  name: rule.name
  properties: {
    startIpAddress: rule.startIpAddress
    endIpAddress: rule.endIpAddress
  }
}]

// Azure Active Directory Admin (if needed)
resource sqlServerAadAdmin 'Microsoft.Sql/servers/administrators@2023-05-01-preview' = if (environment == 'prod') {
  parent: sqlServer
  name: 'ActiveDirectory'
  properties: {
    administratorType: 'ActiveDirectory'
    login: 'scout-sql-admins'
    sid: '00000000-0000-0000-0000-000000000000' // Replace with actual AAD group SID
    tenantId: tenant().tenantId
  }
}

// Transparent Data Encryption
resource transparentDataEncryption 'Microsoft.Sql/servers/databases/transparentDataEncryption@2023-05-01-preview' = {
  parent: sqlDatabase
  name: 'current'
  properties: {
    state: 'Enabled'
  }
}

// Auditing
resource sqlServerAuditing 'Microsoft.Sql/servers/auditingSettings@2023-05-01-preview' = {
  parent: sqlServer
  name: 'default'
  properties: {
    state: 'Enabled'
    storageEndpoint: '' // Will be set if storage account is provided
    isStorageSecondaryKeyInUse: false
    isAzureMonitorTargetEnabled: true
    retentionDays: environment == 'prod' ? 90 : 30
  }
}

// Database Auditing
resource sqlDatabaseAuditing 'Microsoft.Sql/servers/databases/auditingSettings@2023-05-01-preview' = {
  parent: sqlDatabase
  name: 'default'
  properties: {
    state: 'Enabled'
    isAzureMonitorTargetEnabled: true
    retentionDays: environment == 'prod' ? 90 : 30
  }
}

// Security Alert Policy
resource securityAlertPolicy 'Microsoft.Sql/servers/securityAlertPolicies@2023-05-01-preview' = {
  parent: sqlServer
  name: 'default'
  properties: {
    state: 'Enabled'
    emailAddresses: [
      'alerts@tbwa.com'
    ]
    emailAccountAdmins: true
    retentionDays: 30
    disabledAlerts: []
  }
}

// Vulnerability Assessment
resource vulnerabilityAssessment 'Microsoft.Sql/servers/vulnerabilityAssessments@2023-05-01-preview' = if (environment == 'prod') {
  parent: sqlServer
  name: 'default'
  properties: {
    storageContainerPath: '' // Will be set if storage account is provided
    recurringScans: {
      isEnabled: true
      emailSubscriptionAdmins: true
      emails: [
        'security@tbwa.com'
      ]
    }
  }
}

// Diagnostic Settings
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: sqlDatabase
  name: '${sqlDatabaseName}-diagnostics'
  properties: {
    workspaceId: '' // Will be set if Log Analytics workspace is provided
    logs: [
      {
        category: 'SQLInsights'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
      {
        category: 'AutomaticTuning'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
      {
        category: 'QueryStoreRuntimeStatistics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
      {
        category: 'QueryStoreWaitStatistics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
      {
        category: 'Errors'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
      {
        category: 'DatabaseWaitStatistics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
      {
        category: 'Timeouts'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
      {
        category: 'Blocks'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
      {
        category: 'Deadlocks'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
    ]
    metrics: [
      {
        category: 'Basic'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
      {
        category: 'InstanceAndAppAdvanced'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
      {
        category: 'WorkloadManagement'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
    ]
  }
}

// Store connection string in Key Vault
module connectionStringSecret 'keyvault-secret.bicep' = {
  name: 'sqlConnectionStringSecret'
  params: {
    keyVaultName: last(split(keyVaultResourceId, '/'))
    secretName: 'scout-sql-connection-string'
    secretValue: 'Server=${sqlServer.properties.fullyQualifiedDomainName};Database=${sqlDatabaseName};User Id=${administratorLogin};Password=${administratorLoginPassword};Encrypt=true;TrustServerCertificate=false;Connection Timeout=30;'
  }
}

// Outputs
@description('SQL Server resource ID')
output sqlServerId string = sqlServer.id

@description('SQL Server FQDN')
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName

@description('SQL Database resource ID')
output sqlDatabaseId string = sqlDatabase.id

@description('SQL Database name')
output sqlDatabaseName string = sqlDatabase.name

@description('SQL Server administrator login')
output administratorLogin string = administratorLogin

@description('Connection string for application configuration')
output connectionString string = 'Server=${sqlServer.properties.fullyQualifiedDomainName};Database=${sqlDatabaseName};Authentication=Active Directory Managed Identity;Encrypt=true;'

@description('SQL Server managed identity principal ID')
output sqlServerPrincipalId string = sqlServer.identity.principalId