# Farmers Bank Microservices - Deployment Validation Script
param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup = "farmersbank-microservices-dev",
    
    [Parameter(Mandatory=$false)]
    [string]$AksClusterName = "fb-dev-ygfwoi-aks"
)

Write-Host "🚀 Farmers Bank Microservices Deployment Validation" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green

# Check if logged into Azure
Write-Host "`n1. Checking Azure authentication..." -ForegroundColor Yellow
try {
    $account = az account show --query "user.name" -o tsv 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Logged in as: $account" -ForegroundColor Green
    } else {
        Write-Host "❌ Not logged into Azure. Please run: az login" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Azure CLI not available or login required" -ForegroundColor Red
    exit 1
}

# Check Resource Group
Write-Host "`n2. Checking Resource Group..." -ForegroundColor Yellow
$rgExists = az group show --name $ResourceGroup --query "name" -o tsv 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Resource Group '$ResourceGroup' exists" -ForegroundColor Green
} else {
    Write-Host "❌ Resource Group '$ResourceGroup' not found" -ForegroundColor Red
    exit 1
}

# Check Container Registry
Write-Host "`n3. Checking Azure Container Registry..." -ForegroundColor Yellow
$acrName = az acr list --resource-group $ResourceGroup --query "[0].name" -o tsv 2>$null
if ($LASTEXITCODE -eq 0 -and $acrName) {
    Write-Host "✅ ACR '$acrName' available" -ForegroundColor Green
    
    # Check if we can access ACR
    $loginStatus = az acr login --name $acrName 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Successfully authenticated to ACR" -ForegroundColor Green
    } else {
        Write-Host "⚠️  ACR authentication failed" -ForegroundColor Yellow
    }
    
    # Check container images
    $images = az acr repository list --name $acrName --output tsv 2>$null
    if ($images) {
        Write-Host "✅ Container images available:" -ForegroundColor Green
        foreach ($image in $images) {
            Write-Host "   📦 $image" -ForegroundColor Cyan
        }
    } else {
        Write-Host "⚠️  No container images found in ACR" -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ No ACR found in resource group" -ForegroundColor Red
}
}

# Check AKS Cluster
Write-Host "`n4. Checking AKS Cluster..." -ForegroundColor Yellow
$aksExists = az aks show --name $AksClusterName --resource-group $ResourceGroup --query "name" -o tsv 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ AKS Cluster '$AksClusterName' exists" -ForegroundColor Green
    
    # Get cluster status
    $aksStatus = az aks show --name $AksClusterName --resource-group $ResourceGroup --query "provisioningState" -o tsv 2>$null
    Write-Host "   📊 Status: $aksStatus" -ForegroundColor Cyan
    
    if ($aksStatus -eq "Succeeded") {
        Write-Host "`n5. Connecting to AKS Cluster..." -ForegroundColor Yellow
        $getCredentials = az aks get-credentials --resource-group $ResourceGroup --name $AksClusterName --overwrite-existing 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Successfully connected to AKS cluster" -ForegroundColor Green
            
            # Test kubectl
            Write-Host "`n6. Testing Kubernetes Access..." -ForegroundColor Yellow
            $nodes = kubectl get nodes --no-headers 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Kubernetes cluster accessible" -ForegroundColor Green
                Write-Host "   🖥️  Nodes:" -ForegroundColor Cyan
                kubectl get nodes -o wide | Write-Host -ForegroundColor White
                
                # Check if demo app is deployed
                Write-Host "`n7. Checking Demo Application..." -ForegroundColor Yellow
                $demoDeployment = kubectl get deployment memberservices-demo --no-headers 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "✅ Demo application deployed" -ForegroundColor Green
                    kubectl get pods,services,ingress -l app=memberservices-demo | Write-Host -ForegroundColor White
                    
                    # Get service endpoint
                    $serviceIP = kubectl get service memberservices-demo-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
                    if ($serviceIP) {
                        Write-Host "`n🌐 Demo API available at: http://$serviceIP" -ForegroundColor Green
                        Write-Host "   Test endpoints:" -ForegroundColor Cyan
                        Write-Host "   • Health Check: http://$serviceIP/api/Members/health" -ForegroundColor White
                        Write-Host "   • Member List:  http://$serviceIP/api/Members" -ForegroundColor White
                    } else {
                        Write-Host "⚠️  Service IP not yet available (LoadBalancer still provisioning)" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "⚠️  Demo application not yet deployed" -ForegroundColor Yellow
                    Write-Host "   To deploy demo: kubectl apply -f k8s/demo/memberservices-demo.yaml" -ForegroundColor Cyan
                }
            } else {
                Write-Host "❌ Cannot access Kubernetes cluster" -ForegroundColor Red
            }
        } else {
            Write-Host "❌ Failed to get AKS credentials" -ForegroundColor Red
        }
    } else {
        Write-Host "⚠️  AKS Cluster is not ready (Status: $aksStatus)" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️  AKS Cluster '$AksClusterName' not found or not ready" -ForegroundColor Yellow
    Write-Host "   Check deployment status with: az deployment group list --resource-group $ResourceGroup" -ForegroundColor Cyan
}

# Check monitoring
Write-Host "`n8. Checking Monitoring Resources..." -ForegroundColor Yellow
$logAnalytics = az monitor log-analytics workspace list --resource-group $ResourceGroup --query "[0].name" -o tsv 2>$null
if ($logAnalytics) {
    Write-Host "✅ Log Analytics Workspace: $logAnalytics" -ForegroundColor Green
} else {
    Write-Host "⚠️  No Log Analytics Workspace found" -ForegroundColor Yellow
}

$appInsights = az monitor app-insights component show --resource-group $ResourceGroup --query "[0].name" -o tsv 2>$null
if ($appInsights) {
    Write-Host "✅ Application Insights: $appInsights" -ForegroundColor Green
} else {
    Write-Host "⚠️  No Application Insights found" -ForegroundColor Yellow
}

Write-Host "`n🏁 Validation Complete!" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green

if ($aksStatus -eq "Succeeded") {
    Write-Host "✅ Your Farmers Bank microservices infrastructure is ready!" -ForegroundColor Green
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Deploy the demo: kubectl apply -f k8s/demo/memberservices-demo.yaml" -ForegroundColor Cyan
    Write-Host "2. Monitor deployment: kubectl get pods -w" -ForegroundColor Cyan
    Write-Host "3. Test the API endpoints once LoadBalancer IP is available" -ForegroundColor Cyan
} else {
    Write-Host "⚠️  Infrastructure is still deploying. Run this script again in a few minutes." -ForegroundColor Yellow
}