#!/bin/bash
# Delete k8s secret with SSH credentials.
set -euo pipefail

: "${NAMESPACE:=dummy-go-app}"
: "${SECRET_NAME:=github-creds}"

confirm() { read -p "$1 [y/N] " -n 1 -r; echo; [[ $REPLY =~ ^[Yy]$ ]]; }

kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &>/dev/null || { echo "not found: $NAMESPACE/$SECRET_NAME"; exit 0; }

echo "$NAMESPACE/$SECRET_NAME"
confirm "delete?" || exit 0

kubectl delete secret "$SECRET_NAME" -n "$NAMESPACE"
echo "also remove from GitHub: https://github.com/settings/keys"
