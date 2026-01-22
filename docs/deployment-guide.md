# Gateway API Helm Chart - Deployment Guide

**Date:** 2025-01-22

## Overview

Charts are published to **https://charts.cdnn.host/** and can be installed as standalone releases or as subcharts. This guide covers consumption, release pipeline, and environment configuration.

## Helm Repository

- **URL:** https://charts.cdnn.host/
- **Charts:** `gateway-api`, `gateway-api-routes`
- **Artifact Hub:** [gateway-api-chart](https://artifacthub.io/packages/search?repo=gateway-api-chart)

## Installation (End Users)

### Add Repo and Install

```bash
helm repo add dev2prod https://charts.cdnn.host/
helm repo update
helm search repo dev2prod
```

### Install gateway-api (with CRDs)

```bash
helm install my-gateway dev2prod/gateway-api --version 1.0.0
```

### Install gateway-api (skip CRDs)

Use when CRDs are already installed (e.g. by a controller or another release):

```bash
helm install my-gateway dev2prod/gateway-api --version 1.0.0 --skip-crds
```

### Install gateway-api-routes

```bash
helm install routes dev2prod/gateway-api-routes --version 1.0.0
```

### Using Examples

```bash
helm install my-gateway dev2prod/gateway-api \
  --version 1.0.0 \
  --values https://raw.githubusercontent.com/dev2prod-hub/gateway-api-chart/main/examples/cloud-providers/aws-alb/values.yaml
```

(Adjust URL if using a fork or branch.)

## Infrastructure Requirements

- **Kubernetes cluster** with Gateway API support (or CRDs installed).
- **Gateway API controller** (e.g. Envoy Gateway, AWS ALB, GKE Gateway, AKS AGIC). Charts do not install controllers.
- **TLS certificates:** Create `Secret` resources and reference them via `certificateRefs` when using TLS Terminate.

## Environment Configuration

- **Controller names:** Set `gatewayClass.controllerName` / `gateway.gatewayClassName` to match your controller (e.g. `application-networking.k8s.aws/gateway-controller`, `networking.gke.io/gateway`).
- **Listeners:** Configure `gateway.listeners[]` (protocol, port, hostname, TLS).
- **Routes:** Configure `httpRoute`, `grpcRoute`, `tcpRoute`, `udpRoute` `items` in gateway-api-routes.
- **Secrets:** Manage TLS and other secrets outside the chart; reference by name and `kind`.

See `examples/` and main [README](../README.md) for patterns.

## CI/CD Pipeline

### GitHub Actions

Workflow: `.github/workflows/lint-test-release.yaml`

| Job             | Triggers     | Steps                                                                 |
|-----------------|-------------|-----------------------------------------------------------------------|
| Lint & Unit     | Push/PR to main | Checkout → Setup Helm → `helm lint` for each chart in `./charts` |
| Publish Chart   | After lint  | chart-releaser-action; publishes to `https://charts.cdnn.cloud`       |

- **Helm version:** 3.12.0 (workflow env).
- **Unit / integration:** Referenced in `tests/README.md`; some steps (unittest, Kind-based integration) are commented in the workflow for later use.

### Chart Releaser

- **Action:** `helm/chart-releaser-action@v1.7.0`
- **Publish URL:** `https://charts.cdnn.cloud`
- **Skip existing:** `CR_SKIP_EXISTING: "true"`
- **Permissions:** `contents: write` for release artifacts.

### CRD Update Workflow

- **Workflow:** `.github/workflows/update-crds.yaml`
- **Purpose:** Keep CRDs in sync with upstream (e.g. kubernetes-sigs/gateway-api). Run manually or on schedule as configured.

## Release Process

1. **Version bump:** Use `scripts/version-bump.sh` / `scripts/helm-bump.sh`; update `VERSION` and `Chart.yaml` app version.
2. **CRDs (if needed):** Run `scripts/update-crds.sh` and commit changes.
3. **Tests:** Run `./tests/integration/test_integration.sh` and `./tests/integration/test_schema_validation.sh`.
4. **Commit & push:** Merge to `main`; lint job runs, then chart-releaser publishes.
5. **Changelog:** Update `CHANGELOG.md` per project conventions.

## Deployment Checklist

- [ ] Cluster has Gateway API CRDs (or install via chart with `--skip-crds` false).
- [ ] Gateway API controller is installed and running.
- [ ] Controller name in values matches your implementation.
- [ ] TLS secrets exist when using TLS Terminate; `certificateRefs` point to them.
- [ ] Route `parentRefs` reference the correct Gateway name and listener.
- [ ] Chart versions pinned in production (e.g. `--version 1.0.0`).

## Rollback

```bash
helm rollback my-gateway [revision]
helm rollback routes [revision]
```

Ensure Gateway API controller supports any CRD version changes when rolling back.

## References

- [Gateway API](https://gateway-api.sigs.k8s.io/) — Spec and implementations
- [Chart README](../README.md) — Quick start and examples
- [Tests README](../tests/README.md) — CI and test usage

---

_Generated using BMAD Method `document-project` workflow_
