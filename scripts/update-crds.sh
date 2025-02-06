#!/usr/bin/env bash
set -euo pipefail

# Use latest release if no version specified
VERSION="${1:-$(curl -s https://api.github.com/repos/kubernetes-sigs/gateway-api/releases/latest | jq -r .tag_name)}"
REPO_ROOT=$(git rev-parse --show-toplevel)
TARGET_DIR="${REPO_ROOT}/charts/gateway-api/crds"

# Create temporary working directory
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

# Download and extract CRDs
curl -sL "https://github.com/kubernetes-sigs/gateway-api/archive/refs/tags/${VERSION}.tar.gz" | \
  tar -xz -C "$WORK_DIR" --strip-components=3 "gateway-api-${VERSION#v}/config/crd/experimental"

# Update local CRDs
rsync -av --delete --exclude kustomization.yaml "$WORK_DIR/" "$TARGET_DIR/"

# Commit changes
#git add "$TARGET_DIR"
#git commit -m "Update CRDs to gateway-api@${VERSION}"
