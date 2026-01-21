# Dummy Go App

A multi-environment Helm chart for deploying [Podinfo](https://github.com/stefanprodan/podinfo) using ArgoCD GitOps workflow.

## Overview

This project provides a GitOps-ready Helm chart wrapper for Podinfo with multi-environment support (dev/production). It follows DRY principles with a base values configuration and environment-specific overrides.

**Features:**
- ArgoCD-based GitOps deployment
- Multi-environment support (dev, production)
- DRY values structure (base + overrides)
- Automated sync with self-healing

## Project Structure

```
├── argocd/
│   └── applications/
│       ├── dev.yaml              # ArgoCD Application for dev
│       └── production.yaml       # ArgoCD Application for production
├── helm-chart/
│   ├── Chart.yaml                # Chart definition with Podinfo dependency
│   ├── values.yaml               # Base values (shared across environments)
│   ├── values-dev.yaml           # Dev-specific overrides
│   ├── values-production.yaml    # Production-specific overrides
│   └── charts/                   # Downloaded dependencies
└── README.md
```

### Values Hierarchy

Values are loaded in order (later files override earlier):
1. `values.yaml` — Common defaults (image, ingress structure, service config)
2. `values-{env}.yaml` — Environment overrides (replicas, resources, UI, host)

| Setting | Base | Dev | Production |
|---------|------|-----|------------|
| Replicas | - | 1 | 3 |
| Host | - | podinfo-dev.localhost | podinfo-production.localhost |
| UI Color | - | 🔵 Blue | 🟢 Green |
| Resources | - | Lower | Higher |
| Log Level | - | debug | info |

---

## ArgoCD Deployment (Recommended)

### Prerequisites

- Kubernetes cluster with ArgoCD installed
- ArgoCD can access this Git repository
- `kubectl` configured to access your cluster

### Deploy Dev Environment

```bash
kubectl apply -f argocd/applications/dev.yaml
```

### Deploy Production Environment

```bash
kubectl apply -f argocd/applications/production.yaml
```

### Verify Deployments

```bash
# Check ArgoCD applications
kubectl get applications -n argocd

# Check pods in each environment
kubectl get pods -n dummy-app-dev
kubectl get pods -n dummy-app-production

# Using ArgoCD CLI
argocd app list
argocd app get dummy-go-app-dev
argocd app get dummy-go-app-production
```

### Sync Applications

```bash
# Sync dev
argocd app sync dummy-go-app-dev

# Sync production
argocd app sync dummy-go-app-production
```

---

## Accessing the Application

### Dev Environment

```bash
kubectl port-forward -n dummy-app-dev svc/dummy-go-app-dev-podinfo 9898:9898
# Visit http://localhost:9898
```

Or via ingress: `http://podinfo-dev.localhost`

### Production Environment

```bash
kubectl port-forward -n dummy-app-production svc/dummy-go-app-production-podinfo 9898:9898
# Visit http://localhost:9898
```

Or via ingress: `http://podinfo-production.localhost`

---

## Local Development with Helm

For local testing without ArgoCD:

### Prerequisites

- `helm` v3.x installed
- `kubectl` configured to access your cluster

### Update Dependencies

```bash
cd helm-chart
helm dependency update
```

### Install with Dev Values

```bash
helm install dummy-app-dev . \
  -f values.yaml \
  -f values-dev.yaml \
  --namespace dummy-app-dev \
  --create-namespace
```

### Install with Production Values

```bash
helm install dummy-app-prod . \
  -f values.yaml \
  -f values-production.yaml \
  --namespace dummy-app-production \
  --create-namespace
```

---

## Cleanup

### ArgoCD

```bash
# Delete applications
kubectl delete -f argocd/applications/dev.yaml
kubectl delete -f argocd/applications/production.yaml

# Delete namespaces
kubectl delete namespace dummy-app-dev
kubectl delete namespace dummy-app-production
```

### Helm

```bash
helm uninstall dummy-app-dev -n dummy-app-dev
helm uninstall dummy-app-prod -n dummy-app-production
kubectl delete namespace dummy-app-dev dummy-app-production
```



