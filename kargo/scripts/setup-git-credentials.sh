#!/bin/bash
# Create k8s secret with SSH key for Kargo git operations.
set -euo pipefail

: "${NAMESPACE:=dummy-go-app}"
: "${SECRET_NAME:=github-creds}"
: "${REPO_URL:=git@github.com:adamplansky/dummy-go-app.git}"
: "${SSH_KEY_PATH:=$HOME/.ssh/kargo_deploy_key}"

die() { echo "error: $*" >&2; exit 1; }
confirm() { read -p "$1 [y/N] " -n 1 -r; echo; [[ $REPLY =~ ^[Yy]$ ]]; }
ssh_test() { ssh -T -i "$1" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=accept-new git@github.com 2>&1 || true; }

repo_path=${REPO_URL#*github.com?}; repo_path=${repo_path%.git}

[[ "$SSH_KEY_PATH" =~ /(id_ed25519|id_rsa)$ ]] && {
    echo "warning: personal key not recommended (use deploy key)"
    confirm "continue?" || exit 1
}

if [[ ! -f "$SSH_KEY_PATH" ]]; then
    mkdir -p "$(dirname "$SSH_KEY_PATH")"
    ssh-keygen -t ed25519 -C "kargo-deploy" -f "$SSH_KEY_PATH" -N ""
    echo -e "\nadd to GitHub (enable write access):"
    echo "  https://github.com/$repo_path/settings/keys"
    cat "${SSH_KEY_PATH}.pub"
    confirm "done?" || exit 1
fi

[[ -r "$SSH_KEY_PATH" ]] || die "cannot read $SSH_KEY_PATH"
head -1 "$SSH_KEY_PATH" | grep -q "PRIVATE KEY" || die "invalid key: $SSH_KEY_PATH"

echo "testing $SSH_KEY_PATH..."
if ssh_test "$SSH_KEY_PATH" | grep -qi "successfully authenticated"; then
    echo "ok"
else
    echo "failed (ensure key is added to GitHub)"
    confirm "continue?" || exit 1
fi

kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &>/dev/null && {
    confirm "replace existing secret?" || exit 0
    kubectl delete secret "$SECRET_NAME" -n "$NAMESPACE"
}

kubectl create secret generic "$SECRET_NAME" -n "$NAMESPACE" \
    --from-literal=repoURL="$REPO_URL" \
    --from-file=sshPrivateKey="$SSH_KEY_PATH"
kubectl label secret "$SECRET_NAME" -n "$NAMESPACE" kargo.akuity.io/cred-type=git

echo "created $NAMESPACE/$SECRET_NAME"
