# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.2-rc.1] - 2026-10-25

First published release candidate. Everything below is what `v0.1.2` will
contain; it ships early so the packaging, the gate and the version plumbing are
exercised on a real install. The Debian version of this candidate is
`0.1.2~rc.1`, which sorts below `0.1.2` — installing the final release later is a
normal upgrade, not a downgrade.

### Added
- **`Application` / `CommandLine` split** (`include/rtos_manager/application.hpp`,
  `cli.hpp`) — `main.cc` is now a delegate. CLI11 sits behind `CommandLine`,
  which only parses; `Application` owns the lifecycle (version short-circuit →
  config load → logging init → serve).
- **`ServerRunner` seam** — the HTTP backend is a
  `std::function<void(const ServerConfig&)>` defaulting to `RunHttpServer`, so the
  whole startup path runs in a test without binding a socket.
- **`HandleVersionRequest`** — the `/api/v1/version` body is a named handler
  again, assertable with a bare `coro_http_response`.
- **`scripts/gate.sh` + `.githooks/`** — the commit gate: whole-tree formatting,
  the Release workflow (warnings-as-errors, LTO, tests, `.deb`) and the coverage
  workflow with a **90 % line threshold**, from a single entry point
  (`--skip-*` / `RTOS_GATE_*` for one-off runs).
- **New test suites** — `ut_application`, `ut_cli`, `ut_logging` and
  `ut_http_server`: 37 tests, **92.7 %** line coverage over `src/`.
- `cmake/` is split into focused modules (`project_setup`, `build_options`,
  `dependencies`, `compile_commands`, `summary`, `project_finalize`).

### Changed
- **`BuildInfo`** replaces the free functions behind `version.hpp`: one generated
  `constexpr` aggregate (`rtos_manager::build::kMetadata`) plus a class that
  renders text and JSON. Anything derivable (e.g. `IsPrerelease()`) is computed
  instead of being injected twice.
- **DEB control `Version:` follows the tag** — `v0.1.2-rc.1` becomes
  `0.1.2~rc.1`, not `0.1.2-rc.1`: dpkg reads the last `-` as the Debian
  revision, so the dashed form would sort *above* `0.1.2` and the final release
  could never upgrade over its own candidate.
- **`/etc/version/rtos-manager.version`** is installed at the documented path; it
  used to land in `/usr/etc/version` because the destination was resolved
  relative to the packaging prefix.
- **Public headers** are installed together with the generated
  `version_info.hpp`, so downstream `#include <rtos_manager/version.hpp>`
  compiles.
- `CMakePresets.json` is back on preset schema 10, and `ci-lint` now runs
  clang-tidy alone — formatting left the CMake graph.

### Fixed
- **Header edits no longer leave stale objects.** `CMP0155` made GCC build via
  `-fmodules-ts` + a module mapper, a mode in which CMake never writes the
  per-object depfile: editing a header did not rebuild its includers, and the
  failure only surfaced as an undefined reference at link time.
  `CMAKE_CXX_SCAN_FOR_MODULES` is now off.
- **git-cliff no longer aborts on a GitHub API timeout** — every entry point
  passes `--offline`; the changelog is generated from local history only.

### Removed
- `cmake/format.cmake` and its `format` / `format-check` targets — formatting,
  linting and commit validation live in `scripts/`, so `cmake --build` stays a
  build.

## [0.1.1] - 2026-10-17

### Added
- **Build-type aware DEB artifact naming** (`cmake/packaging.cmake`) — Release
  packages are now clean `rtos-manager-<semver>-<arch>.deb` (no hash); Debug
  packages embed build type, branch (truncated to 20 chars), short commit hash
  and a `-dirty` marker for traceability, so a daily build can never collide
  with (or overwrite) a release artifact.
- **`package-debug` workflow preset** — one command
  (`cmake --workflow package-debug`) produces a deploy/debug DEB.
- **Full build metadata in `GET /api/v1/version`** — the JSON now serializes
  every field baked into the binary (description, homepage, semver components,
  git short hash, commit count/date, system version, preRelease), kept in
  lock-step with the `VersionInfo` OpenAPI schema.

### Changed
- The release process now back-merges **`main`** (not the release branch) into
  `develop`, so the `vX.Y.Z` tag stays reachable and `git describe` resolves it.
- `CONTRIBUTING.md` codifies the feature-branch → squash-before-PR → merge
  workflow and the DEB naming strategy; README (en/zh) updated to match.

### Fixed
- `v0.1.0` tag reachability from `develop` — it previously lived only on the
  `main` merge commit, so version metadata built from a develop-based branch
  reported an empty `tag` and a hash-only `describe`.

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

[0.1.2-rc.1]: https://github.com/pineconeforlanm/rtos-manager/releases/tag/v0.1.2-rc.1
[0.1.1]: https://github.com/pineconeforlanm/rtos-manager/releases/tag/v0.1.1
[0.1.0]: https://github.com/pineconeforlanm/rtos-manager/releases/tag/v0.1.0
