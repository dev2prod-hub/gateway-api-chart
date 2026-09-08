# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-09-08

Breaking release. Read [docs/MIGRATION.md](docs/MIGRATION.md) before upgrading --
especially if you install via Flux or Argo CD, where CRDs are replaced unattended.

### Changed (BREAKING)

- **Gateway API CRDs updated v1.4.1 → v1.6.2** (experimental channel). No API
  version is dropped in this jump, so the CRD update is accepted even on clusters
  with objects stored at `v1alpha2`, and the deprecated alphas remain served.
- **`TCPRoute` and `UDPRoute` now render at `gateway.networking.k8s.io/v1`**
  (graduated upstream in Gateway API 1.6). Rendering fails against CRDs older than
  1.6 -- update CRDs before the chart.
- **`appVersion` now tracks the vendored Gateway API bundle** (`1.6.2`) instead of
  duplicating the chart version. `app.kubernetes.io/version` on every rendered
  object now states which CRD bundle the release expects.
- **`kubeVersion: ">=1.31.0-0"` declared.** Gateway API 1.5's TLSRoute CEL
  validation requires Kubernetes 1.31 or newer; the charts refuse to install below
  that where they previously would.

### Removed

- **`gatewayClass.infrastructure`.** The field does not exist in the GatewayClass
  API -- `spec` accepts only `controllerName`, `description` and `parametersRef` --
  so the API server silently pruned it while `values.schema.json` accepted it.
  Because the schema uses `additionalProperties: false`, setting it now fails
  validation instead of doing nothing. `gateway.infrastructure` is a real field and
  is unaffected.
- `XListenerSet` CRD, removed upstream in v1.5.0 in favour of `ListenerSet` in a
  different API group. Neither Helm nor Flux deletes vanished CRDs, so operators
  must remove the orphan by hand -- see MIGRATION.md.

### Added

- **`gateway-api-standard` chart** -- the standard-channel CRDs, for clusters that
  do not want the experimental resources. CRDs only, no templates. Helm's `crds/`
  directory cannot be templated or conditioned, so channel selection is a choice of
  chart rather than a value.
- **`TLSRoute` template** in `gateway-api-routes` (`tlsRoute.items`). TLSRoute
  reached `v1` in Gateway API 1.5; it was the one route type the chart shipped a CRD
  for but no template.
- `ListenerSet` and `XBackend` CRDs, new upstream in v1.5.0 and v1.6.0.
- `docs/MIGRATION.md`, with separate GitOps and `helm` CLI upgrade paths, the
  storage-migration procedure and an honest rollback section.
- `tests/integration/test_crd_upgrade.sh` -- installs the v1.4.1 CRDs, creates
  objects at `v1alpha2`, then replays exactly what Flux does (server-side apply with
  forced conflicts) and asserts the objects survive and are patched in place rather
  than recreated. Refuses to run against a non-kind cluster.
- Unit tests for `gateway-api-routes`, which previously had none.

### Fixed

- **Chart releases could be published from a pull request.** The release job's
  branch guard was commented out while the workflow triggered on `pull_request`, so
  a proposal could publish to `charts.cdnn.host` -- and from there reach clusters
  whose version constraint was a range. Publishing now lives in its own workflow,
  triggered only by a push to `main`.
- **Unit tests never ran.** `helm unittest -f` resolves paths relative to the chart
  directory, so the CI invocation collected zero suites and passed vacuously. With
  the path fixed, all seven pre-existing tests failed -- they had been written
  assuming assertions apply to the combined set of rendered documents rather than
  per template. Suite rewritten, and CI now fails if no suite is collected.
- **The weekly CRD cron ignored its own `version` input** and always pulled upstream
  latest, so it would have opened an unreviewed PR crossing two minor versions.
  `scripts/update-crds.sh` now advances at most one minor unattended, and crossing
  more requires passing the version explicitly.
- `helm lint` broke on any non-CRD file under `crds/`; `.helmignore` now excludes
  tool state, and CI lints the packaged tarball rather than the working tree.
- `scripts/helm-bump.sh` and `scripts/version-bump.sh` used GNU-only `sed -i` and an
  unanchored `version:` pattern, and required a `.git` directory to do anything.
- `docs/deployment-guide.md` documented `helm rollback` as the rollback procedure
  for CRD changes, which does not work -- Helm never tracks `crds/`.

### Security

- `README` and docs now recommend pinning an exact chart version and never a range:
  these charts ship cluster-scoped CRDs that GitOps controllers apply without
  review, so a floating constraint turns any publish into an unreviewed cluster
  change.
- The `helm-unittest` plugin install is pinned to a version instead of tracking the
  repository's `HEAD` in a release pipeline.

### Note

Versions 1.0.1 through 1.0.5 were released without changelog entries and are not
reconstructed here; see the GitHub releases. Version `1.0.2` is absent from the
published `index.yaml`.

## [1.0.0] - 2024-12-23

### Added
- Stable release of gateway-api Helm chart
- Added `.helmignore` file for better chart packaging
- Added `NOTES.txt` template for improved user experience after installation
- Comprehensive documentation updates
- CRD version: v1.4.1 (experimental channel) from kubernetes-sigs/gateway-api

### Changed
- **BREAKING**: Updated GatewayClass API version from `v1beta1` to `v1` to align with latest Gateway API CRDs
- Chart version bumped to `1.0.0` for stable release
- Using experimental CRDs for maximum feature support (TCPRoute, TLSRoute, UDPRoute, and experimental features)

### Fixed
- API version consistency across all templates
- Documentation references updated

### Security
- No security changes in this release

## [0.2.0] - Previous Release

### Changed
- Initial stable version preparation

## [0.1.3-alpha.3] - Previous Release

### Added
- Initial alpha release with experimental CRDs
- Gateway and GatewayClass templates
- Support for HTTPRoute, GRPCRoute, TCPRoute, UDPRoute
