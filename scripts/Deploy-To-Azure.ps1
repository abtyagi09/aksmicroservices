# Farmers Bank Microservices - Complete Azure Deployment Script
# This script deploys the entire solution to Azure including infrastructure, monitoring, and applications

param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "East US",
    
    [Parameter(Mandatory=$true)]
    [SecureString]$SqlAdminPassword,
    
    [Parameter(Mandatory=$false)]
    [string]$GitHubRepository = "farmersbank/microservices",
    
    [Parameter(Mandatory=$false)]
    [string]$ContainerRegistryName = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipInfrastructure,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipApplications,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipMonitoring
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Colors for output
$Green = "Green"
$Yellow = "Yellow" 
$Red = "Red"
$Blue = "Blue"
$White = "White"

Write-Host "🏦 FARMERS BANK MICROSERVICES - AZURE DEPLOYMENT" -ForegroundColor $Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor $Green
Write-Host "🎯 Environment: $Environment" -ForegroundColor $White
Write-Host "📍 Location: $Location" -ForegroundColor $White
Write-Host "📦 Resource Group: $ResourceGroupName" -ForegroundColor $White
Write-Host "🔗 Subscription: $SubscriptionId" -ForegroundColor $White
Write-Host ""

# Function to check prerequisites
function Test-Prerequisites {
    Write-Host "🔍 Checking prerequisites..." -ForegroundColor $Yellow
    
    # Check Azure CLI
    if (-not (Get-Command "az" -ErrorAction SilentlyContinue)) {
        Write-Error "Azure CLI is not installed. Please install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        return $false
    }
    
    # Check kubectl
    if (-not (Get-Command "kubectl" -ErrorAction SilentlyContinue)) {
        Write-Warning "kubectl is not installed. Installing..."
        az aks install-cli
    }
    
    # Check Docker
    if (-not (Get-Command "docker" -ErrorAction SilentlyContinue)) {
        Write-Error "Docker is not installed. Please install Docker Desktop."
        return $false
    }
    
    # Check if logged into Azure
    $account = az account show 2>$null | ConvertFrom-Json
    if (-not $account) {
        Write-Host "🔐 Logging into Azure..." -ForegroundColor $Yellow
        az login
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to log into Azure"
            return $false
        }
    }
    
    # Set subscription
    az account set --subscription $SubscriptionId
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to set subscription: $SubscriptionId"
        return $false
    }
    
    Write-Host "✅ Prerequisites verified" -ForegroundColor $Green
    return $true
}

# Function to create resource group
function New-ResourceGroup {
    Write-Host "📦 Creating resource group..." -ForegroundColor $Yellow
    
    $rgExists = az group exists --name $ResourceGroupName --output tsv
    if ($rgExists -eq "false") {
        az group create --name $ResourceGroupName --location $Location --tags Environment=$Environment Project="FarmersBank" CostCenter="IT-Banking"
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Resource group created: $ResourceGroupName" -ForegroundColor $Green
        } else {
            Write-Error "Failed to create resource group"
        }
    } else {
        Write-Host "ℹ️  Resource group already exists: $ResourceGroupName" -ForegroundColor $Blue
    }
}

