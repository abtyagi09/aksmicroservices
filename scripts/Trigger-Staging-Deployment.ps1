# Promote Dev to Staging - Farmers Bank Microservices

Write-Host "🏦 Farmers Bank - Dev to Staging Promotion" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
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
    Write-Host "Alternative: Use GitHub web interface to promote to staging" -ForegroundColor Yellow
    Write-Host "   1. Go to: https://github.com/abtyagi09/aksmicroservices/actions" -ForegroundColor White
    Write-Host "   2. Select 'Promote Dev to Staging' workflow" -ForegroundColor White
    Write-Host "   3. Click 'Run workflow' and confirm promotion" -ForegroundColor White
    exit 1
}

Write-Host "📋 Promotion Information:" -ForegroundColor Yellow
Write-Host ""

# Get recent dev deployments
Write-Host "Checking recent dev deployments..." -ForegroundColor Yellow

try {
    $recentRuns = gh run list --repo abtyagi09/aksmicroservices --workflow="ci-cd.yml" --limit=5 --json=databaseId,conclusion,createdAt,headSha --jq='.[] | select(.conclusion=="success")'
    
    if ($recentRuns) {
        Write-Host "Recent successful dev deployments:" -ForegroundColor Green
        $runs = $recentRuns | ConvertFrom-Json
        for ($i = 0; $i -lt [Math]::Min($runs.Count, 3); $i++) {
            $run = $runs[$i]
            $date = [DateTime]::Parse($run.createdAt).ToString("yyyy-MM-dd HH:mm")
            Write-Host "  [$($i + 1)] Run ID: $($run.databaseId) - $date (SHA: $($run.headSha.Substring(0,7)))" -ForegroundColor White
        }
        Write-Host "  [Enter] Use latest dev image (default)" -ForegroundColor Gray
        
        $choice = Read-Host "Select dev deployment to promote (1-$([Math]::Min($runs.Count, 3)) or Enter for latest)"
        
        $selectedRunId = ""
        if ($choice -and $choice -match '^\d+$' -and [int]$choice -le $runs.Count -and [int]$choice -gt 0) {
            $selectedRunId = $runs[[int]$choice - 1].databaseId
            Write-Host "📦 Will promote dev run ID: $selectedRunId" -ForegroundColor Cyan
        } else {
            Write-Host "📦 Will promote latest dev image" -ForegroundColor Cyan
        }
    } else {
        Write-Host "⚠️  No recent successful dev deployments found" -ForegroundColor Yellow
        Write-Host "📦 Will promote latest dev image" -ForegroundColor Cyan
        $selectedRunId = ""
    }
}
catch {
    Write-Host "⚠️  Could not retrieve recent deployments" -ForegroundColor Yellow
    Write-Host "📦 Will promote latest dev image" -ForegroundColor Cyan
    $selectedRunId = ""
}

Write-Host ""
Write-Host "🎯 Staging Promotion Configuration:" -ForegroundColor Cyan
Write-Host "   Repository: abtyagi09/aksmicroservices" -ForegroundColor White
Write-Host "   Workflow: Promote Dev to Staging" -ForegroundColor White
if ($selectedRunId) {
    Write-Host "   Dev Run ID: $selectedRunId" -ForegroundColor White
} else {
    Write-Host "   Source: Latest dev image" -ForegroundColor White
}
Write-Host "   Target Namespace: member-services-staging" -ForegroundColor White
Write-Host "   Guarantee: Same image as deployed to dev" -ForegroundColor Green
Write-Host ""

# Confirm promotion
$confirm = Read-Host "Proceed with staging promotion? (y/N)"

if ($confirm -eq 'y' -or $confirm -eq 'Y' -or $confirm -eq 'yes') {
    Write-Host ""
    Write-Host "🚀 Triggering staging promotion..." -ForegroundColor Yellow
    
    try {
        # Trigger the GitHub Actions workflow
        if ($selectedRunId) {
            $result = gh workflow run deploy-staging.yml `
                --repo abtyagi09/aksmicroservices `
                --field dev_run_id=$selectedRunId `
                --field confirm_promotion=true
        } else {
            $result = gh workflow run deploy-staging.yml `
                --repo abtyagi09/aksmicroservices `
                --field confirm_promotion=true
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Staging promotion triggered successfully!" -ForegroundColor Green
            Write-Host ""
            Write-Host "📊 Monitor promotion progress:" -ForegroundColor Cyan
            Write-Host "   GitHub Actions: https://github.com/abtyagi09/aksmicroservices/actions" -ForegroundColor White
            Write-Host ""
            Write-Host "⏳ The promotion will require approval in the staging environment." -ForegroundColor Yellow
            Write-Host "   Check the GitHub Actions page to approve the promotion." -ForegroundColor White
            Write-Host ""
            Write-Host "🎯 The same image deployed to dev will be promoted to staging!" -ForegroundColor Green
        } else {
            Write-Host "❌ Failed to trigger staging promotion" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "❌ Error triggering promotion: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "🌐 Manual trigger alternative:" -ForegroundColor Yellow
        Write-Host "   1. Go to: https://github.com/abtyagi09/aksmicroservices/actions" -ForegroundColor White
        Write-Host "   2. Select 'Promote Dev to Staging'" -ForegroundColor White
        Write-Host "   3. Click 'Run workflow' and confirm promotion" -ForegroundColor White
    }
} else {
    Write-Host "❌ Staging promotion cancelled" -ForegroundColor Red
}