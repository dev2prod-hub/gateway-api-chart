# AWS ALB Example

Gateway API configuration for AWS Application Load Balancer.

## What This Does

Configures a Gateway and GatewayClass to use AWS ALB Controller, which creates Application Load Balancers for your Gateway resources.

## Prerequisites

1. **AWS Load Balancer Controller installed**
   ```bash
   # Install via Helm or other method
   helm repo add eks https://aws.github.io/eks-charts
   helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
     --set clusterName=your-cluster-name
   ```

2. **IAM permissions** - Controller needs permissions to create ALBs
3. **TLS certificate** - Create Secret with your certificate:
   ```bash
   kubectl create secret tls example-com-tls \
     --cert=path/to/cert.pem \
     --key=path/to/key.pem
   ```

## Configuration

Key settings in `values.yaml`:

- **Controller:** `application-networking.k8s.aws/gateway-controller`
- **Listeners:** HTTP (80) and HTTPS (443)
- **TLS:** Terminate mode with certificate reference
- **Allowed routes:** All namespaces

## Installation

```bash
helm install aws-gateway dev2prod/gateway-api \
  --values examples/cloud-providers/aws-alb/values.yaml
```

## Customization

Before installing, update:

1. **Certificate name** - Change `example-com-tls` to your Secret name
2. **Hostname** - Update `*.example.com` to your domain
3. **Gateway names** - Adjust if you need multiple gateways

## Verification

```bash
# Check Gateway status
kubectl get gateway aws-alb-gateway

# Check ALB creation (may take a few minutes)
kubectl get gateway aws-alb-gateway -o jsonpath='{.status.addresses}'
```

## Troubleshooting

- **ALB not created:** Check controller logs and IAM permissions
- **Certificate errors:** Verify Secret exists and is in the same namespace
- **DNS not resolving:** Wait for ALB DNS name, then update your DNS records

## Resources

- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Gateway API on AWS](https://gateway-api.sigs.k8s.io/implementations/)
