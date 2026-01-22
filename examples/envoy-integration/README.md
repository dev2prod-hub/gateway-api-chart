# Envoy Integration Examples

Gateway API configurations for Envoy-based implementations.

## Overview

Examples for integrating Gateway API with Envoy Gateway and other Envoy-based controllers.

## Available Examples

### Standalone
Basic Envoy Gateway setup for standalone deployments.

## Envoy Gateway

The most common Envoy-based Gateway API implementation.

### Quick Start

1. **Install Envoy Gateway**
   ```bash
   kubectl apply -f https://github.com/envoyproxy/gateway/releases/latest/download/install.yaml
   ```

2. **Install Gateway API chart**
   ```bash
   helm install envoy-gateway dev2prod/gateway-api \
     --set gatewayClass.controllerName="gateway.envoyproxy.io/gatewayclass-controller"
   ```

## Controller Name

All Envoy Gateway examples use:
```
gateway.envoyproxy.io/gatewayclass-controller
```

## Features

Envoy Gateway supports:
- HTTP/HTTPS routing
- TLS termination
- Traffic splitting
- Rate limiting
- Request/response modification
- gRPC routing
- TCP/UDP routing

## Resources

- [Envoy Gateway Documentation](https://gateway.envoyproxy.io/)
- [Gateway API Implementations](https://gateway-api.sigs.k8s.io/implementations/)
