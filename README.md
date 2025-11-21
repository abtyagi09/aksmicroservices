# Farmers Bank Microservices Solution

## Overview
This is a comprehensive .NET 8 microservices solution for Farmers Bank's Government backed loan program, implementing domain-driven design with enterprise-grade Azure cloud infrastructure.

## Architecture

### Core Domains
- **Member Services**: Customer account management and government program eligibility
- **Loans & Underwriting**: Loan application processing and automated underwriting
- **Payments**: Payment processing and transaction management
- **Fraud/Risk**: Real-time fraud detection and risk assessment

### Technology Stack
- **.NET 8**: Modern, cross-platform framework
- **Azure Kubernetes Service (AKS)**: Container orchestration
- **Azure SQL Managed Instance**: Enterprise database platform
- **Azure API Management**: API gateway and security
- **Azure Service Bus**: Message queuing and event-driven architecture
- **Azure Application Insights**: Application monitoring and telemetry
- **Bicep**: Infrastructure as Code

## Project Structure

```
FarmersBank.Microservices/
├── src/
│   ├── Services/
│   │   ├── MemberServices/
│   │   │   ├── MemberServices.API/
│   │   │   ├── MemberServices.Domain/
│   │   │   ├── MemberServices.Application/
│   │   │   └── MemberServices.Infrastructure/
│   │   ├── LoansUnderwriting/
│   │   ├── Payments/
│   │   └── FraudRisk/
│   ├── Shared/
│   │   ├── Common/
│   │   └── Contracts/
│   └── Infrastructure/
│       ├── MessageBus/
│       └── Security/
├── k8s/
│   ├── memberservices/
│   ├── loansunderwriting/
│   ├── payments/
│   ├── fraudrisk/
│   └── shared/
├── infrastructure/
│   ├── bicep/
│   └── templates/
├── scripts/
└── tests/
```

## Key Features

### Enterprise Architecture
- **Domain-Driven Design**: Clean separation of business logic
- **CQRS Pattern**: Command Query Responsibility Segregation
- **Event Sourcing**: Audit trail and state reconstruction
- **Microservices**: Independent, scalable services

### Cloud-Native
- **Azure Kubernetes Service**: High availability and auto-scaling
- **Azure SQL MI**: Enterprise-grade database with 99.99% SLA
- **API Management**: Rate limiting, authentication, and monitoring
- **Service Mesh**: Secure inter-service communication

### Security & Compliance
- **PCI DSS Compliance**: Payment card industry standards
- **SOX Compliance**: Financial reporting controls
- **Data Encryption**: At-rest and in-transit encryption
- **Network Policies**: Kubernetes network segmentation
- **Azure Key Vault**: Secrets and certificate management

### Monitoring & Observability
- **Application Insights**: Real-time application monitoring
- **Azure Monitor**: Infrastructure and platform metrics
- **Structured Logging**: Centralized log management
- **Health Checks**: Proactive system monitoring

## Deployment

### Prerequisites
- Azure CLI 2.50+
- kubectl 1.27+
- Docker Desktop
- .NET 8 SDK
- PowerShell 7+

### Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/farmersbank/microservices.git
   cd microservices
   ```

2. **Deploy infrastructure and applications**
   ```powershell
   ./scripts/Deploy-FarmersBankMicroservices.ps1 `
     -Environment "dev" `
     -ResourceGroupName "farmersbank-dev-rg" `
     -Location "East US 2"
   ```

3. **Verify deployment**
   ```bash
   kubectl get pods -n farmersbank
   kubectl get services -n farmersbank
   ```

### Manual Deployment Steps

#### 1. Infrastructure Deployment
```bash
# Deploy Azure resources
az deployment group create \
  --resource-group farmersbank-dev-rg \
  --template-file infrastructure/bicep/main.bicep \
  --parameters infrastructure/bicep/main.parameters.json
```

#### 2. Container Images
```bash
# Build and push images
az acr login --name farmersbankacr
docker build -t farmersbankacr.azurecr.io/farmersbank/memberservices-api:latest .
docker push farmersbankacr.azurecr.io/farmersbank/memberservices-api:latest
```

#### 3. Kubernetes Deployment
```bash
# Deploy shared resources
kubectl apply -f k8s/shared/base-resources.yaml
kubectl apply -f k8s/shared/network-policies.yaml

# Deploy microservices
kubectl apply -f k8s/memberservices/deployment.yaml
kubectl apply -f k8s/loansunderwriting/deployment.yaml
kubectl apply -f k8s/payments/deployment.yaml
kubectl apply -f k8s/fraudrisk/deployment.yaml
```

## Configuration

### Environment Variables
- `ASPNETCORE_ENVIRONMENT`: Application environment (Development/Production)
- `ConnectionStrings__DefaultConnection`: Azure SQL MI connection string
- `ApplicationInsights__InstrumentationKey`: Application Insights key
- `ServiceBus__ConnectionString`: Azure Service Bus connection string

