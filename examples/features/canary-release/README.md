# Canary Release Example

Gradual traffic rollout configuration for safe deployments.

## What This Does

Sets up a Gateway for canary deployments where you can gradually shift traffic from the old version to the new version.

## How It Works

1. **Gateway** - Provides the entry point (this example)
2. **HTTPRoutes** - Define traffic splitting rules (use `gateway-api-routes` chart)
3. **Backend services** - Old (stable) and new (canary) versions

## Configuration

This example provides the Gateway foundation. Traffic splitting is configured via HTTPRoute resources:

```yaml
# Example HTTPRoute for canary (90% stable, 10% canary)
rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: stable-service
      port: 80
      weight: 90
    - name: canary-service
      port: 80
      weight: 10
```

## Installation

```bash
# Install Gateway
helm install canary-gateway dev2prod/gateway-api \
  --values examples/features/canary-release/values.yaml

# Then create HTTPRoutes with traffic splitting
helm install canary-routes dev2prod/gateway-api-routes \
  --values your-canary-routes.yaml
```

## Best Practices

1. **Start small** - Begin with 5-10% traffic to canary
2. **Monitor metrics** - Watch error rates, latency, success metrics
3. **Gradual increase** - Increase canary percentage over time (10% → 25% → 50% → 100%)
4. **Automated rollback** - Set up alerts to automatically rollback on errors
5. **Feature flags** - Use feature flags in addition to traffic splitting

## Traffic Splitting Strategies

### Percentage-based
Split traffic by percentage (e.g., 90/10, 50/50)

### Header-based
Route specific users (e.g., internal team) to canary:
```yaml
matches:
  - headers:
    - name: X-Canary
      value: "true"
```

### Path-based
Route specific paths to canary:
```yaml
matches:
  - path:
      type: PathPrefix
      value: /v2
```

## Verification

```bash
# Check Gateway status
kubectl get gateway canary-gateway

# Monitor traffic distribution
# Use your monitoring tools to verify traffic split
```

## Rollback

To rollback, update HTTPRoute to route 100% to stable service:

```yaml
backendRefs:
- name: stable-service
  port: 80
  weight: 100
```

## Resources

- [Gateway API Traffic Splitting](https://gateway-api.sigs.k8s.io/guides/traffic-splitting/)
- [Gateway API Guides](https://gateway-api.sigs.k8s.io/guides/)
