#!/usr/bin/env bash
# Prove the Gateway API CRD jump this release ships is safe on a real cluster.
#
# Why this test exists: `helm upgrade` from the CLI never touches crds/, so a CLI
# test says nothing about what GitOps consumers actually experience. Flux's
# helm-controller applies chart CRDs with server-side apply and forced conflicts
# (upgrade.crds: CreateReplace under the default serverSideApply), so the apply
# below is byte-for-byte the operation that runs against production clusters.
#
# Requires: a reachable cluster (kind), kubectl, helm.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CRD_DIR="${REPO_ROOT}/charts/gateway-api/crds/experimental"

PREVIOUS_BUNDLE="v1.4.1"
PREVIOUS_CHART="1.0.5"   # last release before this upgrade
NS="gw-upgrade-test"

pass=0; fail=0
ok()   { printf '  \033[32mPASS\033[0m %s\n' "$1"; pass=$((pass+1)); }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=$((fail+1)); [ -n "${2:-}" ] && printf '       %s\n' "$2"; }
step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }

target_bundle() {
  grep -rhom1 'gateway.networking.k8s.io/bundle-version: v[0-9.]*' "$CRD_DIR" \
    | head -1 | sed 's/.*: //'
}
TARGET_BUNDLE="$(target_bundle)"
[[ -n "$TARGET_BUNDLE" ]] || { echo "cannot read vendored bundle-version from $CRD_DIR"; exit 1; }

# This test DOWNGRADES CRDs to v1.4.1, replaces them, patches CRD status and
# flips a served version to false. That is destructive to any real cluster's
# Gateway API installation. Refuse to run anywhere but a throwaway cluster.
CONTEXT="$(kubectl config current-context)"
if [[ "$CONTEXT" != kind-* && "${ALLOW_ANY_CONTEXT:-false}" != "true" ]]; then
  cat >&2 <<MSG
refusing to run: current kube context is "${CONTEXT}", which is not a kind cluster.

This test installs Gateway API ${PREVIOUS_BUNDLE} CRDs, replaces them, patches CRD
status subresources and disables a served API version. Against a real cluster that
breaks its Gateway API installation.

Point kubectl at a throwaway cluster:

  kind create cluster --name gwtest --image kindest/node:v1.37.0
  kubectl config use-context kind-gwtest

Set ALLOW_ANY_CONTEXT=true only if you are certain the target is disposable.
MSG
  exit 1
fi

echo "Upgrade under test: ${PREVIOUS_BUNDLE} -> ${TARGET_BUNDLE} (experimental channel)"
echo "Target cluster: ${CONTEXT}"
kubectl cluster-info >/dev/null 2>&1 || { echo "no reachable cluster"; exit 1; }


step "Install the previous CRD bundle (${PREVIOUS_BUNDLE})"
kubectl apply --server-side -f \
  "https://github.com/kubernetes-sigs/gateway-api/releases/download/${PREVIOUS_BUNDLE}/experimental-install.yaml" >/dev/null
kubectl wait --for=condition=Established --timeout=90s \
  crd/tcproutes.gateway.networking.k8s.io crd/udproutes.gateway.networking.k8s.io >/dev/null

step "Install the PREVIOUS published chart so the objects are Helm-owned"
# Helm refuses to take over a resource lacking its ownership metadata, so an object
# created with kubectl would fail adoption for a reason unrelated to the CRD jump.
# A real consumer is upgrading objects created by the previous chart release.
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
helm repo add dev2prod https://charts.cdnn.host/ >/dev/null 2>&1
helm repo update dev2prod >/dev/null 2>&1
if out="$(helm install gwr dev2prod/gateway-api-routes --version "$PREVIOUS_CHART" -n "$NS" --wait --timeout 3m \
     --set tcpRoute.items[0].name=legacy-tcp \
     --set tcpRoute.items[0].parentRefs[0].name=legacy-gw \
     --set tcpRoute.items[0].rules[0].backendRefs[0].name=tcp-svc \
     --set tcpRoute.items[0].rules[0].backendRefs[0].port=9000 \
     --set udpRoute.items[0].name=legacy-udp \
     --set udpRoute.items[0].parentRefs[0].name=legacy-gw \
     --set udpRoute.items[0].rules[0].backendRefs[0].name=udp-svc \
     --set udpRoute.items[0].rules[0].backendRefs[0].port=9001 2>&1)"; then
  ok "chart ${PREVIOUS_CHART} installed, rendering routes at v1alpha2"
