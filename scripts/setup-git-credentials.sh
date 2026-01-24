#!/bin/bash
# Create SSH credentials for both Kargo and ArgoCD.
# This script:
#   1. Generates an SSH deploy key (if not exists)
#   2. Creates a Kubernetes secret for Kargo
#   3. Adds the repository to ArgoCD with SSH credentials
set -euo pipefail

: "${NAMESPACE:=dummy-go-app}"
: "${SECRET_NAME:=github-creds}"
: "${REPO_URL:=git@github.com:adamplansky/dummy-go-app.git}"
: "${SSH_KEY_PATH:=$HOME/.ssh/kargo_deploy_key}"
: "${SETUP_ARGOCD:=true}"

die() { echo "error: $*" >&2; exit 1; }
confirm() { read -p "$1 [y/N] " -n 1 -r; echo; [[ $REPLY =~ ^[Yy]$ ]]; }
ssh_test() { ssh -T -i "$1" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=accept-new git@github.com 2>&1 || true; }

repo_path=${REPO_URL#*github.com?}; repo_path=${repo_path%.git}

echo "=============================================="
echo "  SSH Credentials Setup for Kargo + ArgoCD"
echo "=============================================="
echo ""
echo "Repository: $REPO_URL"
echo "SSH Key:    $SSH_KEY_PATH"
echo "Namespace:  $NAMESPACE"
echo ""

# Warn about personal keys
[[ "$SSH_KEY_PATH" =~ /(id_ed25519|id_rsa)$ ]] && {
    echo "⚠️  WARNING: Using personal SSH key is not recommended (use deploy key)"
    confirm "Continue anyway?" || exit 1
}

# Generate SSH key if needed
if [[ ! -f "$SSH_KEY_PATH" ]]; then
    echo "📝 Generating new SSH deploy key..."
    mkdir -p "$(dirname "$SSH_KEY_PATH")"
    ssh-keygen -t ed25519 -C "kargo-argocd-deploy" -f "$SSH_KEY_PATH" -N ""
    echo ""
    echo "=============================================="
    echo "  ⚠️  ACTION REQUIRED: Add key to GitHub"
    echo "=============================================="
    echo ""
    echo "1. Go to: https://github.com/$repo_path/settings/keys"
    echo "2. Click 'Add deploy key'"
    echo "3. Title: 'Kargo/ArgoCD Deploy Key'"
    echo "4. Paste this public key:"
    echo ""
    echo "---BEGIN PUBLIC KEY---"
    cat "${SSH_KEY_PATH}.pub"
    echo "---END PUBLIC KEY---"
    echo ""
    echo "5. ✅ CHECK 'Allow write access' (required for Kargo promotions!)"
    echo "6. Click 'Add key'"
    echo ""
    confirm "Have you added the key to GitHub with write access?" || exit 1
fi

# Validate key
[[ -r "$SSH_KEY_PATH" ]] || die "Cannot read $SSH_KEY_PATH"
head -1 "$SSH_KEY_PATH" | grep -q "PRIVATE KEY" || die "Invalid key format: $SSH_KEY_PATH"

# Test SSH connection
echo ""
echo "🔐 Testing SSH connection to GitHub..."
if ssh_test "$SSH_KEY_PATH" | grep -qi "successfully authenticated"; then
    echo "✅ SSH authentication successful"
else
    echo "❌ SSH authentication failed"
    echo "   Make sure the public key is added to GitHub"
    confirm "Continue anyway?" || exit 1
fi

# Setup Kargo credentials
echo ""
echo "📦 Setting up Kargo credentials..."
if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &>/dev/null; then
    confirm "Secret '$SECRET_NAME' exists in namespace '$NAMESPACE'. Replace it?" || {
        echo "Skipping Kargo secret creation"
    }
    kubectl delete secret "$SECRET_NAME" -n "$NAMESPACE" 2>/dev/null || true
fi

if kubectl get namespace "$NAMESPACE" &>/dev/null; then
    kubectl create secret generic "$SECRET_NAME" -n "$NAMESPACE" \
        --from-literal=repoURL="$REPO_URL" \
        --from-file=sshPrivateKey="$SSH_KEY_PATH"
    kubectl label secret "$SECRET_NAME" -n "$NAMESPACE" kargo.akuity.io/cred-type=git --overwrite
    echo "✅ Created Kargo secret: $NAMESPACE/$SECRET_NAME"
else
    echo "⚠️  Namespace '$NAMESPACE' does not exist. Skipping Kargo secret."
    echo "   Run this script again after creating the namespace with:"
    echo "   kubectl apply -f kargo/manifests/project.yaml"
fi

# Setup ArgoCD credentials
if [[ "$SETUP_ARGOCD" == "true" ]]; then
    echo ""
    echo "🔄 Setting up ArgoCD repository credentials..."

    argocd_manual_instructions() {
        echo ""
        echo "   Option 1 - Using ArgoCD CLI:"
        echo "   argocd login <argocd-server>"
        echo "   argocd repo add $REPO_URL --ssh-private-key-path $SSH_KEY_PATH"
        echo ""
        echo "   Option 2 - Using kubectl (create secret directly):"
        echo "   kubectl create secret generic repo-${SECRET_NAME} -n argocd \\"
        echo "     --from-literal=type=git \\"
        echo "     --from-literal=url=$REPO_URL \\"
        echo "     --from-file=sshPrivateKey=$SSH_KEY_PATH"
        echo "   kubectl label secret repo-${SECRET_NAME} -n argocd argocd.argoproj.io/secret-type=repository"
    }

    if command -v argocd &>/dev/null; then
        # Check if logged in (suppress all output including JSON errors)
        # Use subshell to completely isolate the command's output
        if ( argocd account get-user-info --grpc-web ) >/dev/null 2>&1; then
            # Check if repo already exists
            if argocd repo get "$REPO_URL" >/dev/null 2>&1; then
                echo "Repository already configured in ArgoCD"
                confirm "Update ArgoCD repository credentials?" && {
                    argocd repo rm "$REPO_URL" 2>/dev/null || true
                    argocd repo add "$REPO_URL" --ssh-private-key-path "$SSH_KEY_PATH"
                    echo "✅ Updated ArgoCD repository credentials"
                }
            else
                argocd repo add "$REPO_URL" --ssh-private-key-path "$SSH_KEY_PATH"
                echo "✅ Added repository to ArgoCD"
            fi
        else
            echo "⚠️  ArgoCD CLI session expired or not logged in."
            echo "   Configure ArgoCD repository manually:"
            argocd_manual_instructions
        fi
    else
        echo "⚠️  ArgoCD CLI not found. Configure ArgoCD repository manually:"
        argocd_manual_instructions
    fi
fi

echo ""
echo "=============================================="
echo "  ✅ Setup Complete"
echo "=============================================="
echo ""
echo "Next steps:"
echo "  1. Apply Kargo resources: ./kargo/scripts/apply-all.sh"
echo "  2. Apply ArgoCD ApplicationSet: kubectl apply -f kargo/manifests/applicationset.yaml"
echo ""

