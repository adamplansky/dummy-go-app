# Bundling and Pushing Helm Charts to OCI Registry

## Prerequisites

- Helm 3.8.0+ (OCI support is enabled by default)
- Access to an OCI-compatible registry (e.g., Docker Hub, GitHub Container Registry, AWS ECR, Azure ACR)

## Steps

### 1. Login to your OCI Registry

```bash
# For Docker Hub
helm registry login registry-1.docker.io -u <username>

# For GitHub Container Registry
helm registry login ghcr.io -u <username>

# For AWS ECR
aws ecr get-login-password --region <region> | helm registry login --username AWS --password-stdin <account>.dkr.ecr.<region>.amazonaws.com

# For Azure ACR
helm registry login <registry-name>.azurecr.io -u <username>
```

### 2. Package the Helm Chart

```bash
# Navigate to directory containing your chart
cd /path/to/charts

# Package the chart (creates a .tgz file)
helm package ./my-chart

# This creates: my-chart-<version>.tgz
```

### 3. Push to OCI Registry

```bash
# Push the packaged chart to OCI registry
helm push my-chart-0.1.0.tgz oci://registry-1.docker.io/<namespace>

# Example for GitHub Container Registry
helm push my-chart-0.1.0.tgz oci://ghcr.io/<owner>

# Example for AWS ECR
helm push my-chart-0.1.0.tgz oci://<account>.dkr.ecr.<region>.amazonaws.com
```

### 4. Verify the Push

```bash
# Show chart info from registry
helm show all oci://registry-1.docker.io/<namespace>/my-chart --version 0.1.0
```

## Installing from OCI Registry

```bash
# Install directly from OCI registry
helm install my-release oci://registry-1.docker.io/<namespace>/my-chart --version 0.1.0

# Or pull first, then install
helm pull oci://registry-1.docker.io/<namespace>/my-chart --version 0.1.0
helm install my-release my-chart-0.1.0.tgz
```

## Inspecting Helm Chart Contents

### View Chart Metadata

```bash
# Show chart definition (Chart.yaml)
helm show chart oci://registry-1.docker.io/<namespace>/my-chart --version 0.1.0

# Show default values (values.yaml)
helm show values oci://registry-1.docker.io/<namespace>/my-chart --version 0.1.0

# Show README
helm show readme oci://registry-1.docker.io/<namespace>/my-chart --version 0.1.0

# Show everything (chart, values, readme)
helm show all oci://registry-1.docker.io/<namespace>/my-chart --version 0.1.0
```

### Extract and Explore Chart Files

```bash
# Pull the chart without unpacking (downloads .tgz)
helm pull oci://registry-1.docker.io/<namespace>/my-chart --version 0.1.0

# Pull and unpack to a directory
helm pull oci://registry-1.docker.io/<namespace>/my-chart --version 0.1.0 --untar

# Pull, unpack to a specific directory
helm pull oci://registry-1.docker.io/<namespace>/my-chart --version 0.1.0 --untar --untardir ./charts

# Explore the extracted chart
ls -la my-chart/
cat my-chart/Chart.yaml
cat my-chart/values.yaml
ls my-chart/templates/
```

### Preview Rendered Templates

```bash
# Render templates locally without installing (from OCI)
helm template my-release oci://registry-1.docker.io/<namespace>/my-chart --version 0.1.0

# Render with custom values
helm template my-release oci://registry-1.docker.io/<namespace>/my-chart --version 0.1.0 -f my-values.yaml

# Render a specific template
helm template my-release oci://registry-1.docker.io/<namespace>/my-chart --version 0.1.0 -s templates/deployment.yaml

# Dry-run install to see what would be deployed
helm install my-release oci://registry-1.docker.io/<namespace>/my-chart --version 0.1.0 --dry-run --debug
```

### Inspect a Local .tgz Chart

```bash
# List contents of the tarball
tar tzf my-chart-0.1.0.tgz

# Extract and view
tar xzf my-chart-0.1.0.tgz
cat my-chart/Chart.yaml
```

## Quick Reference Commands

| Action | Command |
|--------|---------|
| Login | `helm registry login <registry>` |
| Package | `helm package ./chart-dir` |
| Push | `helm push chart.tgz oci://<registry>/<repo>` |
| Pull | `helm pull oci://<registry>/<repo>/chart --version x.y.z` |
| Install | `helm install release oci://<registry>/<repo>/chart` |
| Show | `helm show all oci://<registry>/<repo>/chart` |

## Example Workflow

```bash
# Complete example for Docker Hub
helm registry login registry-1.docker.io -u myuser
helm package ./helm-chart
helm push dummy-go-app-1.0.0.tgz oci://registry-1.docker.io/<user>
helm install myapp oci://registry-1.docker.io/<user>/dummy-go-app --version 1.0.0
```