else
  bad "could not install the previous published chart ${PREVIOUS_CHART}" "$(echo "$out" | tail -3)"
fi

uid_before_tcp="$(kubectl get tcproute legacy-tcp -n "$NS" -o jsonpath='{.metadata.uid}')"
stored_before="$(kubectl get crd tcproutes.gateway.networking.k8s.io -o jsonpath='{.status.storedVersions}')"
echo "  TCPRoute storedVersions before: ${stored_before}"
if [[ "$stored_before" == *v1alpha2* ]]; then
  ok "objects are stored at v1alpha2 (the case that could strand an upgrade)"
else
  bad "expected v1alpha2 in storedVersions, got ${stored_before}"
fi

step "Replace CRDs exactly as Flux does (server-side apply, forced conflicts)"
rejected=""
for crd in "$CRD_DIR"/*.yaml; do
  if ! out="$(kubectl apply --server-side --force-conflicts -f "$crd" 2>&1)"; then
    rejected="${rejected}${crd##*/}\n${out}\n"
  fi
done
if [ -z "$rejected" ]; then
  ok "all vendored CRDs accepted by the API server"
else
  bad "the API server rejected at least one CRD -- under remediation retries this loops forever"
  printf '%b' "$rejected" | sed 's/^/       /'
  printf '%b' "$rejected" | grep -q 'must appear in spec.versions' && \
    echo "       ^ a version was dropped from spec.versions while objects are stored at it"
  printf '%b' "$rejected" | grep -q 'undeclared reference' && \
    echo "       ^ a CEL rule uses a library this Kubernetes version does not have"
fi

crd_count="$(find "$CRD_DIR" -name '*.yaml' | wc -l | tr -d ' ')"
echo "  vendored CRD files: ${crd_count}"

step "Old objects must still be readable through BOTH the old and new versions"
if kubectl get tcproutes.v1alpha2.gateway.networking.k8s.io legacy-tcp -n "$NS" >/dev/null 2>&1; then
  ok "TCPRoute readable via v1alpha2 (deprecated but still served)"
else
  bad "TCPRoute no longer readable via v1alpha2"
fi
if kubectl get tcproutes.v1.gateway.networking.k8s.io legacy-tcp -n "$NS" >/dev/null 2>&1; then
  ok "TCPRoute readable via v1"
else
  bad "TCPRoute not readable via v1"
fi
if kubectl get udproutes.v1.gateway.networking.k8s.io legacy-udp -n "$NS" >/dev/null 2>&1; then
  ok "UDPRoute readable via v1"
else
  bad "UDPRoute not readable via v1"
fi

step "Install the charts against the new CRDs"
if out="$(helm upgrade --install gw "${REPO_ROOT}/charts/gateway-api" \
     -n "$NS" --skip-crds --wait --timeout 3m 2>&1)"; then
  ok "gateway-api installs"
else
  bad "gateway-api install failed" "$(echo "$out" | tail -3)"
fi

