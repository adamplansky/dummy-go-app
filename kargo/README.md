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
┌─────────────────────────────────────────────────────────────────────────┐
│                        Kargo Project: dummy-go-app                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌──────────────────┐                                                  │
│   │    WAREHOUSE     │                                                  │
│   │   (Git Repo)     │                                                  │
│   │                  │                                                  │
│   │ Watches:         │                                                  │
│   │ helm-chart/      │                                                  │
│   └────────┬─────────┘                                                  │
│            │                                                            │
│            │ New commit detected → Creates FREIGHT                      │
│            ▼                                                            │
│   ┌──────────────────┐         ┌──────────────────┐                    │
│   │    DEV STAGE     │         │ PRODUCTION STAGE │                    │
│   │                  │         │                  │                    │
│   │ Auto-promotion   │────────▶│ Manual approval  │                    │
│   │ (immediate)      │ promote │ (requires OK)    │                    │
│   │                  │         │                  │                    │
│   └────────┬─────────┘         └────────┬─────────┘                    │
│            │                            │                              │
│            ▼                            ▼                              │
│   ┌──────────────────┐         ┌──────────────────┐                    │
│   │ ArgoCD App       │         │ ArgoCD App       │                    │
│   │ dummy-go-app-dev │         │ dummy-go-app-    │                    │
│   │                  │         │ production       │                    │
│   └──────────────────┘         └──────────────────┘                    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

**Promotion Flow:**
```
Git Push → Warehouse detects → Freight created → Dev (auto) → Production (manual)
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
├── README.md              # This file
├── applicationset.yaml    # ArgoCD ApplicationSet (generates dev + production apps)
├── project.yaml           # Kargo Project (creates namespace)
├── projectconfig.yaml     # Promotion policies (auto for dev, manual for production)
├── warehouse.yaml         # Git repository watcher
└── stages.yaml            # Dev and Production stages (in one file)
```

### File Descriptions

| File | Purpose |
|------|---------|
| `applicationset.yaml` | Replaces separate ArgoCD apps with a single ApplicationSet |
| `project.yaml` | Creates the `dummy-go-app` Kargo project and namespace |
| `projectconfig.yaml` | Defines promotion policies (Kargo v1.5+) |
| `warehouse.yaml` | Watches `helm-chart/` path in Git for changes |
| `stages.yaml` | Defines dev (auto) and production (manual) stages |

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
# Apply the ApplicationSet (generates both dev and production apps)
kubectl apply -f kargo/applicationset.yaml

# Verify the applications were created
kubectl get applications -n argocd | grep dummy-go-app
```

### Step 3: Apply Kargo Resources (Order Matters!)

```bash
# 1. Create the project first (creates namespace)
kubectl apply -f kargo/project.yaml

# 2. Apply project config (promotion policies) - requires namespace to exist
kubectl apply -f kargo/projectconfig.yaml

# 3. Apply warehouse (watches for changes)
kubectl apply -f kargo/warehouse.yaml

# 4. Apply stages (dev and production in one file)
kubectl apply -f kargo/stages.yaml
```

**⚠️ Important:** Apply in order! Project creates namespace, then projectconfig, warehouse, and stages.

---

## How Promotions Work

### Automatic Promotion (Dev Stage)

When the warehouse detects a new commit in `helm-chart/`:

1. **Freight Created** - Kargo creates a new "freight" artifact
2. **Auto-Promotion** - Dev stage automatically promotes (no approval needed)
3. **ArgoCD Sync** - Kargo triggers ArgoCD to sync `dummy-go-app-dev`

```yaml
# In stage-dev.yaml - automatic promotion policy
spec:
  promotionMechanisms:
    argoCDAppUpdates:
    - appName: dummy-go-app-dev
  subscriptions:
    warehouse: dummy-go-app-warehouse
  # No requestedFreight approval required = auto-promotion
```

### Manual Promotion (Production Stage)

Production requires explicit approval:

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
4. ⬜ Apply resources in order: `project.yaml` → `warehouse.yaml` → `stages.yaml`
5. ⬜ Apply ApplicationSet: `applicationset.yaml`
6. ⬜ Make a change to `helm-chart/` and watch auto-promotion to dev
7. ⬜ Manually promote to production
8. ⬜ Try rolling back a promotion

Happy GitOps! 🚀

