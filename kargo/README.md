# Kargo Setup for dummy-go-app

This guide explains the Kargo progressive delivery setup for the dummy-go-app learning project.

## What is Kargo?

**Kargo** is a progressive delivery tool built on top of ArgoCD that adds:

| Feature | Plain ArgoCD | ArgoCD + Kargo |
|---------|--------------|----------------|
| GitOps deployment | ✅ | ✅ |
| Environment promotion | Manual git commits | Automated with approval gates |
| Freight tracking | ❌ | ✅ Tracks artifacts through stages |
| Promotion policies | ❌ | ✅ Auto or manual per stage |
| Rollback | Manual | Built-in with freight history |

**Key Concepts:**
- **Project** - Groups related resources (warehouses, stages)
- **Warehouse** - Watches for new artifacts (Git commits, Helm charts, container images)
- **Freight** - A bundle of artifacts that can be promoted through stages
- **Stage** - An environment (dev, staging, production) with promotion policies
- **Promotion** - Moving freight from one stage to another

---

## Project Overview

```
┌───────────────────────────────────────────────────────────────────────────────────────┐
│                            Kargo Project: dummy-go-app                                 │
├───────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                        │
│   ┌──────────────────┐                                                                │
│   │    WAREHOUSE     │                                                                │
│   │   (Git Repo)     │                                                                │
│   │                  │                                                                │
│   │ Watches:         │                                                                │
│   │ helm-chart/      │                                                                │
│   └────────┬─────────┘                                                                │
│            │                                                                          │
│            │ New commit detected → Creates FREIGHT                                    │
│            ▼                                                                          │
│   ┌──────────────────┐       ┌──────────────────┐       ┌──────────────────┐         │
│   │    DEV STAGE     │       │  STAGING STAGE   │       │ PRODUCTION STAGE │         │
│   │                  │       │                  │       │                  │         │
│   │ Auto-promotion   │──────▶│ Auto-promotion   │──────▶│ Auto-promotion   │         │
│   │ (immediate)      │promote│ (immediate)      │promote│ (immediate)      │         │
│   │                  │       │                  │       │                  │         │
│   └────────┬─────────┘       └────────┬─────────┘       └────────┬─────────┘         │
│            │                          │                          │                    │
│            ▼                          ▼                          ▼                    │
│   ┌──────────────────┐       ┌──────────────────┐       ┌──────────────────┐         │
│   │ ArgoCD App       │       │ ArgoCD App       │       │ ArgoCD App       │         │
│   │ dummy-go-app-dev │       │ dummy-go-app-    │       │ dummy-go-app-    │         │
│   │                  │       │ staging          │       │ production       │         │
│   └──────────────────┘       └──────────────────┘       └──────────────────┘         │
│                                                                                        │
└───────────────────────────────────────────────────────────────────────────────────────┘
```

**Promotion Flow:**
```
Git Push → Warehouse detects → Freight created → Dev (auto) → Staging (auto) → Production (auto)
```

---

## Prerequisites

Before setting up Kargo, ensure you have:

