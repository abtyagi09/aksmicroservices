# Simple Infrastructure Deployment for Farmers Bank Microservices
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "East US"
)

$ErrorActionPreference = "Stop"

Write-Host "🏦 Deploying Farmers Bank Infrastructure..." -ForegroundColor Green

# Set subscription
az account set --subscription $SubscriptionId

# Create resource group
Write-Host "📦 Creating resource group: $ResourceGroupName" -ForegroundColor Yellow
az group create --name $ResourceGroupName --location $Location --tags Environment=$Environment Project="FarmersBank"

# Create a minimal parameters file
$parametersContent = @{
    '$schema' = "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#"
    contentVersion = "1.0.0.0"
    parameters = @{
        environment = @{ value = $Environment }
        location = @{ value = $Location }
        sqlAdminUsername = @{ value = "farmersadmin" }
        sqlAdminPassword = @{ value = "FarmersBank123!" }
        apimPublisherEmail = @{ value = "admin@farmersbank.com" }
        apimPublisherName = @{ value = "Farmers Bank IT" }
    }
}

$parametersPath = "infrastructure/bicep/main.parameters.json"
$parametersContent | ConvertTo-Json -Depth 4 | Out-File -FilePath $parametersPath -Encoding UTF8

# Deploy infrastructure
Write-Host "🚀 Deploying infrastructure..." -ForegroundColor Yellow
$deploymentName = "farmersbank-infra-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file "infrastructure/bicep/main.bicep" `
    --parameters $parametersPath `
    --name $deploymentName `
    --verbose

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Infrastructure deployment completed!" -ForegroundColor Green
    
    # Get outputs
    $outputs = az deployment group show --resource-group $ResourceGroupName --name $deploymentName --query "properties.outputs" --output json | ConvertFrom-Json
    
    Write-Host "`n📊 Resources Created:" -ForegroundColor Blue
    Write-Host "   • AKS Cluster: $($outputs.aksClusterName.value)" -ForegroundColor White
    Write-Host "   • Container Registry: $($outputs.containerRegistryName.value)" -ForegroundColor White
    Write-Host "   • SQL Managed Instance: $($outputs.sqlManagedInstanceName.value)" -ForegroundColor White
    Write-Host "   • Application Insights: $($outputs.appInsightsName.value)" -ForegroundColor White
    
    Write-Host "`n🎉 Infrastructure deployment successful!" -ForegroundColor Green
} else {
    Write-Host "❌ Infrastructure deployment failed" -ForegroundColor Red
    exit 1
}