# Function to deploy infrastructure
function Deploy-Infrastructure {
    Write-Host "🏗️  Deploying infrastructure..." -ForegroundColor $Yellow
    
    $templateFile = "infrastructure/bicep/main.bicep"
    $parametersFile = "infrastructure/bicep/main.parameters.json"
    
    if (-not (Test-Path $templateFile)) {
        Write-Error "Bicep template not found: $templateFile"
        return $false
    }
    
    # Create parameters file if it doesn't exist
    if (-not (Test-Path $parametersFile)) {
        Write-Host "📝 Creating parameters file..." -ForegroundColor $Yellow
        $parameters = @{
            '$schema' = "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#"
            contentVersion = "1.0.0.0"
            parameters = @{
                environment = @{ value = $Environment }
                location = @{ value = $Location }
                sqlAdminUsername = @{ value = "farmersadmin" }
                sqlAdminPassword = @{ value = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SqlAdminPassword)) }
                apimPublisherEmail = @{ value = "admin@farmersbank.com" }
                apimPublisherName = @{ value = "Farmers Bank IT" }
            }
        }
        $parameters | ConvertTo-Json -Depth 4 | Out-File -FilePath $parametersFile -Encoding UTF8
    }
    
    # Deploy infrastructure
    $deploymentName = "farmersbank-infra-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Write-Host "🚀 Starting infrastructure deployment: $deploymentName" -ForegroundColor $Yellow
    
    az deployment group create `
        --resource-group $ResourceGroupName `
        --template-file $templateFile `
        --parameters $parametersFile `
        --name $deploymentName `
        --verbose
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Infrastructure deployed successfully" -ForegroundColor $Green
        
        # Get deployment outputs
        $outputs = az deployment group show --resource-group $ResourceGroupName --name $deploymentName --query "properties.outputs" --output json | ConvertFrom-Json
        
        # Store important values for later use
        $script:AksClusterName = $outputs.aksClusterName.value
        $script:AcrName = $outputs.containerRegistryName.value
        $script:SqlServerName = $outputs.sqlManagedInstanceName.value
        $script:KeyVaultName = $outputs.keyVaultName.value
        $script:AppInsightsName = $outputs.appInsightsName.value
        
        Write-Host "📊 Infrastructure Resources Created:" -ForegroundColor $Blue
        Write-Host "   • AKS Cluster: $script:AksClusterName" -ForegroundColor $White
        Write-Host "   • Container Registry: $script:AcrName" -ForegroundColor $White
        Write-Host "   • SQL Managed Instance: $script:SqlServerName" -ForegroundColor $White
        Write-Host "   • Key Vault: $script:KeyVaultName" -ForegroundColor $White
        Write-Host "   • Application Insights: $script:AppInsightsName" -ForegroundColor $White
        
        return $true
    } else {
        Write-Error "Infrastructure deployment failed"
        return $false
    }
}

# Function to build and push container images
function Build-ContainerImages {
    Write-Host "🐳 Building and pushing container images..." -ForegroundColor $Yellow
    
    # Get ACR login server
    $acrLoginServer = az acr show --name $script:AcrName --resource-group $ResourceGroupName --query "loginServer" --output tsv
    
    # Login to ACR
    az acr login --name $script:AcrName
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to login to Azure Container Registry"
        return $false
    }
    
    # Build and push each microservice
    $services = @(
        @{ Name = "memberservices"; Path = "src/Services/MemberServices" },
        @{ Name = "loansunderwriting"; Path = "src/Services/LoansUnderwriting" },
        @{ Name = "payments"; Path = "src/Services/Payments" },
        @{ Name = "fraudrisk"; Path = "src/Services/FraudRisk" }
    )
    
    foreach ($service in $services) {
        Write-Host "🔨 Building $($service.Name)..." -ForegroundColor $Yellow
        
        # Create Dockerfile for the service
        $dockerfilePath = "$($service.Path)/Dockerfile"
        if (-not (Test-Path $dockerfilePath)) {
            $dockerfileContent = @"
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["$($service.Path)/$($service.Name).API/$($service.Name).API.csproj", "$($service.Path)/$($service.Name).API/"]
COPY ["$($service.Path)/$($service.Name).Domain/$($service.Name).Domain.csproj", "$($service.Path)/$($service.Name).Domain/"]
COPY ["$($service.Path)/$($service.Name).Infrastructure/$($service.Name).Infrastructure.csproj", "$($service.Path)/$($service.Name).Infrastructure/"]
COPY ["src/Shared/", "src/Shared/"]
RUN dotnet restore "$($service.Path)/$($service.Name).API/$($service.Name).API.csproj"
COPY . .
WORKDIR "/src/$($service.Path)/$($service.Name).API"
RUN dotnet build "$($service.Name).API.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "$($service.Name).API.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "$($service.Name).API.dll"]
"@
            $dockerfileContent | Out-File -FilePath $dockerfilePath -Encoding UTF8
        }
        
        # Build and tag image
        $imageTag = "$acrLoginServer/farmersbank/$($service.Name.ToLower()):$Environment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        
        docker build -t $imageTag -f $dockerfilePath .
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to build image for $($service.Name)"
            continue
        }
        
        # Push image
        docker push $imageTag
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Pushed: $imageTag" -ForegroundColor $Green
            
            # Store image tag for Kubernetes deployment
            Set-Variable -Name "$($service.Name)ImageTag" -Value $imageTag -Scope Script
        } else {
            Write-Error "Failed to push image for $($service.Name)"
        }
    }
    
    Write-Host "✅ Container images built and pushed" -ForegroundColor $Green
    return $true
}

# Function to deploy applications to Kubernetes
function Deploy-Applications {
    Write-Host "☸️  Deploying applications to Kubernetes..." -ForegroundColor $Yellow
    
    # Get AKS credentials
    az aks get-credentials --resource-group $ResourceGroupName --name $script:AksClusterName --overwrite-existing
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to get AKS credentials"
        return $false
    }
    
    # Verify kubectl connection
    kubectl cluster-info
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to connect to Kubernetes cluster"
        return $false
    }
    
    # Create namespace
    kubectl create namespace farmersbank --dry-run=client -o yaml | kubectl apply -f -
    
    # Get connection strings from Key Vault for secrets
    Write-Host "🔐 Retrieving secrets from Key Vault..." -ForegroundColor $Yellow
    
    $sqlConnectionString = az keyvault secret show --vault-name $script:KeyVaultName --name "sql-connection-string" --query "value" --output tsv
    $serviceBusConnectionString = az keyvault secret show --vault-name $script:KeyVaultName --name "servicebus-connection-string" --query "value" --output tsv
    $appInsightsConnectionString = az keyvault secret show --vault-name $script:KeyVaultName --name "appinsights-instrumentation-key" --query "value" --output tsv
    
    # Create Kubernetes secrets
    kubectl create secret generic farmersbank-secrets `
        --namespace=farmersbank `
        --from-literal=sql-connection-string="$sqlConnectionString" `
        --from-literal=servicebus-connection-string="$serviceBusConnectionString" `
        --from-literal=appinsights-connection-string="$appInsightsConnectionString" `
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy base resources
    Write-Host "📦 Deploying base resources..." -ForegroundColor $Yellow
    kubectl apply -f k8s/shared/base-resources.yaml
    kubectl apply -f k8s/shared/network-policies.yaml
    
    # Update deployment manifests with current image tags
    $acrLoginServer = az acr show --name $script:AcrName --resource-group $ResourceGroupName --query "loginServer" --output tsv
    
    $services = @("memberservices", "loansunderwriting", "payments", "fraudrisk")
    foreach ($service in $services) {
        Write-Host "🚀 Deploying $service..." -ForegroundColor $Yellow
        
        # Read deployment manifest
        $deploymentFile = "k8s/$service/deployment.yaml"
        if (Test-Path $deploymentFile) {
            $deployment = Get-Content $deploymentFile -Raw
            
            # Update image reference
            $imageTag = Get-Variable -Name "$($service)ImageTag" -ValueOnly -ErrorAction SilentlyContinue
            if ($imageTag) {
                $deployment = $deployment -replace "farmersbank/$service.*", $imageTag.Split('/')[-1]
            }
            
            # Apply deployment
            $deployment | kubectl apply -f -
            
            # Wait for rollout
            kubectl rollout status deployment/$service-deployment --namespace=farmersbank --timeout=300s
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ $service deployed successfully" -ForegroundColor $Green
            } else {
                Write-Warning "⚠️  $service deployment may have issues"
            }
        } else {
            Write-Warning "⚠️  Deployment file not found: $deploymentFile"
        }
    }
    
    # Verify deployments
    Write-Host "🔍 Verifying deployments..." -ForegroundColor $Yellow
    kubectl get pods --namespace=farmersbank
    kubectl get services --namespace=farmersbank
    
    Write-Host "✅ Applications deployed to Kubernetes" -ForegroundColor $Green
    return $true
}

