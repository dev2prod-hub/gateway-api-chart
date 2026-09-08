#!/usr/bin/env bash
# Fail if any chart's appVersion has drifted from the vendored CRD bundle.
#
# Shared by the appversion-matches-crds pre-commit hook and CI (lint-test.yaml)
# so there is exactly one place that knows how to read the vendored bundle
# version -- a multi-line copy of this logic previously lived inline in
# .pre-commit-config.yaml, where YAML folding silently dropped the CRD_DIR
# argument from the grep pipeline (see git history) and made the check
# unreliable.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CRD_DIR="${REPO_ROOT}/charts/gateway-api/crds"

# Any vendored CRD carries the bundle it came from; they are all vendored
# together so any one of them names the bundle for the whole tree.
bundle="$(grep -rhom1 'gateway.networking.k8s.io/bundle-version: v[0-9.]*' "$CRD_DIR" \
  | head -1 | sed 's/.*: v//')"
[[ -n "$bundle" ]] || { echo "error: no vendored bundle-version found under ${CRD_DIR}" >&2; exit 1; }

fail=0
for chart_file in "${REPO_ROOT}"/charts/*/Chart.yaml; do
  av="$(grep -m1 '^appVersion:' "$chart_file" | tr -d '"' | awk '{print $2}')"
  if [[ "$av" != "$bundle" ]]; then
    echo "${chart_file}: appVersion ${av} != vendored CRD bundle ${bundle}" >&2
    fail=1
  fi
done
exit "$fail"
