# Schema Validation Testing Guide

This guide explains how to test schema validation for the gateway-api Helm charts.

## Overview

Both `gateway-api` and `gateway-api-routes` charts include `values.schema.json` files that validate user-provided values before chart rendering. This prevents common configuration errors and provides better error messages.

## Quick Start

### Run All Schema Tests

```bash
# From project root
./tests/integration/test_schema_validation.sh
```

This script runs comprehensive negative tests to ensure schema validation catches invalid values.

## Manual Testing

### 1. Test with Helm Lint (Recommended)

Helm lint automatically validates values against the schema when using the `--strict` flag:

```bash
# Test gateway-api chart
helm lint charts/gateway-api --strict

# Test with custom values
helm lint charts/gateway-api --strict --values your-values.yaml

# Test gateway-api-routes chart
helm lint charts/gateway-api-routes --strict --values your-values.yaml
```

### 2. Test with Helm Template

Schema validation also runs during `helm template`:

```bash
# This will fail if values don't match schema
helm template test-release charts/gateway-api --values invalid-values.yaml
```

### 3. Test Invalid Values

Create a test values file with invalid data:

```yaml
# invalid-values.yaml
gateway:
  enabled: true
  listeners:
    - name: test
      protocol: INVALID_PROTOCOL  # Should fail
      port: 80
```

Then test:
```bash
helm lint charts/gateway-api --strict --values invalid-values.yaml
# Expected output: Error about invalid protocol
```

## Test Cases

### gateway-api Chart Schema Tests

#### Invalid Protocol
```yaml
gateway:
  listeners:
    - name: test
      protocol: INVALID_PROTOCOL  # ❌ Should fail
      port: 80
```
**Expected Error:** `value must be one of 'HTTP', 'HTTPS', 'TLS', 'TCP', 'UDP'`

#### Invalid Port (Too High)
```yaml
gateway:
  listeners:
    - name: test
      protocol: HTTP
      port: 99999  # ❌ Should fail (> 65535)
```
**Expected Error:** `maximum`

#### Invalid Port (Too Low)
```yaml
gateway:
  listeners:
    - name: test
      protocol: HTTP
      port: 0  # ❌ Should fail (< 1)
```
**Expected Error:** `minimum`

#### Missing Required Fields
```yaml
gateway:
  listeners:
    - protocol: HTTP  # ❌ Missing 'name' and 'port'
      port: 80
```
**Expected Error:** `missing properties 'name'`

#### Invalid TLS Mode
```yaml
gateway:
  listeners:
    - name: test
      protocol: HTTPS
      port: 443
      tls:
        mode: INVALID_MODE  # ❌ Should fail
```
**Expected Error:** `must be one of 'Terminate', 'Passthrough'`

#### Invalid CertificateRef Kind
```yaml
gateway:
  listeners:
    - name: test
      protocol: HTTPS
      port: 443
      tls:
        mode: Terminate
        certificateRefs:
          - name: test-cert
            kind: InvalidKind  # ❌ Should fail
```
**Expected Error:** `must be one of 'Secret'`

#### Type Mismatches
```yaml
# String instead of boolean
gateway:
  enabled: "true"  # ❌ Should be boolean

# String instead of integer
gateway:
  listeners:
    - name: test
      protocol: HTTP
      port: "80"  # ❌ Should be integer
```

### gateway-api-routes Chart Schema Tests

#### Invalid Items Type
```yaml
httpRoute:
  enabled: true
  items: {}  # ❌ Should be array, not object
```
**Expected Error:** `got object, want array`

#### Missing Required Name
```yaml
httpRoute:
  enabled: true
  items:
    - parentRefs:  # ❌ Missing 'name'
        - name: test-gateway
```
**Expected Error:** `missing properties 'name'`

#### Invalid Enabled Type
```yaml
httpRoute:
  enabled: "yes"  # ❌ Should be boolean
  items: []
```

## Running Specific Tests

### Test Single Invalid Value

```bash
# Create test file
cat > /tmp/test-invalid.yaml << 'EOF'
gateway:
  enabled: true
  listeners:
    - name: test
      protocol: INVALID
      port: 80
EOF

# Test it
helm lint charts/gateway-api --strict --values /tmp/test-invalid.yaml
```

### Test Valid Values

```bash
# Should pass
helm lint charts/gateway-api --strict
helm lint charts/gateway-api --strict --values charts/gateway-api/fixture-values.yaml
```

## Integration with CI/CD

The schema validation tests are designed to run in CI/CD pipelines. Add to your workflow:

```yaml
- name: Run Schema Validation Tests
  run: ./tests/integration/test_schema_validation.sh
```

## Understanding Schema Errors

### Common Error Formats

1. **Enum validation:**
   ```
   value must be one of 'HTTP', 'HTTPS', 'TLS', 'TCP', 'UDP'
   ```

2. **Range validation:**
   ```
   must be >= 1
   must be <= 65535
   ```

3. **Required field:**
   ```
   missing properties 'name', 'port'
   ```

4. **Type mismatch:**
   ```
   got object, want array
   got string, want integer
   ```

### Error Location

Schema errors show the exact path to the invalid value:
```
at '/gateway/listeners/0/protocol': value must be one of ...
```

This tells you:
- The path: `/gateway/listeners/0/protocol`
- The field: `protocol` in the first listener
- The issue: invalid enum value

## Best Practices

1. **Always use `--strict` flag** when linting to enable schema validation
2. **Test with invalid values** to ensure schema catches errors
3. **Update schema** when adding new values to `values.yaml`
4. **Run schema tests** before committing changes
5. **Document schema changes** in CHANGELOG.md

## Troubleshooting

### Schema validation not working?

1. Check schema file exists:
   ```bash
   ls -la charts/gateway-api/values.schema.json
   ```

2. Verify schema is valid JSON:
   ```bash
   python3 -m json.tool charts/gateway-api/values.schema.json > /dev/null
   ```

3. Ensure `--strict` flag is used:
   ```bash
   helm lint charts/gateway-api --strict
   ```

### Schema too strict?

If valid values are being rejected:
1. Check the schema definition matches your values structure
2. Verify enum values include all valid options
3. Ensure optional fields are not marked as required

### Schema not catching errors?

1. Verify schema file is in the chart directory
2. Check Helm version (schema validation requires Helm 3.x)
3. Ensure `--strict` flag is used with `helm lint`

## Additional Resources

- [Helm Values Schema](https://helm.sh/docs/topics/charts/#schema-files)
- [JSON Schema Specification](https://json-schema.org/)
- [Helm Lint Documentation](https://helm.sh/docs/helm/helm_lint/)
