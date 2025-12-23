# Rate Limiting Example

Request throttling configuration to protect backends.

## What This Does

Configures Gateway API with rate limiting to prevent backends from being overwhelmed by too many requests.

## How It Works

Rate limiting can be implemented at different levels:

1. **Gateway level** - Global rate limits via annotations
2. **HTTPRoute level** - Per-route limits via filters
3. **Provider-specific** - Controller-specific rate limiting features

## Configuration

This example shows Gateway-level annotations (Envoy Gateway):

```yaml
annotations:
  gateway.envoyproxy.io/rate-limit-enabled: "true"
  gateway.envoyproxy.io/rate-limit-requests-per-second: "100"
```

## Installation

```bash
helm install ratelimit-gateway dev2prod/gateway-api \
  --values examples/features/rate-limiting/values.yaml
```

## Provider-Specific Configuration

### Envoy Gateway

Gateway annotations:
```yaml
annotations:
  gateway.envoyproxy.io/rate-limit-enabled: "true"
  gateway.envoyproxy.io/rate-limit-requests-per-second: "100"
```

HTTPRoute filters (more granular):
```yaml
rules:
  - filters:
    - type: ExtensionRef
      extensionRef:
        group: gateway.envoyproxy.io
        kind: RateLimitPolicy
        name: api-rate-limit
```

### Cloud Providers

Rate limiting is typically configured via:
- **AWS ALB:** WAF rules or target group settings
- **GKE:** Cloud Armor policies
- **AKS:** Application Gateway WAF rules

## Best Practices

1. **Start conservative** - Set limits higher initially, tune down based on metrics
2. **Monitor metrics** - Track rate limit hits, 429 responses, backend load
3. **Different limits** - Apply different limits to different routes/users
4. **Graceful degradation** - Return meaningful error messages (429 Too Many Requests)
5. **Whitelisting** - Exclude internal services or critical paths from limits

## Rate Limiting Strategies

### Global Limit
All requests share the same limit pool.

### Per-IP Limit
Limit based on client IP address.

### Per-User Limit
Limit based on authenticated user (requires auth integration).

### Per-Route Limit
Different limits for different routes (e.g., API vs static content).

## Example HTTPRoute with Rate Limit

```yaml
# gateway-api-routes chart
httpRoute:
  items:
    - name: api-route
      parentRefs:
        - name: ratelimit-gateway
      rules:
        - filters:
          - type: ExtensionRef
            extensionRef:
              group: gateway.envoyproxy.io
              kind: RateLimitPolicy
              name: api-limit-100rps
          backendRefs:
            - name: api-service
              port: 80
```

## Verification

```bash
# Check Gateway
kubectl get gateway ratelimit-gateway

# Test rate limiting
# Send many requests quickly, should get 429 after limit
for i in {1..150}; do
  curl -w "\n" https://api.example.com
done
```

## Monitoring

Track these metrics:
- Rate limit hits
- 429 response count
- Requests per second
- Backend response times

## Troubleshooting

- **Too restrictive:** Increase limits or adjust per-route
- **Not working:** Verify provider supports rate limiting
- **Backend still overloaded:** Check if limits are applied correctly

## Resources

- [Gateway API Filters](https://gateway-api.sigs.k8s.io/reference/spec/#gateway.networking.k8s.io/v1.HTTPRouteFilter)
- [Envoy Rate Limiting](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/rate_limit_filter)
