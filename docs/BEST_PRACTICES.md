# Best Practices

Practices used in this repository for charts, configuration, testing, and documentation. Aligned with [.cursorrules](../.cursorrules), [llm.txt](../llm.txt), and the [examples](../examples/) guides.

---

## 1. Project principles

- **CRDs unchanged** — Keep CRDs in `charts/gateway-api/crds/experimental/` as-original from [kubernetes-sigs/gateway-api](https://github.com/kubernetes-sigs/gateway-api). Do not modify them. Update via `./scripts/update-crds.sh`.
- **Two-chart separation** — Infrastructure (`gateway-api`: GatewayClass, Gateway, CRDs) vs routes (`gateway-api-routes`: HTTPRoute, GRPCRoute, TCPRoute, UDPRoute). Maintain this split.
- **Experimental CRDs** — Use the experimental channel (v1.4.1) for maximum feature support (TCPRoute, TLSRoute, UDPRoute, etc.).
- **Provider-agnostic** — Charts work with any Gateway API provider (Envoy, AWS ALB, GKE, AKS). No controller is shipped; users install a provider and set `controllerName` / `gatewayClassName` in values.
- **Helm 3** — Follow [Helm chart best practices](https://helm.sh/docs/chart_best_practices/) and Kubernetes Gateway API v1.4.1.

---

## 2. Helm template practices

Used in `charts/*/templates/` and `_helpers.tpl`:

- **Whitespace control** — Use `{{-` and `-}}` to avoid stray newlines and indentation issues.
- **Quote strings** — Use `| quote` for user-facing strings:
  `{{ .Values.gateway.name | default (include "gateway-api.fullname" .) | quote }}`
- **Check `.Values.*.enabled`** — Guard resources with `{{- if .Values.gateway.enabled }}` (and similar) so components can be turned off.
- **Optional nesting with `with`** — Use `{{- with .Values.gateway.annotations }} ... {{- end }}` for optional blocks; omit when empty.
- **Sensible defaults** — Use `default`:
  `{{ .Values.gateway.name | default (include "gateway-api.fullname" .) | quote }}`
- **Reusable helpers** — Use `include` for shared logic: `include "gateway-api.fullname" .`, `include "gateway-api.labels" .`, `include "gateway-api.chart" .`.
- **Naming** — Follow `chart-name.fullname`, `chart-name.labels`, `chart-name.chart` (see `_helpers.tpl`). Truncate to 63 chars for DNS-compatible names.
- **Labels** — Use `helm.sh/chart`, `app.kubernetes.io/name`, `app.kubernetes.io/instance`, `app.kubernetes.io/version`, `app.kubernetes.io/managed-by`. Support `global.labels` for extra labels.

---

## 3. Code style

- **YAML** — 2 spaces indentation everywhere.
- **Values** — Document in `values.yaml` with `# --` comments. Provide `values.schema.json` per chart and run schema validation in CI/tests.

---

## 4. Gateway & listener configuration

- **HTTP** — `protocol: HTTP`, `port: 80` (or your choice).
- **HTTPS with TLS** — `protocol: HTTPS`, `port: 443`, `tls.mode: Terminate`, `tls.certificateRefs` pointing to `Secret` or `Certificate`.
- **TCP / UDP** — `protocol: TCP` or `UDP` with appropriate `port` (e.g. 3306, 53).
- **Hostnames** — Set `hostname` when using TLS or host-based routing.
- **TLS** — **Terminate**: gateway terminates TLS, needs `certificateRefs`. **Passthrough**: TLS forwarded to backend (e.g. mTLS at backend).

---

## 5. Routes configuration

- **parentRefs** — Every route must reference the correct Gateway (and optional `sectionName` for listener).
- **hostnames** — Use `hostnames[]` for host-based routing.
- **Rules** — Use `rules[].matches[].path`, `rules[].backendRefs[]`. Supports filters: `RequestRedirect`, `URLRewrite`, `RequestHeaderModifier`, etc.
- **Feature-specific** — Canary (weight-based `backendRefs`), rate limiting (provider annotations or `ExtensionRef`), mTLS (listener TLS config) — see `examples/features/`.

---

## 6. Using examples and installing

From [examples/README](../examples/README.md):

1. **Review values before use** — Examples are templates; customize for your environment.
2. **TLS certificates** — Replace example `certificateRefs` with your own `Secret` / `Certificate` names.
3. **Hostnames** — Replace `example.com` (or similar) with your real domains.
4. **Test in staging first** — Validate configuration before production.
5. **Version pinning** — Use `--version 1.0.0` (or current) in production.

```bash
helm install my-gateway dev2prod/gateway-api \
  --version 1.0.0 \
  --values examples/cloud-providers/aws-alb/values.yaml
```

---

## 7. Canary releases

From [examples/features/canary-release](../examples/features/canary-release/):

- Start with **5–10%** traffic to canary; increase gradually (e.g. 10% → 25% → 50% → 100%).
- **Monitor** error rates, latency, success metrics.
- Use **automated rollback** (alerts) and **feature flags** where appropriate.
- Prefer **percentage-based** splits first; use **header-based** or **path-based** matches when needed.

---

## 8. Mutual TLS (mTLS)

From [examples/features/mutual-tls](../examples/features/mutual-tls/):

- **Passthrough** — Simplest: Gateway passes TLS through; backend does mTLS.
- **Terminate** — Gateway terminates TLS and can validate client certs (provider-specific).
- **Rotate** server and client certificates regularly; **monitor** validation failures.
- **Document** CA and cert details securely; **back up** CA keys.

---

## 9. Rate limiting

From [examples/features/rate-limiting](../examples/features/rate-limiting/):

- **Start conservative** — Set limits higher, then tune down from metrics.
- **Monitor** rate-limit hits, 429s, backend load.
- Use **different limits** per route or user where needed.
- **Whitelist** internal or critical paths when appropriate.
- Prefer **per-route** or **per-IP** limits over a single global limit when it makes sense.

---

## 10. Validation and testing

### Commands (from [llm.txt](../llm.txt))

```bash
helm template . --debug
helm lint .
helm template . | kubectl apply --dry-run=client -f -
helm schema validate values.yaml   # if plugin installed
```

### Integration tests

```bash
./tests/integration/test_integration.sh
./tests/integration/test_schema_validation.sh
```

- **Lint** each chart with `--strict`.
- **Template** with default and fixture values; validate all **examples** (cloud-providers, features).
- **Schema** — Cover invalid and valid cases via `test_schema_validation.sh`.
- **CRDs** — Ensure experimental CRDs are present and used.

### Unit tests (optional)

- Use [helm-unittest](https://github.com/quintush/helm-unittest) with `tests/unit/*.yaml`.
- Assert default values, enable/disable, names, API version, labels, TLS.

See [tests/README](../tests/README.md) for details.

---

## 11. Pre-commit and tooling

From [.pre-commit-config.yaml](../.pre-commit-config.yaml):

- **check-added-large-files** — Max 3000 KB.
- **check-case-conflict**, **check-json**, **check-merge-conflict**, **check-symlinks** (excluding CRDs/templates).
- **detect-private-key**, **end-of-file-fixer**, **trailing-whitespace** (excluding `_bmad`, `.cursor`, `.github/*.md`).
- **no-commit-to-branch** — Enforce branch rules.

Run `pre-commit run --all-files` before pushing.

---

## 12. Documentation

From [.cursorrules](../.cursorrules):

- **README.md** — Update for user-facing changes (install, config, examples).
- **llm.txt** — Keep AI-oriented summary current (structure, config, validation, patterns).
- **CHANGELOG.md** — Record version history and notable changes.
- **docs/** — Use [index.md](./index.md) as the entry point; update architecture, dev, and deployment guides when behavior or layout changes.

---

## 13. CI/CD

- **Lint** — `helm lint` for every chart in `./charts` on push/PR.
- **Schema** — Run `test_schema_validation.sh` (or equivalent) in CI.
- **Examples** — Integration tests run all example values; keep them valid.
- **Release** — Use chart-releaser for publishing; pin chart versions in consumption.

---

## 14. Checklist before PR

- [ ] `helm lint` passes for all charts.
- [ ] `helm template` works with default and fixture values.
- [ ] All examples render (integration script passes).
- [ ] Schema validation passes.
- [ ] No CRD edits; CRD updates done via `update-crds.sh` only.
- [ ] README / llm.txt / CHANGELOG updated if user-facing or notable.
- [ ] Pre-commit hooks pass.

---

## References

- [Gateway API](https://gateway-api.sigs.k8s.io/) — Spec and guides
- [Gateway API v1.4.1](https://gateway-api.sigs.k8s.io/v1.4.1/)
- [Helm Chart Best Practices](https://helm.sh/docs/chart_best_practices/)
