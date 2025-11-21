# Quick AKS Status Check
Write-Host "🔍 Checking AKS Status..." -ForegroundColor Cyan

$status = az aks show --name "farmersbank-aks" --resource-group "farmersbank-microservices-dev" --query "provisioningState" -o tsv 2>$null

if ($LASTEXITCODE -eq 0) {
    switch ($status) {
        "Succeeded" {
            Write-Host "✅ AKS Cluster is READY!" -ForegroundColor Green
            Write-Host ""
            Write-Host "🔗 Next steps:" -ForegroundColor Yellow
            Write-Host "1. Connect: az aks get-credentials --resource-group farmersbank-microservices-dev --name farmersbank-aks" -ForegroundColor White
            Write-Host "2. Deploy demo: kubectl apply -f k8s/demo/memberservices-demo.yaml" -ForegroundColor White
            Write-Host "3. Check status: kubectl get pods,svc" -ForegroundColor White
        }
        "Creating" {
            Write-Host "⏳ AKS Cluster is still deploying..." -ForegroundColor Yellow
            Write-Host "   Status: $status" -ForegroundColor Cyan
        }
        "Failed" {
            Write-Host "❌ AKS Cluster deployment failed!" -ForegroundColor Red
        }
        default {
            Write-Host "📊 AKS Status: $status" -ForegroundColor Cyan
        }
    }
} else {
    Write-Host "⚠️ Unable to check AKS status. Cluster may not exist yet." -ForegroundColor Yellow
}