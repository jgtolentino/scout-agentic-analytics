@description('Azure Key Vault deployment for Scout v7')

// Parameters
@description('Key Vault name')
param keyVaultName string

@description('Azure region')
param location string

@description('Resource tags')
param tags object

@description('Environment name')
param environment string

@description('Azure AD tenant ID')
param tenantId string

@description('Object IDs that should have access to Key Vault')
param objectIds array = []

// Variables
var keyVaultSku = environment == 'prod' ? 'premium' : 'standard'
var enablePurgeProtection = environment == 'prod'
var enableSoftDelete = true
var softDeleteRetentionInDays = environment == 'prod' ? 90 : 7

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: keyVaultSku
    }
    tenantId: tenantId
    enablePurgeProtection: enablePurgeProtection
    enableSoftDelete: enableSoftDelete
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enableRbacAuthorization: true
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
      ipRules: []
      virtualNetworkRules: []
    }
    accessPolicies: []
  }
}

// Private Endpoint for Production
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = if (environment == 'prod') {
  name: '${keyVaultName}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: '' // Will be set if VNet is deployed
    }
    privateLinkServiceConnections: [
      {
        name: '${keyVaultName}-pe-connection'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

// Diagnostic Settings
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: keyVault
  name: '${keyVaultName}-diagnostics'
  properties: {
    workspaceId: '' // Will be set if Log Analytics workspace is provided
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 365 : 90
        }
      }
      {
        category: 'AzurePolicyEvaluationDetails'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 365 : 90
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 365 : 90
        }
      }
    ]
  }
}

// Default secrets for Scout v7
resource jwtSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'scout-jwt-secret'
  properties: {
    value: base64(guid())
    attributes: {
      enabled: true
    }
    contentType: 'text/plain'
  }
}

resource apiKey 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'scout-api-key'
  properties: {
    value: base64(guid())
    attributes: {
      enabled: true
    }
    contentType: 'text/plain'
  }
}

// Placeholder secrets (will be updated by deployment process)
resource sqlPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'scout-sql-password'
  properties: {
    value: 'placeholder'
    attributes: {
      enabled: true
    }
    contentType: 'text/plain'
  }
}

resource redisPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'scout-redis-password'
  properties: {
    value: 'placeholder'
    attributes: {
      enabled: true
    }
    contentType: 'text/plain'
  }
}

resource storageConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'scout-storage-connection-string'
  properties: {
    value: 'placeholder'
    attributes: {
      enabled: true
    }
    contentType: 'text/plain'
  }
}

// External service API keys (to be updated manually)
resource openaiApiKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'scout-openai-api-key'
  properties: {
    value: 'placeholder'
    attributes: {
      enabled: true
    }
    contentType: 'text/plain'
  }
}

resource anthropicApiKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'scout-anthropic-api-key'
  properties: {
    value: 'placeholder'
    attributes: {
      enabled: true
    }
    contentType: 'text/plain'
  }
}

resource sendgridApiKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'scout-sendgrid-api-key'
  properties: {
    value: 'placeholder'
    attributes: {
      enabled: true
    }
    contentType: 'text/plain'
  }
}

resource slackWebhookSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'scout-slack-webhook-url'
  properties: {
    value: 'placeholder'
    attributes: {
      enabled: true
    }
    contentType: 'text/plain'
  }
}

// Azure AD configuration secrets
resource azureAdClientSecretSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'scout-azure-ad-client-secret'
  properties: {
    value: 'placeholder'
    attributes: {
      enabled: true
    }
    contentType: 'text/plain'
  }
}

// Role assignments for Key Vault access
resource keyVaultSecretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for objectId in objectIds: {
  scope: keyVault
  name: guid(keyVault.id, objectId, 'Key Vault Secrets User')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: objectId
    principalType: 'ServicePrincipal'
  }
}]

// Outputs
@description('Key Vault resource ID')
output keyVaultId string = keyVault.id

@description('Key Vault name')
output keyVaultName string = keyVault.name

@description('Key Vault URI')
output keyVaultUri string = keyVault.properties.vaultUri

@description('Key Vault resource group')
output keyVaultResourceGroup string = resourceGroup().name

@description('Created secrets')
output secrets array = [
  'scout-jwt-secret'
  'scout-api-key'
  'scout-sql-password'
  'scout-redis-password'
  'scout-storage-connection-string'
  'scout-openai-api-key'
  'scout-anthropic-api-key'
  'scout-sendgrid-api-key'
  'scout-slack-webhook-url'
  'scout-azure-ad-client-secret'
]