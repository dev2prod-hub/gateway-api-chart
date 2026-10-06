# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Helm chart repository is now served from `https://charts.oncdn.xyz/`; chart `home` URLs and docs updated

### Migration
Existing users must switch to the new repository URL:

```bash
helm repo remove dev2prod
helm repo add dev2prod https://charts.oncdn.xyz/
```

Flux users: update `HelmRepository.spec.url` to `https://charts.oncdn.xyz/`.

**Warning:** do not use the old host `charts.cdnn.host`, even if it starts resolving again. The domain has expired; anyone can register it and serve their own `index.yaml`.

## [1.0.0] - 2024-12-23

### Added
- Stable release of gateway-api Helm chart
- Added `.helmignore` file for better chart packaging
- Added `NOTES.txt` template for improved user experience after installation
- Comprehensive documentation updates
- CRD version: v1.4.1 (experimental channel) from kubernetes-sigs/gateway-api

### Changed
- **BREAKING**: Updated GatewayClass API version from `v1beta1` to `v1` to align with latest Gateway API CRDs
- Chart version bumped to `1.0.0` for stable release
- Using experimental CRDs for maximum feature support (TCPRoute, TLSRoute, UDPRoute, and experimental features)

### Fixed
- API version consistency across all templates
- Documentation references updated

### Security
- No security changes in this release

## [0.2.0] - Previous Release

### Changed
- Initial stable version preparation

## [0.1.3-alpha.3] - Previous Release

### Added
- Initial alpha release with experimental CRDs
- Gateway and GatewayClass templates
- Support for HTTPRoute, GRPCRoute, TCPRoute, UDPRoute