### Azure Key Vault Secrets
- `sql-connection-string`: Database connection string
- `servicebus-connection-string`: Message bus connection
- `storage-connection-string`: Blob storage connection
- `appinsights-instrumentation-key`: Monitoring key

## API Documentation

### Member Services API
- **Base URL**: `https://api.farmersbank.com/api/members`
- **Authentication**: OAuth 2.0 with scopes: `member.read`, `member.write`
- **Rate Limiting**: 100 requests/minute per IP

### Loans & Underwriting API
- **Base URL**: `https://api.farmersbank.com/api/loans`
- **Authentication**: OAuth 2.0 with scopes: `loan.read`, `loan.write`, `loan.underwrite`
- **Rate Limiting**: 50 requests/minute per user

### Payments API
- **Base URL**: `https://api.farmersbank.com/api/payments`
- **Authentication**: OAuth 2.0 with scopes: `payment.read`, `payment.write`, `payment.process`
- **Rate Limiting**: 20 requests/minute per user

### Fraud & Risk API
- **Base URL**: `https://api.farmersbank.com/api/fraud-risk`
- **Authentication**: OAuth 2.0 with scopes: `fraud.read`, `fraud.write`, `risk.assess`
- **Rate Limiting**: 1000 requests/minute (internal service)

## Monitoring

### Health Checks
Each service exposes health check endpoints:
- `/health/live`: Liveness probe
- `/health/ready`: Readiness probe
- `/health/startup`: Startup probe

### Metrics
Key performance indicators:
- **Response Time**: < 200ms for 95th percentile
- **Availability**: 99.9% uptime SLA
- **Error Rate**: < 0.1% of requests
- **Throughput**: Support for 10,000 requests/minute

### Alerts
Configured alerts for:
- High error rates (>1%)
- Slow response times (>500ms)
- Resource utilization (>80% CPU/Memory)
- Failed deployments
- Security incidents

## Security

### Network Security
- **Virtual Network**: Isolated network environment
- **Network Security Groups**: Firewall rules
- **Network Policies**: Kubernetes network segmentation
- **Private Endpoints**: Secure Azure service connections

### Application Security
- **HTTPS Only**: TLS 1.3 encryption
- **OAuth 2.0**: Industry standard authentication
- **JWT Tokens**: Stateless authorization
- **Rate Limiting**: DDoS protection
- **Input Validation**: SQL injection prevention

### Data Security
- **Encryption at Rest**: Azure SQL Transparent Data Encryption
- **Encryption in Transit**: TLS encryption
- **Key Management**: Azure Key Vault
- **Data Classification**: PII and sensitive data protection
- **Audit Logging**: Complete audit trail

## Compliance

### PCI DSS Requirements
- ✅ Secure network architecture
- ✅ Data encryption and tokenization
- ✅ Access controls and authentication
- ✅ Network monitoring and testing
- ✅ Security policies and procedures

### SOX Requirements
- ✅ Change management controls
- ✅ Access controls and segregation of duties
- ✅ Data integrity and backup procedures
- ✅ Audit logging and monitoring
- ✅ Business continuity planning

## Business Continuity

### Recovery Objectives
- **RTO (Recovery Time Objective)**: ≤ 2 hours
- **RPO (Recovery Point Objective)**: ≤ 15 minutes
- **SLO (Service Level Objective)**: 99.9% availability

### Backup Strategy
- **Database**: Automated daily backups with 30-day retention
- **Application Data**: Cross-region replication
- **Configuration**: Infrastructure as Code in version control
- **Secrets**: Key Vault backup and recovery

### Disaster Recovery
- **Multi-Region**: Active-passive deployment model
- **Automated Failover**: Health check-based failover
- **Data Synchronization**: Real-time replication
- **Recovery Testing**: Monthly DR drills

## Development

### Local Development Setup
1. Install prerequisites
2. Clone repository
3. Configure local environment variables
4. Run database migrations
5. Start services with `dotnet run`

### Testing
```bash
# Unit tests
dotnet test src/Services/*/Tests/*.UnitTests

# Integration tests
dotnet test src/Services/*/Tests/*.IntegrationTests

# End-to-end tests
dotnet test tests/E2E.Tests
```

### CI/CD Pipeline
- **Build**: Automated on pull requests
- **Test**: Comprehensive test suite
- **Security Scan**: Vulnerability assessment
- **Deploy**: Automated deployment to staging/production

## Support

### Documentation
- [API Reference](docs/api-reference.md)
- [Deployment Guide](docs/deployment.md)
- [Security Guide](docs/security.md)
- [Troubleshooting](docs/troubleshooting.md)

### Contact
- **Development Team**: dev-team@farmersbank.com
- **Operations Team**: ops-team@farmersbank.com
- **Security Team**: security@farmersbank.com
- **Business Team**: business-team@farmersbank.com

## License
© 2025 Farmers Bank. All rights reserved. Proprietary and confidential.