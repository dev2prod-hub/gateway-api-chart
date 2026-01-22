# Gateway API Helm Chart - Source Tree Analysis

**Date:** 2025-01-22

## Overview

Single-part infrastructure project. Two Helm charts under `charts/`, CRDs in `gateway-api`, examples and tests at repo root. No multi-part client/server split; all artifacts are chart-related (YAML templates, values, schemas, examples).

## Complete Directory Structure

```
gateway-api-chart/
├── .cursorrules                 # Cursor AI rules: Helm style, Gateway API, docs
├── .github/
│   ├── agents/                  # BMAD/BMM agent configs (e.g. bmd-custom-*)
│   └── workflows/
│       ├── lint-test-release.yaml   # Lint, unit, chart-releaser
│       └── update-crds.yaml         # CRD update automation
├── .gitignore
├── .pre-commit-config.yaml      # Pre-commit hooks (excludes _bmad, .cursor)
├── artifacthub-repo.yml         # Artifact Hub repo metadata
├── CHANGELOG.md
├── charts/
│   ├── gateway-api/             # GatewayClass + Gateway + CRDs
│   │   ├── .helmignore
│   │   ├── Chart.yaml
│   │   ├── crds/
│   │   │   └── experimental/    # kubernetes-sigs CRDs (v1.4.1)
│   │   │       ├── gateway.networking.k8s.io_*.yaml
│   │   │       └── gateway.networking.x-k8s.io_*.yaml
│   │   ├── fixture-values.yaml  # Test fixtures
│   │   ├── README.md
│   │   ├── templates/
│   │   │   ├── _helpers.tpl
│   │   │   ├── gateway.yaml
│   │   │   ├── gatewayclass.yaml
│   │   │   └── NOTES.txt
│   │   ├── values.schema.json
│   │   └── values.yaml
│   └── gateway-api-routes/      # HTTPRoute, GRPCRoute, TCPRoute, UDPRoute
│       ├── Chart.yaml
│       ├── fixture-values.yaml
│       ├── README.md
│       ├── templates/
│       │   ├── _helpers.tpl
│       │   ├── grpcroute.yaml
│       │   ├── httproute.yaml
│       │   ├── tcproute.yaml
│       │   └── udproute.yaml
│       ├── values.schema.json
│       └── values.yaml
├── docs/
│   ├── ADMIN.md
│   ├── ARCHITECTURE.md
│   ├── BEST_PRACTICES.md
│   ├── MIGRATION.md
│   ├── USER_GUIDE.md
│   ├── project-overview.md      # Generated: project overview
│   ├── source-tree-analysis.md  # This file
│   ├── architecture.md          # Generated: architecture
│   ├── development-guide.md     # Generated: dev guide
│   ├── deployment-guide.md      # Generated: deployment
│   └── index.md                 # Generated: master index
├── examples/
│   ├── README.md
│   ├── cloud-providers/
│   │   ├── README.md
│   │   ├── aks-agic/
│   │   ├── aws-alb/
│   │   └── gke-gclb/
│   ├── envoy-integration/
│   │   └── README.md
│   └── features/
│       ├── README.md
│       ├── canary-release/
│       ├── mutual-tls/
│       └── rate-limiting/
├── LICENSE
├── llm.txt                      # AI-oriented project summary (quick ref)
├── README.md                    # User-facing quick start, features, examples
├── scripts/
│   ├── generate-docs.sh
│   ├── helm-bump.sh
│   ├── helm-gen.sh
│   ├── update-crds.sh           # Fetch CRDs from kubernetes-sigs
│   └── version-bump.sh
├── tests/
│   ├── README.md                # Test types, commands, CI usage
│   ├── SCHEMA_TESTING.md
│   ├── integration/
│   │   ├── test_integration.sh
│   │   └── test_schema_validation.sh
│   ├── kind-configs/
│   │   └── cluster.yaml
│   └── unit/
│       └── test_gateway.yaml    # helm-unittest
├── VERSION                      # 1.0.0
└── _bmad/                       # BMAD method (workflows, agents); gitignored in pre-commit
```

## Critical Directories

### `charts/gateway-api/`

