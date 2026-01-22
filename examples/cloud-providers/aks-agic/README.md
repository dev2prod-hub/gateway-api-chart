# AKS AGIC Example

Gateway API configuration for Azure Kubernetes Service with Application Gateway Ingress Controller.

## What This Does

Configures a Gateway to use Azure Application Gateway via AGIC, providing Layer 7 load balancing and SSL termination.

## Prerequisites

1. **AGIC installed** on your AKS cluster
   ```bash
   # Install via Helm
   helm repo add application-gateway-kubernetes-ingress \
     https://appgwingress.blob.core.windows.net/ingress-azure-helm-package/
   helm install ingress-azure application-gateway-kubernetes-ingress/ingress-azure
   ```

2. **Application Gateway** - Must exist in your Azure subscription
3. **TLS certificate** - Create Secret:
   ```bash
   kubectl create secret tls app-example-com-tls \
     --cert=path/to/cert.pem \
     --key=path/to/key.pem
   ```

## Configuration

Key settings in `values.yaml`:

- **Controller:** `azure.com/application-gateway`
- **Listeners:** HTTP (80) and HTTPS (443)
- **TLS:** Terminate mode with certificate reference

## Installation

```bash
helm install aks-gateway dev2prod/gateway-api \
  --values examples/cloud-providers/aks-agic/values.yaml
```

## Customization

1. **Certificate name** - Change `app-example-com-tls` to your Secret name
2. **Hostname** - Update `app.example.com` to your domain
3. **Gateway name** - Adjust if needed for multiple gateways

## Azure-Specific Notes

- Application Gateway must be in the same resource group as AKS
- AGIC requires appropriate RBAC permissions
- Certificates can be stored in Azure Key Vault (advanced)
- Health probes are configured automatically

## Verification

```bash
# Check Gateway status
kubectl get gateway azure-gateway

# Check Application Gateway configuration in Azure Portal
# Navigate to: Application Gateway > Configuration
```

## Troubleshooting

- **Gateway not provisioning:** Check AGIC pod logs and Azure permissions
- **Certificate errors:** Verify Secret exists and format is correct
- **Health probe failures:** Review backend service health

## Resources

- [AGIC Documentation](https://azure.github.io/application-gateway-kubernetes-ingress/)
- [Gateway API on AKS](https://gateway-api.sigs.k8s.io/implementations/)
