---
title: 'Fix Gateway API v1.4.1 Schema Validation Warnings'
slug: 'fix-gateway-api-1-4-1-schema-warnings'
created: '2026-01-23T17:23:42+03:00'
status: 'Implementation Complete'
stepsCompleted: [1, 2, 3, 4, 5]
tech_stack: ["Helm 3", "JSON Schema Draft-07", "Kubernetes Gateway API v1.4.1"]
files_to_modify: ["charts/gateway-api/values.schema.json", "charts/gateway-api-routes/values.schema.json"]
code_patterns: ["JSON Schema Draft-07", "Kubernetes Role-Oriented Design"]
test_patterns: ["helm lint --strict", "helm-gen.sh validation"]
---

# Tech-Spec: Fix Gateway API v1.4.1 Schema Validation Warnings

**Created:** 2026-01-23T17:23:42+03:00

## Overview

### Problem Statement

Schema validation in the `gateway-api` and `gateway-api-routes` Helm charts is too restrictive for the v1.4.1 "experimental" channel. It prevents the use of new fields (like `infrastructure`), strictly enforces older resource models, and limits common configurations (e.g., cert-manager `Certificate` resources in `certificateRefs`).

### Solution

Update the `values.schema.json` files for both charts to align with Gateway API v1.4.1 specifications. This includes adding support for missing experimental fields, loosening `enum` constraints where standard extensions are common, and allowing `additionalProperties` where implementation-specific fields are expected.

### Scope

**In Scope:**
- Update `charts/gateway-api/values.schema.json` to include `infrastructure`, expanded `certificateRefs`, and detailed `allowedRoutes`.
- Update `charts/gateway-api-routes/values.schema.json` to support v1.4.1 route rule features and filters.
- Ensure `helm lint --strict` passes with valid v1.4.1 configurations.

**Out of Scope:**
- No changes to core CRD files (must remain original from kubernetes-sigs).
- No changes to template logic unless strictly required for schema compatibility.

## Context for Development

### Codebase Patterns

- **JSON Schema**: Both charts use `$schema: "http://json-schema.org/draft-07/schema#"`.
- **Helm Convention**: Charts follow a separate infrastructure/routes model.
- **Strict Linting**: The project relies on `helm lint --strict` for quality control.

### Files to Reference

| File | Purpose |
| ---- | ------- |
| `charts/gateway-api/values.schema.json` | Infrastructure schema to be updated. |
| `charts/gateway-api-routes/values.schema.json` | Routes schema to be updated. |
| `charts/gateway-api/crds/experimental/gateway.networking.k8s.io_gateways.yaml` | Source of truth for Gateway v1.4.1 spec. |
| `tests/SCHEMA_TESTING.md` | Reference for testing schema changes. |

### Technical Decisions

- **Loosen `additionalProperties`**: Set to `true` or specific object schemas where implementation-specific extensions (like Envoy or AWS) are common.
- **Expand `kind` enums**: Include `Certificate` and others in `certificateRefs` to support cert-manager.

## Implementation Plan

### Tasks

- [x] Task 1: Update `gateway-api` schema for v1.4.1 compliance
  - File: `charts/gateway-api/values.schema.json`
  - Action: Add `infrastructure` object to `gateway` and `gatewayClass`. Expand `certificateRefs.items.properties.kind` enum to include `Certificate`. Add `allowedRoutes` structure to listeners.
  - Notes: Set `additionalProperties: true` for `extraSpec` and `tls.options`.
- [x] Task 2: Update `gateway-api-routes` schema for v1.4.1 compliance
  - File: `charts/gateway-api-routes/values.schema.json`
  - Action: Update `httpRoute`, `grpcRoute`, `tcpRoute`, and `udpRoute` item schemas to allow new v1.4.1 fields.
  - Notes: Loosen `rules` and `parentRefs` schema to allow implementation-specific extensions.
- [x] Task 3: Verify schema changes via strict linting
  - File: N/A
  - Action: Run `helm lint charts/gateway-api --strict` and `helm lint charts/gateway-api-routes --strict`.
  - Notes: Fix any regressions or missed required fields.
- [x] Task 4: Enhance test scripts with strict schema validation
  - File: `tests/integration/test_integration.sh`, `scripts/helm-gen.sh`
  - Action: Add `--strict` flag to `helm lint` commands and ensure schema validation runs in generation scripts.
  - Notes: Ensures schema validation is part of the standard testing workflow.

### Acceptance Criteria

- [x] AC 1: Given a valid v1.4.1 Gateway configuration using `infrastructure` fields, when running `helm lint --strict`, then it passes without validation errors.
- [x] AC 2: Given a `certificateRef` with `kind: Certificate`, when running `helm lint --strict`, then it passes without validation errors.
- [x] AC 3: Given invalid port values (e.g., 0 or 70000), when running `helm lint --strict`, then it correctly fails with a schema error.

## Additional Context

### Dependencies

- Gateway API v1.4.1 CRDs (already present in `charts/gateway-api/crds/experimental/`).

### Testing Strategy

- Run `./scripts/helm-gen.sh` and verify no schema warnings in debug output.
- Run `helm lint charts/gateway-api --strict` and `helm lint charts/gateway-api-routes --strict`.

### Notes

- Focus is on "Experimental" channel support as specified in the project README.
- Fixed `test_integration.sh` to use fixture values for `gateway-api-routes` API version check to ensure templates are rendered during testing.
