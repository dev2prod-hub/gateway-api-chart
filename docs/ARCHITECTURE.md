# Gateway API Helm Chart - Architecture

**Date:** 2025-01-22

## Executive Summary

This project packages **Kubernetes Gateway API** (v1.4.1, experimental) as two Helm charts: **gateway-api** (infrastructure) and **gateway-api-routes** (routing). CRDs are original from kubernetes-sigs and live in the gateway-api chart. The design is provider-agnostic: no controller is shipped; users install a Gateway API implementation (Envoy, AWS ALB, GKE, AKS, etc.) and configure controller names via values.

## Architecture Pattern

- **Chart-based packaging:** Standard Helm 3 layout; each chart has `Chart.yaml`, `values.yaml`, `values.schema.json`, and `templates/`.
- **Separation of concerns:** Infrastructure (GatewayClass, Gateway, CRDs) vs routes (HTTPRoute, GRPCRoute, TCPRoute, UDPRoute) in separate charts. Routes reference Gateways via `parentRefs`.
- **Configuration-driven:** All resources are generated from values; no hardcoded provider logic. Controller names, listener config, TLS, and route rules are fully configurable.

## Technology Stack

| Category     | Technology           | Role                                  |
|-------------|----------------------|----------------------------------------|
| Packaging   | Helm 3               | Chart format, templating, releases     |
| Spec        | Kubernetes Gateway API v1.4.1 | CRDs and resource model    |
| CRD source  | kubernetes-sigs/gateway-api | Experimental channel CRDs   |
| Validation  | JSON Schema          | values.schema.json per chart           |
| CI/CD       | GitHub Actions       | Lint, test, chart-releaser             |

## Component Structure

### gateway-api Chart

- **GatewayClass:** Optional; name and `controllerName` from values. Typically one per controller type.
- **Gateway:** Optional; name, `gatewayClassName`, and `listeners[]`. Listeners define protocol, port, hostname, and TLS (Terminate/Passthrough, `certificateRefs`).
- **CRDs:** Optional install via Helm; stored in `crds/experimental/`. Include GatewayClass, Gateway, *Route, ReferenceGrant, BackendTLSPolicy, and experimental resources (e.g. x-backendtrafficpolicies, x-listener-sets).

### gateway-api-routes Chart

- **HTTPRoute, GRPCRoute, TCPRoute, UDPRoute:** Each has `enabled` and `items[]`. Items define `parentRefs`, `hostnames`, and `rules` (e.g. `backendRefs`, filters like RequestRedirect, URLRewrite, RequestHeaderModifier).
- **Dependencies:** Routes chart is independent of gateway-api at Helm level; it only references Gateway/GatewayClass via Kubernetes `parentRefs`.

## Data Flow and Integration

- **Gateway API controller** watches GatewayClass, Gateway, and Route resources. It reconciles them into provider-specific config (e.g. Envoy config, ALB target groups).
- **Charts:** gateway-api installs Gateway + optional CRDs; gateway-api-routes installs Route resources. Both can be used as main chart or as subcharts. No shared “application” database or app-level APIs.
- **Examples:** `examples/cloud-providers/*` and `examples/features/*` provide value overrides. They are consumed via `--values` at install time.

## Source Tree (High Level)

```
charts/
├── gateway-api/       # GatewayClass, Gateway, CRDs
│   ├── crds/experimental/
│   └── templates/
└── gateway-api-routes/ # HTTPRoute, GRPCRoute, TCPRoute, UDPRoute
    └── templates/
```

See [source-tree-analysis.md](./source-tree-analysis.md) for full layout.

## Development Workflow

- **Local:** `helm lint`, `helm template`, `helm install --dry-run` (or `helm template | kubectl apply --dry-run=client -f -`).
- **Tests:** Integration scripts (`test_integration.sh`, `test_schema_validation.sh`), optional helm-unittest in `tests/unit/`.
- **CRD updates:** `scripts/update-crds.sh` fetches CRDs from kubernetes-sigs; no manual edits to CRD YAML.

See [development-guide.md](./development-guide.md) for details.

## Deployment Architecture

- **Delivery:** Helm charts published to `https://charts.cdnn.host/` via chart-releaser (GitHub Actions on main).
- **Consumption:** Users add the repo, install gateway-api and gateway-api-routes (or use as subcharts). Cluster must have a Gateway API controller installed separately.
- **Environments:** Examples show provider-specific controller names and TLS; same charts work across AWS, GKE, AKS, Envoy, etc.

See [deployment-guide.md](./deployment-guide.md) for CI/CD and release process.

## Testing Strategy

- **Lint:** `helm lint` per chart.
- **Template validation:** `helm template` with default and fixture values; integration script runs all examples.
- **Schema:** `values.schema.json` validates values; `test_schema_validation.sh` covers invalid and valid cases.
- **Unit (optional):** helm-unittest in `tests/unit/`; referenced in `tests/README.md` (CI wiring TBD).
- **Integration (optional):** Kind cluster + install + smoke checks; config in `tests/kind-configs/`; CI steps commented in workflow.

## Security and Configuration

- **No secrets in charts:** TLS certs referenced via `certificateRefs` (e.g. `kind: Secret`); users create Secrets separately.
- **RBAC:** Not managed by charts; controller and cluster admins configure as needed.
- **Network policies:** Not included; provider-specific.

## Constraints and Conventions

- CRDs are **unchanged** from upstream; do not patch them in-repo.
- Use `{{-` for whitespace control; quote strings in templates; check `.Values.*.enabled` before rendering.
- Document user-facing changes in README and llm.txt; keep CHANGELOG updated (per .cursorrules).

---

_Generated using BMAD Method `document-project` workflow_
