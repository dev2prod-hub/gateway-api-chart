# Mutual TLS (mTLS) Example

Client certificate authentication configuration.

## What This Does

Configures Gateway API for mutual TLS, where both the server and client present certificates for authentication.

## How It Works

Two approaches:

1. **Passthrough mode** - TLS is terminated at the backend, Gateway passes through encrypted traffic
2. **Terminate mode** - Gateway terminates TLS and validates client certificates

## Configuration

### Passthrough Mode (Recommended for mTLS)

Gateway passes encrypted traffic to backend, backend handles mTLS:

```yaml
listeners:
  - name: https-mtls
    protocol: HTTPS
    port: 443
    tls:
      mode: Passthrough  # Backend handles mTLS
```

### Terminate Mode

Gateway terminates TLS and can validate client certificates (provider-specific):

```yaml
listeners:
  - name: https-terminate
    protocol: HTTPS
    port: 8443
    tls:
      mode: Terminate
      certificateRefs:
        - name: server-cert
          kind: Secret
      # Client certificate validation is provider-specific
```

## Prerequisites

1. **Server certificate** - TLS certificate for the Gateway
2. **Client certificates** - CA certificate for validating clients
3. **Backend configured** - Backend service must support mTLS (if using Passthrough)

## Installation

```bash
helm install mtls-gateway dev2prod/gateway-api \
  --values examples/features/mutual-tls/values.yaml
```

## Provider-Specific Notes

### Envoy Gateway
Client certificate validation configured via EnvoyProxy CRD or annotations.

### Cloud Providers
- **AWS ALB:** Limited mTLS support, check AWS documentation
- **GKE:** Supports client certificate validation
- **AKS:** Application Gateway supports client certificate validation

## Client Certificate Setup

Clients must present valid certificates signed by your CA:

```bash
# Generate client certificate
openssl req -new -key client.key -out client.csr
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -out client.crt

# Use in client requests
curl --cert client.crt --key client.key https://secure.example.com
```

## Best Practices

1. **Use Passthrough** - Simplest approach, backend handles mTLS
2. **Rotate certificates** - Regularly rotate both server and client certificates
3. **Monitor failures** - Track certificate validation failures
4. **Documentation** - Keep CA and certificate details documented securely
5. **Backup CA** - Store CA keys securely, losing them breaks all clients

## Verification

```bash
# Test with valid client certificate
curl --cert client.crt --key client.key https://secure.example.com

# Test without certificate (should fail)
curl https://secure.example.com
# Expected: Certificate required error
```

## Troubleshooting

- **Certificate errors:** Verify certificate format and CA chain
- **Connection refused:** Check backend mTLS configuration (Passthrough mode)
- **Provider limitations:** Some providers have limited mTLS support

## Resources

- [Gateway API TLS Configuration](https://gateway-api.sigs.k8s.io/reference/spec/#gateway.networking.k8s.io/v1.TLSConfig)
- [mTLS Best Practices](https://kubernetes.io/docs/tasks/tls/managing-tls-in-a-cluster/)