**Purpose:** GatewayClass and Gateway chart; optional CRD install.
**Contains:** Chart.yaml, values, schema, templates (gateway, gatewayclass), CRDs in `crds/experimental/`.
**Entry points:** `values.yaml` (config), `templates/gateway.yaml`, `templates/gatewayclass.yaml`.

### `charts/gateway-api-routes/`

**Purpose:** Route resources (HTTP, gRPC, TCP, UDP).
**Contains:** Chart.yaml, values, schema, route templates.
**Entry points:** `values.yaml`; route templates render based on `*Route.enabled` and `items`.

### `charts/gateway-api/crds/experimental/`

**Purpose:** Original Kubernetes Gateway API CRDs (v1.4.1, experimental). Unchanged from upstream.
**Contains:** GatewayClass, Gateway, *Route, ReferenceGrant, BackendTLSPolicy, etc.

### `examples/`

**Purpose:** Ready-to-use value overrides for cloud providers and features.
**Contains:** `cloud-providers/` (AWS ALB, GKE, AKS), `features/` (canary, mTLS, rate-limiting), `envoy-integration/`.

### `scripts/`

**Purpose:** CRD updates, version bumps, Helm/doc generation.
**Key:** `update-crds.sh` downloads CRDs from kubernetes-sigs; `version-bump.sh`, `helm-gen.sh` for releases.

### `tests/`

**Purpose:** Integration (template + example smoke), schema validation, optional unit (helm-unittest).
**Contains:** `integration/` scripts, `kind-configs/`, `unit/` YAML.

### `docs/`

**Purpose:** Project and product documentation.
**Contains:** Generated project docs (overview, architecture, guides) plus ADMIN, ARCHITECTURE, USER_GUIDE, etc.

## Entry Points

- **Main config (gateway-api):** `charts/gateway-api/values.yaml` — GatewayClass, Gateway, listeners.
- **Main config (routes):** `charts/gateway-api-routes/values.yaml` — `httpRoute`, `grpcRoute`, `tcpRoute`, `udpRoute` items.
- **Install:** `helm install` with `dev2prod/gateway-api` and `dev2prod/gateway-api-routes` (or local `charts/*`).
- **CI:** `.github/workflows/lint-test-release.yaml` — lint, (optional) unit, chart-releaser.

## File Organization Patterns

- **Charts:** Each chart is self-contained (Chart.yaml, values.yaml, values.schema.json, templates/, optional crds/).
- **Examples:** Each example = `values.yaml` (+ optional README) under `examples/cloud-providers|features/`.
- **Tests:** Integration scripts in `tests/integration/`; unit tests in `tests/unit/` for helm-unittest.
- **Docs:** `docs/` for all project docs; `llm.txt` and `README.md` at root for quick reference.

## Key File Types

| Type        | Pattern              | Purpose                    | Examples                    |
|------------|----------------------|----------------------------|-----------------------------|
| Chart meta | `Chart.yaml`         | Chart identity, version    | `charts/*/Chart.yaml`       |
| Values     | `values.yaml`        | Default configuration      | `charts/*/values.yaml`      |
| Schema     | `values.schema.json` | Validation for values      | `charts/*/values.schema.json` |
| Templates  | `*.yaml`, `_helpers` | Helm templates             | `templates/*.yaml`          |
| CRDs       | `*.yaml` in crds/    | Gateway API CRDs           | `crds/experimental/*.yaml`  |
| Examples   | `values.yaml`        | Example overrides          | `examples/**/values.yaml`   |
| CI         | `*.yaml` in .github  | GitHub Actions             | `lint-test-release.yaml`    |

## Configuration Files

- `charts/*/values.yaml` — Chart defaults.
- `charts/*/values.schema.json` — JSON Schema for values.
- `artifacthub-repo.yml` — Artifact Hub repository config.
- `.pre-commit-config.yaml` — Lint/hooks (excludes _bmad, .cursor).
- `tests/kind-configs/cluster.yaml` — Kind cluster config for integration.

## Notes for Development

- Run `helm lint` and `helm template` from each chart directory.
- Use `./tests/integration/test_integration.sh` and `test_schema_validation.sh` before PRs.
- CRD updates: `./scripts/update-crds.sh [version]` (default: latest Gateway API release).
- Follow `.cursorrules` and `llm.txt` for conventions and AI context.

---

_Generated using BMAD Method `document-project` workflow_
