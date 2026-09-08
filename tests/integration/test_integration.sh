#!/usr/bin/env bash
# Integration tests for gateway-api Helm chart
# This script tests the chart installation and template rendering

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CHART_DIR="${PROJECT_ROOT}/charts/gateway-api"
STANDARD_CHART_DIR="${PROJECT_ROOT}/charts/gateway-api-standard"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
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
    local chart_path="$2"
    local values_file="${3:-}"
    local extra_flags=()
    if [ "$#" -gt 3 ]; then
        extra_flags=("${@:4}")
    fi

    if [ -n "$values_file" ] && [ -f "$values_file" ]; then
        if helm template test-release "$chart_path" --values "$values_file" "${extra_flags[@]+"${extra_flags[@]}"}" > /dev/null 2>&1; then
            print_test "$test_name" "PASS"
            return 0
        else
            print_test "$test_name" "FAIL"
            helm template test-release "$chart_path" --values "$values_file" "${extra_flags[@]+"${extra_flags[@]}"}" 2>&1 | tail -5
            return 1
        fi
    else
        if helm template test-release "$chart_path" "${extra_flags[@]+"${extra_flags[@]}"}" > /dev/null 2>&1; then
            print_test "$test_name" "PASS"
            return 0
        else
            print_test "$test_name" "FAIL"
            helm template test-release "$chart_path" "${extra_flags[@]+"${extra_flags[@]}"}" 2>&1 | tail -5
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
test_lint "Helm lint: gateway-api-standard" "$STANDARD_CHART_DIR"

# Test 2: Template rendering with default values
test_template "Template rendering: gateway-api (default)" "$CHART_DIR"
test_template "Template rendering: gateway-api-routes (default)" "${PROJECT_ROOT}/charts/gateway-api-routes"
test_template "Template rendering: gateway-api-standard (default)" "$STANDARD_CHART_DIR"

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

# Test 5: CRDs present, and the two channels stay in their own charts
test_crds_present "CRDs are present: gateway-api" "$CHART_DIR"
test_crds_present "CRDs are present: gateway-api-standard" "$STANDARD_CHART_DIR"

# The channel annotation must match the chart. Two charts shipping the same CRD
# name with different channels into one cluster would flap under a GitOps
# controller that replaces CRDs on every reconcile.
check_channel() {
    local test_name="$1" chart_dir="$2" expected="$3" found
    # Collect the distinct channel values across all vendored CRDs; there must be
    # exactly one and it must be the expected channel.
    found=$(grep -rho 'gateway.networking.k8s.io/channel: [a-z]*' "$chart_dir/crds" 2>/dev/null \
            | sed 's/.*: //' | sort -u | tr '\n' ' ' | sed 's/ $//')
    if [ "$found" = "$expected" ]; then
        print_test "$test_name" "PASS"
    else
        print_test "$test_name (found: '${found}')" "FAIL"
    fi
}
check_channel "gateway-api ships only the experimental channel" "$CHART_DIR" "experimental"
check_channel "gateway-api-standard ships only the standard channel" "$STANDARD_CHART_DIR" "standard"

# A non-CRD file under crds/ breaks helm lint and is silently dropped by Flux.
for chart_dir in "$CHART_DIR" "$STANDARD_CHART_DIR"; do
    chart_name=$(basename "$chart_dir")
    stray=$(find "$chart_dir/crds" -type f ! -name '*.yaml' 2>/dev/null | wc -l | tr -d ' ')
    non_crd=$(grep -rL "^kind: CustomResourceDefinition" "$chart_dir/crds" --include='*.yaml' 2>/dev/null | wc -l | tr -d ' ')
    if [ "$stray" = "0" ] && [ "$non_crd" = "0" ]; then
        print_test "crds/ contains only CRD manifests: $chart_name" "PASS"
    else
        print_test "crds/ contains only CRD manifests: $chart_name ($stray stray, $non_crd non-CRD)" "FAIL"
    fi
done

# Test 6: Test with all examples
echo ""
echo "Testing example configurations..."
( shopt -s nullglob 2>/dev/null || true
for example in "$PROJECT_ROOT/examples/cloud-providers"/*/values.yaml "$PROJECT_ROOT/examples/features"/*/values.yaml; do
    if [ -f "$example" ]; then
        example_name=$(basename "$(dirname "$example")")
        test_template "Example: $example_name" "$CHART_DIR" "$example"
    fi
done )

# Test 7: Gateway disabled
test_template "Gateway disabled" "$CHART_DIR" "" --set gateway.enabled=false

# Test 8: GatewayClass disabled
test_template "GatewayClass disabled" "$CHART_DIR" "" --set gatewayClass.enabled=false

# Test 9: Both disabled (should still render, just empty)
test_template "Both disabled" "$CHART_DIR" "" --set gateway.enabled=false --set gatewayClass.enabled=false

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
