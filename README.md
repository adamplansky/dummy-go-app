# Dummy Go App Helm Chart

This guide explains how to create a custom Helm chart wrapper for a dummy Go application that uses [Podinfo](https://github.com/stefanprodan/podinfo) as a dependency.

## Overview

Podinfo is a tiny web application made with Go that showcases best practices of running microservices in Kubernetes. This chart wraps Podinfo as a dependency, allowing you to customize and extend it for your needs.

## Prerequisites

- Kubernetes cluster (local or remote)
- `kubectl` configured to access your cluster
- `helm` v3.x installed
- Docker (optional, for building custom images)

### Step 1: Create Chart Structure

```bash
cd dummy-go-app
mkdir -p helm-chart/templates
cd helm-chart
```

### Step 2: Create Chart.yaml

Create `Chart.yaml`:

```yaml
apiVersion: v2
name: dummy-go-app
description: A dummy Go application using Podinfo
type: application
version: 1.0.0
appVersion: "6.9.4"

dependencies:
  - name: podinfo
    version: "6.9.4"
    repository: "https://stefanprodan.github.io/podinfo"
```

### Step 3: Create values.yaml

Create `values.yaml`:

```yaml
# Override podinfo default values
podinfo:
  replicaCount: 2

  image:
    repository: ghcr.io/stefanprodan/podinfo
    tag: 6.9.4
    pullPolicy: IfNotPresent

  ui:
    color: "#34577c"
    message: "My Dummy Go Application"

  service:
    enabled: true
    type: ClusterIP
    httpPort: 9898

  resources:
    limits:
      cpu: 500m
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 64Mi
```

### Step 4: Update Dependencies

```bash
helm dependency update
```

### Step 5: Install the Chart

```bash
helm install dummy-app . \
  --namespace dummy-app \
  --create-namespace

# Or with custom values
helm install dummy-app . \
  --namespace dummy-app \
  --create-namespace \
  --set podinfo.replicaCount=3 \
  --set podinfo.ui.message="Custom Message"
```

## Accessing the Application

```bash
# Port forward to access the app
kubectl port-forward -n dummy-app svc/dummy-app-podinfo 9898:9898

# Visit http://localhost:9898
```

## Cleanup

```bash
# Uninstall the Helm release
helm uninstall dummy-app -n dummy-app

# Delete the namespace
kubectl delete namespace dummy-app
```



