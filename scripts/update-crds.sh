#!/usr/bin/env bash
# Vendor Gateway API CRDs into the charts.
#
#   ./scripts/update-crds.sh            # advance at most ONE minor from what is vendored
#   ./scripts/update-crds.sh v1.6.2     # vendor an exact version
#
# Upstream's most-tested upgrade path is one minor at a time, and a CRD bump is an
# unattended production change for GitOps consumers (see docs/MIGRATION.md). So the
# unattended default deliberately refuses to skip minors -- crossing two of them is
# an explicit, argument-passing decision.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

EXPERIMENTAL_DIR="${REPO_ROOT}/charts/gateway-api/crds"
STANDARD_DIR="${REPO_ROOT}/charts/gateway-api-standard/crds"

# The safe-upgrades ValidatingAdmissionPolicy ships in config/crd/ but is not a CRD:
# helm lint rejects it and Flux's helm-controller silently discards it. Operators who
# want it install it themselves -- docs/MIGRATION.md carries the command.
EXCLUDES=(--exclude kustomization.yaml --exclude 'gateway.networking.k8s.io_vap_safeupgrades.yaml')

current_bundle() {
  # Any vendored CRD carries the bundle it came from.
  grep -rhom1 'gateway.networking.k8s.io/bundle-version: v[0-9.]*' \
    "${EXPERIMENTAL_DIR}" 2>/dev/null | head -1 | sed 's/.*: //'
}

resolve_next_minor() {
  local current="$1" major minor
  major="$(printf '%s' "${current#v}" | cut -d. -f1)"
  minor="$(printf '%s' "${current#v}" | cut -d. -f2)"

  # Highest stable release no more than one minor above the vendored one. Major and
  # minor are compared as separate integers -- treating "1.10" as a decimal would
  # sort it below "1.9".
  curl -sfL 'https://api.github.com/repos/kubernetes-sigs/gateway-api/releases?per_page=100' \
    | jq -r '.[] | select(.prerelease == false) | .tag_name' \
    | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
    | awk -F. -v maj="$major" -v ceil="$((minor + 1))" '
        { m = substr($1, 2) + 0; n = $2 + 0 }
        m < maj + 0 || (m == maj + 0 && n <= ceil + 0) { print }
      ' \
    | sort -V | tail -1
}

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  CURRENT="$(current_bundle)"
  [[ -n "$CURRENT" ]] || { echo "error: no vendored bundle-version found in ${EXPERIMENTAL_DIR}" >&2; exit 1; }
  VERSION="$(resolve_next_minor "$CURRENT")"
  [[ -n "$VERSION" ]] || { echo "error: could not resolve a release at most one minor above ${CURRENT}" >&2; exit 1; }
  if [[ "$VERSION" == "$CURRENT" ]]; then
    echo "Already on ${CURRENT}; nothing to do."
    exit 0
  fi
  echo "Vendored ${CURRENT} -> advancing one minor to ${VERSION}"
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "Downloading gateway-api ${VERSION}..."
curl -sfL "https://github.com/kubernetes-sigs/gateway-api/archive/refs/tags/${VERSION}.tar.gz" \
  | tar -xz -C "$WORK_DIR" --strip-components=3 \
      "gateway-api-${VERSION#v}/config/crd/experimental" \
      "gateway-api-${VERSION#v}/config/crd/standard"

mkdir -p "$EXPERIMENTAL_DIR" "$STANDARD_DIR"
rsync -a --delete "${EXCLUDES[@]}" "$WORK_DIR/experimental/" "${EXPERIMENTAL_DIR}/experimental/"
rsync -a --delete "${EXCLUDES[@]}" "$WORK_DIR/standard/"     "${STANDARD_DIR}/standard/"

# appVersion is the version of the app the chart deploys, and that app IS Gateway
# API. Keeping it in lockstep here is what makes the in-cluster
# app.kubernetes.io/version label and the ArtifactHub listing tell the truth about
# which CRD bundle landed. No `sed -i`: its syntax differs on GNU vs BSD/macOS.
for chart in gateway-api gateway-api-routes gateway-api-standard; do
  chart_file="${REPO_ROOT}/charts/${chart}/Chart.yaml"
  [[ -f "$chart_file" ]] || continue
  tmp="$(mktemp)"
  sed "s|^appVersion:.*|appVersion: \"${VERSION#v}\"|" "$chart_file" > "$tmp" && mv "$tmp" "$chart_file"
done

echo
echo "Vendored ${VERSION}:"
printf '  experimental  %s CRDs\n' "$(find "${EXPERIMENTAL_DIR}/experimental" -name '*.yaml' | wc -l | tr -d ' ')"
printf '  standard      %s CRDs\n' "$(find "${STANDARD_DIR}/standard" -name '*.yaml' | wc -l | tr -d ' ')"
printf '  appVersion    %s in all charts\n' "${VERSION#v}"
echo
echo "Review the CRD diff and docs/MIGRATION.md before releasing. If any version"
echo "disappeared from a CRD's spec.versions, operators must migrate storage first."
