# Trigger Staging Deployment - Farmers Bank Microservices

Write-Host "🏦 Farmers Bank - Staging Deployment Trigger" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Check if GitHub CLI is available
try {
    gh --version | Out-Null
    Write-Host "✅ GitHub CLI is available" -ForegroundColor Green
}
catch {
    Write-Host "❌ GitHub CLI not found. Please install GitHub CLI first:" -ForegroundColor Red
    Write-Host "   https://cli.github.com/" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Alternative: Use GitHub web interface to trigger staging deployment" -ForegroundColor Yellow
    Write-Host "   1. Go to: https://github.com/abtyagi09/aksmicroservices/actions" -ForegroundColor White
    Write-Host "   2. Select 'Deploy to Staging Environment' workflow" -ForegroundColor White
    Write-Host "   3. Click 'Run workflow' and confirm deployment" -ForegroundColor White
    exit 1
}

Write-Host "📋 Staging Deployment Options:" -ForegroundColor Yellow
Write-Host ""

# Get available image tags from ACR
Write-Host "Checking available image tags..." -ForegroundColor Yellow

$imageTags = @()
try {
    $acrLogin = az acr login --name fbdevygfwoiacr 2>$null
    $tags = az acr repository show-tags --name fbdevygfwoiacr --repository farmersbank/memberservices --output tsv 2>$null
    if ($tags) {
        $imageTags = $tags -split "`n" | Where-Object { $_ -ne "" } | Sort-Object -Descending
        Write-Host "Available image tags:" -ForegroundColor Green
        $imageTags | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }
    } else {
        Write-Host "⚠️  Could not retrieve image tags from ACR" -ForegroundColor Yellow
        $imageTags = @("latest")
    }
}
catch {
    Write-Host "⚠️  Could not connect to ACR, using 'latest' tag" -ForegroundColor Yellow
    $imageTags = @("latest")
}

Write-Host ""

# Get user input for image tag
$selectedTag = "latest"
if ($imageTags.Count -gt 1) {
    Write-Host "Select image tag for staging deployment:" -ForegroundColor Cyan
    for ($i = 0; $i -lt [Math]::Min($imageTags.Count, 5); $i++) {
        Write-Host "  [$($i + 1)] $($imageTags[$i])" -ForegroundColor White
    }
    Write-Host "  [Enter] latest (default)" -ForegroundColor Gray
    
    $choice = Read-Host "Enter choice (1-$([Math]::Min($imageTags.Count, 5)) or Enter for latest)"
    
    if ($choice -and $choice -match '^\d+$' -and [int]$choice -le $imageTags.Count -and [int]$choice -gt 0) {
        $selectedTag = $imageTags[[int]$choice - 1]
    }
}

Write-Host ""
Write-Host "🎯 Staging Deployment Configuration:" -ForegroundColor Cyan
Write-Host "   Repository: abtyagi09/aksmicroservices" -ForegroundColor White
Write-Host "   Workflow: Deploy to Staging Environment" -ForegroundColor White
Write-Host "   Image Tag: $selectedTag" -ForegroundColor White
Write-Host "   Target Namespace: member-services-staging" -ForegroundColor White
Write-Host ""

# Confirm deployment
$confirm = Read-Host "Proceed with staging deployment? (y/N)"

if ($confirm -eq 'y' -or $confirm -eq 'Y' -or $confirm -eq 'yes') {
    Write-Host ""
    Write-Host "🚀 Triggering staging deployment..." -ForegroundColor Yellow
    
    try {
        # Trigger the GitHub Actions workflow
        $result = gh workflow run deploy-staging.yml `
            --repo abtyagi09/aksmicroservices `
            --field image_tag=$selectedTag `
            --field confirm_deployment=true
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Staging deployment triggered successfully!" -ForegroundColor Green
            Write-Host ""
            Write-Host "📊 Monitor deployment progress:" -ForegroundColor Cyan
            Write-Host "   GitHub Actions: https://github.com/abtyagi09/aksmicroservices/actions" -ForegroundColor White
            Write-Host ""
            Write-Host "⏳ The deployment will require approval in the staging environment." -ForegroundColor Yellow
            Write-Host "   Check the GitHub Actions page to approve the deployment." -ForegroundColor White
        } else {
            Write-Host "❌ Failed to trigger staging deployment" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "❌ Error triggering deployment: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "🌐 Manual trigger alternative:" -ForegroundColor Yellow
        Write-Host "   1. Go to: https://github.com/abtyagi09/aksmicroservices/actions" -ForegroundColor White
        Write-Host "   2. Select 'Deploy to Staging Environment'" -ForegroundColor White
        Write-Host "   3. Click 'Run workflow' with image_tag='$selectedTag'" -ForegroundColor White
    }
} else {
    Write-Host "❌ Staging deployment cancelled" -ForegroundColor Red
}