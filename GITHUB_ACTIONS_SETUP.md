# GitHub Actions CI/CD Setup

## Overview
This repository includes a comprehensive CI/CD pipeline for the Farmers Bank Microservices solution using GitHub Actions.

## Prerequisites

### 1. Azure Service Principal
Create an Azure Service Principal with the necessary permissions:

```bash
# Create service principal
az ad sp create-for-rbac --name "farmersbank-github-actions" \
  --role contributor \
  --scopes /subscriptions/{subscription-id}/resourceGroups/farmersbank-microservices-dev \
  --sdk-auth

# Grant ACR push permissions
az role assignment create \
  --assignee {service-principal-id} \
  --role AcrPush \
  --scope /subscriptions/{subscription-id}/resourceGroups/farmersbank-microservices-dev/providers/Microsoft.ContainerRegistry/registries/fbdevygfwoiacr
```

### 2. GitHub Repository Secrets
Add the following secrets to your GitHub repository (`Settings > Secrets and variables > Actions`):

#### Required Secrets:
- **AZURE_CREDENTIALS**: Output from the `az ad sp create-for-rbac` command above
  ```json
  {
    "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "clientSecret": "your-client-secret",
    "subscriptionId": "your-subscription-id",
    "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  }
  ```

## Pipeline Overview

The CI/CD pipeline consists of the following jobs:

### 1. **Build and Test**
- Compiles the .NET 8 solution
- Runs unit tests
- Generates code coverage reports

### 2. **Build Images**
- Builds Docker images for all microservices
- Pushes images to Azure Container Registry
- Tags images with commit SHA and latest

### 3. **Integration Tests**
- Runs integration tests with SQL Server
- Validates service functionality

### 4. **Security Scan**
- Scans container images for vulnerabilities using Trivy
- Uploads security findings to GitHub Security tab

### 5. **Deploy to Development**
- Deploys all services to AKS cluster
- Creates isolated namespaces for each service
- Runs smoke tests to validate deployment

## Microservices Architecture

The pipeline deploys four microservices:

| Service | Namespace | Description |
|---------|-----------|-------------|
| Member Services | `member-services` | Customer management and authentication |
| Loans Underwriting | `loans-underwriting` | Loan application processing |
| Payments | `payments` | Payment processing and transactions |
| Fraud Risk | `fraud-risk` | Fraud detection and risk assessment |

## Deployment Strategy

### Namespace Isolation
Each microservice is deployed to its own Kubernetes namespace to provide:
- Resource isolation
- Network policy enforcement
- Independent scaling and updates

### Service Architecture
- **LoadBalancer Services**: Each service exposes external endpoints
- **Health Checks**: All services include health endpoints
- **Resource Limits**: CPU and memory limits configured for each service

## Triggering Deployments

### Automatic Triggers
- **Push to main**: Triggers full CI/CD pipeline
- **Push to develop**: Runs build and test only
- **Pull Request**: Runs build, test, and security scans

### Manual Triggers
Use the GitHub Actions "Run workflow" button with options:
- **Environment**: Choose deployment target (dev/staging/prod)
- **Services**: Deploy all services or specific ones

## Monitoring and Troubleshooting

### Checking Deployment Status
```bash
# Get all services
kubectl get services --all-namespaces

# Check pod status
kubectl get pods --all-namespaces

# View service logs
kubectl logs -n member-services deployment/memberservices-service
```

### Health Check Endpoints
Each service exposes a health endpoint:
- Member Services: `http://{external-ip}/health`
- Loans Underwriting: `http://{external-ip}/health`
- Payments: `http://{external-ip}/health`
- Fraud Risk: `http://{external-ip}/health`

### API Endpoints
Business logic endpoints:
- Member Services: `http://{external-ip}/api/Members`
- Loans Underwriting: `http://{external-ip}/api/LoanApplications`
- Payments: `http://{external-ip}/api/Payments`
- Fraud Risk: `http://{external-ip}/api/FraudAlerts`

## Security Features

### Container Security
- Trivy vulnerability scanning for all images
- SARIF reports uploaded to GitHub Security tab
- Fail on HIGH and CRITICAL vulnerabilities

### Access Control
- Azure RBAC for resource access
- Kubernetes namespace isolation
- Network policies for inter-service communication

### Compliance
- PCI DSS compliance ready
- SOX compliance controls
- Audit logging enabled

## Environments

### Development Environment
- **Resource Group**: `farmersbank-microservices-dev`
- **AKS Cluster**: `farmersbank-aks`
- **ACR**: `fbdevygfwoiacr.azurecr.io`
- **Region**: `East US 2`

### Future Environments
The pipeline is designed to support:
- **Staging**: For pre-production testing
- **Production**: Blue-green deployment strategy

## File Structure

```
.github/
├── workflows/
│   └── ci-cd.yml                 # Main CI/CD pipeline
└── copilot-instructions.md       # Project documentation

scripts/
├── smoke-tests.sh               # Service health validation
└── blue-green-deploy.sh         # Blue-green deployment script

k8s/
├── memberservices/
│   └── deployment.yaml          # Member Services deployment
├── loansunderwriting/
│   └── deployment.yaml          # Loans deployment
├── payments/
│   └── deployment.yaml          # Payments deployment
└── fraudrisk/
    └── deployment.yaml          # Fraud Risk deployment
```

## Next Steps

1. **Set up GitHub Secrets** as described above
2. **Push code to GitHub** repository
3. **Create environments** in GitHub (Settings > Environments)
4. **Configure branch protection** for main branch
5. **Set up notifications** for deployment status

## Support

For issues with the CI/CD pipeline:
1. Check GitHub Actions logs for detailed error messages
2. Verify Azure credentials and permissions
3. Ensure AKS cluster is accessible
4. Check ACR authentication

## Best Practices

- **Git Flow**: Use feature branches and pull requests
- **Testing**: All changes should include appropriate tests
- **Security**: Regularly update dependencies and base images
- **Monitoring**: Monitor deployment metrics and service health