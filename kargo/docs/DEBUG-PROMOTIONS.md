# Debugging Kargo Promotions

This guide helps you debug common Kargo promotion issues.

## Quick Diagnostic Commands

```bash
# 1. Check promotion status
kubectl get promotions -n dummy-go-app -o wide

# 2. Get detailed promotion info
kubectl describe promotion <promotion-name> -n dummy-go-app

# 3. Check stage status
kubectl get stages -n dummy-go-app -o wide

# 4. Check freight
kubectl get freight -n dummy-go-app -o wide

# 5. View Kargo controller logs
kubectl logs -n kargo -l app.kubernetes.io/component=controller --tail=100 -f

# 6. Check ArgoCD Application status
kubectl get application dummy-go-app-dev -n argocd -o yaml
```

---

## Common Issues

### Issue 1: "sync result revision does not match desired revision"

**Symptoms:**
```
sync result revisions [d4ee6e7...] do not match desired revisions [dadde52...]
```

**Root Cause:**
Kargo is trying to deploy a specific commit, but ArgoCD keeps syncing to a different commit.

**Common Causes:**

1. **`targetRevision: HEAD` in ApplicationSet** - ArgoCD resolves HEAD to the default branch (usually `main`), not your working branch (`kargo`)

2. **Branch mismatch** - Warehouse watches branch `kargo`, but ApplicationSet uses default branch

3. **ApplicationSet overrides Kargo changes** - ApplicationSet continuously reconciles, resetting any changes Kargo makes

**Solution Options:**

#### Option A: Change ApplicationSet to use `kargo` branch
```yaml
spec:
  template:
    spec:
      source:
        targetRevision: kargo  # Instead of HEAD
```

#### Option B: Let Kargo manage targetRevision (requires allowedSourceTypes)
For Kargo to update the Application's targetRevision, the ArgoCD Application must:
1. Have `kargo.akuity.io/authorized-stage` annotation ✅
2. Kargo must be configured with ArgoCD integration

---

### Issue 2: Promotion stuck in "Running" state

**Diagnostic:**
```bash
# Check which step is running
kubectl get promotion <name> -n dummy-go-app -o jsonpath='{.status.currentStep}'

# Check step details
kubectl describe promotion <name> -n dummy-go-app | grep -A 20 "Step Execution"
```

**Common Causes:**
- ArgoCD sync taking too long
- Revision mismatch (see Issue 1)
- ArgoCD Application not healthy

---

### Issue 3: Promotion "Errored" immediately

**Diagnostic:**
```bash
kubectl describe promotion <name> -n dummy-go-app | grep -A 10 "Message"
```

**Common Causes:**
- Invalid step configuration (e.g., `fromFreight: true` instead of expression syntax)
- Missing required fields
- Invalid expressions

---

### Issue 4: No Freight being created

**Diagnostic:**
```bash
# Check warehouse status
kubectl describe warehouse dummy-go-app -n dummy-go-app

# Check if commits are being discovered
kubectl get warehouse dummy-go-app -n dummy-go-app -o jsonpath='{.status}'
```

**Common Causes:**
- Wrong branch configured
- `includePaths` filter too restrictive
- Repository not accessible

---

## Understanding the Promotion Flow

```
┌──────────────┐     ┌─────────────────┐     ┌────────────────────┐
│   Freight    │────▶│   Promotion     │────▶│  ArgoCD Update     │
│   (commit)   │     │   Created       │     │   Step             │
└──────────────┘     └─────────────────┘     └────────────────────┘
                                                      │
                     ┌─────────────────┐              │
                     │ Kargo updates   │◀─────────────┘
                     │ ArgoCD App      │
                     │ targetRevision  │
                     └─────────────────┘
                              │
                              ▼
                     ┌─────────────────┐
                     │ ArgoCD syncs    │
                     │ to new commit   │
                     └─────────────────┘
                              │
                              ▼
                     ┌─────────────────┐
                     │ Kargo verifies  │
                     │ sync completed  │◀──── If mismatch, retries!
                     └─────────────────┘
```

---

## Live Debugging Session

```bash
# Terminal 1: Watch promotions
watch kubectl get promotions -n dummy-go-app

# Terminal 2: Watch Kargo logs
kubectl logs -n kargo -l app.kubernetes.io/component=controller -f | grep dummy-go-app

# Terminal 3: Watch ArgoCD app
watch kubectl get application dummy-go-app-dev -n argocd -o jsonpath='{.status.sync.revision}'
```

---

## Current Issue Analysis

**Your Problem:**
- Warehouse watches: `kargo` branch
- Freight commit: `dadde5265c1dc556d8f281479fd3fd4d4b77efd4` (from `kargo` branch)
- ApplicationSet targetRevision: `HEAD` (resolves to `main` branch default)
- ArgoCD syncs to: `d4ee6e7dece83282e48e738428b86f9aba10af22` (from `main` branch)

**Result:** Kargo keeps retrying because ArgoCD never syncs to the Kargo-requested commit.

**Fix:** Update ApplicationSet to use `targetRevision: kargo`

