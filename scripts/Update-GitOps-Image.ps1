#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Updates GitOps manifests with new image tags
.DESCRIPTION
    This script updates the GitOps environment manifests with new image tags
    for the specified service and environment.
.PARAMETER Service
    The service name (e.g., memberservices)
.PARAMETER ImageTag
    The new image tag to use
.PARAMETER Environment
    The environment to update (dev, staging, or all)
.EXAMPLE
    .\Update-GitOps-Image.ps1 -Service memberservices -ImageTag "fbdevygfwoiacr.azurecr.io/farmersbank/memberservices:abc123" -Environment dev
.EXAMPLE
    .\Update-GitOps-Image.ps1 -Service memberservices -ImageTag "latest" -Environment all
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Service,
    
    [Parameter(Mandatory = $true)]
    [string]$ImageTag,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("dev", "staging", "all")]
    [string]$Environment = "all"
)

# Ensure we're in the correct directory
$rootPath = Split-Path $PSScriptRoot -Parent
Set-Location $rootPath

Write-Host "🚀 Updating GitOps manifests for $Service" -ForegroundColor Green
Write-Host "Image Tag: $ImageTag" -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor Cyan

# Construct full image path if only tag provided
if ($ImageTag -notlike "*/*") {
    $fullImagePath = "fbdevygfwoiacr.azurecr.io/farmersbank/$Service`:$ImageTag"
} else {
    $fullImagePath = $ImageTag
}

Write-Host "Full image path: $fullImagePath" -ForegroundColor Yellow

# Function to update a specific environment file
function Update-Environment {
    param(
        [string]$EnvName,
        [string]$FilePath
    )
    
    if (Test-Path $FilePath) {
        Write-Host "Updating $EnvName environment..." -ForegroundColor Yellow
        
        # Read content
        $content = Get-Content $FilePath -Raw
        
        # Update image tag using regex (supports latest, PLACEHOLDER_IMAGE_TAG, and GitHub SHA)
        $pattern = "image: fbdevygfwoiacr\.azurecr\.io/farmersbank/$Service`:($\{\{\s*github\.sha\s*\}\}|latest|PLACEHOLDER_IMAGE_TAG|.*)"
        $replacement = "image: $fullImagePath"
        
        if ($content -match $pattern) {
            $newContent = $content -replace $pattern, $replacement
            Set-Content -Path $FilePath -Value $newContent -NoNewline
            Write-Host "✅ Updated $EnvName environment with new image tag" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Image pattern not found in $EnvName environment file" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ File not found: $FilePath" -ForegroundColor Red
    }
}

# Update environments based on parameter
switch ($Environment) {
    "dev" {
        Update-Environment -EnvName "Development" -FilePath "gitops/environments/dev/$Service.yaml"
    }
    "staging" {
        Update-Environment -EnvName "Staging" -FilePath "gitops/environments/staging/$Service.yaml"
    }
    "all" {
        Update-Environment -EnvName "Development" -FilePath "gitops/environments/dev/$Service.yaml"
        Update-Environment -EnvName "Staging" -FilePath "gitops/environments/staging/$Service.yaml"
    }
}

Write-Host ""
Write-Host "📋 Summary:" -ForegroundColor Magenta
Write-Host "  Service: $Service" -ForegroundColor White
Write-Host "  Image: $fullImagePath" -ForegroundColor White
Write-Host "  Environment(s): $Environment" -ForegroundColor White

Write-Host ""
Write-Host "🔄 To commit and push changes:" -ForegroundColor Cyan
Write-Host "  git add gitops/environments/" -ForegroundColor Gray
Write-Host "  git commit -m 'Update $Service image to $ImageTag'" -ForegroundColor Gray
Write-Host "  git push" -ForegroundColor Gray

Write-Host ""
Write-Host "🔍 To check Argo CD sync status:" -ForegroundColor Cyan
Write-Host "  kubectl get applications -n argocd" -ForegroundColor Gray
Write-Host "  kubectl get pods -n memberservices-gitops" -ForegroundColor Gray