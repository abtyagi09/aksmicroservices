# 🚀 GitHub Actions Secrets Configuration

## Required Repository Secrets for aksmicroservices

Go to: **https://github.com/abtyagi09/aksmicroservices/settings/secrets/actions**

Click "New repository secret" and add these three secrets:

### 1. AZURE_CREDENTIALS
Run this command to create the service principal and copy the output:
```bash
az ad sp create-for-rbac --name "farmersbank-github-actions" \
  --role contributor \
  --scopes /subscriptions/{your-subscription-id}/resourceGroups/farmersbank-microservices-dev \
  --sdk-auth
```

### 2. ACR_USERNAME and ACR_PASSWORD  
Run this command to get ACR credentials:
```bash
az acr credential show --name fbdevygfwoiacr
```
- Copy the `username` value to **ACR_USERNAME** secret
- Copy one of the `passwords[].value` to **ACR_PASSWORD** secret

## ✅ Quick Setup Steps

1. **Go to GitHub Repository Secrets**
   - https://github.com/abtyagi09/aksmicroservices/settings/secrets/actions

2. **Get your credentials using Azure CLI** and add them as repository secrets:
   
   For AZURE_CREDENTIALS:
   ```bash
   az ad sp create-for-rbac --name "farmersbank-github-actions" \
     --role contributor \
     --scopes /subscriptions/{your-subscription-id}/resourceGroups/farmersbank-microservices-dev \
     --sdk-auth
   ```
   
   For ACR credentials:
   ```bash
   az acr credential show --name fbdevygfwoiacr
   ```

3. **Push code to repository** (we'll do this next)

4. **GitHub Actions will automatically deploy!** 🎉

## 🔐 Security Notes

- These credentials are only for the development environment
- The service principal has contributor access only to the `farmersbank-microservices-dev` resource group
- ACR credentials are admin-level but scoped to the container registry only
- All secrets are encrypted in GitHub

## 🚀 What Happens Next

Once secrets are configured and code is pushed:

1. **Build & Test**: All .NET services compile and test
2. **Container Images**: Build and push to ACR with commit SHA tags
3. **Security Scan**: Trivy scans for vulnerabilities
4. **Deploy to AKS**: All 4 services deployed to isolated namespaces
5. **Health Checks**: Automated validation of all endpoints

## 📊 Monitoring After Deployment

Check your deployments:
```bash
# Get service status
kubectl get services --all-namespaces

# Get pod status  
kubectl get pods --all-namespaces

# Check logs
kubectl logs -n member-services deployment/memberservices-service
```

## 🌐 Your Current Infrastructure

| Component | Details |
|-----------|---------|
| **Resource Group** | farmersbank-microservices-dev |
| **AKS Cluster** | farmersbank-aks |
| **Container Registry** | fbdevygfwoiacr.azurecr.io |
| **Region** | East US 2 |
| **Current Services** | member-services, fraud-risk, loans-underwriting, payments |

## 🎯 Ready to Deploy!

Your infrastructure is ready and secrets are configured. 
Next step: Push the code to GitHub! 🚀