# Build script for all microservices
Write-Host "🏗️ Building All Farmers Bank Microservices" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green

$services = @(
    @{Name="fraudrisk"; Display="Fraud Risk"},
    @{Name="loansunderwriting"; Display="Loans & Underwriting"},
    @{Name="payments"; Display="Payments"}
)

foreach ($service in $services) {
    Write-Host "`n📦 Building $($service.Display) Service..." -ForegroundColor Yellow
    
    $imageName = "fbdevygfwoiacr.azurecr.io/farmersbank/$($service.Name):v1"
    
    # Build using the working Dockerfile pattern
    docker build -t $imageName -f Dockerfile.working . 
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Successfully built $($service.Display)" -ForegroundColor Green
        
        # Push to ACR
        Write-Host "📤 Pushing $($service.Display) to ACR..." -ForegroundColor Cyan
        docker push $imageName
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Successfully pushed $($service.Display)" -ForegroundColor Green
        } else {
            Write-Host "❌ Failed to push $($service.Display)" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ Failed to build $($service.Display)" -ForegroundColor Red
    }
}

Write-Host "`n🎉 Build process complete!" -ForegroundColor Green