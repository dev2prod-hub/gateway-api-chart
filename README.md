# Gateway API Helm Chart 🚪⚡

[![CI](https://github.com/dev2prod-hub/gateway-api-chart/actions/workflows/lint-test-release.yaml/badge.svg)](https://github.com/dev2prod-hub/gateway-api-chart/actions)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/gateway-api-chart)](https://artifacthub.io/packages/search?repo=gateway-api-chart)

[charts.dev2prod.xyz](https://charts.dev2prod.xyz/)

Replace ingress to the next level with Gateway API Helm Chart.
**Gateway API** is the successor to Ingress, providing a Kubernetes-native way to manage API gateways.
_Stop reinventing Ingress controllers. Start using the Kubernetes-native successor._

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

### Add repository

```bash
helm repo add dev2prod https://charts.dev2prod.xyz/
helm repo update
helm repo search dev2prod
```

### To skip CRD installation, use the following command:

```bash
helm install my-gateway dev2prod/gateway-api \
  --version 0.1.0 \
  --skip-crds
```

Install gateway-api with CRDs
```bash
helm install my-gateway dev2prod/gateway-api \
  --version 0.1.0
````

### Install gateway-api-routes
```bash
helm install routes dev2prod/gateway-api-routes \
  --version 0.1.0
```

## Features 📦
✔️ **CRD Management** (an original CRDs from the kubernetes-sigs without any changes)
✔️ **Split to 2 charts** as a GW API main chart and routes chart

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
- [Gateway API Concepts](https://gateway-api.sigs.k8s.io/concepts/)
- [Migration from Ingress](https://gateway-api.sigs.k8s.io/guides/migration/)

🔗 **Related Projects**:
- [Gateway API Providers](https://gateway-api.sigs.k8s.io/implementations/)

---

_Maintained with ❤️ by Dev2Prod. Licensed under [Apache 2.0](LICENSE)._
