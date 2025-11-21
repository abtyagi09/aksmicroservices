# Farmers Bank Microservices Deployment Script
# This script deploys the entire infrastructure and application stack

param(
    [Parameter(Mandatory=$true)]
    [string]$Environment,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$Location,
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipInfrastructure,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipApplication
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Function to write colored output
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    } else {
        $input | Write-Output
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

# Function to log messages
function Write-Log {
    param($Message, $Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-ColorOutput $Color "[$timestamp] $Message"
}

Write-Log "Starting Farmers Bank Microservices Deployment" "Green"
Write-Log "Environment: $Environment" "Yellow"
Write-Log "Resource Group: $ResourceGroupName" "Yellow"
Write-Log "Location: $Location" "Yellow"

# Validate prerequisites
Write-Log "Validating prerequisites..." "Cyan"

# Check if Azure CLI is installed
try {
    $azVersion = az --version | Select-Object -First 1
    Write-Log "Azure CLI: $azVersion" "Green"
} catch {
    Write-Log "Azure CLI is not installed. Please install Azure CLI." "Red"
    exit 1
}

# Check if kubectl is installed
try {
    $kubectlVersion = kubectl version --client=true --short 2>$null
    Write-Log "kubectl: $kubectlVersion" "Green"
} catch {
    Write-Log "kubectl is not installed. Please install kubectl." "Red"
    exit 1
}

# Set subscription if provided
if ($SubscriptionId) {
    Write-Log "Setting Azure subscription to: $SubscriptionId" "Cyan"
    az account set --subscription $SubscriptionId
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Failed to set subscription" "Red"
        exit 1
    }
}

# Get current subscription
$currentSubscription = az account show --query "id" -o tsv
Write-Log "Current subscription: $currentSubscription" "Yellow"

# Create resource group if it doesn't exist
Write-Log "Creating resource group: $ResourceGroupName" "Cyan"
az group create --name $ResourceGroupName --location $Location
if ($LASTEXITCODE -ne 0) {
    Write-Log "Failed to create resource group" "Red"
    exit 1
}

if (-not $SkipInfrastructure) {
    # Deploy infrastructure using Bicep
    Write-Log "Deploying infrastructure..." "Cyan"
    
    $deploymentName = "farmersbank-infra-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    $bicepFile = "infrastructure/bicep/main.bicep"
    $parametersFile = "infrastructure/bicep/main.parameters.json"
    
    # Update parameters file with current values
    $parameters = Get-Content $parametersFile | ConvertFrom-Json
    $parameters.parameters.environment.value = $Environment
    $parameters.parameters.location.value = $Location
    $parameters | ConvertTo-Json -Depth 10 | Set-Content $parametersFile
    
    Write-Log "Starting Bicep deployment: $deploymentName" "Yellow"
    $deploymentResult = az deployment group create `
        --resource-group $ResourceGroupName `
        --template-file $bicepFile `
        --parameters $parametersFile `
        --name $deploymentName `
        --output json | ConvertFrom-Json
    
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Infrastructure deployment failed" "Red"
        exit 1
    }
    
    Write-Log "Infrastructure deployment completed successfully" "Green"
    
    # Extract outputs
    $aksName = $deploymentResult.properties.outputs.aksClusterName.value
    $acrName = $deploymentResult.properties.outputs.containerRegistryName.value
    $keyVaultName = $deploymentResult.properties.outputs.keyVaultName.value
    
    Write-Log "AKS Cluster: $aksName" "Yellow"
    Write-Log "Container Registry: $acrName" "Yellow"
    Write-Log "Key Vault: $keyVaultName" "Yellow"
    
    # Get AKS credentials
    Write-Log "Getting AKS credentials..." "Cyan"
    az aks get-credentials --resource-group $ResourceGroupName --name $aksName --overwrite-existing
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Failed to get AKS credentials" "Red"
        exit 1
    }
    
    # Test AKS connectivity
    Write-Log "Testing AKS connectivity..." "Cyan"
    $nodes = kubectl get nodes --no-headers 2>$null
    if ($LASTEXITCODE -eq 0) {
        $nodeCount = ($nodes | Measure-Object).Count
        Write-Log "Successfully connected to AKS. Node count: $nodeCount" "Green"
    } else {
        Write-Log "Failed to connect to AKS cluster" "Red"
        exit 1
    }
    
} else {
    Write-Log "Skipping infrastructure deployment" "Yellow"
    
    # Try to get existing resource names
    try {
        $aksName = az aks list --resource-group $ResourceGroupName --query "[0].name" -o tsv
        $acrName = az acr list --resource-group $ResourceGroupName --query "[0].name" -o tsv
        $keyVaultName = az keyvault list --resource-group $ResourceGroupName --query "[0].name" -o tsv
        
        Write-Log "Using existing AKS Cluster: $aksName" "Yellow"
        Write-Log "Using existing Container Registry: $acrName" "Yellow"
        Write-Log "Using existing Key Vault: $keyVaultName" "Yellow"
    } catch {
        Write-Log "Could not find existing infrastructure resources" "Red"
        exit 1
    }
}

if (-not $SkipApplication) {
    # Build and push container images
    Write-Log "Building and pushing container images..." "Cyan"
    
    # Login to ACR
    az acr login --name $acrName
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Failed to login to ACR" "Red"
        exit 1
    }
    
    $acrLoginServer = az acr show --name $acrName --query "loginServer" -o tsv
    $services = @("memberservices", "loansunderwriting", "payments", "fraudrisk")
    
    foreach ($service in $services) {
        Write-Log "Building and pushing $service..." "Yellow"
        
        $imageName = "$acrLoginServer/farmersbank/$service-api:latest"
        $dockerFile = "src/Services/$($service.Substring(0,1).ToUpper() + $service.Substring(1))/$($service.Substring(0,1).ToUpper() + $service.Substring(1)).API/Dockerfile"
        
        # Build image
        docker build -t $imageName -f $dockerFile .
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed to build $service image" "Red"
            exit 1
        }
        
        # Push image
        docker push $imageName
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed to push $service image" "Red"
            exit 1
        }
        
        Write-Log "$service image built and pushed successfully" "Green"
    }
    
    # Deploy Kubernetes resources
    Write-Log "Deploying Kubernetes resources..." "Cyan"
    
    # Apply shared resources first
    Write-Log "Deploying shared resources..." "Yellow"
    kubectl apply -f k8s/shared/base-resources.yaml
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Failed to deploy shared resources" "Red"
        exit 1
    }
    
    kubectl apply -f k8s/shared/network-policies.yaml
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Failed to deploy network policies" "Red"
        exit 1
    }
    
    # Deploy services
    foreach ($service in $services) {
        Write-Log "Deploying $service..." "Yellow"
        kubectl apply -f "k8s/$service/deployment.yaml"
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed to deploy $service" "Red"
            exit 1
        }
    }
    
    # Wait for deployments to be ready
    Write-Log "Waiting for deployments to be ready..." "Cyan"
    foreach ($service in $services) {
        $deploymentName = "$service-api"
        Write-Log "Waiting for $deploymentName deployment..." "Yellow"
        
        kubectl wait --for=condition=available --timeout=300s deployment/$deploymentName -n farmersbank
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Deployment $deploymentName failed to become ready" "Red"
            exit 1
        }
        
        Write-Log "$deploymentName is ready" "Green"
    }
    
} else {
    Write-Log "Skipping application deployment" "Yellow"
}

# Display deployment summary
Write-Log "=== Deployment Summary ===" "Green"
Write-Log "Environment: $Environment" "White"
Write-Log "Resource Group: $ResourceGroupName" "White"
Write-Log "Location: $Location" "White"

if (-not $SkipInfrastructure) {
    Write-Log "Infrastructure: Deployed" "Green"
} else {
    Write-Log "Infrastructure: Skipped" "Yellow"
}

if (-not $SkipApplication) {
    Write-Log "Application: Deployed" "Green"
} else {
    Write-Log "Application: Skipped" "Yellow"
}

# Get service information
Write-Log "=== Service Information ===" "Cyan"
try {
    $services = kubectl get services -n farmersbank --no-headers 2>$null
    if ($LASTEXITCODE -eq 0 -and $services) {
        Write-Log "Services deployed:" "White"
        $services | ForEach-Object { Write-Log "  $_" "White" }
    }
    
    $pods = kubectl get pods -n farmersbank --no-headers 2>$null
    if ($LASTEXITCODE -eq 0 -and $pods) {
        Write-Log "Pods status:" "White"
        $pods | ForEach-Object { Write-Log "  $_" "White" }
    }
} catch {
    Write-Log "Could not retrieve service information" "Yellow"
}

Write-Log "Farmers Bank Microservices deployment completed successfully!" "Green"

# Provide next steps
Write-Log "=== Next Steps ===" "Cyan"
Write-Log "1. Configure API Management policies and routing" "White"
Write-Log "2. Set up monitoring and alerting in Azure Monitor" "White"
Write-Log "3. Configure backup and disaster recovery procedures" "White"
Write-Log "4. Implement CI/CD pipelines for automated deployments" "White"
Write-Log "5. Conduct security and compliance testing" "White"