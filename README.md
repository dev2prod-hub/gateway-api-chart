# Gateway API Helm Chart 🚪⚡

[![CI](https://github.com/dev2prod-hub/gateway-api-helm/actions/workflows/lint-test.yaml/badge.svg)](https://github.com/dev2prod-hub/gateway-api-helm/actions)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/gateway-api)](https://artifacthub.io/packages/search?repo=gateway-api)

**Production-ready Helm templates for standardized Kubernetes L7 traffic management using [Gateway API](https://gateway-api.sigs.k8s.io/)** -  
_Stop reinventing Ingress controllers. Start using the Kubernetes-native successor._

## Why This Chart? 🌟
Provides opinionated yet flexible configurations for:
- **GatewayClass** templates (cloud-agnostic or provider-specific)
- **Gateway** declarations with TLS/HTTPS best practices
- **HTTPRoute** configurations with path-based routing
- **CRD management** (optional installation with version pinning)

Designed to be used either:
- **As your main chart** for API gateway deployment
- **As a dependency/subchart** in larger applications needing routing

## Quick Start 🚀
```bash
# Add repository
helm repo add gateway-api https://charts.dev2prod.xyz/

# Install with production profile
helm install my-gateway gateway-api/gateway-api \
  --version 1.2.0 \
  --set profile=production
```

## Features 📦
✔️ **CRD Management** (v1.0+ Gateway API versions)  
✔️ **Pre-configured Listeners** (HTTP/HTTPS, TLS termination)  
✔️ **Multi-cloud Profiles** (AWS ALB, GCP GLB, Azure AGIC)  
✔️ **RBAC-ready** ServiceAccount & Role bindings  
✔️ **Version-safe** upgrades (Helm hooks for CRD changes)

## Configuration Example 🔧
```yaml
# values.yaml
profile: aws

gatewayClasses:
  - name: amazon-lb
    controller: "application-networking.k8s.aws/gateway-controller"

gateways:
  - name: main-gateway
    listeners:
      - protocol: HTTPS
        port: 443
        tls:
          mode: Terminate
          certificateRefs: [acme-cert]
```

## Usage as Subchart 🧩
```yaml
# parent-chart/Chart.yaml
dependencies:
  - name: gateway-api
    version: "~1.2.0"
    repository: "https://charts.dev2prod.xyz/"
    condition: gatewayApi.enabled
```

## Development Setup 💻
```bash
# Test with Kind cluster
kind create cluster
helm dependency update
helm install --dry-run --debug ./charts/gateway-api
```

## Compatibility ✅
| Kubernetes Version | Gateway API Version   |
|--------------------|-----------------------|
| 1.25+              | v1.0.0                |
| 1.23+              | v0.8.0 (experimental) |

---

📚 **Official References**:
- [Gateway API Concepts](https://gateway-api.sigs.k8s.io/concepts/)
- [Migration from Ingress](https://gateway-api.sigs.k8s.io/guides/migration/)

🔗 **Related Projects**:
- [Gateway API Providers](https://gateway-api.sigs.k8s.io/implementations/)
- [Istio Gateway API Support](https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/)

---

_Maintained with ❤️ by Dev2Prod. Licensed under [Apache 2.0](LICENSE)._
