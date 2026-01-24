#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

kubectl apply \
    -f applicationset.yaml \
    -f project.yaml

# Wait for namespace to be created by Project
sleep 2

kubectl apply \
    -f projectconfig.yaml \
    -f warehouse.yaml \
    -f stages.yaml

