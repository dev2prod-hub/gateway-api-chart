# GKE GCLB Example

Gateway API configuration for Google Kubernetes Engine with Cloud Load Balancer.

## What This Does

Configures a Gateway to use GKE's native Gateway controller, which provisions Google Cloud Load Balancers.

## Prerequisites

1. **GKE cluster** with Gateway controller enabled
   ```bash
   # Enable Gateway API when creating cluster
   gcloud container clusters create my-cluster \
     --gateway-api=standard
   ```

2. **TLS certificate** - Create Secret:
   ```bash
   kubectl create secret tls api-example-com-tls \
     --cert=path/to/cert.pem \
     --key=path/to/key.pem
   ```

## Configuration

Key settings in `values.yaml`:

- **Controller:** `networking.gke.io/gateway`
- **Listeners:** HTTP (80) and HTTPS (443)
- **Address:** NamedAddress for static IP (optional)
- **TLS:** Terminate mode

## Installation

```bash
helm install gke-gateway dev2prod/gateway-api \
  --values examples/cloud-providers/gke-gclb/values.yaml
```

## Customization

1. **Static IP** - Update `gke-gateway-ip` to your reserved IP name, or remove for ephemeral
2. **Certificate** - Change `api-example-com-tls` to your Secret name
3. **Hostname** - Update `api.example.com` to your domain

## Address Configuration

GKE supports static IP addresses via `extraSpec.addresses`:

```yaml
extraSpec:
  addresses:
    - type: NamedAddress
      value: my-reserved-ip-name
```

Or use an IP address directly:
```yaml
extraSpec:
  addresses:
    - type: IPAddress
      value: 34.123.45.67
```

## Verification

```bash
# Check Gateway status
kubectl get gateway gke-gateway

# Get load balancer IP
kubectl get gateway gke-gateway -o jsonpath='{.status.addresses[0].value}'
```

## Troubleshooting

- **Controller not found:** Ensure Gateway API is enabled on your GKE cluster
- **IP not assigned:** Check quota limits and IP reservation
- **Certificate issues:** Verify Secret format and namespace

## Resources

- [GKE Gateway Controller](https://cloud.google.com/kubernetes-engine/docs/how-to/gateway-api)
- [Gateway API on GKE](https://gateway-api.sigs.k8s.io/implementations/)
