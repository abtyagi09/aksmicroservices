# AKS Deployment Monitor
Write-Host "🚀 Farmers Bank AKS Cluster Deployment Monitor" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host "VM Size: Standard_NV12s_v3 (GPU-enabled, 1 node)" -ForegroundColor Cyan

$resourceGroup = "farmersbank-microservices-dev"
$aksName = "farmersbank-aks"

# Monitor deployment progress
Write-Host "`n⏳ Monitoring AKS deployment progress..." -ForegroundColor Yellow

do {
    try {
        $aksStatus = az aks show --name $aksName --resource-group $resourceGroup --query "provisioningState" -o tsv 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            $timestamp = Get-Date -Format "HH:mm:ss"
            Write-Host "[$timestamp] AKS Status: $aksStatus" -ForegroundColor Cyan
            
            if ($aksStatus -eq "Succeeded") {
                Write-Host "`n✅ AKS Cluster deployed successfully!" -ForegroundColor Green
                break
            } elseif ($aksStatus -eq "Failed") {
                Write-Host "`n❌ AKS Cluster deployment failed!" -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Host "[$(Get-Date -Format "HH:mm:ss")] AKS cluster not yet available..." -ForegroundColor Yellow
        }
        
        Start-Sleep -Seconds 30
    } catch {
        Write-Host "Error checking status: $_" -ForegroundColor Red
        Start-Sleep -Seconds 30
    }
} while ($true)

# Once successful, connect and deploy demo
Write-Host "`n🔗 Connecting to AKS cluster..." -ForegroundColor Yellow
az aks get-credentials --resource-group $resourceGroup --name $aksName --overwrite-existing

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Successfully connected to AKS cluster" -ForegroundColor Green
    
    # Test kubectl access
    Write-Host "`n🧪 Testing Kubernetes access..." -ForegroundColor Yellow
    kubectl cluster-info
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n🚀 Ready to deploy applications!" -ForegroundColor Green
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "1. Deploy demo: kubectl apply -f k8s/demo/memberservices-demo.yaml" -ForegroundColor White
        Write-Host "2. Check pods: kubectl get pods -w" -ForegroundColor White
        Write-Host "3. Get service IP: kubectl get service memberservices-demo-service" -ForegroundColor White
    } else {
        Write-Host "❌ Unable to connect to Kubernetes API" -ForegroundColor Red
    }
} else {
    Write-Host "❌ Failed to get AKS credentials" -ForegroundColor Red
}