#!/bin/bash
# Wrapper script - calls the shared setup script at the repository root.
# This script sets up SSH credentials for both Kargo AND ArgoCD.
#
# For the full script, see: scripts/setup-git-credentials.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

exec "$REPO_ROOT/scripts/setup-git-credentials.sh" "$@"
