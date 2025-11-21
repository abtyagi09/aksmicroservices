# Farmers Bank Microservices - Azure Deployment Guide

This guide provides step-by-step instructions for deploying the complete Farmers Bank microservices solution to Azure.

## 🚀 Quick Start

### Prerequisites

1. **Azure CLI** - [Install Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
2. **Docker Desktop** - [Install Docker](https://www.docker.com/products/docker-desktop)
3. **kubectl** - Will be installed automatically during deployment
4. **PowerShell 5.1+** - Required for deployment scripts
5. **Azure Subscription** with appropriate permissions

### Required Azure Permissions

Your Azure account needs the following roles:
- `Contributor` or `Owner` on the target subscription
- `User Access Administrator` for role assignments (if using managed identities)

## 📋 Pre-Deployment Checklist

- [ ] Azure subscription is active and accessible
- [ ] Resource group name is available
- [ ] SQL Admin password meets complexity requirements
- [ ] Docker is running locally
- [ ] Azure CLI is logged in (`az login`)

## 🎯 One-Command Deployment

For a complete automated deployment, run:

```powershell
# Navigate to the project root
cd c:\agents\FMBservcs

# Run complete deployment
.\scripts\Deploy-To-Azure.ps1 `
    -SubscriptionId "your-subscription-id" `
    -ResourceGroupName "farmersbank-microservices-rg" `
    -Environment "dev" `
    -Location "East US" `
    -SqlAdminPassword (ConvertTo-SecureString "YourStrongPassword123!" -AsPlainText -Force)
```

### Deployment Parameters

| Parameter | Required | Description | Example |
|-----------|----------|-------------|---------|
| `SubscriptionId` | Yes | Your Azure subscription ID | `12345678-1234-1234-1234-123456789012` |
| `ResourceGroupName` | Yes | Name for the resource group | `farmersbank-microservices-rg` |
| `Environment` | No | Deployment environment | `dev`, `staging`, `prod` (default: `dev`) |
| `Location` | No | Azure region | `East US` (default) |
| `SqlAdminPassword` | Yes | SQL admin password | Must meet complexity requirements |

### Optional Switches

- `-SkipInfrastructure` - Skip infrastructure deployment (if already deployed)
- `-SkipApplications` - Skip application deployment
- `-SkipMonitoring` - Skip monitoring setup

## 🔧 Step-by-Step Deployment

If you prefer to deploy components individually:

### 1. Infrastructure Deployment

Deploy Azure resources using Bicep templates:

```powershell
# Deploy infrastructure only
.\scripts\Deploy-To-Azure.ps1 `
    -SubscriptionId "your-subscription-id" `
    -ResourceGroupName "farmersbank-microservices-rg" `
    -SqlAdminPassword (ConvertTo-SecureString "YourStrongPassword123!" -AsPlainText -Force) `
    -SkipApplications `
    -SkipMonitoring
```

**Resources Created:**
- Virtual Network with multiple subnets
- Azure Kubernetes Service (AKS)
- Azure SQL Managed Instance
- Azure Container Registry
- Azure Key Vault
- Azure Service Bus
- Azure API Management
- Azure Storage Account
- Application Insights
- Log Analytics Workspace

### 2. Application Deployment

Build and deploy microservices:

```powershell
# Deploy applications only (after infrastructure is ready)
.\scripts\Deploy-To-Azure.ps1 `
    -SubscriptionId "your-subscription-id" `
    -ResourceGroupName "farmersbank-microservices-rg" `
    -SqlAdminPassword (ConvertTo-SecureString "YourStrongPassword123!" -AsPlainText -Force) `
    -SkipInfrastructure `
    -SkipMonitoring
```

**Services Deployed:**
- Member Services API
- Loans & Underwriting API
- Payments API
- Fraud/Risk API

### 3. Monitoring Setup

Configure comprehensive monitoring:

```powershell
# Setup monitoring only
.\scripts\Setup-Monitoring.ps1 `
    -SubscriptionId "your-subscription-id" `
    -ResourceGroupName "farmersbank-microservices-rg" `
    -Environment "dev"
```

## 🔍 Verification Steps

After deployment, verify everything is working:

### 1. Check Infrastructure

```bash
# Verify resource group
az group show --name farmersbank-microservices-rg

# Check AKS cluster
az aks show --resource-group farmersbank-microservices-rg --name fb-dev-xxxxxx-aks

# Verify SQL Managed Instance
az sql mi show --resource-group farmersbank-microservices-rg --name fb-dev-xxxxxx-sqlmi
```

### 2. Verify Kubernetes Deployment

```bash
# Get AKS credentials
az aks get-credentials --resource-group farmersbank-microservices-rg --name fb-dev-xxxxxx-aks

# Check pods
kubectl get pods --namespace=farmersbank

# Check services
kubectl get services --namespace=farmersbank

# View deployment status
kubectl get deployments --namespace=farmersbank
```

### 3. Test Application Health

```bash
# Port forward to test services locally
kubectl port-forward service/memberservices-service 8080:80 --namespace=farmersbank

# Test health endpoint (in another terminal)
curl http://localhost:8080/health
```

### 4. Verify Monitoring

```bash
# Check Application Insights
az monitor app-insights component show --app fb-dev-xxxxxx-ai --resource-group farmersbank-microservices-rg

# View alert rules
az monitor metrics alert list --resource-group farmersbank-microservices-rg
```

## 🔧 Configuration Updates

After deployment, update configuration as needed:

### Update Application Settings

1. Navigate to Azure Key Vault in the portal
2. Update connection strings and secrets
3. Restart pods to pick up new settings:

```bash
kubectl rollout restart deployment/memberservices-deployment --namespace=farmersbank
```

### Scale Services

```bash
# Scale a service
kubectl scale deployment memberservices-deployment --replicas=5 --namespace=farmersbank

# Enable autoscaling
kubectl autoscale deployment memberservices-deployment --cpu-percent=70 --min=3 --max=10 --namespace=farmersbank
```

## 🗄️ Database Setup

### Run Entity Framework Migrations

```bash
# Get a running pod
POD_NAME=$(kubectl get pods --namespace=farmersbank --selector=app=memberservices --output=jsonpath='{.items[0].metadata.name}')

# Run migrations for each service
kubectl exec $POD_NAME --namespace=farmersbank -- dotnet ef database update --project MemberServices.Infrastructure --startup-project MemberServices.API
```

### Seed Initial Data

Connect to SQL Managed Instance and run initial data scripts if needed.

## 🔒 Security Configuration

### Configure Azure AD Authentication

1. Register applications in Azure AD
2. Update appsettings with client IDs
3. Configure redirect URIs

### Network Security

```bash
# Verify network policies
kubectl get networkpolicies --namespace=farmersbank

# Check security groups
az network nsg list --resource-group farmersbank-microservices-rg
```

## 📊 Monitoring and Observability

### Access Application Insights

1. Navigate to Azure Portal
2. Go to Application Insights resource
3. View Live Metrics, Logs, and Performance

### Custom Dashboards

Import the custom dashboard template:
1. Open Azure Portal
2. Navigate to Dashboards
3. Import `infrastructure/monitoring/dashboard-config.json`

### Set Up Alerts

Alerts are automatically configured for:
- Response time > 200ms
- Availability < 99%
- Exception rate > 5%
- Critical errors in logs

## 🚨 Troubleshooting

### Common Issues

#### 1. Pod Startup Failures

```bash
# Check pod logs
kubectl logs deployment/memberservices-deployment --namespace=farmersbank

# Describe pod for events
kubectl describe pod <pod-name> --namespace=farmersbank
```

#### 2. Database Connection Issues

- Verify SQL Managed Instance is running
- Check connection strings in Key Vault
- Ensure network connectivity between AKS and SQL MI

#### 3. Container Registry Access

```bash
# Check ACR access
az acr check-health --name fb-dev-xxxxxx-acr

# Verify AKS has pull access
az role assignment list --assignee <aks-identity> --scope /subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.ContainerRegistry/registries/<acr-name>
```

#### 4. Monitoring Not Working

- Verify Application Insights connection string
- Check if telemetry is being sent
- Review monitoring setup script output

### Debug Commands

```bash
# View all resources in resource group
az resource list --resource-group farmersbank-microservices-rg --output table

# Check AKS node status
kubectl get nodes

# View service endpoints
kubectl get endpoints --namespace=farmersbank

# Check persistent volumes
kubectl get pv,pvc --namespace=farmersbank

# View secrets
kubectl get secrets --namespace=farmersbank
```

## 🔄 Updates and Maintenance

### Update Application Code

1. Build new container images
2. Push to Azure Container Registry
3. Update Kubernetes deployments:

```bash
kubectl set image deployment/memberservices-deployment memberservices=fb-dev-xxxxxx-acr.azurecr.io/farmersbank/memberservices:new-tag --namespace=farmersbank
```

### Infrastructure Updates

```bash
# Update infrastructure
az deployment group create --resource-group farmersbank-microservices-rg --template-file infrastructure/bicep/main.bicep --parameters infrastructure/bicep/main.parameters.json
```

## 🆘 Support and Documentation

### Useful Resources

- [Azure Kubernetes Service Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [Azure SQL Managed Instance Documentation](https://docs.microsoft.com/en-us/azure/azure-sql/managed-instance/)
- [Application Insights Documentation](https://docs.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview)

### Log Locations

- **Application Logs**: Application Insights / Log Analytics
- **Infrastructure Logs**: Azure Activity Log
- **Kubernetes Logs**: `kubectl logs` command
- **Deployment Logs**: Script output and Azure deployment history

### Contact Information

- **DevOps Team**: devops@farmersbank.com
- **Security Team**: security@farmersbank.com
- **Operations Team**: operations@farmersbank.com

---

## 📝 Deployment Checklist

- [ ] Prerequisites installed and configured
- [ ] Azure subscription and permissions verified
- [ ] Resource group name decided
- [ ] SQL admin password prepared
- [ ] Infrastructure deployed successfully
- [ ] Container images built and pushed
- [ ] Kubernetes applications deployed
- [ ] Database migrations completed
- [ ] Monitoring configured
- [ ] Health checks passed
- [ ] Security configurations validated
- [ ] Documentation updated
- [ ] Team notifications sent

🎉 **Congratulations!** Your Farmers Bank microservices solution is now running in Azure!