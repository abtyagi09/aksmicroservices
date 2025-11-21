# Cost Management Alert for Farmers Bank Demo
Write-Host "💰 COST MANAGEMENT ALERT" -ForegroundColor Yellow
Write-Host "========================" -ForegroundColor Yellow
Write-Host ""
Write-Host "⚠️  IMPORTANT COST NOTICE:" -ForegroundColor Red
Write-Host ""
Write-Host "Your AKS cluster is now using:" -ForegroundColor White
Write-Host "• VM Size: Standard_NV12s_v3" -ForegroundColor Yellow
Write-Host "• Type: GPU-enabled (NVIDIA Tesla M60)" -ForegroundColor Yellow
Write-Host "• Estimated cost: ~$3-4/hour when running" -ForegroundColor Red
Write-Host ""
Write-Host "💡 COST OPTIMIZATION TIPS:" -ForegroundColor Cyan
Write-Host "1. Stop the cluster when not in use:" -ForegroundColor White
Write-Host "   az aks stop --name farmersbank-aks --resource-group farmersbank-microservices-dev" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Start when needed:" -ForegroundColor White
Write-Host "   az aks start --name farmersbank-aks --resource-group farmersbank-microservices-dev" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Delete when demo is complete:" -ForegroundColor White
Write-Host "   az aks delete --name farmersbank-aks --resource-group farmersbank-microservices-dev" -ForegroundColor Gray
Write-Host ""
Write-Host "📊 Monitor your Azure costs at:" -ForegroundColor Cyan
Write-Host "   https://portal.azure.com/#blade/Microsoft_Azure_CostManagement/CostManagementMenu" -ForegroundColor Blue
Write-Host ""
Write-Host "🎯 For production deployment, consider:" -ForegroundColor Green
Write-Host "   • Moving to a region with Standard_B2s availability" -ForegroundColor White
Write-Host "   • Using spot instances for cost savings" -ForegroundColor White
Write-Host "   • Implementing auto-scaling policies" -ForegroundColor White