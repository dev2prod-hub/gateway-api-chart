# Cloud Provider Examples

Gateway API configurations for major cloud providers.

## Overview

These examples configure Gateway API to work with cloud-native load balancers and ingress controllers.

## Prerequisites

Each provider requires:
- Kubernetes cluster running on the respective cloud
- Provider-specific Gateway API controller installed
- Appropriate IAM/RBAC permissions configured

## Examples

### AWS ALB
Application Load Balancer via AWS Load Balancer Controller.

**Controller:** `application-networking.k8s.aws/gateway-controller`

### GKE GCLB
Google Cloud Load Balancer via GKE Gateway Controller.

**Controller:** `networking.gke.io/gateway`

### AKS AGIC
Azure Application Gateway via Application Gateway Ingress Controller.

**Controller:** `azure.com/application-gateway`

## Installation

1. Install the provider's Gateway API controller
2. Review and customize the example values.yaml
3. Update TLS certificate references
4. Install the chart with the example values

```bash
helm install my-gateway dev2prod/gateway-api \
  --values examples/cloud-providers/aws-alb/values.yaml
```

## Important Notes

- Controller names are provider-specific and must match exactly
- Some providers require additional configuration (addresses, annotations)
- TLS certificates must exist as Kubernetes Secrets before installation
- Check provider documentation for advanced features and limitations