| Component | Required | Installation |
|-----------|----------|--------------|
| Kubernetes cluster | ✅ | kind, k3s, minikube, or cloud |
| kubectl | ✅ | `brew install kubectl` |
| ArgoCD | ✅ | See [ArgoCD docs](https://argo-cd.readthedocs.io/) |
| cert-manager | ✅ | Required by Kargo |
| Kargo | ✅ | See installation below |
| Kargo CLI | Optional | For CLI promotions |

```bash
# Verify prerequisites
kubectl version --client
kubectl get pods -n argocd
kubectl get pods -n cert-manager
```

---

## File Structure

```
kargo/
├── README.md
├── manifests/                   # Kargo resource definitions
│   ├── applicationset.yaml      # ArgoCD ApplicationSet (creates apps for each env)
│   ├── project.yaml             # Kargo Project (creates namespace)
│   ├── projectconfig.yaml       # Promotion policies (auto-promotion settings)
│   ├── warehouse.yaml           # Git repository watcher
│   └── stages.yaml              # Dev, staging, and production stages
├── scripts/                     # Operational scripts
│   ├── apply-all.sh             # Apply all manifests
│   ├── setup-git-credentials.sh # Create SSH secret
│   ├── test-git-credentials.sh  # Test SSH key from secret
│   └── delete-git-credentials.sh# Delete SSH secret
└── docs/                        # Detailed documentation
    ├── STAGES.md
    ├── DEBUG-PROMOTIONS.md
    └── promotion-steps/
        └── git-operations.md
```

---

## Git Credentials (SSH)

Kargo needs SSH access to push commits. Use a deploy key, not personal keys.

```bash
./kargo/scripts/setup-git-credentials.sh  # create secret (generates key if needed)
./kargo/scripts/test-git-credentials.sh   # verify key works
./kargo/scripts/delete-git-credentials.sh # remove secret
```

Environment variables:

| Variable | Default |
|----------|---------|
| `NAMESPACE` | `dummy-go-app` |
| `SECRET_NAME` | `github-creds` |
| `REPO_URL` | `git@github.com:adamplansky/dummy-go-app.git` |
| `SSH_KEY_PATH` | `~/.ssh/kargo_deploy_key` |

Key rotation:

```bash
./kargo/scripts/delete-git-credentials.sh
rm ~/.ssh/kargo_deploy_key*
# remove old key from GitHub
./kargo/scripts/setup-git-credentials.sh
```

---

## Installation Steps

### Step 1: Install Kargo

```bash
# Add Kargo Helm repository
helm repo add kargo https://kargo.akuity.io/charts
helm repo update

# Install Kargo with cert-manager
helm install kargo kargo/kargo \
  --namespace kargo \
  --create-namespace \
  --set api.adminAccount.enabled=true \
  --set api.adminAccount.password=admin \
  --wait

# Verify installation
kubectl get pods -n kargo
```

### Step 2: Apply ArgoCD ApplicationSet

```bash
kubectl apply -f kargo/manifests/applicationset.yaml
kubectl get applications -n argocd | grep dummy-go-app
```

### Step 3: Apply Kargo Resources

```bash
# Option A: Apply all at once
./kargo/scripts/apply-all.sh

# Option B: Apply manually (order matters)
kubectl apply -f kargo/manifests/project.yaml
kubectl apply -f kargo/manifests/projectconfig.yaml
kubectl apply -f kargo/manifests/warehouse.yaml
kubectl apply -f kargo/manifests/stages.yaml
```

---

## How Promotions Work

### Automatic Promotion (All Stages)

When the warehouse detects a new commit in `helm-chart/`:

1. **Freight Created** - Kargo creates a new "freight" artifact
2. **Auto-Promotion to Dev** - Dev stage automatically promotes (no approval needed)
3. **Auto-Promotion to Staging** - Once dev succeeds, staging auto-promotes
4. **Auto-Promotion to Production** - Once staging succeeds, production auto-promotes
5. **ArgoCD Sync** - Kargo triggers ArgoCD to sync each environment's app

```yaml
# In projectconfig.yaml - all stages have auto-promotion enabled
spec:
  promotionPolicies:
    - stage: dev
      autoPromotionEnabled: true
    - stage: staging
      autoPromotionEnabled: true
    - stage: production
      autoPromotionEnabled: true
```

### Manual Promotion (If Needed)

If you disable auto-promotion for a stage, you can manually promote:

```bash
# Option 1: Via Kargo CLI
kargo promote --project dummy-go-app --freight <freight-id> --stage production

# Option 2: Via Kargo UI
# Navigate to: https://<kargo-url>/project/dummy-go-app
# Click "Promote" on the freight you want to deploy

# Option 3: Via kubectl (create a Promotion resource)
kubectl apply -f - <<EOF
apiVersion: kargo.akuity.io/v1alpha1
kind: Promotion
metadata:
  name: promote-to-prod-$(date +%s)
  namespace: dummy-go-app
spec:
  stage: production
  freight: <freight-name>
EOF
```

### Finding Freight IDs

```bash
# List all freight in the project
kubectl get freight -n dummy-go-app

# Get freight details
kubectl describe freight <freight-name> -n dummy-go-app

# Using Kargo CLI
kargo get freight --project dummy-go-app
```

---

## Verification Commands

### Check Kargo Resources

```bash
# List all Kargo projects
kubectl get projects.kargo.akuity.io -A

# Check project status
kubectl get project dummy-go-app -n dummy-go-app -o yaml

# List warehouses
kubectl get warehouses -n dummy-go-app

# List stages
kubectl get stages -n dummy-go-app

# List freight (artifacts ready for promotion)
kubectl get freight -n dummy-go-app

# List promotions (history)
kubectl get promotions -n dummy-go-app
```

### Using Kargo CLI

```bash
# Install Kargo CLI
brew install kargo  # macOS
# or download from https://github.com/akuity/kargo/releases

# Login to Kargo (local development)
kargo login http://kargo.localhost/ --insecure-skip-tls-verify

# Or with admin password
kargo login http://kargo.localhost/ --admin --insecure-skip-tls-verify

# List projects
kargo get projects

# Get project details
kargo get project dummy-go-app

# List freight
kargo get freight --project dummy-go-app

# List promotions
kargo get promotions --project dummy-go-app

# Watch stage status
kargo get stages --project dummy-go-app -w
```

### Verify ArgoCD Integration

```bash
# Check ArgoCD applications
kubectl get applications -n argocd | grep dummy-go-app

# Verify apps are synced
argocd app get dummy-go-app-dev
argocd app get dummy-go-app-staging
argocd app get dummy-go-app-production
```

---

## Troubleshooting

### Common Issues

#### 1. Warehouse Not Detecting Changes

```bash
# Check warehouse status
kubectl describe warehouse dummy-go-app-warehouse -n dummy-go-app

# Look for errors
kubectl logs -n kargo -l app.kubernetes.io/component=controller

# Verify Git URL is correct
kubectl get warehouse dummy-go-app-warehouse -n dummy-go-app -o yaml
```

**Solution:** Ensure the Git repo is accessible and the path matches your chart location.

#### 2. Promotion Stuck or Failed

```bash
# Check promotion status
kubectl get promotions -n dummy-go-app
kubectl describe promotion <promotion-name> -n dummy-go-app

# Check controller logs
kubectl logs -n kargo deployment/kargo-controller
```

**Solution:** Verify ArgoCD app name matches exactly, and the app is healthy.

#### 3. Stage Not Updating

```bash
# Check stage conditions
kubectl get stage dev -n dummy-go-app -o yaml

# Verify freight exists
kubectl get freight -n dummy-go-app
```

**Solution:** Ensure the stage subscribes to the correct warehouse.

#### 4. ArgoCD App Not Syncing

```bash
# Check ArgoCD app health
argocd app get dummy-go-app-dev

# Force refresh
argocd app get dummy-go-app-dev --hard-refresh

# Check sync status
kubectl get application dummy-go-app-dev -n argocd -o yaml
```

#### 5. Permission/RBAC Issues

```bash
# Check if Kargo can access ArgoCD
kubectl get secret -n argocd | grep kargo

# Verify Kargo service account
kubectl get serviceaccount -n kargo
```

---

## Learning Resources

### Official Documentation

- 📚 [Kargo Documentation](https://docs.kargo.io/)
- 📚 [Kargo GitHub](https://github.com/akuity/kargo)
- 📚 [ArgoCD Documentation](https://argo-cd.readthedocs.io/)

### Tutorials

- 🎓 [Kargo Quickstart](https://docs.kargo.io/quickstart)
- 🎓 [Progressive Delivery with Kargo](https://akuity.io/blog/kargo-progressive-delivery/)
- 🎥 [Kargo Introduction Video](https://www.youtube.com/watch?v=KJwK2NG4Rr8)

### Related Concepts

- [GitOps Principles](https://opengitops.dev/)
- [Progressive Delivery](https://www.weave.works/blog/progressive-delivery)
- [ArgoCD ApplicationSets](https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/)

---

## Quick Reference

| Action | Command |
|--------|---------|
| List projects | `kubectl get projects.kargo.akuity.io -A` |
| List warehouses | `kubectl get warehouses -n dummy-go-app` |
| List stages | `kubectl get stages -n dummy-go-app` |
| List freight | `kubectl get freight -n dummy-go-app` |
| List promotions | `kubectl get promotions -n dummy-go-app` |
| Promote freight | `kargo promote --project dummy-go-app --freight <id> --stage production` |
| Watch stages | `kubectl get stages -n dummy-go-app -w` |

---

## Next Steps

1. ✅ Understand Kargo concepts (you are here!)
2. ✅ All Kargo resources are already created in this folder
3. ⬜ Install Kargo in your cluster
4. ⬜ Apply resources in order: `project.yaml` → `projectconfig.yaml` → `warehouse.yaml` → `stages.yaml`
5. ⬜ Apply ApplicationSet: `applicationset.yaml`
6. ⬜ Make a change to `helm-chart/` and watch auto-promotion through dev → staging → production
7. ⬜ Try rolling back a promotion

Happy GitOps! 🚀

