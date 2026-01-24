#!/bin/bash
# Test SSH key from k8s secret.
set -euo pipefail

: "${NAMESPACE:=dummy-go-app}"
: "${SECRET_NAME:=github-creds}"

die() { echo "error: $*" >&2; exit 1; }
ssh_test() { ssh -T -i "$1" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=accept-new git@github.com 2>&1 || true; }

kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &>/dev/null || die "secret not found: $NAMESPACE/$SECRET_NAME"

tmp=$(mktemp); trap "rm -f $tmp" EXIT
kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.sshPrivateKey}' | base64 -d > "$tmp"
chmod 600 "$tmp"

head -1 "$tmp" | grep -q "PRIVATE KEY" || die "invalid key in secret"

repo=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.repoURL}' | base64 -d 2>/dev/null || echo "-")
echo "testing $NAMESPACE/$SECRET_NAME (repo: $repo)"

if ssh_test "$tmp" | grep -qi "successfully authenticated"; then
    echo "ok"
else
    echo "failed"
    ssh-keygen -lf "$tmp" 2>/dev/null && echo "add key to: https://github.com/settings/keys"
    exit 1
fi