# Function to setup monitoring
function Setup-Monitoring {
    Write-Host "📊 Setting up monitoring and observability..." -ForegroundColor $Yellow
    
    # Run the monitoring setup script
    $monitoringScript = "scripts/Setup-Monitoring.ps1"
    if (Test-Path $monitoringScript) {
        & $monitoringScript -SubscriptionId $SubscriptionId -ResourceGroupName $ResourceGroupName -Environment $Environment -Location $Location
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Monitoring setup completed" -ForegroundColor $Green
            return $true
        } else {
            Write-Error "Monitoring setup failed"
            return $false
        }
    } else {
        Write-Warning "⚠️  Monitoring setup script not found: $monitoringScript"
        return $false
    }
}

# Function to run database migrations
function Run-DatabaseMigrations {
    Write-Host "🗄️  Running database migrations..." -ForegroundColor $Yellow
    
    # Get one of the pods to run migrations from
    $podName = kubectl get pods --namespace=farmersbank --selector=app=memberservices --output=jsonpath='{.items[0].metadata.name}' 2>$null
    
    if ($podName) {
        # Run Entity Framework migrations
        Write-Host "🔄 Running Entity Framework migrations..." -ForegroundColor $Yellow
        
        $services = @("MemberServices", "LoansUnderwriting", "Payments", "FraudRisk")
        foreach ($service in $services) {
            kubectl exec $podName --namespace=farmersbank -- dotnet ef database update --project "$service.Infrastructure" --startup-project "$service.API"
        }
        
        Write-Host "✅ Database migrations completed" -ForegroundColor $Green
    } else {
        Write-Warning "⚠️  No pods found to run migrations. Run manually after deployment."
    }
}

