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
test_template() {
    local test_name="$1"
    local values_file="${2:-}"
    local extra_flags="${3:-}"

    if [ -n "$values_file" ] && [ -f "$values_file" ]; then
        if helm template test-release "$CHART_DIR" --values "$values_file" $extra_flags > /dev/null 2>&1; then
            print_test "$test_name" "PASS"
            return 0
        else
            print_test "$test_name" "FAIL"
            helm template test-release "$CHART_DIR" --values "$values_file" $extra_flags 2>&1 | tail -5
            return 1
        fi
    else
        if helm template test-release "$CHART_DIR" $extra_flags > /dev/null 2>&1; then
            print_test "$test_name" "PASS"
            return 0
        else
            print_test "$test_name" "FAIL"
            helm template test-release "$CHART_DIR" $extra_flags 2>&1 | tail -5
            return 1
        fi
    fi
}

# Function to test helm lint
test_lint() {
    local test_name="$1"
    if helm lint "$CHART_DIR" > /dev/null 2>&1; then
        print_test "$test_name" "PASS"
        return 0
    else
        print_test "$test_name" "FAIL"
        return 1
    fi
}

# Function to verify API versions
test_api_version() {
    local test_name="$1"
    local expected_version="gateway.networking.k8s.io/v1"

    if helm template test-release "$CHART_DIR" 2>/dev/null | grep -q "apiVersion: $expected_version"; then
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
    local crd_count

    crd_count=$(find "$CHART_DIR/crds" -name "*.yaml" 2>/dev/null | wc -l | tr -d ' ')

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
test_lint "Helm lint check"

# Test 2: Template rendering with default values
test_template "Template rendering (default values)"

# Test 3: Template rendering with fixture values
if [ -f "$CHART_DIR/fixture-values.yaml" ]; then
    test_template "Template rendering (fixture values)" "$CHART_DIR/fixture-values.yaml"
fi

# Test 4: API version check
test_api_version "API version is v1"

# Test 5: CRDs present
test_crds_present "CRDs are present"

# Test 6: Test with all examples
echo ""
echo "Testing example configurations..."
for example in "$PROJECT_ROOT/examples/cloud-providers"/*/values.yaml "$PROJECT_ROOT/examples/features"/*/values.yaml; do
    if [ -f "$example" ]; then
        example_name=$(basename "$(dirname "$example")")
        test_template "Example: $example_name" "$example"
    fi
done

# Test 7: Gateway disabled
test_template "Gateway disabled" "" "--set gateway.enabled=false"

# Test 8: GatewayClass disabled
test_template "GatewayClass disabled" "" "--set gatewayClass.enabled=false"

# Test 9: Both disabled (should still render, just empty)
test_template "Both disabled" "" "--set gateway.enabled=false --set gatewayClass.enabled=false"

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
