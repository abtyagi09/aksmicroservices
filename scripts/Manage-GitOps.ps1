# GitOps Management Script - Farmers Bank

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("promote-staging", "rollback", "sync-dev", "sync-staging", "status")]
    [string]$Action,
    
    [string]$ImageTag = "",
    
    [string]$ArgoCDServer = "",
    
    [switch]$DryRun
)

Write-Host "🏦 Farmers Bank GitOps Manager" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""

# Check if Argo CD CLI is available
$argoCLIAvailable = $false
try {
    argocd version --client | Out-Null
    $argoCLIAvailable = $true
    Write-Host "✅ Argo CD CLI is available" -ForegroundColor Green
}
catch {
    Write-Host "⚠️  Argo CD CLI not found. Some operations will be limited." -ForegroundColor Yellow
    Write-Host "   Install from: https://github.com/argoproj/argo-cd/releases" -ForegroundColor Gray
}

switch ($Action) {
    "promote-staging" {
        Write-Host "🚀 Promoting to Staging Environment" -ForegroundColor Yellow
        Write-Host "====================================" -ForegroundColor Yellow
        
        if (-not $ImageTag) {
            # Get current dev image
            $devManifest = Get-Content "gitops\environments\dev\memberservices.yaml" -Raw
            $imageMatch = [regex]::Match($devManifest, 'image: (fbdevygfwoiacr\.azurecr\.io/farmersbank/memberservices:[^\s]+)')
            
            if ($imageMatch.Success) {
                $ImageTag = $imageMatch.Groups[1].Value
                Write-Host "📦 Found current dev image: $ImageTag" -ForegroundColor Green
            } else {
                Write-Host "❌ Could not find current dev image. Please specify -ImageTag" -ForegroundColor Red
                exit 1
            }
        }
        
        Write-Host "📝 Updating staging manifest..." -ForegroundColor White
        
        if ($DryRun) {
            Write-Host "🔍 DRY RUN - Would update staging with: $ImageTag" -ForegroundColor Cyan
        } else {
            # Update staging manifest
            $stagingManifest = Get-Content "gitops\environments\staging\memberservices.yaml" -Raw
            $updatedManifest = $stagingManifest -replace 'image: fbdevygfwoiacr\.azurecr\.io/farmersbank/memberservices:[^\s]+', "image: $ImageTag"
            
            Set-Content "gitops\environments\staging\memberservices.yaml" -Value $updatedManifest
            
            # Commit changes
            git add "gitops\environments\staging\memberservices.yaml"
            git commit -m "GitOps: Promote staging to $ImageTag"
            git push origin main
            
            Write-Host "✅ Staging manifest updated and pushed" -ForegroundColor Green
        }
    }
    
    "rollback" {
        Write-Host "⏪ Rolling Back Deployment" -ForegroundColor Yellow
        Write-Host "==========================" -ForegroundColor Yellow
        
        # Show recent commits for rollback options
        Write-Host "Recent GitOps commits:" -ForegroundColor White
        git log --oneline -10 --grep="GitOps:"
        
        Write-Host ""
        $commitHash = Read-Host "Enter commit hash to rollback to"
        
        if ($DryRun) {
            Write-Host "🔍 DRY RUN - Would rollback to: $commitHash" -ForegroundColor Cyan
        } else {
            git revert $commitHash --no-edit
            git push origin main
            Write-Host "✅ Rollback complete" -ForegroundColor Green
        }
    }
    
    "sync-dev" {
        Write-Host "🔄 Syncing Dev Application" -ForegroundColor Yellow
        Write-Host "==========================" -ForegroundColor Yellow
        
        if ($argoCLIAvailable -and $ArgoCDServer) {
            if ($DryRun) {
                Write-Host "🔍 DRY RUN - Would sync dev application" -ForegroundColor Cyan
            } else {
                argocd app sync memberservices-dev --server $ArgoCDServer
                Write-Host "✅ Dev sync triggered" -ForegroundColor Green
            }
        } else {
            Write-Host "📌 Manual sync required in Argo CD UI:" -ForegroundColor White
            Write-Host "   1. Open Argo CD dashboard" -ForegroundColor Gray
            Write-Host "   2. Find 'memberservices-dev' application" -ForegroundColor Gray
            Write-Host "   3. Click 'Sync' button" -ForegroundColor Gray
        }
    }
    
    "sync-staging" {
        Write-Host "🔄 Syncing Staging Application" -ForegroundColor Yellow
        Write-Host "==============================" -ForegroundColor Yellow
        
        if ($argoCLIAvailable -and $ArgoCDServer) {
            if ($DryRun) {
                Write-Host "🔍 DRY RUN - Would sync staging application" -ForegroundColor Cyan
            } else {
                argocd app sync memberservices-staging --server $ArgoCDServer
                Write-Host "✅ Staging sync triggered" -ForegroundColor Green
            }
        } else {
            Write-Host "📌 Manual sync required in Argo CD UI:" -ForegroundColor White
            Write-Host "   1. Open Argo CD dashboard" -ForegroundColor Gray
            Write-Host "   2. Find 'memberservices-staging' application" -ForegroundColor Gray
            Write-Host "   3. Click 'Sync' button" -ForegroundColor Gray
        }
    }
    
    "status" {
        Write-Host "📊 GitOps Status" -ForegroundColor Yellow
        Write-Host "================" -ForegroundColor Yellow
        Write-Host ""
        
        # Show current images in both environments
        Write-Host "Current Deployments:" -ForegroundColor Cyan
        
        $devManifest = Get-Content "gitops\environments\dev\memberservices.yaml" -Raw
        $devImageMatch = [regex]::Match($devManifest, 'image: (fbdevygfwoiacr\.azurecr\.io/farmersbank/memberservices:[^\s]+)')
        if ($devImageMatch.Success) {
            Write-Host "  Dev: $($devImageMatch.Groups[1].Value)" -ForegroundColor White
        }
        
        $stagingManifest = Get-Content "gitops\environments\staging\memberservices.yaml" -Raw
        $stagingImageMatch = [regex]::Match($stagingManifest, 'image: (fbdevygfwoiacr\.azurecr\.io/farmersbank/memberservices:[^\s]+)')
        if ($stagingImageMatch.Success) {
            Write-Host "  Staging: $($stagingImageMatch.Groups[1].Value)" -ForegroundColor White
        }
        
        Write-Host ""
        Write-Host "Recent GitOps Changes:" -ForegroundColor Cyan
        git log --oneline -5 --grep="GitOps:"
        
        if ($argoCLIAvailable -and $ArgoCDServer) {
            Write-Host ""
            Write-Host "Argo CD Application Status:" -ForegroundColor Cyan
            argocd app list --server $ArgoCDServer
        }
    }
}

Write-Host ""
Write-Host "📚 GitOps Commands:" -ForegroundColor Cyan
Write-Host "   Promote to staging: .\scripts\Manage-GitOps.ps1 -Action promote-staging" -ForegroundColor White
Write-Host "   Check status: .\scripts\Manage-GitOps.ps1 -Action status" -ForegroundColor White
Write-Host "   Sync dev: .\scripts\Manage-GitOps.ps1 -Action sync-dev -ArgoCDServer <url>" -ForegroundColor White