if out="$(helm upgrade gwr "${REPO_ROOT}/charts/gateway-api-routes" -n "$NS" --wait --timeout 3m \
     --set tcpRoute.items[0].name=legacy-tcp \
     --set tcpRoute.items[0].parentRefs[0].name=legacy-gw \
     --set tcpRoute.items[0].rules[0].backendRefs[0].name=tcp-svc \
     --set tcpRoute.items[0].rules[0].backendRefs[0].port=9000 \
     --set udpRoute.items[0].name=legacy-udp \
     --set udpRoute.items[0].parentRefs[0].name=legacy-gw \
     --set udpRoute.items[0].rules[0].backendRefs[0].name=udp-svc \
     --set udpRoute.items[0].rules[0].backendRefs[0].port=9001 2>&1)"; then
  ok "routes chart upgrades the v1alpha2 objects to v1 in place"
else
  bad "gateway-api-routes upgrade failed" "$(echo "$out" | tail -3)"
fi

step "The adopted object must be patched in place, not recreated"
uid_after_tcp="$(kubectl get tcproute legacy-tcp -n "$NS" -o jsonpath='{.metadata.uid}' 2>/dev/null)"
if [[ -n "$uid_after_tcp" && "$uid_after_tcp" == "$uid_before_tcp" ]]; then
  ok "metadata.uid unchanged (${uid_before_tcp:0:8}...) -- no delete-and-recreate, no traffic drop"
else
  bad "metadata.uid changed: ${uid_before_tcp} -> ${uid_after_tcp:-<gone>}"
fi

step "Storage migration must bring storedVersions to v1 only"
for k in tcproutes udproutes; do
  count="$(kubectl get "${k}.gateway.networking.k8s.io" -A -o name 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "$count" -eq 0 ]]; then
    bad "${k}: no objects found to migrate -- storage rewrite would prove nothing"
    continue
  fi
  if ! replace_out="$(kubectl get "${k}.gateway.networking.k8s.io" -A -o yaml | kubectl replace -f - 2>&1)"; then
    bad "${k}: kubectl replace (storage rewrite) failed" "$(echo "$replace_out" | tail -3)"
    continue
  fi
  stored_between="$(kubectl get crd "${k}.gateway.networking.k8s.io" -o jsonpath='{.status.storedVersions}')"
  echo "  ${k} storedVersions after rewriting ${count} object(s), before narrowing patch: ${stored_between}"
  if ! patch_out="$(kubectl patch crd "${k}.gateway.networking.k8s.io" --subresource=status \
       --type=merge -p '{"status":{"storedVersions":["v1"]}}' 2>&1)"; then
    bad "${k}: storedVersions narrowing patch was rejected by the API server" "$(echo "$patch_out" | tail -3)"
    continue
  fi
  stored="$(kubectl get crd "${k}.gateway.networking.k8s.io" -o jsonpath='{.status.storedVersions}')"
  if [[ "$stored" == '["v1"]' ]]; then
    ok "${k} storedVersions == [\"v1\"] (rewrote ${count} object(s), narrowing patch accepted)"
  else
    bad "${k} storedVersions == ${stored}"
  fi
done

step "Negative test: routes chart against the OLD CRDs must fail cleanly"
# Reinstalling the old bundle is blocked from v1.5 onward by the safe-upgrades
# ValidatingAdmissionPolicy, and by storedVersions. So simulate the stale-CRD case
# by rendering against a cluster whose TCPRoute CRD does not serve v1.
kubectl delete namespace "$NS" --wait=true >/dev/null 2>&1
kubectl patch crd tcproutes.gateway.networking.k8s.io --type=json \
  -p '[{"op":"replace","path":"/spec/versions/0/served","value":false}]' >/dev/null 2>&1
if helm install neg "${REPO_ROOT}/charts/gateway-api-routes" -n "${NS}-neg" --create-namespace \
     --set tcpRoute.items[0].name=x \
     --set tcpRoute.items[0].parentRefs[0].name=g >/dev/null 2>&1; then
  bad "install succeeded against a CRD that does not serve v1 -- expected a clean failure"
  helm uninstall neg -n "${NS}-neg" >/dev/null 2>&1
else
  ok "install fails cleanly when the CRDs do not serve the emitted apiVersion"
fi

printf '\n\033[1mResults: %d passed, %d failed\033[0m\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
