# Gateway API Examples

Ready-to-use configurations for common Gateway API scenarios.

## Quick Start

```bash
# Use an example with your installation
helm install my-gateway dev2prod/gateway-api \
  --values examples/cloud-providers/aws-alb/values.yaml
```

## Available Examples

### Cloud Providers

- **[AWS ALB](cloud-providers/aws-alb/)** - AWS Application Load Balancer
- **[GKE GCLB](cloud-providers/gke-gclb/)** - Google Kubernetes Engine with Cloud Load Balancer
- **[AKS AGIC](cloud-providers/aks-agic/)** - Azure Kubernetes Service with Application Gateway

### Features

- **[Canary Release](features/canary-release/)** - Gradual traffic rollout
- **[Mutual TLS](features/mutual-tls/)** - Client certificate authentication
- **[Rate Limiting](features/rate-limiting/)** - Request throttling

## Best Practices

1. **Review values before use** - Examples are templates, customize for your environment
2. **Update TLS certificates** - Replace example certificate references with your own
3. **Adjust hostnames** - Change example.com to your actual domains
4. **Test in staging first** - Validate configuration before production
5. **Use version pinning** - Specify chart version in production

## Customization

Each example includes comments explaining key settings. Common customizations:

- Controller names (provider-specific)
- Gateway and GatewayClass names
- Listener ports and protocols
- TLS certificate references
- Namespace restrictions

## Need Help?

- Check the [main README](../../README.md) for general usage
- Review [Gateway API documentation](https://gateway-api.sigs.k8s.io/)
- Check [Gateway API Guides](https://gateway-api.sigs.k8s.io/guides/) for detailed examples
- See provider-specific docs for advanced features
