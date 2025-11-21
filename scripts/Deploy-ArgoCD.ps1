# Deploy Argo CD to AKS Cluster

Write-Host "🚀 Deploying Argo CD for GitOps - Farmers Bank" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

# Check kubectl
try {
    kubectl version --client | Out-Null
    Write-Host "✅ kubectl is available" -ForegroundColor Green
}
catch {
    Write-Host "❌ kubectl not found. Please ensure kubectl is installed and configured." -ForegroundColor Red
    exit 1
}

# Check AKS connection
try {
    kubectl get nodes | Out-Null
    Write-Host "✅ Connected to AKS cluster" -ForegroundColor Green
}
catch {
    Write-Host "❌ Cannot connect to AKS cluster. Please run:" -ForegroundColor Red
    Write-Host "   az aks get-credentials --resource-group farmersbank-microservices-dev --name farmersbank-aks" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "📦 Installing Argo CD..." -ForegroundColor Yellow

# Create argocd namespace
Write-Host "Creating argocd namespace..." -ForegroundColor White
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install Argo CD
Write-Host "Installing Argo CD components..." -ForegroundColor White
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

if ($?) {
    Write-Host "✅ Argo CD installed successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to install Argo CD" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "⏳ Waiting for Argo CD pods to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=available --timeout=600s deployment --all -n argocd

Write-Host ""
Write-Host "🔧 Configuring Argo CD access..." -ForegroundColor Yellow

# Patch argocd-server service to LoadBalancer for external access
Write-Host "Exposing Argo CD server..." -ForegroundColor White
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

Write-Host ""
Write-Host "🔐 Getting Argo CD admin password..." -ForegroundColor Yellow
$adminPassword = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object {
    [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_))
}

Write-Host ""
Write-Host "📊 Argo CD Deployment Status:" -ForegroundColor Cyan
kubectl get all -n argocd

Write-Host ""
Write-Host "🌐 Getting Argo CD external IP..." -ForegroundColor Yellow
Write-Host "This may take a few minutes for the LoadBalancer to assign an IP..." -ForegroundColor Gray

$attempts = 0
$maxAttempts = 20
$externalIP = $null

while ($attempts -lt $maxAttempts -and -not $externalIP) {
    Start-Sleep -Seconds 15
    $externalIP = kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
    if ($externalIP) {
        break
    }
    $attempts++
    Write-Host "Waiting for external IP... (attempt $($attempts)/$maxAttempts)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "🎉 Argo CD Deployment Complete!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""

if ($externalIP) {
    Write-Host "🌐 Argo CD Access Information:" -ForegroundColor Cyan
    Write-Host "   URL: https://$externalIP" -ForegroundColor White
    Write-Host "   Username: admin" -ForegroundColor White
    Write-Host "   Password: $adminPassword" -ForegroundColor White
    Write-Host ""
    Write-Host "📋 Next Steps:" -ForegroundColor Yellow
    Write-Host "   1. Access Argo CD at: https://$externalIP" -ForegroundColor White
    Write-Host "   2. Login with admin/$adminPassword" -ForegroundColor White
    Write-Host "   3. Configure GitOps applications" -ForegroundColor White
    Write-Host "   4. Set up push-based deployments" -ForegroundColor White
} else {
    Write-Host "⏳ External IP not yet assigned. Check later with:" -ForegroundColor Yellow
    Write-Host "kubectl get svc argocd-server -n argocd" -ForegroundColor White
    Write-Host ""
    Write-Host "🔐 Argo CD Credentials:" -ForegroundColor Cyan
    Write-Host "   Username: admin" -ForegroundColor White
    Write-Host "   Password: $adminPassword" -ForegroundColor White
}

Write-Host ""
Write-Host "Argo CD CLI Installation (Optional):" -ForegroundColor Cyan
Write-Host "   Windows: choco install argocd-cli" -ForegroundColor White
Write-Host "   Or download from: https://github.com/argoproj/argo-cd/releases" -ForegroundColor White