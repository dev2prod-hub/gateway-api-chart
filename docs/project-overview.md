# Gateway API Helm Chart - Project Overview

**Date:** 2025-01-22
**Type:** Infrastructure (Helm / Kubernetes)
**Architecture:** Chart-based, two-chart separation (infrastructure vs routes)

## Executive Summary

This repository provides production-ready Helm charts for **Kubernetes Gateway API** — the successor to Ingress. It ships two charts: **gateway-api** (GatewayClass, Gateway, optional CRDs) and **gateway-api-routes** (HTTPRoute, GRPCRoute, TCPRoute, UDPRoute). CRDs are original from kubernetes-sigs (v1.4.1, experimental channel), unmodified. The charts are cloud-agnostic and work with any Gateway API provider (Envoy, AWS ALB, GKE, AKS, etc.). The project does not include a controller; users install a Gateway API provider separately.

## Project Classification

- **Repository Type:** Monolith (single cohesive codebase)
- **Project Type(s):** Infra (Helm, Kubernetes, YAML)
- **Primary Language(s):** YAML, Shell (scripts)
- **Architecture Pattern:** Helm chart packaging; infrastructure vs routes separation

## Technology Stack Summary

| Category        | Technology              | Version | Justification                                      |
|----------------|-------------------------|---------|----------------------------------------------------|
| Packaging      | Helm                    | 3       | Chart format, templating, release management       |
| Orchestration  | Kubernetes Gateway API  | v1.4.1  | CRD source; experimental channel for max features  |
| Spec           | Gateway API             | v1.4.1  | GatewayClass, Gateway, *Route resources            |
| CI/CD          | GitHub Actions          | -       | Lint, test, chart-releaser                         |
| Validation     | JSON Schema             | -       | values.schema.json per chart                       |
| Testing        | Shell scripts, unittest | -       | Integration and schema validation; optional unit   |

## Key Features

- **CRD management:** Optional installation; original kubernetes-sigs CRDs (experimental).
- **GatewayClass & Gateway:** Configurable via values; TLS terminate/passthrough, listeners.
- **Routes:** HTTPRoute, GRPCRoute, TCPRoute, UDPRoute via gateway-api-routes chart.
- **Examples:** Cloud providers (AWS ALB, GKE GCLB, AKS AGIC) and features (canary, mTLS, rate limiting).
- **Validation:** Helm lint, `helm template`, schema validation, example smoke tests.

## Architecture Highlights

- **Two-chart split:** gateway-api (infra) and gateway-api-routes (routes) for clear separation.
- **Experimental CRDs:** TCPRoute, TLSRoute, UDPRoute, BackendTLSPolicy, ReferenceGrant, etc.
- **Provider-agnostic:** Controller name and settings configurable per environment.
- **No controller included:** Users bring their own Gateway API implementation.

## Development Overview

### Prerequisites

- Helm 3.x
- Kubernetes cluster (optional, for integration tests)
- `curl`, `jq`, `rsync` (for CRD update script)

### Getting Started

- Add Helm repo: `helm repo add dev2prod https://charts.cdnn.host/`
- Install gateway-api: `helm install my-gateway dev2prod/gateway-api --version 1.0.0`
- Install routes: `helm install routes dev2prod/gateway-api-routes --version 1.0.0`
- Use `--skip-crds` if CRDs are already installed.

### Key Commands

- **Lint:** `helm lint charts/gateway-api` / `helm lint charts/gateway-api-routes`
- **Template:** `helm template . --debug` (from chart dir)
- **Integration tests:** `./tests/integration/test_integration.sh`
- **Schema validation:** `./tests/integration/test_schema_validation.sh`
- **CRD update:** `./scripts/update-crds.sh [version]`

## Repository Structure

```
gateway-api-chart/
├── charts/
│   ├── gateway-api/          # GatewayClass, Gateway, CRDs
│   └── gateway-api-routes/   # HTTPRoute, GRPCRoute, TCPRoute, UDPRoute
├── crds/                     # Symlink/concept; CRDs live in gateway-api/crds/experimental/
├── docs/                     # Documentation
├── examples/                 # Cloud provider and feature examples
├── scripts/                  # update-crds, version-bump, helm-gen, etc.
└── tests/                    # Integration, schema, unit (helm-unittest)
```

## Documentation Map

- [index.md](./index.md) — Master documentation index
- [architecture.md](./architecture.md) — Technical architecture
- [source-tree-analysis.md](./source-tree-analysis.md) — Directory structure
- [development-guide.md](./development-guide.md) — Development workflow
- [deployment-guide.md](./deployment-guide.md) — Deployment and CI/CD

---

_Generated using BMAD Method `document-project` workflow_
