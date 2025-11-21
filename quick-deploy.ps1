# Quick Azure Deployment - Farmers Bank Microservices
# Run this script to deploy everything in one go

Write-Host "🏦 FARMERS BANK MICROSERVICES - QUICK DEPLOYMENT" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green

# Collect deployment parameters
$subscriptionId = Read-Host "Enter your Azure Subscription ID"
$resourceGroupName = Read-Host "Enter Resource Group name (e.g., farmersbank-dev-rg)"
$environment = Read-Host "Enter Environment [dev/staging/prod] (default: dev)"
if ([string]::IsNullOrEmpty($environment)) { $environment = "dev" }

$location = Read-Host "Enter Azure region (default: East US)"
if ([string]::IsNullOrEmpty($location)) { $location = "East US" }

$sqlPassword = Read-Host "Enter SQL Admin password (min 8 chars, must include uppercase, lowercase, number, special char)" -AsSecureString

Write-Host "`n🚀 Starting deployment with parameters:" -ForegroundColor Yellow
Write-Host "   Subscription: $subscriptionId"
Write-Host "   Resource Group: $resourceGroupName" 
Write-Host "   Environment: $environment"
Write-Host "   Location: $location"
Write-Host ""

$confirm = Read-Host "Continue with deployment? (y/N)"
if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Host "❌ Deployment cancelled by user" -ForegroundColor Red
    exit 0
}

# Execute main deployment script
try {
    & .\scripts\Deploy-To-Azure.ps1 `
        -SubscriptionId $subscriptionId `
        -ResourceGroupName $resourceGroupName `
        -Environment $environment `
        -Location $location `
        -SqlAdminPassword $sqlPassword
        
    Write-Host "`n✅ Deployment completed successfully!" -ForegroundColor Green
    Write-Host "Check the output above for connection details and next steps." -ForegroundColor Yellow
}
catch {
    Write-Host "`n❌ Deployment failed: $_" -ForegroundColor Red
    Write-Host "Check the error messages above for troubleshooting guidance." -ForegroundColor Yellow
    exit 1
}