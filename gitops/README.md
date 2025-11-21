# GitOps Deployment with Argo CD

This directory contains the GitOps configuration for Farmers Bank microservices using Argo CD for declarative, automated deployments.

## 📁 Structure

```
gitops/
├── applications/           # Argo CD Application definitions
│   ├── memberservices-dev.yaml     # Dev environment app
│   └── memberservices-staging.yaml # Staging environment app
└── environments/          # Environment-specific manifests
    ├── dev/
    │   └── memberservices.yaml     # Dev deployment config
    └── staging/
        └── memberservices.yaml     # Staging deployment config
```

## 🚀 Getting Started

### 1. Deploy Argo CD

Run the deployment script:

```powershell
.\scripts\Deploy-ArgoCD.ps1
```

This will:
- Install Argo CD in the `argocd` namespace
- Expose Argo CD server via LoadBalancer
- Provide admin credentials

### 2. Access Argo CD Dashboard

```powershell
# Get Argo CD external IP
kubectl get svc argocd-server -n argocd

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Login at `https://<EXTERNAL-IP>` with:
- Username: `admin`
- Password: `<retrieved-password>`

### 3. Install Argo CD Applications

```powershell
# Install dev application
kubectl apply -f gitops/applications/memberservices-dev.yaml

# Install staging application  
kubectl apply -f gitops/applications/memberservices-staging.yaml
```

## 🔄 GitOps Workflow

### Automatic Dev Deployment

1. **Code Push** → `main` branch
2. **CI/CD Pipeline** builds and tests
3. **GitOps Workflow** updates `gitops/environments/dev/memberservices.yaml`
4. **Argo CD** automatically syncs changes to dev environment

### Manual Staging Promotion

1. **Review** dev deployment success
2. **Promote** using GitOps manager:
   ```powershell
   .\scripts\Manage-GitOps.ps1 -Action promote-staging
   ```
3. **Manual Sync** in Argo CD dashboard for staging approval

## 🛠️ Management Commands

### GitOps Manager Script

```powershell
# Check current status
.\scripts\Manage-GitOps.ps1 -Action status

# Promote current dev to staging
.\scripts\Manage-GitOps.ps1 -Action promote-staging

# Promote specific image to staging
.\scripts\Manage-GitOps.ps1 -Action promote-staging -ImageTag "fbdevygfwoiacr.azurecr.io/farmersbank/memberservices:abc123f"

# Sync applications (requires Argo CD CLI)
.\scripts\Manage-GitOps.ps1 -Action sync-dev -ArgoCDServer "https://<ARGOCD-IP>"
.\scripts\Manage-GitOps.ps1 -Action sync-staging -ArgoCDServer "https://<ARGOCD-IP>"

# Rollback to previous version
.\scripts\Manage-GitOps.ps1 -Action rollback
```

### Direct kubectl Commands

```powershell
# View applications
kubectl get applications -n argocd

# Check app status
kubectl get application memberservices-dev -n argocd -o yaml

# Manual sync via kubectl
kubectl patch application memberservices-dev -n argocd --type merge -p '{"operation":{"sync":{}}}'
```

## 📊 Environment Configuration

### Dev Environment
- **Namespace**: `member-services`
- **Replicas**: 1
- **Auto-sync**: Enabled
- **Self-heal**: Enabled
- **Pruning**: Enabled

### Staging Environment
- **Namespace**: `member-services-staging`
- **Replicas**: 2
- **Auto-sync**: Disabled (manual approval)
- **Load Balancer**: External access
- **Resource limits**: Higher for staging load

## 🔐 Security Features

- **RBAC**: Argo CD uses service account permissions
- **Git-based**: All changes tracked in Git history
- **Audit Trail**: Full deployment history in Argo CD
- **Rollback**: Easy rollback to any previous state
- **Approval Gates**: Manual sync for staging

## 📈 Benefits

### Push-based GitOps
- **Immediate Updates**: Changes pushed to cluster on Git commit
- **No Pull Interval**: Faster than traditional pull-based GitOps
- **CI/CD Integration**: Seamless workflow integration
- **Artifact Tracking**: Direct correlation between builds and deployments

### Argo CD Features
- **Visual Dashboard**: Clear view of application state
- **Drift Detection**: Identifies manual changes
- **Health Monitoring**: Application and resource health status
- **Multi-Environment**: Manage multiple environments from one place

## 🚨 Troubleshooting

### Application Not Syncing

```powershell
# Check application status
kubectl describe application memberservices-dev -n argocd

# View Argo CD logs
kubectl logs -n argocd deployment/argocd-application-controller

# Force refresh
kubectl patch application memberservices-dev -n argocd --type merge -p '{"spec":{"source":{"targetRevision":"HEAD"}}}'
```

### Access Issues

```powershell
# Reset admin password
kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData": {
    "admin.password": "$2a$10$rRyBsGSHK6.uc8fntPwVIuLVHgsAhAX7TcdrqW/RADU0uh7CaChLa",
    "admin.passwordMtime": "'$(date +%FT%T%Z)'"
  }}'
```

### Sync Failures

```powershell
# Check repository access
kubectl get secret argocd-repo-creds-<repo> -n argocd

# Validate manifests locally
kubectl apply --dry-run=client -f gitops/environments/dev/memberservices.yaml
```

## 📚 Additional Resources

- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [GitOps Principles](https://opengitops.dev/)
- [Kubernetes GitOps Best Practices](https://github.com/argoproj/argo-cd/blob/master/docs/best_practices.md)