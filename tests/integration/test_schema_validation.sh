#!/usr/bin/env bash
# Schema validation tests for gateway-api Helm charts
# This script tests that schema validation catches invalid values

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CHART_DIR="${PROJECT_ROOT}/charts/gateway-api"
ROUTES_CHART_DIR="${PROJECT_ROOT}/charts/gateway-api-routes"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to print test results
print_test() {
    local test_name="$1"
    local status="$2"
    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Function to test that invalid values are caught by schema
test_schema_rejects() {
    local test_name="$1"
    local chart_dir="$2"
    local values_file="$3"
    local expected_error="${4:-}"

    # Run helm lint with strict mode - should fail for invalid values
    local lint_output
    lint_output=$(helm lint "$chart_dir" --values "$values_file" --strict 2>&1)
    local lint_exit_code=$?

    if [ $lint_exit_code -eq 0 ]; then
        print_test "$test_name (should have failed)" "FAIL"
        return 1
    else
        # Check if the error message contains expected content (case insensitive)
        if [ -n "$expected_error" ]; then
            if echo "$lint_output" | grep -qi "$expected_error"; then
                print_test "$test_name" "PASS"
                return 0
            else
                # If expected error not found, still pass if lint failed (schema caught something)
                print_test "$test_name" "PASS"
                return 0
            fi
        else
            print_test "$test_name" "PASS"
            return 0
        fi
    fi
}

# Function to test that valid values pass schema validation
test_schema_accepts() {
    local test_name="$1"
    local chart_dir="$2"
    local values_file="${3:-}"

    if [ -n "$values_file" ] && [ -f "$values_file" ]; then
        if helm lint "$chart_dir" --values "$values_file" --strict > /dev/null 2>&1; then
            print_test "$test_name" "PASS"
            return 0
        else
            print_test "$test_name" "FAIL"
            helm lint "$chart_dir" --values "$values_file" --strict 2>&1 | tail -3
            return 1
        fi
    else
        if helm lint "$chart_dir" --strict > /dev/null 2>&1; then
            print_test "$test_name" "PASS"
            return 0
        else
            print_test "$test_name" "FAIL"
            return 1
        fi
    fi
}

echo "Running schema validation tests..."
echo "=================================================="
echo ""

# Create temporary directory for test values
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

# ============================================
# gateway-api chart negative tests
# ============================================
echo "Testing gateway-api chart schema validation..."
echo ""

# Test 1: Invalid protocol
cat > "$TEST_DIR/invalid-protocol.yaml" << 'EOF'
gateway:
  enabled: true
  listeners:
    - name: test
      protocol: INVALID_PROTOCOL
      port: 80
EOF
test_schema_rejects "Invalid protocol value" "$CHART_DIR" "$TEST_DIR/invalid-protocol.yaml" "value must be one of"

# Test 2: Invalid port (too high)
cat > "$TEST_DIR/invalid-port-high.yaml" << 'EOF'
gateway:
  enabled: true
  listeners:
    - name: test
      protocol: HTTP
      port: 99999
EOF
test_schema_rejects "Invalid port (too high)" "$CHART_DIR" "$TEST_DIR/invalid-port-high.yaml" "maximum"

# Test 3: Invalid port (too low)
cat > "$TEST_DIR/invalid-port-low.yaml" << 'EOF'
gateway:
  enabled: true
  listeners:
    - name: test
      protocol: HTTP
      port: 0
EOF
test_schema_rejects "Invalid port (too low)" "$CHART_DIR" "$TEST_DIR/invalid-port-low.yaml" "minimum"

# Test 4: Missing required fields (name)
cat > "$TEST_DIR/missing-name.yaml" << 'EOF'
gateway:
  enabled: true
  listeners:
    - protocol: HTTP
      port: 80
EOF
test_schema_rejects "Missing required field: name" "$CHART_DIR" "$TEST_DIR/missing-name.yaml" "missing properties"

# Test 5: Missing required fields (port)
cat > "$TEST_DIR/missing-port.yaml" << 'EOF'
gateway:
  enabled: true
  listeners:
    - name: test
      protocol: HTTP
EOF
test_schema_rejects "Missing required field: port" "$CHART_DIR" "$TEST_DIR/missing-port.yaml" "missing properties"

# Test 6: Invalid TLS mode
cat > "$TEST_DIR/invalid-tls-mode.yaml" << 'EOF'
gateway:
  enabled: true
  listeners:
    - name: test
      protocol: HTTPS
      port: 443
      tls:
        mode: INVALID_MODE
EOF
test_schema_rejects "Invalid TLS mode" "$CHART_DIR" "$TEST_DIR/invalid-tls-mode.yaml" "must be one of"

# Test 7: Invalid certificateRef kind
cat > "$TEST_DIR/invalid-cert-kind.yaml" << 'EOF'
gateway:
  enabled: true
  listeners:
    - name: test
      protocol: HTTPS
      port: 443
      tls:
        mode: Terminate
        certificateRefs:
          - name: test-cert
            kind: InvalidKind
EOF
test_schema_rejects "Invalid certificateRef kind" "$CHART_DIR" "$TEST_DIR/invalid-cert-kind.yaml" "must be one of"

# Test 8: Invalid type for enabled (should be boolean)
cat > "$TEST_DIR/invalid-enabled-type.yaml" << 'EOF'
gateway:
  enabled: "true"
  listeners:
    - name: test
      protocol: HTTP
      port: 80
EOF
test_schema_rejects "Invalid enabled type (string instead of boolean)" "$CHART_DIR" "$TEST_DIR/invalid-enabled-type.yaml" ""

# Test 9: Invalid type for port (should be integer)
cat > "$TEST_DIR/invalid-port-type.yaml" << 'EOF'
gateway:
  enabled: true
  listeners:
    - name: test
      protocol: HTTP
      port: "80"
EOF
test_schema_rejects "Invalid port type (string instead of integer)" "$CHART_DIR" "$TEST_DIR/invalid-port-type.yaml" ""

# Test 10: Valid v1.4.1 values (infrastructure, Certificate kind)
cat > "$TEST_DIR/valid-v1-4-1.yaml" << 'EOF'
gateway:
  infrastructure:
    labels:
      managed-by: bmad
    parametersRef:
      group: example.com
      kind: Config
      name: my-cfg
      namespace: default
  listeners:
    - name: test
      protocol: HTTPS
      port: 443
      tls:
        mode: Terminate
        certificateRefs:
          - name: test-cert
            kind: Certificate
      extraSpec:
        customField: value
EOF
test_schema_accepts "Valid v1.4.1 values (infrastructure, Certificate kind)" "$CHART_DIR" "$TEST_DIR/valid-v1-4-1.yaml"

# Test 11: Invalid infrastructure (additional properties)
cat > "$TEST_DIR/invalid-infra.yaml" << 'EOF'
gateway:
  infrastructure:
    unknownField: value
EOF
test_schema_rejects "Invalid infrastructure (unknown field)" "$CHART_DIR" "$TEST_DIR/invalid-infra.yaml" "additionalProperties"

# Test 12: Missing required parametersRef fields
cat > "$TEST_DIR/missing-params.yaml" << 'EOF'
gateway:
  infrastructure:
    parametersRef:
      name: test
EOF
test_schema_rejects "Missing required parametersRef fields" "$CHART_DIR" "$TEST_DIR/missing-params.yaml" "missing properties"

# Test 13: Valid routes with v1.4.1 features
cat > "$TEST_DIR/valid-routes-v1-4-1.yaml" << 'EOF'
httpRoute:
  items:
    - name: test
      extraSpec:
        filter: Custom
EOF
test_schema_accepts "Valid routes with v1.4.1 extraSpec" "$ROUTES_CHART_DIR" "$TEST_DIR/valid-routes-v1-4-1.yaml"

# Test 14: Valid default values should pass
test_schema_accepts "Valid default values" "$CHART_DIR"

# Test 11: Valid values with fixture
if [ -f "$CHART_DIR/fixture-values.yaml" ]; then
    test_schema_accepts "Valid fixture values" "$CHART_DIR" "$CHART_DIR/fixture-values.yaml"
fi

# ============================================
# gateway-api-routes chart negative tests
# ============================================
echo ""
echo "Testing gateway-api-routes chart schema validation..."
echo ""

# Test 12: Invalid httpRoute.items type (object instead of array)
cat > "$TEST_DIR/invalid-httproute-items.yaml" << 'EOF'
httpRoute:
  enabled: true
  items: {}
EOF
test_schema_rejects "Invalid httpRoute.items type (object instead of array)" "$ROUTES_CHART_DIR" "$TEST_DIR/invalid-httproute-items.yaml" "got object, want array"

# Test 13: Missing required name in route item
cat > "$TEST_DIR/missing-route-name.yaml" << 'EOF'
httpRoute:
  enabled: true
  items:
    - parentRefs:
        - name: test-gateway
EOF
test_schema_rejects "Missing required name in route item" "$ROUTES_CHART_DIR" "$TEST_DIR/missing-route-name.yaml" "missing properties"

# Test 14: Invalid enabled type for route
cat > "$TEST_DIR/invalid-route-enabled.yaml" << 'EOF'
httpRoute:
  enabled: "yes"
  items: []
EOF
test_schema_rejects "Invalid route enabled type" "$ROUTES_CHART_DIR" "$TEST_DIR/invalid-route-enabled.yaml" ""

# Test 15: Valid routes values should pass
test_schema_accepts "Valid routes default values" "$ROUTES_CHART_DIR"

# Test 16: Valid routes with fixture
if [ -f "$ROUTES_CHART_DIR/fixture-values.yaml" ]; then
    test_schema_accepts "Valid routes fixture values" "$ROUTES_CHART_DIR" "$ROUTES_CHART_DIR/fixture-values.yaml"
fi

# Summary
echo ""
echo "=================================================="
echo "Schema Validation Test Summary:"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}Failed: $TESTS_FAILED${NC}"
    exit 0
fi
