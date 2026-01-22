# Gateway API Helm Chart - Development Guide

**Date:** 2025-01-22

## Prerequisites

- **Helm 3.x** — Chart development and validation
- **Kubernetes cluster** (optional) — For `helm install` or integration tests; not required for lint/template/schema checks
- **Shell tools:** `bash`, `curl`, `jq`, `rsync` — For `scripts/update-crds.sh`
- **Git** — Version control and script usage (e.g. `git rev-parse --show-toplevel`)

## Repository Setup

```bash
git clone https://github.com/dev2prod-hub/gateway-api-chart.git
cd gateway-api-chart
```

No `npm install` or language-specific setup; the project is YAML/Helm and shell scripts.

## Environment and Configuration

- **Charts:** `charts/gateway-api` and `charts/gateway-api-routes`. Each has `values.yaml` and `values.schema.json`.
- **Examples:** Overrides in `examples/cloud-providers/*` and `examples/features/*`. Use `--values` to test.
- **Fixtures:** `charts/*/fixture-values.yaml` for integration and unit tests.

## Local Development Commands

### Lint

```bash
helm lint charts/gateway-api --strict
helm lint charts/gateway-api-routes --strict
```

Or from repo root:

```bash
for chart in charts/gateway-api charts/gateway-api-routes; do helm lint $chart --strict; done
```

### Template Rendering

```bash
# Default values
helm template my-gateway charts/gateway-api
helm template routes charts/gateway-api-routes

# With example values
helm template my-gateway charts/gateway-api --values examples/cloud-providers/aws-alb/values.yaml

# Debug (show computed values)
helm template my-gateway charts/gateway-api --debug
```

### Dry-Run Apply (Kubernetes)

```bash
helm template my-gateway charts/gateway-api | kubectl apply --dry-run=client -f -
```

### Schema Validation

```bash
# If helm schema plugin is installed
helm schema validate charts/gateway-api/values.yaml
helm schema validate charts/gateway-api-routes/values.yaml
```

The project also provides:

```bash
./tests/integration/test_schema_validation.sh
```

## Testing

### Integration Tests (Recommended)

```bash
./tests/integration/test_integration.sh
```

Covers:

- Helm lint
- Template rendering with default and fixture values
- API version checks (v1)
- CRD presence
- All example configs (cloud-providers, features)
- Edge cases (components disabled)

### Schema Validation Tests

```bash
./tests/integration/test_schema_validation.sh
```

Covers invalid protocols, ports, TLS, types, and valid default/fixture values for both charts.

### Unit Tests (Optional)

Requires [helm-unittest](https://github.com/quintush/helm-unittest):

```bash
helm plugin install https://github.com/quintush/helm-unittest
helm unittest charts/gateway-api -f tests/unit/*.yaml
```

See `tests/README.md` for details.

## Common Development Tasks

### Updating CRDs

```bash
./scripts/update-crds.sh
# Or specific version:
./scripts/update-crds.sh v1.4.1
```

Fetches experimental CRDs from kubernetes-sigs and updates `charts/gateway-api/crds/experimental/`. Commit the changes separately.

### Adding a New Example

1. Create `examples/cloud-providers/<name>/` or `examples/features/<name>/`.
2. Add `values.yaml` (and optionally `README.md`).
3. Ensure `test_integration.sh` runs all examples; add the new one if the script uses an explicit list.

### Modifying Chart Values

1. Update `values.yaml` and/or `values.schema.json` in the relevant chart.
2. Run `helm lint` and `helm template`.
3. Run `test_schema_validation.sh` if you changed schema or validation rules.
4. Update `README.md` and `llm.txt` if user-facing (per .cursorrules).

### Bumping Versions

Use the version scripts as documented (e.g. `scripts/version-bump.sh`, `scripts/helm-bump.sh`). Keep `VERSION` and `Chart.yaml` versions in sync.

## Code and Chart Conventions

- **YAML:** 2-space indentation.
- **Helm:** Use `{{-` for whitespace control; quote strings with `| quote`; use `include` for helpers.
- **Conditionals:** Check `.Values.*.enabled` before rendering resources; use `with` for optional nested values.
- **Docs:** Update README and llm.txt for user-facing changes; maintain CHANGELOG.

See `.cursorrules` and `llm.txt` for more detail.

## Troubleshooting

- **Lint failures:** Fix `values.yaml` or templates; ensure required fields exist and types match schema.
- **Template errors:** Use `--debug`; check `_helpers.tpl` and value references.
- **Schema failures:** Run `test_schema_validation.sh`; align `values.schema.json` with `values.yaml` and fixture values.
- **CRD update issues:** Ensure `curl`, `jq`, `rsync` are available; check GitHub API and kubernetes-sigs release tags.

## References

- [Gateway API](https://gateway-api.sigs.k8s.io/) — Spec and guides
- [Helm Chart Best Practices](https://helm.sh/docs/chart_best_practices/) — General Helm guidance
- [Tests README](../tests/README.md) — Test types and CI usage

---

_Generated using BMAD Method `document-project` workflow_
