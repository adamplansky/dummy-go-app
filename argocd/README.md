# ArgoCD CLI Cheatsheet

## Installation

```bash
# macOS
brew install argocd

# Linux
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd && sudo mv argocd /usr/local/bin/
```

## Authentication

```bash
# Login to ArgoCD server
argocd login <ARGOCD_SERVER> --username admin --password <PASSWORD>

# Login with SSO
argocd login <ARGOCD_SERVER> --sso

# Get current context
argocd context

# Switch context
argocd context <CONTEXT_NAME>
```

## Application Management

```bash
# List all applications
argocd app list

# Get application details
argocd app get <APP_NAME>

# Create application
argocd app create <APP_NAME> \
  --repo <REPO_URL> \
  --path <PATH> \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace <NAMESPACE>

# Delete application
argocd app delete <APP_NAME>

# Sync application (deploy)
argocd app sync <APP_NAME>

# Sync with prune (remove resources not in git)
argocd app sync <APP_NAME> --prune

# Force sync (replace resources)
argocd app sync <APP_NAME> --force

# Sync specific resources only
argocd app sync <APP_NAME> --resource <GROUP>:<KIND>:<NAME>

# Hard refresh (clear cache)
argocd app get <APP_NAME> --hard-refresh
```

## Application Status & History

```bash
# View app diff (what would change)
argocd app diff <APP_NAME>

# View sync history
argocd app history <APP_NAME>

# Rollback to previous version
argocd app rollback <APP_NAME> <HISTORY_ID>

# View application logs
argocd app logs <APP_NAME>

# View logs for specific container
argocd app logs <APP_NAME> --container <CONTAINER_NAME>

# Watch app status in real-time
argocd app wait <APP_NAME>
```

## Project Management

```bash
# List projects
argocd proj list

# Get project details
argocd proj get <PROJECT_NAME>

# Create project
argocd proj create <PROJECT_NAME>
```

## Cluster Management

```bash
# List clusters
argocd cluster list

# Add cluster
argocd cluster add <CONTEXT_NAME>

# Remove cluster
argocd cluster rm <SERVER_URL>
```

## Repository Management

```bash
# List repositories
argocd repo list

# Add repository (HTTPS)
argocd repo add <REPO_URL> --username <USER> --password <PASSWORD>

# Add repository (SSH)
argocd repo add <REPO_URL> --ssh-private-key-path <PATH>

# Remove repository
argocd repo rm <REPO_URL>
```

## Account & RBAC

```bash
# Get current user info
argocd account get-user-info

# List accounts
argocd account list

# Update password
argocd account update-password

# Generate auth token
argocd account generate-token --account <ACCOUNT>
```

## Useful Flags

```bash
# Output as JSON
argocd app list -o json

# Output as YAML
argocd app get <APP_NAME> -o yaml

# Use specific config file
argocd --config <PATH>

# Skip TLS verification (dev only)
argocd login <SERVER> --insecure
```

## Common Workflows

```bash
# Quick deploy: sync and wait
argocd app sync <APP_NAME> && argocd app wait <APP_NAME>

# Preview changes before sync
argocd app diff <APP_NAME> && argocd app sync <APP_NAME> --dry-run

# Terminate running sync operation
argocd app terminate-op <APP_NAME>
```

