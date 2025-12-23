# Feature Examples

Gateway API configurations for advanced features and use cases.

## Overview

These examples demonstrate how to configure Gateway API for specific features like canary deployments, mutual TLS, and rate limiting.

## Examples

### Canary Release
Gradual traffic rollout for safe deployments. Routes a percentage of traffic to new versions.

### Mutual TLS
Client certificate authentication for enhanced security. Validates both server and client certificates.

### Rate Limiting
Request throttling to protect backends from overload. Limits requests per second/minute.

## Usage

Each feature example includes:
- Gateway configuration
- Required annotations or settings
- Provider-specific notes

**Note:** Some features require additional configuration via HTTPRoute resources (use `gateway-api-routes` chart) or provider-specific settings.

## Installation

```bash
# Example: Canary release
helm install canary-gateway dev2prod/gateway-api \
  --values examples/features/canary-release/values.yaml
```

## Best Practices

1. **Test in staging** - Validate feature behavior before production
2. **Monitor metrics** - Track success rates, latency, errors
3. **Gradual rollout** - Start with small percentages, increase gradually
4. **Documentation** - Keep notes on your specific configuration
5. **Backup plan** - Know how to rollback if issues occur

## Provider Support

Feature support varies by Gateway API provider:
- **Envoy Gateway:** Full feature support
- **Cloud providers:** Check provider documentation for supported features
- **Custom controllers:** Review controller capabilities

## Combining Features

You can combine multiple features by merging values or using multiple Gateways. For example:
- Canary release with rate limiting
- Mutual TLS with specific route rules
- Multiple features on different listeners
