# Farmers Bank - Setup Staging Environment

Write-Host "🏦 Setting up Farmers Bank Staging Environment..." -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

# Check if kubectl is available
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
Write-Host "Creating staging namespace and resources..." -ForegroundColor Yellow

# Create staging namespace
kubectl create namespace member-services-staging --dry-run=client -o yaml | kubectl apply -f -

if ($?) {
    Write-Host "✅ Created member-services-staging namespace" -ForegroundColor Green
} else {
    Write-Host "⚠️  Staging namespace may already exist" -ForegroundColor Yellow
}

# Apply staging deployment
if (Test-Path "k8s\memberservices\staging-deployment.yaml") {
    kubectl apply -f k8s\memberservices\staging-deployment.yaml
    if ($?) {
        Write-Host "✅ Applied staging deployment configuration" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to apply staging deployment" -ForegroundColor Red
    }
} else {
    Write-Host "❌ Staging deployment file not found at k8s\memberservices\staging-deployment.yaml" -ForegroundColor Red
}

Write-Host ""
Write-Host "Checking staging deployment status..." -ForegroundColor Yellow

# Wait for deployment to be ready
Write-Host "Waiting for pods to be ready (this may take a few minutes)..." -ForegroundColor Yellow
kubectl wait --for=condition=available --timeout=300s deployment/memberservices-api-staging -n member-services-staging

Write-Host ""
Write-Host "📊 Staging Environment Status:" -ForegroundColor Cyan
Write-Host ""

# Show deployment status
Write-Host "Deployments:" -ForegroundColor White
kubectl get deployments -n member-services-staging

Write-Host ""
Write-Host "Pods:" -ForegroundColor White
kubectl get pods -n member-services-staging

Write-Host ""
Write-Host "Services:" -ForegroundColor White
kubectl get services -n member-services-staging

Write-Host ""
Write-Host "HPA (Auto-scaling):" -ForegroundColor White
kubectl get hpa -n member-services-staging

# Get external IP
Write-Host ""
Write-Host "Getting staging service external IP..." -ForegroundColor Yellow
$externalIP = kubectl get svc memberservices-api-service-staging -n member-services-staging -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

if ($externalIP) {
    Write-Host ""
    Write-Host "🌐 Staging Service Access:" -ForegroundColor Green
    Write-Host "  HTTP: http://$externalIP" -ForegroundColor White
    Write-Host "  Health Check: http://$externalIP/health" -ForegroundColor White
    Write-Host "  gRPC: $externalIP:5001" -ForegroundColor White
} else {
    Write-Host "⏳ External IP not yet assigned. Run this command later to get the IP:" -ForegroundColor Yellow
    Write-Host "kubectl get svc memberservices-api-service-staging -n member-services-staging" -ForegroundColor White
}

Write-Host ""
Write-Host "🎯 Staging environment setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Wait for external IP to be assigned" -ForegroundColor White
Write-Host "  2. Test the staging environment" -ForegroundColor White
Write-Host "  3. Approve production deployment in GitHub Actions" -ForegroundColor White
Write-Host "  4. Monitor staging metrics and performance" -ForegroundColor White