#!/usr/bin/env bash
# Integration tests for gateway-api Helm chart
# This script tests the chart installation and template rendering

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CHART_DIR="${PROJECT_ROOT}/charts/gateway-api"

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

# Function to test helm template rendering
# Function to test helm template rendering
test_template() {
    local test_name="$1"
    local chart_path="$2"
    local values_file="${3:-}"
    local extra_flags="${4:-}"

    if [ -n "$values_file" ] && [ -f "$values_file" ]; then
        if helm template test-release "$chart_path" --values "$values_file" $extra_flags > /dev/null 2>&1; then
            print_test "$test_name" "PASS"
            return 0
        else
            print_test "$test_name" "FAIL"
            helm template test-release "$chart_path" --values "$values_file" $extra_flags 2>&1 | tail -5
            return 1
        fi
    else
        if helm template test-release "$chart_path" $extra_flags > /dev/null 2>&1; then
            print_test "$test_name" "PASS"
            return 0
        else
            print_test "$test_name" "FAIL"
            helm template test-release "$chart_path" $extra_flags 2>&1 | tail -5
            return 1
        fi
    fi
}

# Function to test helm lint with schema validation
test_lint() {
    local test_name="$1"
    local chart_path="$2"
    if helm lint "$chart_path" --strict > /dev/null 2>&1; then
        print_test "$test_name" "PASS"
        return 0
    else
        print_test "$test_name" "FAIL"
        helm lint "$chart_path" --strict 2>&1 | tail -5
        return 1
    fi
}

# Function to verify API versions
test_api_version() {
    local test_name="$1"
    local chart_path="$2"
    local expected_version="gateway.networking.k8s.io/v1"

    if helm template test-release "$chart_path" 2>/dev/null | grep -q "apiVersion: $expected_version"; then
        print_test "$test_name" "PASS"
        return 0
    else
        print_test "$test_name" "FAIL"
        return 1
    fi
}

# Function to verify CRDs are present
test_crds_present() {
    local test_name="$1"
    local chart_path="$2"
    local crd_count

    crd_count=$(find "$chart_path/crds" -name "*.yaml" 2>/dev/null | wc -l | tr -d ' ')

    if [ "$crd_count" -gt 0 ]; then
        print_test "$test_name (found $crd_count CRDs)" "PASS"
        return 0
    else
        print_test "$test_name" "FAIL"
        return 1
    fi
}

echo "Running integration tests for gateway-api chart..."
echo "=================================================="
echo ""

# Test 1: Helm lint
test_lint "Helm lint: gateway-api" "$CHART_DIR"
test_lint "Helm lint: gateway-api-routes" "${PROJECT_ROOT}/charts/gateway-api-routes"

# Test 2: Template rendering with default values
test_template "Template rendering: gateway-api (default)" "$CHART_DIR"
test_template "Template rendering: gateway-api-routes (default)" "${PROJECT_ROOT}/charts/gateway-api-routes"

# Test 3: Template rendering with fixture values
if [ -f "$CHART_DIR/fixture-values.yaml" ]; then
    test_template "Template rendering: gateway-api (fixture)" "$CHART_DIR" "$CHART_DIR/fixture-values.yaml"
fi
if [ -f "${PROJECT_ROOT}/charts/gateway-api-routes/fixture-values.yaml" ]; then
    test_template "Template rendering: gateway-api-routes (fixture)" "${PROJECT_ROOT}/charts/gateway-api-routes" "${PROJECT_ROOT}/charts/gateway-api-routes/fixture-values.yaml"
fi

# Test 4: API version check
test_api_version "API version is v1: gateway-api" "$CHART_DIR"
if [ -f "${PROJECT_ROOT}/charts/gateway-api-routes/fixture-values.yaml" ]; then
    if helm template test-release "${PROJECT_ROOT}/charts/gateway-api-routes" --values "${PROJECT_ROOT}/charts/gateway-api-routes/fixture-values.yaml" 2>/dev/null | grep -q "apiVersion: gateway.networking.k8s.io/v1"; then
        print_test "API version is v1: gateway-api-routes" "PASS"
    else
        print_test "API version is v1: gateway-api-routes" "FAIL"
    fi
fi

# Test 5: CRDs present
test_crds_present "CRDs are present: gateway-api" "$CHART_DIR"

# Test 6: Test with all examples
echo ""
echo "Testing example configurations..."
for example in "$PROJECT_ROOT/examples/cloud-providers"/*/values.yaml "$PROJECT_ROOT/examples/features"/*/values.yaml; do
    if [ -f "$example" ]; then
        example_name=$(basename "$(dirname "$example")")
        test_template "Example: $example_name" "$CHART_DIR" "$example"
    fi
done

# Test 7: Gateway disabled
test_template "Gateway disabled" "$CHART_DIR" "" "--set gateway.enabled=false"

# Test 8: GatewayClass disabled
test_template "GatewayClass disabled" "$CHART_DIR" "" "--set gatewayClass.enabled=false"

# Test 9: Both disabled (should still render, just empty)
test_template "Both disabled" "$CHART_DIR" "" "--set gateway.enabled=false --set gatewayClass.enabled=false"

# Test 10: Schema validation (if schema test script exists)
if [ -f "$SCRIPT_DIR/test_schema_validation.sh" ]; then
    echo ""
    echo "Running schema validation tests..."
    if bash "$SCRIPT_DIR/test_schema_validation.sh" > /dev/null 2>&1; then
        print_test "Schema validation tests" "PASS"
    else
        print_test "Schema validation tests" "FAIL"
    fi
fi

# Summary
echo ""
echo "=================================================="
echo "Test Summary:"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}Failed: $TESTS_FAILED${NC}"
    exit 0
fi