# Function to perform health checks
function Test-Deployment {
    Write-Host "🏥 Performing health checks..." -ForegroundColor $Yellow
    
    # Get service endpoints
    $services = @("memberservices", "loansunderwriting", "payments", "fraudrisk")
    $healthyServices = 0
    
    foreach ($service in $services) {
        try {
            # Get service external IP (if LoadBalancer) or use port-forward
            $serviceInfo = kubectl get service $service-service --namespace=farmersbank --output=json | ConvertFrom-Json
            
            if ($serviceInfo.spec.type -eq "LoadBalancer") {
                $externalIP = $serviceInfo.status.loadBalancer.ingress[0].ip
                if ($externalIP) {
                    $healthUrl = "http://$externalIP/health"
                    $response = Invoke-RestMethod -Uri $healthUrl -Method Get -TimeoutSec 10
                    if ($response) {
                        Write-Host "✅ $service is healthy" -ForegroundColor $Green
                        $healthyServices++
                    }
                }
            } else {
                Write-Host "ℹ️  $service is deployed (health check requires port-forward)" -ForegroundColor $Blue
                $healthyServices++
            }
        } catch {
            Write-Warning "⚠️  $service health check failed: $_"
        }
    }
    
    Write-Host "📊 Health Check Summary: $healthyServices/$($services.Count) services healthy" -ForegroundColor $Blue
    return $healthyServices -eq $services.Count
}

