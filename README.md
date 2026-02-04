# Gateway API Helm Chart 🚪⚡

[![CI](https://github.com/dev2prod-hub/gateway-api-chart/actions/workflows/lint-test-release.yaml/badge.svg)](https://github.com/dev2prod-hub/gateway-api-chart/actions)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/gateway-api-chart)](https://artifacthub.io/packages/search?repo=gateway-api-chart)

**Gateway API Helm Chart** — install Kubernetes Gateway API (CRDs, GatewayClass, Gateway, HTTPRoute, GRPCRoute, TCPRoute, UDPRoute) via Helm. Kubernetes-native successor to Ingress.

| Resource | URL |
|----------|-----|
| Helm chart repo | [charts.cdnn.host](https://charts.cdnn.host/) |
| Git source | [github.com/dev2prod-hub/gateway-api-chart](https://github.com/dev2prod-hub/gateway-api-chart) |
| Artifact Hub | [artifacthub.io/packages/search?repo=gateway-api-chart](https://artifacthub.io/packages/search?repo=gateway-api-chart) |

Replace ingress with the **Gateway API Helm chart**. Gateway API is the Kubernetes-native successor to Ingress for managing API gateways and routing.

_Stop reinventing Ingress controllers. Start using the Kubernetes-native successor._

## Gateway API Resource Model

The Gateway API follows a role-oriented design with three layers:

![Gateway API Resource Model - Infrastructure Provider, Cluster Operator, Application Developer layers](https://gateway-api.sigs.k8s.io/images/resource-model.png)

**Source:** [Kubernetes Gateway API Documentation](https://gateway-api.sigs.k8s.io/)

## Chart Architecture 🏗️

This repository provides **two separate Helm charts** that align with the Gateway API resource model:

### 1. `gateway-api` - Infrastructure Layer

**Purpose:** Manages the infrastructure layer of Gateway API.

**What it installs:**
- **CRDs** (optional) - Original Custom Resource Definitions from [kubernetes-sigs/gateway-api](https://github.com/kubernetes-sigs/gateway-api) (v1.4.1, experimental channel)
- **GatewayClass** - Defines the type of gateway controller (e.g., Envoy, AWS ALB, GKE, AKS)
- **Gateway** - Declares the actual gateway instance with listeners, TLS configuration, and network settings

**When to use:** Install this chart once per cluster or namespace to set up the gateway infrastructure. Typically managed by cluster operators or infrastructure teams.

### 2. `gateway-api-routes` - Routing Layer

**Purpose:** Manages the routing layer of Gateway API.

**What it installs:**
- **HTTPRoute** - HTTP traffic routing rules
- **GRPCRoute** - gRPC traffic routing rules
- **TCPRoute** - TCP traffic routing rules
- **UDPRoute** - UDP traffic routing rules

**When to use:** Install this chart per application or team to define routing rules. Routes reference Gateways via `parentRefs`. Typically managed by application developers.

### Why Two Charts? 🤔

This separation provides:

1. **Role-oriented design** - Matches Gateway API's three-layer model (Infrastructure Provider → Cluster Operator → Application Developer)
2. **Independent lifecycle** - Infrastructure changes (GatewayClass, Gateway) don't require redeploying routes
3. **Multi-tenancy** - Multiple teams can deploy routes independently while sharing the same Gateway infrastructure
4. **Flexibility** - Use `gateway-api` as a dependency in infrastructure charts, and `gateway-api-routes` in application charts

## Why This Chart? 🌟
Provides opinionated yet flexible configurations for:
- **CRD management** (an optional installation)
- **GatewayClass** templates (cloud-agnostic or provider-specific)
- **Gateway** declarations with TLS/HTTPS best practices
- **HTTPRoute** configurations with path-based routing
- **GRPCRoute** configurations with service-based routing
- **TCPRoute** configurations with port-based routing
- **UDPRoute** configurations with port-based routing

Designed to be used either:
- **As your main chart** for API gateway deployment
- **As a dependency/subchart** in larger applications needing routing

## Quick Start 🚀

Install the Gateway API Helm chart from [charts.cdnn.host](https://charts.cdnn.host/):

### Add repository

```bash
helm repo add dev2prod https://charts.cdnn.host/
helm repo update
helm repo search dev2prod
```

### To skip CRD installation, use the following command:

```bash
helm install my-gateway dev2prod/gateway-api \
  --version 1.0.0 \
  --skip-crds
```

Install gateway-api with CRDs
```bash
helm install my-gateway dev2prod/gateway-api \
  --version 1.0.0
```

### Install gateway-api-routes
```bash
helm install routes dev2prod/gateway-api-routes \
  --version 1.0.0
```

## Features 📦
✔️ **CRD Management** — Original CRDs from kubernetes-sigs (unchanged)
✔️ **CRD Version** v1.4.1 (experimental) — TCPRoute, TLSRoute, UDPRoute, experimental features
✔️ **Two Helm charts** — gateway-api (infra) and gateway-api-routes (HTTPRoute, GRPCRoute, TCPRoute, UDPRoute)

## Configuration Example 🔧

### gateway-api

```yaml
# values.yaml
gatewayClass:
  name: envoy-gateway
  controller: "application-networking.k8s.aws/gateway-controller"

gateway:
  name: envoy-gateway
  listeners:
  - protocol: HTTPS
    port: 443
    tls:
      mode: Terminate
      certificateRefs:
      - name: mydomain-com-tls
        kind: Secret
```
### gateway-api-routes

```yaml
httpRoute:
  enabled: true
  items:
  - name: http-filter-redirect
    parentRefs:
    - name: redirect-gateway
      sectionName: http
    hostnames:
    - redirect.example
    rules:
    - filters:
      - type: RequestRedirect
        requestRedirect:
          scheme: https
          statusCode: 301
  - name: https-route
    parentRefs:
    - name: redirect-gateway
      sectionName: https
    hostnames:
    - redirect.example
    rules:
    - backendRefs:
      - name: example-svc
        port: 80
```

---

📚 **Official References**:
- [Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
- [Gateway API Guides](https://gateway-api.sigs.k8s.io/guides/)

🔗 **Related Projects**:
- [Gateway API Providers](https://gateway-api.sigs.k8s.io/implementations/)

---

## Maintainer 👤

This is a personal project maintained by:

**Kirill Kazakov** - Full Stack DevOps and Magician

- **Website:** [kazakov.xyz](https://kazakov.xyz/)
- **Email:** k@kazakov.xyz

---

_Maintained with ❤️ by [Kirill Kazakov](https://kazakov.xyz/). Licensed under [Apache 2.0](LICENSE)._
