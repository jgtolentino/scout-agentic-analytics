# Secrets & Security Posture

## Storage Locations

* **Local Development**: Bruno Vault (`~/.bruno/vault`) + macOS Keychain
* **Production Runtime**: Azure Key Vault → Function App via Key Vault references
* **CI/CD**: Environment variables from secure CI vault

## Secret Categories

### Database Connections
- **Azure SQL**: Full connection string in macOS Keychain
- **Access Method**: `scripts/conn_default.sh` wrapper
- **Backup**: User/password components in Bruno vault

### API Keys
- **OpenAI**: API key and endpoint in Bruno vault
- **Vercel**: Deployment token in Bruno vault
- **GitHub**: Personal access token in Bruno vault

### Azure Resources
- **Subscription ID**: In Bruno vault and Azure Key Vault
- **Key Vault Access**: Via Azure AD/Managed Identity

## Security Measures

### Encryption at Rest
- macOS Keychain: System-level encryption
- Azure Key Vault: FIPS 140-2 Level 2 HSMs
- Bruno Vault: File system permissions (600)

### Access Control
- Keychain: User-level access only
- Azure Key Vault: RBAC with principle of least privilege
- Bruno Vault: Owner read/write only

### Audit Trail
- Azure Key Vault: Full access logging
- Keychain: System audit logs
- Bruno Vault: File system access logs

## Rotation Schedule

* **Quarterly**: OpenAI API keys, Vercel tokens, GitHub tokens
* **As Needed**: Azure SQL credentials, upon exposure events
* **Emergency**: All credentials within 24 hours of suspected compromise

## Compliance

* **No plaintext storage** in repositories, CI logs, or application settings
* **Secure transmission** only (HTTPS, encrypted channels)
* **Principle of least privilege** for all service accounts
* **Regular auditing** of access patterns and permissions

## Emergency Procedures

1. **Immediate**: Rotate compromised credentials
2. **Assessment**: Review access logs for unauthorized usage
3. **Communication**: Notify relevant teams and stakeholders
4. **Documentation**: Update incident response documentation
5. **Prevention**: Implement additional controls to prevent recurrence

> **Azure-only profile:** This project uses Azure SQL, Azure Functions, Azure AI Search, Azure Key Vault, and Azure OpenAI. No Supabase components are required.