#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/../manifests"

kubectl apply \
    -f applicationset.yaml \
    -f project.yaml

sleep 2  # wait for namespace

kubectl apply \
    -f projectconfig.yaml \
    -f warehouse.yaml \
    -f analysis-template.yaml \
    -f stages.yaml
