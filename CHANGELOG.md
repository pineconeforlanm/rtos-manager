# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-10-17

### Added
- **CMake workflow presets** (`dev`, `full`, `release`, `sanitize`, `docs`,
  `bench`, `ci-lint`) — the entire lifecycle (configure → build → test →
  package) now runs with one command: `cmake --workflow <name>`.
- **packagePresets** for CPack DEB; release workflow produces
  `rtos-manager-<semver>-<build>-<arch>-<hash>[-dirty].deb`.
- **Semantic version parsing** in `cmake/version_info.cmake`:
  `v?MAJOR.MINOR.PATCH[-(alpha|beta|rc).N]` extracted from the latest Git
  tag with project VERSION fallback; new constants
  `RTOS_VERSION_SEMVER/_MAJOR/_MINOR/_PATCH/_PRE_RELEASE/_PRE_NUM/_IS_PRERELEASE`
  exposed to `version_info.hpp` and `/etc/version/<pkg>.version`.
- **DEB maintainer scripts** (`preinst`/`postinst`/`prerm`/`postrm`) that
  auto `systemctl daemon-reload + enable + restart` the service on install
  and clean up on purge.
- **`/etc/version/rtos-manager.version`** installed alongside the package
  (operator-friendly view of semver + git + build metadata).
- **Runnable examples** under `example/` (gated by `RTOS_ENABLE_EXAMPLES`):
  `01_version_info`, `02_config_yaml`, `03_http_minimal`.
- **clang-format / clang-tidy integration** (`cmake/format.cmake` + project
  `.clang-format` and `.clang-tidy`): `format`, `format-check`, `tidy`
  custom targets, plus a `tidy` configure preset that wires
  `CMAKE_CXX_CLANG_TIDY`.
- **Sanitizer presets**: `asan-ubsan` and `tsan` configure presets, plus a
  `sanitize` workflow that builds and tests under ASan+UBSan.
- **OpenAPI 3.1 contract** at `api/openapi.yaml` and `cmake/openapi.cmake`
  exposing `openapi-validate`, `openapi-docs`, `openapi` targets via local
  `npx @redocly/cli`.
- New configure presets: `relwithdebinfo` (optimized + symbols) and the
  sanitizer/tidy set above.
- `version_test` now includes a `SemverLooksCanonical` regression test that
  guards the semver regex against future drift.
- HTTP `/api/v1/version` JSON now exposes `describe` and `prerelease`
  alongside the existing fields.

### Changed
- `CPack` block: corrected `CPACK_PACKING_INSTALL_PREFIX` → **`CPACK_PACKAGING_INSTALL_PREFIX`**
  (the prior typo made the DEB silently fall back to `/usr/local`, mismatching
  the systemd unit's `/usr/bin/...` ExecStart path).
- DEB `CPACK_DEBIAN_PACKAGE_DEPENDS` fallback now also lists `systemd` so
  installs succeed on minimal images lacking `dpkg-shlibdeps`.
- Preset version bumped to **11** (CMake ≥ 3.31) to enable `outputDirectory`
  and the latest workflow semantics.
- `CMAKE_BUILD_PARALLEL_LEVEL` honoured across all build presets via
  `"jobs": 0`.
- `--version` and HTTP JSON now print the parsed semver rather than the
  raw `git describe` string.

### Removed
- The `protos/` placeholder directory is no longer referenced from the build;
  the OpenAPI contract at `api/openapi.yaml` is now the live source for the
  HTTP surface.

[0.1.0]: https://github.com/pineconeforlanm/rtos-manager/releases/tag/v0.1.0
