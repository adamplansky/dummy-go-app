# Kargo Stages Guide

> ⚠️ **SSH Key Required**: Stages push rendered manifests to Git. You must set up SSH credentials first!
> Run `./scripts/setup-git-credentials.sh` and add the key to GitHub with write access.
> See the main [README](../README.md) for details.

A **Stage** is an environment (dev, staging, production) in your delivery pipeline. Stages define *what* artifacts to deploy, *how* to deploy them, and *when* they're ready for the next environment.

```
Warehouse ──▶ DEV ──▶ STAGING ──▶ PRODUCTION
   │           │         │            │
creates    auto-     manual       manual
freight   promote    promote      promote
```

---

## The Three Core Components

Every Stage has three parts:

| Component | Purpose | Required |
|-----------|---------|----------|
| `requestedFreight` | What artifacts this stage accepts | ✅ Yes |
| `promotionTemplate` | How to deploy those artifacts | ✅ Yes |
| `verification` | Post-deployment testing | ❌ Optional |

---

## 1. requestedFreight: Where Artifacts Come From

### First stage (dev): Direct from Warehouse

```yaml
spec:
  requestedFreight:
    - origin:
        kind: Warehouse
        name: dummy-go-app
      sources:
        direct: true    # Receives freight immediately
```

### Downstream stages: From upstream stages

```yaml
spec:
  requestedFreight:
    - origin:
        kind: Warehouse
        name: dummy-go-app
      sources:
        stages:
          - dev         # Only accepts freight verified in dev
```

### Advanced options

```yaml
sources:
  stages: [qa, uat]
  availabilityStrategy: All    # Must pass ALL stages (default: OneOf)
  requiredSoakTime: 4h         # Must be stable for 4 hours first
```

---

## 2. promotionTemplate: How Deployment Happens

```yaml
promotionTemplate:
  spec:
    vars:
      - name: gitRepo
        value: https://github.com/adamplansky/dummy-go-app.git
    steps:
      - uses: git-clone
        as: clone
        config:
          repoURL: ${{ vars.gitRepo }}
          checkout:
            - commit: ${{ commitFrom(vars.gitRepo).ID }}
              path: ./src
      - uses: argocd-update
        config:
          apps:
            - name: dummy-go-app-${{ ctx.stage }}
              sources:
                - repoURL: ${{ vars.gitRepo }}
                  desiredRevision: ${{ outputs.clone.commits["./src"] }}
```

### Common steps

| Step | Purpose |
|------|---------|
| `git-clone` | Clone repo at specific commit |
| `git-commit` / `git-push` | Commit and push changes |
| `argocd-update` | Sync ArgoCD Application |
| `kustomize-set-image` | Update image in kustomization |
| `kustomize-build` | Render manifests |
| `helm-template` | Render Helm chart |

### Expression functions

```yaml
${{ ctx.stage }}                           # Current stage name
${{ commitFrom(vars.gitRepo).ID }}         # Git commit SHA
${{ imageFrom("ghcr.io/org/app").Tag }}    # Image tag
${{ outputs.clone.commits["./src"] }}      # Output from previous step
```

---

## 3. verification: Post-Deployment Testing

```yaml
spec:
  verification:
    analysisTemplates:
      - name: smoke-test
    args:
      - name: target-url
        value: http://app.${{ ctx.stage }}.svc.cluster.local
```

Verification uses Argo Rollouts AnalysisTemplates. Freight is blocked from downstream stages until verification passes.

**Implicit verification**: Even without explicit verification, Kargo waits for ArgoCD Applications to reach `Healthy` state.

---

## Complete Example: dummy-go-app Pipeline

