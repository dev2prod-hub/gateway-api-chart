# Testing Guide

This directory contains tests for the gateway-api Helm chart.

## Test Types

### 1. Integration Tests (Recommended - Works Now)

Integration tests verify that the chart templates render correctly and validate the chart structure.

**Run integration tests:**
```bash
# From project root
./tests/integration/test_integration.sh

# Or with bash explicitly
bash tests/integration/test_integration.sh
```

**What it tests:**
- Helm lint check
- Template rendering with default values
- Template rendering with fixture values
- API version verification (v1)
- CRD presence check
- All example configurations
- Edge cases (disabled components)

**Expected output:**
```
Running integration tests for gateway-api chart...
==================================================

✓ Helm lint check
✓ Template rendering (default values)
✓ Template rendering (fixture values)
✓ API version is v1
✓ CRDs are present (found 12 CRDs)

Testing example configurations...
✓ Example: aks-agic
✓ Example: aws-alb
✓ Example: gke-gclb
✓ Example: canary-release
✓ Example: mutual-tls
✓ Example: rate-limiting
✓ Gateway disabled
✓ GatewayClass disabled
✓ Both disabled

==================================================
Test Summary:
Passed: 14
Failed: 0
```

### 2. Unit Tests (Requires helm-unittest Plugin)

Unit tests provide detailed assertions about specific template outputs.

**Install helm-unittest plugin:**
```bash
helm plugin install https://github.com/quintush/helm-unittest
```

**Run unit tests:**
```bash
# From project root
helm unittest charts/gateway-api -f tests/unit/*.yaml

# Or with specific test file
helm unittest charts/gateway-api -f tests/unit/test_gateway.yaml
```

**What it tests:**
- Default values rendering
- Component enable/disable scenarios
- Custom names
- API version verification
- Labels and metadata
- TLS configuration

### 3. Schema Validation Tests

Schema validation tests verify that invalid values are properly caught by the schema.

**Run schema validation tests:**
```bash
# From project root
./tests/integration/test_schema_validation.sh
```

**What it tests:**
- Invalid protocol values
- Invalid port ranges
- Missing required fields
- Invalid TLS configurations
- Type mismatches (string vs integer, object vs array)
- Valid values acceptance

**Expected output:**
```
Running schema validation tests...
==================================================

Testing gateway-api chart schema validation...

✓ Invalid protocol value
✓ Invalid port (too high)
✓ Invalid port (too low)
✓ Missing required field: name
✓ Missing required field: port
✓ Invalid TLS mode
✓ Invalid certificateRef kind
✓ Invalid enabled type (string instead of boolean)
✓ Invalid port type (string instead of integer)
✓ Valid default values
✓ Valid fixture values

Testing gateway-api-routes chart schema validation...

✓ Invalid httpRoute.items type (object instead of array)
✓ Missing required name in route item
✓ Invalid route enabled type
✓ Valid routes default values
✓ Valid routes fixture values

==================================================
Schema Validation Test Summary:
Passed: 16
Failed: 0
```

**See detailed guide:** `tests/SCHEMA_TESTING.md`

### 4. Manual Testing Commands

#### Helm Lint
```bash
helm lint charts/gateway-api
helm lint charts/gateway-api --strict  # More strict validation
```

#### Helm Template (Dry Run)
```bash
# Default values
helm template test-release charts/gateway-api

# With custom values
helm template test-release charts/gateway-api --values charts/gateway-api/fixture-values.yaml

# With example values
helm template test-release charts/gateway-api --values examples/cloud-providers/aws-alb/values.yaml

# Debug mode (shows computed values)
helm template test-release charts/gateway-api --debug

# Validate against Kubernetes API
helm template test-release charts/gateway-api | kubectl apply --dry-run=client -f -
```

#### Test Specific Examples
```bash
# Test all examples
for example in examples/cloud-providers/*/values.yaml examples/features/*/values.yaml; do
  echo "Testing: $example"
  helm template test-release charts/gateway-api --values "$example" > /dev/null 2>&1 && echo "  ✓ Valid" || echo "  ✗ Invalid"
done
```

#### Verify CRDs
```bash
# Count CRDs
find charts/gateway-api/crds -name "*.yaml" | wc -l

# List CRDs
ls -1 charts/gateway-api/crds/experimental/

# Check CRD version
grep "bundle-version" charts/gateway-api/crds/experimental/*.yaml | head -1
```

## Quick Test Commands

### Run All Tests
```bash
# Integration tests
./tests/integration/test_integration.sh

# Schema validation tests
./tests/integration/test_schema_validation.sh

# Lint (includes schema validation with --strict)
helm lint charts/gateway-api --strict

# Template validation
helm template test-release charts/gateway-api > /dev/null && echo "✓ Template valid"
```

### Test Specific Scenarios
```bash
# Test with gateway disabled
helm template test-release charts/gateway-api --set gateway.enabled=false

# Test with gatewayClass disabled
helm template test-release charts/gateway-api --set gatewayClass.enabled=false

# Test with custom values
helm template test-release charts/gateway-api \
  --set gateway.name=my-gateway \
  --set gatewayClass.name=my-gatewayclass
```

## Troubleshooting

### Integration tests fail
- Ensure you're in the project root directory
- Check that Helm is installed: `helm version`
- Verify chart directory exists: `ls -la charts/gateway-api`

### Unit tests fail
- Install helm-unittest plugin: `helm plugin install https://github.com/quintush/helm-unittest`
- Verify plugin: `helm plugin list`
- Check test file syntax: `cat tests/unit/test_gateway.yaml`

### Template rendering errors
- Check values file syntax: `yamllint charts/gateway-api/values.yaml`
- Validate template syntax: `helm template test-release charts/gateway-api --debug`
- Check for missing required values

## CI/CD Integration

The tests are designed to run in CI/CD pipelines. See `.github/workflows/lint-test-release.yaml` for GitHub Actions integration.

**Note:** Unit tests are currently commented out in CI (TBD) but can be run manually after installing helm-unittest plugin.
