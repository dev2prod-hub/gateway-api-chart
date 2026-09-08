# Migration guide

## Chart 1.0.5 → 2.0.0 (Gateway API v1.4.1 → v1.6.2)

This is a **breaking** release. Read the section that matches how you install these
charts — GitOps consumers and `helm` CLI consumers need opposite instructions,
because Helm and GitOps controllers treat the chart's `crds/` directory
differently.

### What changed

| Change | Effect |
|---|---|
| Gateway API CRDs bumped v1.4.1 → v1.6.2 (experimental channel) | Two upstream minor versions. `ListenerSet` and `XBackend` are new; `XListenerSet` is gone. |
| `TCPRoute` and `UDPRoute` templates now emit `gateway.networking.k8s.io/v1` | They graduated to `v1` in Gateway API 1.6. Rendering fails against CRDs older than 1.6. |
| New `TLSRoute` template in `gateway-api-routes` | `TLSRoute` reached `v1` in Gateway API 1.5. Opt in via `tlsRoute.items`. |
| `gatewayClass.infrastructure` **removed** | The field never existed in the GatewayClass API. It was silently pruned by the API server while `values.schema.json` accepted it. Setting it now fails validation. |
| New `gateway-api-standard` chart | Ships the standard-channel CRDs, for clusters that do not want the experimental resources. |
| `appVersion` now tracks Gateway API (`1.6.2`), not the chart version | `app.kubernetes.io/version` on every rendered object finally states which CRD bundle the release expects. |
| `kubeVersion: ">=1.33.0-0"` added | The charts refuse to install below Kubernetes 1.33. See [Kubernetes floor](#kubernetes-floor). |

**Nothing in this jump drops an API version.** Every version served by the v1.4.1
CRDs is still listed in v1.6.2's `spec.versions`, so the CRD update is accepted by
the API server even on clusters with objects stored at `v1alpha2`. The deprecated
alpha versions remain **served** in the experimental channel, so existing manifests
keep working. That is the whole reason this can ship as one release.

### Kubernetes floor

**Chart 2.0.0 requires Kubernetes 1.33 or newer**, and this is a hard stop rather
than a recommendation.

The experimental `XBackend` CRD, new in Gateway API 1.6, carries a CEL validation
rule using `format.dns1123Label()`. The Kubernetes CEL *format* library only exists
from **1.32**, so on 1.31 the API server rejects that CRD outright:

```
ERROR: <input>:1:50: undeclared reference to 'validate' (in container '')
 | size(self) == 0 || format.dns1123Label().validate(self) == null
```

Under a GitOps controller that is not a clean failure: the CRD apply is rejected,
the reconcile fails, and remediation retries it on every interval indefinitely.

The declared floor is 1.33 rather than the technical 1.32 because upstream Gateway
API supports only the 5 most recent Kubernetes minors -- 1.33 through 1.37 for
v1.6.2 -- and CI tests 1.33 and 1.37. Declaring 1.32 would claim a version nobody
tests.

Note that this rule lives only in the *experimental* channel; the standard-channel
CRDs contain no CEL format rules at all. The `gateway-api-standard` chart still
declares the same floor, because the charts move in lockstep and 1.32 and below are
outside upstream's support window regardless.

---

### Pre-flight — run these before you upgrade anything

**1. Remove `gatewayClass.infrastructure` from your values.** Anything else fails
at schema validation, and under a GitOps controller a failed install can trigger
remediation:

```bash
grep -rn -A3 'gatewayClass:' path/to/your/values.yaml | grep infrastructure
```

**2. Find `ReferenceGrant` objects with no `spec`.** In v1.4.1 `spec` was optional;
in v1.6.2 it is required on every version. Existing objects stay *readable*, but
every write to them is rejected — which means a GitOps controller trying to sync
one gets stuck. These charts never create ReferenceGrants, so anything found here
is yours:

```bash
kubectl get referencegrants -A -o json \
  | jq -r '.items[] | select(.spec == null or .spec.from == null or .spec.to == null)
           | "\(.metadata.namespace)/\(.metadata.name)"'
```

Fix or delete everything listed before proceeding.

**3. Look for fields removed in v1.6 inside `extraSpec`.** `extraSpec` is an
untyped passthrough, so anything you put there that v1.6 dropped from the schema is
**silently pruned** on the next write — no error, no event. This is the only part
of the upgrade that can lose configuration quietly. The known removal is
`idleTimeout` under the experimental SessionPersistence API:

```bash
kubectl get httproutes,grpcroutes -A -o yaml | grep -n idleTimeout
```

**4. Back up.** CRD updates are not reversible by Helm or by Git (see
[Rollback](#rollback)):

```bash
kubectl get gateways,gatewayclasses,httproutes,grpcroutes,tcproutes,udproutes,\
tlsroutes,referencegrants,backendtlspolicies -A -o yaml > gwapi-backup.yaml
kubectl get crd -o name | grep gateway.networking | xargs kubectl get -o yaml > gwapi-crds-backup.yaml
```

Take an etcd snapshot or a Velero backup too, if you have one.

**5. Record the current storage versions**, so you can tell afterwards whether the
migration in step 3 of the upgrade actually took effect:

```bash
kubectl get crd -o custom-columns=NAME:.metadata.name,STORED:.status.storedVersions \
  | grep gateway.networking
```

---

## GitOps consumers (Flux, Argo CD)

Your controller replaces the chart's CRDs for you — that is the important
difference from the CLI path, and the reason to be deliberate.

With Flux, `upgrade.crds: CreateReplace` applies every CRD in the chart's `crds/`
directory on **every chart revision**, using server-side apply with forced
conflicts. It is not gated on anything, there is no diff, and nothing in the Helm
release records that it happened. `driftDetection: enabled` makes it reachable from
ordinary drift as well, because drift correction runs a `helm upgrade`, which runs
the CRD apply again.

So the safety of this upgrade rests entirely on **when** the new chart version
becomes visible to your version constraint.

**Pin an exact version. Never a range.**

```yaml
# helm.toolkit.fluxcd.io/v2 HelmRelease
spec:
  chart:
    spec:
      version: "2.0.0"     # not "2.*", not ">=2.0.0"
```

A range means any chart publish reaches your cluster within one reconcile
interval, replaces cluster-scoped CRDs, and does so with no human in the loop.
A `2.0.0` release does not match a `1.*` constraint, which is exactly the pause
this upgrade needs.

Also cap remediation. `install.remediation.retries: -1` retries forever, and
remediation for a failed *install* is an **uninstall** — which deletes your
`Gateway` and `GatewayClass`, and provisioners such as Envoy Gateway respond by
tearing down the data plane and its LoadBalancer. Every retry cycle is an outage:

```yaml
spec:
  install:
    remediation:
      retries: 3
  upgrade:
    remediation:
      retries: 3
```

And fetch the chart over TLS. A `HelmRepository` on plain `http://` is refetched
every interval and handed straight to a controller that applies cluster-scoped
CRDs; `index.yaml` digests give no protection because they arrive over the same
channel:

```yaml
# source.toolkit.fluxcd.io/v1 HelmRepository
spec:
  url: https://charts.cdnn.host/
```

### Upgrade sequence

1. Confirm the pre-flight checks above are clean.
2. Confirm the release is currently healthy and pinned to the old version:
   ```bash
   kubectl get helmrelease <name> -n <ns> \
     -o custom-columns=READY:.status.conditions[0].status,REV:.status.lastAppliedRevision
   ```
3. Change the pinned version to `2.0.0` in Git. One commit, reviewable, revertable.
4. Watch the reconcile. The CRDs are replaced as part of it:
   ```bash
   kubectl get helmrelease <name> -n <ns> -w
   kubectl get crd gateways.gateway.networking.k8s.io \
     -o jsonpath='{.metadata.annotations.gateway\.networking\.k8s\.io/bundle-version}{"\n"}'
   ```
5. Run the [post-upgrade steps](#post-upgrade-required).

If it goes wrong mid-flight, the emergency brake is to stop the controller from
touching CRDs at all, then investigate — otherwise it keeps retrying at you:

```yaml
spec:
  upgrade:
    crds: Skip
```

---

## `helm` CLI consumers

**`helm upgrade` never updates CRDs.** Helm applies `crds/` on install only, and
even then it skips CRDs that already exist. There is no diff, no warning, and the
release reports `deployed` regardless. So a chart bump alone leaves your cluster on
Gateway API v1.4.1 while the chart claims 1.6.2.

Because chart 2.0.0 renders `TCPRoute`/`UDPRoute` at `v1`, the order matters —
**CRDs first, chart second**:

```bash
# 1. CRDs
kubectl apply --server-side --force-conflicts \
  -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.2/experimental-install.yaml

# 2. verify what landed
kubectl get crd gateways.gateway.networking.k8s.io \
  -o jsonpath='{.metadata.annotations.gateway\.networking\.k8s\.io/bundle-version}{"\n"}'

# 3. then the charts
helm upgrade my-gateway dev2prod/gateway-api       --version 2.0.0
helm upgrade routes     dev2prod/gateway-api-routes --version 2.0.0
```

`--server-side` is required, not optional: the HTTPRoute CRD is over 500 KB and
client-side apply stores the manifest in a `last-applied-configuration` annotation
capped at 256 KB.

Getting the order wrong fails cleanly and creates nothing:

```
Error: UPGRADE FAILED: unable to build kubernetes objects from release manifest:
resource mapping not found for kind "TCPRoute" in version "gateway.networking.k8s.io/v1":
no matches for kind "TCPRoute" in version "gateway.networking.k8s.io/v1"
```

If you cannot update CRDs yet, stay on chart `1.0.5`.

---

## Post-upgrade (required)

### 1. Migrate storage versions

`TCPRoute`, `UDPRoute` and `TLSRoute` objects created under v1.4.1 are still stored
in etcd at their old alpha versions. Nothing breaks today — the alphas remain served
in the experimental channel — but a future upstream release will remove them from
`spec.versions`, and on that day the CRD apply is **rejected** by the API server
while any object is still recorded at the removed version. Under a GitOps controller
that means a reconcile loop that never succeeds.

Do it now, supervised, instead of meeting it unattended in a year.

**The order below is load-bearing.** Rewrite the objects first, then narrow
`storedVersions`. Patching `storedVersions` before rewriting makes those objects
undecodable from etcd — that is the one genuinely irreversible step in this whole
upgrade.

```bash
# 1. rewrite every stored object at the new storage version (v1)
for k in tcproutes udproutes tlsroutes; do
  kubectl get "$k.gateway.networking.k8s.io" -A -o yaml | kubectl replace -f -
done

# 2. ONLY NOW narrow storedVersions
for k in tcproutes udproutes tlsroutes; do
  kubectl patch crd "$k.gateway.networking.k8s.io" --subresource=status \
    --type=merge -p '{"status":{"storedVersions":["v1"]}}'
done

# 3. verify
kubectl get crd -o custom-columns=NAME:.metadata.name,STORED:.status.storedVersions \
  | grep -E 'tcproutes|udproutes|tlsroutes'
```

`kube-storage-version-migrator` does the same thing with throttling if you have
thousands of routes; for three resource types on a one-time upgrade the loop above
is enough.

### 2. Delete the orphaned XListenerSet CRD

Gateway API v1.5.0 replaced `XListenerSet` (`gateway.networking.x-k8s.io`) with
`ListenerSet` (`gateway.networking.k8s.io`). That is a change of API *group*, so
neither Helm nor Flux will ever remove the old CRD — both deliberately refuse to
delete CRDs that disappeared from a chart. It stays in your cluster forever unless
you remove it:

```bash
kubectl get xlistenersets.gateway.networking.x-k8s.io -A   # check first: this deletes any objects
kubectl delete crd xlistenersets.gateway.networking.x-k8s.io
```

### 3. Optional: install the safe-upgrades admission policy

Gateway API ships a `ValidatingAdmissionPolicy` that blocks installing experimental
CRDs over standard ones and blocks CRD downgrades below v1.5. **These charts do not
bundle it**, for three reasons: Flux's helm-controller discards non-CRD objects from
`crds/` anyway; Helm never removes anything in `crds/`, so `helm uninstall` would
leave a cluster-wide admission gate behind; and it evaluates with
`failurePolicy: Fail` against *every* CRD write in the cluster, not just Gateway
API's.

Install it yourself if you want that guard — knowing it makes the rollback below
harder:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.6.2/config/crd/experimental/gateway.networking.k8s.io_vap_safeupgrades.yaml
```

---

## Rollback

**Updating Gateway API CRDs is a one-way operation.** Plan a restore, not a
rollback.

Reverting the chart is easy — `helm rollback`, or reverting the pinned version in
Git. Neither touches CRDs: Helm does not track `crds/` in the release manifest, so
the cluster keeps the v1.6.2 CRDs while the templates go back. For this chart that
mismatch is harmless (`Gateway` and `GatewayClass` are `v1` in both bundles), but
`gateway-api-routes` 1.0.5 emits `TCPRoute` at `v1alpha2`, which the experimental
v1.6.2 CRDs still serve — so that works too.

Reverting the **CRDs** hits two walls in sequence:

1. If you installed the `safe-upgrades` policy, it rejects any bundle matching
   `v1.[0-4]`. You must delete the policy first, deliberately:
   `kubectl delete validatingadmissionpolicy safe-upgrades.gateway.networking.k8s.io`
2. The API server rejects any CRD update whose `spec.versions` omits a version
   still listed in `status.storedVersions`. After the storage migration above,
   that list contains `v1`, which the v1.4.1 CRDs do not have. You would need a
   reverse storage migration first — and objects written with v1.6-only fields lose
   those fields on the way back, via pruning.

So the actual procedure, if you truly need to go back:

1. Pin the chart version and set `upgrade.crds: Skip` (GitOps), so the controller
   stops fighting you.
2. Delete the `safe-upgrades` policy if present.
3. Reverse-migrate storage versions.
4. Apply the v1.4.1 CRDs.
5. Restore objects from `gwapi-backup.yaml`.
6. Restore your original `crds` policy.

---

## Switching CRD channels

The `gateway-api` chart ships the **experimental** channel; the new
`gateway-api-standard` chart ships the **standard** channel. Install exactly one of
them per cluster, and pass `--skip-crds` (CLI) or `crds: Skip` (Flux) to whichever
chart should not manage CRDs.

Treat the choice as one-directional:

- The `safe-upgrades` policy rejects installing experimental CRDs on top of
  standard ones.
- In the standard channel the deprecated alpha versions are present but
  `served: false`. Objects stay readable through `v1`, but every manifest,
  controller and `kubectl` call still addressing `v1alpha2` breaks the moment those
  CRDs are applied.

Do not combine both charts' CRDs in one cluster. They carry the same CRD names with
different channel annotations, so a GitOps controller that replaces CRDs on each
reconcile would flap between them.