```yaml
# kargo/stages.yaml
apiVersion: kargo.akuity.io/v1alpha1
kind: Stage
metadata:
  name: dev
  namespace: dummy-go-app
spec:
  requestedFreight:
    - origin:
        kind: Warehouse
        name: dummy-go-app
      sources:
        direct: true              # First in pipeline
  promotionTemplate:
    spec:
      vars:
        - name: gitRepo
          value: https://github.com/adamplansky/dummy-go-app.git
      steps:
        - uses: git-clone
          as: clone
          config:
            repoURL: ${{ vars.gitRepo }}
            checkout:
              - commit: ${{ commitFrom(vars.gitRepo).ID }}
                path: ./src
        - uses: argocd-update
          config:
            apps:
              - name: dummy-go-app-dev
                sources:
                  - repoURL: ${{ vars.gitRepo }}
                    desiredRevision: ${{ outputs.clone.commits["./src"] }}
---
apiVersion: kargo.akuity.io/v1alpha1
kind: Stage
metadata:
  name: staging
  namespace: dummy-go-app
spec:
  requestedFreight:
    - origin:
        kind: Warehouse
        name: dummy-go-app
      sources:
        stages: [dev]             # Requires dev verification
  promotionTemplate:
    spec:
      vars:
        - name: gitRepo
          value: https://github.com/adamplansky/dummy-go-app.git
      steps:
        - uses: git-clone
          as: clone
          config:
            repoURL: ${{ vars.gitRepo }}
            checkout:
              - commit: ${{ commitFrom(vars.gitRepo).ID }}
                path: ./src
        - uses: argocd-update
          config:
            apps:
              - name: dummy-go-app-staging
                sources:
                  - repoURL: ${{ vars.gitRepo }}
                    desiredRevision: ${{ outputs.clone.commits["./src"] }}
---
apiVersion: kargo.akuity.io/v1alpha1
kind: Stage
metadata:
  name: production
  namespace: dummy-go-app
spec:
  requestedFreight:
    - origin:
        kind: Warehouse
        name: dummy-go-app
      sources:
        stages: [staging]         # Requires staging verification
  promotionTemplate:
    spec:
      vars:
        - name: gitRepo
          value: https://github.com/adamplansky/dummy-go-app.git
      steps:
        - uses: git-clone
          as: clone
          config:
            repoURL: ${{ vars.gitRepo }}
            checkout:
              - commit: ${{ commitFrom(vars.gitRepo).ID }}
                path: ./src
        - uses: argocd-update
          config:
            apps:
              - name: dummy-go-app-production
                sources:
                  - repoURL: ${{ vars.gitRepo }}
                    desiredRevision: ${{ outputs.clone.commits["./src"] }}
```

---

## Auto-Promotion

Configured in `ProjectConfig`, not in Stages (for security):

```yaml
# kargo/projectconfig.yaml
apiVersion: kargo.akuity.io/v1alpha1
kind: ProjectConfig
metadata:
  name: dummy-go-app
  namespace: dummy-go-app
spec:
  promotionPolicies:
    - stage: dev
      autoPromotionEnabled: true      # Auto-deploy to dev
    - stage: staging
      autoPromotionEnabled: false     # Manual approval
    - stage: production
      autoPromotionEnabled: false     # Manual approval
```

---

## ArgoCD Integration

ArgoCD Applications **must authorize** Kargo to manage them:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: dummy-go-app-dev
  namespace: argocd
  annotations:
    kargo.akuity.io/authorized-stage: dummy-go-app:dev  # Required!
spec:
  source:
    repoURL: https://github.com/adamplansky/dummy-go-app.git
    targetRevision: main
    path: helm-chart
  destination:
    server: https://kubernetes.default.svc
    namespace: dummy-go-app-dev
```

---

## Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| Freight not appearing | Warehouse misconfigured | Check `kubectl describe warehouse -n dummy-go-app` |
| Promotion stuck pending | Another promotion running | Wait or check `kubectl get promotions -n dummy-go-app` |
| argocd-update fails | Missing authorization | Add `kargo.akuity.io/authorized-stage` annotation |
| Verification fails | AnalysisTemplate error | Check `kubectl get analysisrun -n dummy-go-app` |
| "non-fast-forward" error | Git race condition | Use stage-specific branches |

### Debug commands

```bash
kubectl get stages -n dummy-go-app              # Stage status
kubectl get freight -n dummy-go-app             # Available freight
kubectl get promotions -n dummy-go-app          # Promotion history
kubectl describe stage dev -n dummy-go-app      # Detailed status
kubectl logs -n kargo -l app.kubernetes.io/component=controller  # Controller logs
```

---

## Quick Reference

### Stage sources

| Stage Position | Configuration | Effect |
|----------------|---------------|--------|
| First (dev) | `sources.direct: true` | Gets freight immediately |
| Middle/End | `sources.stages: [upstream]` | Waits for upstream verification |

### Common patterns

| Pattern | Configuration |
|---------|---------------|
| Auto-promote dev | `autoPromotionEnabled: true` in ProjectConfig |
| Require soak time | `requiredSoakTime: 4h` in sources |
| Parallel verification | `stages: [qa, uat]` with `availabilityStrategy: All` |
| PR-based production | Use `git-open-pr` + `git-wait-for-pr` steps |

### Pipeline flow

```
1. Warehouse detects new artifact → creates Freight
2. Dev stage auto-promotes → ArgoCD syncs → Freight verified
3. Staging: Freight available → manual promote → verified
4. Production: Freight available → manual promote → deployed
```