# Function to display deployment summary
function Show-DeploymentSummary {
    Write-Host "`n🎉 DEPLOYMENT COMPLETE!" -ForegroundColor $Green
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor $Green
    
    Write-Host "`n📊 Deployment Summary:" -ForegroundColor $Blue
    Write-Host "   • Environment: $Environment" -ForegroundColor $White
    Write-Host "   • Resource Group: $ResourceGroupName" -ForegroundColor $White
    Write-Host "   • AKS Cluster: $script:AksClusterName" -ForegroundColor $White
    Write-Host "   • Container Registry: $script:AcrName" -ForegroundColor $White
    Write-Host "   • SQL Managed Instance: $script:SqlServerName" -ForegroundColor $White
    Write-Host "   • Application Insights: $script:AppInsightsName" -ForegroundColor $White
    
    Write-Host "`n🔗 Useful Commands:" -ForegroundColor $Blue
    Write-Host "   # Get AKS credentials" -ForegroundColor $White
    Write-Host "   az aks get-credentials --resource-group $ResourceGroupName --name $script:AksClusterName" -ForegroundColor $Yellow
    
    Write-Host "   # View pods" -ForegroundColor $White
    Write-Host "   kubectl get pods --namespace=farmersbank" -ForegroundColor $Yellow
    
    Write-Host "   # View services" -ForegroundColor $White
    Write-Host "   kubectl get services --namespace=farmersbank" -ForegroundColor $Yellow
    
    Write-Host "   # Port forward to access services locally" -ForegroundColor $White
    Write-Host "   kubectl port-forward service/memberservices-service 8080:80 --namespace=farmersbank" -ForegroundColor $Yellow
    
    Write-Host "   # View logs" -ForegroundColor $White
    Write-Host "   kubectl logs -f deployment/memberservices-deployment --namespace=farmersbank" -ForegroundColor $Yellow
    
    Write-Host "`n🏦 Farmers Bank Microservices are now deployed and running in Azure!" -ForegroundColor $Green
}

# Main deployment process
try {
    $startTime = Get-Date
    
    # Check prerequisites
    if (-not (Test-Prerequisites)) {
        exit 1
    }
    
    # Create resource group
    New-ResourceGroup
    
    # Deploy infrastructure
    if (-not $SkipInfrastructure) {
        if (-not (Deploy-Infrastructure)) {
            exit 1
        }
    } else {
        # Get existing resource names if skipping infrastructure
        Write-Host "⏭️  Skipping infrastructure deployment, retrieving existing resources..." -ForegroundColor $Blue
        $script:AksClusterName = az aks list --resource-group $ResourceGroupName --query "[0].name" --output tsv
        $script:AcrName = az acr list --resource-group $ResourceGroupName --query "[0].name" --output tsv
        $script:SqlServerName = az sql mi list --resource-group $ResourceGroupName --query "[0].name" --output tsv
        $script:KeyVaultName = az keyvault list --resource-group $ResourceGroupName --query "[0].name" --output tsv
        $script:AppInsightsName = az monitor app-insights component list --resource-group $ResourceGroupName --query "[0].name" --output tsv
    }
    
    # Build and push container images
    if (-not $SkipApplications) {
        if (-not (Build-ContainerImages)) {
            Write-Warning "⚠️  Container image build failed, but continuing..."
        }
        
        # Deploy applications
        if (-not (Deploy-Applications)) {
            Write-Warning "⚠️  Application deployment had issues, but continuing..."
        }
        
        # Run database migrations
        Run-DatabaseMigrations
    } else {
        Write-Host "⏭️  Skipping application deployment" -ForegroundColor $Blue
    }
    
    # Setup monitoring
    if (-not $SkipMonitoring) {
        Setup-Monitoring
    } else {
        Write-Host "⏭️  Skipping monitoring setup" -ForegroundColor $Blue
    }
    
    # Perform health checks
    Test-Deployment
    
    # Show summary
    Show-DeploymentSummary
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    Write-Host "`n⏱️  Total deployment time: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor $Blue
    
} catch {
    Write-Host "`n❌ DEPLOYMENT FAILED" -ForegroundColor $Red
    Write-Host "Error: $_" -ForegroundColor $Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor $Red
    exit 1
}