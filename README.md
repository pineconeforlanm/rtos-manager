<p align="center">
  <h1 align="center">rtos-manager</h1>
  <h6 align="center">An HTTP service for managing RTOS devices.</h6>
</p>

<p align="center">
  <img alt="license" src="https://img.shields.io/github/license/pineconeforlanm/rtos-manager?style=flat-square">
  <img alt="language" src="https://img.shields.io/github/languages/top/pineconeforlanm/rtos-manager?style=flat-square">
  <img alt="version" src="https://img.shields.io/badge/version-0.1.0-orange?style=flat-square">
  <img alt="last commit" src="https://img.shields.io/github/last-commit/pineconeforlanm/rtos-manager?style=flat-square">
</p>

<p align="center">
  <a href="README.zh.md">中文文档</a>
</p>

`rtos-manager` is a C++ HTTP server that will grow into a full device/runtime
management service. This repository currently contains the **project skeleton**:
a buildable hello-world service with a modern CMake + Conan toolchain, compile
time version/build metadata injected into the binary, a Git Flow branching
model, and hooks for testing, coverage, documentation and API contracts.

---

## Tech stack

| Concern            | Tool                                         |
|--------------------|----------------------------------------------|
| Build system       | [CMake](https://cmake.org/) (≥ 3.28, presets) |
| Package manager    | [Conan 2](https://conan.io/)                  |
| Compiler           | GCC / G++ (C++26, `-freflection`)             |
| Test               | [GoogleTest](https://github.com/google/googletest) + CTest |
| Benchmarking       | [Google Benchmark](https://github.com/google/benchmark) |
| Coverage           | [gcovr](https://gcovr.com/)                   |
| Documentation      | [Doxygen](https://www.doxygen.nl/) + [doxygen-awesome-css](https://github.com/jothepro/doxygen-awesome-css) |
| HTTP backend       | [coro_http](https://github.com/alibaba/yalantinglibs) (yalantinglibs, header-only) |
| CLI parsing        | [CLI11](https://github.com/CLIUtils/CLI11)   |
| Config parsing     | [glaze](https://github.com/stephenberry/glaze) (YAML via reflection) |
| Logging            | [easylog](https://github.com/alibaba/yalantinglibs) (yalantinglibs, header-only) |
| Packaging          | [CPack](https://cmake.org/cpack/) (DEB)       |
| Service manager    | systemd                                        |
| API contracts      | OpenAPI (reserved for future milestones)      |
| Dependencies       | CLI11, glaze, gtest, benchmark (Conan); yalantinglibs (git submodule) |

---

## Project layout

```
rtos-manager/
├── CMakeLists.txt          # top-level project & options
├── CMakePresets.json       # configure/build/test/package/workflow presets (Conan-aware)
├── conanfile.py            # Conan 2 dependency manifest (Boost/hical/CLI11/glaze/spdlog/gtest/benchmark)
├── cmake/                  # reusable CMake modules
│   ├── compiler_options.cmake  # C++26 standard, reflection, warnings, optimization
│   ├── version_info.cmake      # Git + semver + system/build metadata -> version_info.hpp
│   ├── coverage.cmake          # gcov/gcovr instrumentation + `coverage` target
│   ├── doxygen.cmake           # `docs` target helper
│   ├── openapi.cmake           # `openapi` target (npx @redocly/cli lint + build-docs)
│   ├── format.cmake            # `format` / `format-check` / `tidy` clang-* conveniences
│   ├── packaging.cmake         # systemd unit + CPack DEB + maintainer scripts + version file
│   └── templates/
│       ├── version_info.hpp.in
│       ├── rtos-manager.service.in      # systemd unit template
│       ├── rtos-manager.version.in      # /etc/version/<pkg>.version metadata file
│       └── maint/                       # DEB pre/postinst/prerm/postrm templates
├── include/rtos_manager/   # public headers (version/config/logging/http_server)
├── src/                    # core library + executable (CLI tool + HTTP daemon)
├── test/unittest/          # unit tests (ut_*.cc, GoogleTest + CTest)
├── example/                # runnable examples, one folder each (RTOS_ENABLE_EXAMPLES=ON)
│   └── api_client/
│       └── exp_api_client.cc   # coro_http client that hits GET /api/v1/version
├── bench/                  # Google Benchmark (bm_*.cc, RTOS_ENABLE_BENCH)
├── docs/                   # Doxygen config + vendored doxygen-awesome theme
│   └── doxygen-awesome/    # theme CSS (MIT, committed for offline builds)
├── api/
│   ├── openapi.yaml                    # OpenAPI 3.1 contract (single source of truth for the REST surface)
│   └── rtos-manager.hoppscotch.json       # Hoppscotch import for the version endpoint
├── config/                 # runtime configuration (YAML)
└── thirdparty/             # vendored deps: yalantinglibs (coro_http + easylog)
    └── yalantinglibs/      # git submodule, exposed as header-only rtos::ylt
```

---

## Getting started

### Prerequisites

```bash
# Conan 2
pip install conan
# gcovr + doxygen (Debian/Ubuntu)
pip install gcovr
sudo apt install doxygen ninja-build
# optional: graphviz (Doxygen diagrams) and dpkg-dev (DEB auto shlib deps)
sudo apt install graphviz dpkg-dev
```

> `yalantinglibs` (coro_http + easylog) is **not** a Conan package — it is
> vendored as a git submodule under `thirdparty/yalantinglibs` and exposed as a
> header-only `rtos::ylt` target. Clone with submodules, or run
> `git submodule update --init --recursive` before configuring. The Conan
> default profile must use `compiler.cppstd=26` (glaze needs ≥ 23).

### Build & run

Conan dependencies are fetched **automatically at configure time** by the
CMake-Conan provider (`conan_provider.cmake`, wired into the presets via
`CMAKE_PROJECT_TOP_LEVEL_INCLUDES`). There is no manual `conan install` step —
just pick a preset:

```bash
cmake --preset release
cmake --build --preset release
ctest  --preset release
./build/release/bin/rtos-manager -h               # usage
./build/release/bin/rtos-manager -v               # build metadata (via logging)
./build/release/bin/rtos-manager -c config/rtos_manager.yaml   # run HTTP daemon
```

> The CLI accepts exactly three flags: `-h` (help), `-v` (version) and `-c`
> (config path). Everything else — listen host/port, IO threads, logging — is
> configured through the YAML file.

#### One-click lifecycle with `cmake --workflow`

Every common pipeline shape is encoded as a workflow preset; one command runs
the whole chain (configure → build → test → package as appropriate):

| Workflow     | What it does                                                            |
|--------------|-------------------------------------------------------------------------|
| `dev`        | Debug configure + build + test (the day-to-day loop)                    |
| `full`       | Coverage configure + build + test + gcovr report                        |
| `release`    | Release configure + build + test + DEB package (clean, no hash)          |
| `package-debug` | Debug configure + build + test + DEB (daily deploy/debug, hash-tagged) |
| `sanitize`   | ASan + UBSan configure + build + test                                    |
| `docs`       | Doxygen + OpenAPI HTML render                                            |
| `bench`      | Build Google Benchmark executable                                       |
| `ci-lint`    | clang-tidy analysis (the `tidy` configure preset sets `CMAKE_CXX_CLANG_TIDY`) |

```bash
cmake --workflow dev            # quick local loop
cmake --workflow release        # → build/release/rtos-manager-<ver>-<arch>.deb  (clean, no hash)
cmake --workflow package-debug  # → build/debug/rtos-manager-<ver>-Debug-<branch>-<hash>[-dirty]-<arch>.deb
cmake --workflow full           # coverage HTML at build/coverage/index.html
```

Configure presets available: `debug`, `release`, `relwithdebinfo`, `coverage`,
`docs`, `bench`, `asan-ubsan`, `tsan`, `tidy`.

### Examples (RTOS_ENABLE_EXAMPLES=ON, on by default in `debug`)

Examples live one-per-folder under `example/<name>/exp_<name>.cc` and build to
`build/<preset>/bin/examples/exp_<name>` (the `exp_` prefix marks them as
examples). Today there is one — a coro_http **client** that exercises the
running service:

```bash
# terminal 1: start the server
./build/debug/bin/rtos-manager -c config/rtos_manager.yaml
# terminal 2: hit GET /api/v1/version and print the JSON
./build/debug/bin/examples/exp_api_client
./build/debug/bin/examples/exp_api_client http://127.0.0.1:8080/api/v1/version
```

### HTTP endpoints (RESTful)

The MVP exposes exactly one endpoint:

| Method | Path              | Response                            |
|--------|-------------------|-------------------------------------|
| GET    | `/api/v1/version` | JSON build metadata (git, build …)  |

```bash
curl -s http://127.0.0.1:8080/api/v1/version
```

The same request is packaged as a **Hoppscotch collection** at
[`api/rtos-manager.hoppscotch.json`](api/rtos-manager.hoppscotch.json)
(with an `Accept: application/json` header and response tests asserting status
200, JSON content type and the `project`/`version`/`buildType` fields). Import
it via Hoppscotch → Collections → … → Import/Export → **Hoppscotch (v1)**. The
endpoint defaults to `http://127.0.0.1:8080`; point it at your instance (or
swap in a `{{baseUrl}}` Hoppscotch environment variable) as needed.

### Packaging (DEB) + systemd

`cmake/packaging.cmake` sets up CPack (DEB only), the systemd unit, the
`/etc/version/rtos-manager.version` file and the four DEB maintainer scripts
(`preinst` / `postinst` / `prerm` / `postrm`) — installing the package
automatically enables and restarts the service:

The **artifact name encodes the build type** so a debug build can never be
confused with (or overwrite) a release package:

| Build | Command | Artifact name |
|-------|---------|---------------|
| Release | `cmake --workflow release` | `rtos-manager-<ver>-<arch>.deb` (clean, **no hash**) |
| Debug (daily) | `cmake --workflow package-debug` | `rtos-manager-<ver>-Debug-<branch>-<hash>[-dirty]-<arch>.deb` |

```bash
cmake --workflow release            # or: cmake --workflow package-debug
sudo dpkg -i build/release/rtos-manager-*.deb
systemctl status rtos-manager
```

The package installs:

| Path                                                | Purpose                              |
|-----------------------------------------------------|--------------------------------------|
| `/usr/bin/rtos-manager`                             | the daemon / CLI                     |
| `/usr/share/rtos-manager/rtos_manager.yaml`         | default config                       |
| `/usr/lib/systemd/system/rtos-manager.service`      | unit file                            |
| `/etc/version/rtos-manager.version`                 | semver + git + build metadata (text) |
| `/usr/include/rtos_manager/*`                       | public headers                       |
| `/usr/lib/librtos_manager_core.a`                   | static library for embedders         |

### Semantic versioning

The version is parsed from the latest annotated Git tag matching
`v?MAJOR.MINOR.PATCH[-(alpha|beta|rc).N]`. With no tag present, it falls
back to `project(... VERSION 0.1.0)` declared in `CMakeLists.txt`. The
resolved values are baked into:

- `rtos_manager::build::kVersionSemver` etc. in the generated `version_info.hpp`
- the DEB file name: `rtos-manager-<semver>-<build>-<arch>-<hash>[-dirty].deb`
- `/etc/version/rtos-manager.version`
- the HTTP `GET /api/v1/version` JSON response (`prerelease: true|false`)

Tag commits according to Git Flow (see `CONTRIBUTING.md`): `v0.2.0`,
`v0.2.0-rc.1`, etc.

### OpenAPI contract

`api/openapi.yaml` describes the REST surface in OpenAPI 3.1 and is the
single source of truth for the one endpoint (`GET /api/v1/version`). The build
wires up two targets via local `npx @redocly/cli`:

```bash
cmake --build build/debug --target openapi-validate   # lint the spec
cmake --build build/debug --target openapi-docs       # render <build>/openapi/index.html
cmake --build build/debug --target openapi            # both
```

Keep `src/http_server.cc`, `api/openapi.yaml` and
`api/rtos-manager.hoppscotch.json` in sync; the `docs` workflow runs
both Doxygen and OpenAPI.

### Continuous integration (local)

This project builds and validates **entirely locally** — there is no hosted CI.
Every pipeline shape is encoded as a `cmake --workflow` preset, so the exact
same commands run on your machine (and in any future automation):

| Pipeline     | When to run         | Command                                             |
|--------------|---------------------|-----------------------------------------------------|
| `dev`        | every change        | `cmake --workflow dev`                              |
| `lint`       | before every commit | `cmake --build build/debug --target format-check`   |
| `sanitize`   | before a release    | `cmake --workflow sanitize`                         |
| `coverage`   | before a release    | `cmake --workflow full` (report under build/coverage/) |
| `release`    | cutting a version   | `cmake --workflow release` (produces the `.deb`)    |

To add a new pipeline shape, drop a step into `CMakePresets.json`'s
`workflowPresets` — there is no other tooling to keep in sync.

### Sanitizers & static analysis

```bash
cmake --workflow sanitize          # ASan + UBSan build & tests
cmake --preset tsan                # ThreadSanitizer (run ctest manually)
cmake --workflow ci-lint           # clang-tidy across all TUs (needs clang-tidy on PATH)
cmake --build build/debug --target format        # rewrite sources per .clang-format
cmake --build build/debug --target format-check  # pre-commit gate (non-zero on any diff)
```

---

## Version / build metadata

At configure time, `cmake/version_info.cmake` collects **Git** information
(commit hash, branch, tag, commit count, commit date, dirty flag) together with
**system / toolchain** information (build type, build time, OS, CPU
architecture, compiler id/version, C++ standard) and generates
`build/generated/rtos_manager/version_info.hpp`.

These values are compiled into the binary and surfaced via `--version`, which
emits them through the easylog logging framework (one log line per section, so
each carries the `[timestamp] LEVEL [pid] [file:line]` prefix):

```bash
$ rtos-manager --version
2026-10-11 09:30:00.123456 INFO [12345] [version.cc:24] rtos_manager 0.1.0
2026-10-11 09:30:00.123456 INFO [12345] [version.cc:25]   description : RTOS Manager — an HTTP service for managing RTOS devices
2026-10-11 09:30:00.123456 INFO [12345] [version.cc:26]   homepage    : https://github.com/pineconeforlanm/rtos-manager
2026-10-11 09:30:00.123456 INFO [12345] [version.cc:27]   git         : 0.1.0-1-ga1b2c3d [hash=a1b2c3d... branch=develop ... dirty=true ...]
2026-10-11 09:30:00.123456 INFO [12345] [version.cc:31]   build       : type=Release time=2026-10-11 09:30:00 UTC
2026-10-11 09:30:00.123456 INFO [12345] [version.cc:33]   system      : Linux 6.x (x86_64)
2026-10-11 09:30:00.123456 INFO [12345] [version.cc:35]   compiler    : GNU 16.2.0 (C++26)
```

---

## Testing & coverage

Unit tests use **GoogleTest** and are registered into CTest automatically
(`gtest_discover_tests`), so individual cases show up as separate tests.

```bash
# Configure, build, run the suite (deps auto-installed)
cmake --preset coverage
cmake --build --preset coverage
ctest --preset coverage

# Produce an HTML + XML coverage report under build/coverage/coverage/
cmake --build build/coverage --target coverage
```

## Benchmarks

Micro-benchmarks use **Google Benchmark** and are opt-in via the `bench` preset
(`RTOS_ENABLE_BENCH=ON`). Build and run them with:

```bash
cmake --preset bench
cmake --build --preset bench
./build/bench/bin/rtos_bench            # or --benchmark_format=json
# filter groups, e.g. only the JSON benchmarks:
./build/bench/bin/rtos_bench --benchmark_filter=Json
```

### Serialization performance: Glaze vs. ylt struct_json / struct_yaml

`bench/bm_serialization.cc` serialises and parses the same `AppConfig` with
the two stacks the project could use for configuration. Glaze reflects the
aggregates through **C++26 standard static reflection** (`std::meta`, P2996 —
auto-enabled by `-std=c++26 -freflection` on GCC 16); ylt's `struct_json` /
`struct_yaml` (iguana) uses its own `YLT_REFL` registration. Representative
numbers (lower is better; re-run `rtos_bench` to reproduce on your machine):

| Scenario           | Glaze     | iguana (ylt) | Winner              |
|--------------------|----------:|-------------:|---------------------|
| JSON serialise     | **35 ns** | 134 ns       | Glaze (~3.8×)       |
| JSON parse         | **83 ns** | 165 ns       | Glaze (~2.0×)       |
| YAML serialise     | 90 ns     | **85 ns**    | ~parity             |
| YAML parse         | 465 ns    | **247 ns**   | iguana (~1.9×)      |

**Takeaways:** Glaze dominates JSON (its core-optimised path); for YAML the
two are near-equal on writing while iguana parses roughly 2× faster (Glaze's
YAML reader is comparatively less mature). Either stack is ample for the
project's config work; Glaze has the edge wherever JSON is involved.

---

## Documentation

```bash
cmake --preset docs
cmake --build build/docs --target docs
# -> build/docs/html/index.html (styled with doxygen-awesome-css)
```

The API docs are styled with [doxygen-awesome-css](https://github.com/jothepro/doxygen-awesome-css).
The theme's CSS is **vendored in-repo** under `docs/doxygen-awesome/` (MIT), so a
fresh clone works fully offline — no download happens during the build.
Dependency/class diagrams are generated only when Graphviz (`dot`) is installed —
it is auto-detected, so a missing Graphviz simply skips diagrams without breaking
the build.

---

## Contributing

This project follows **Git Flow**. See [CONTRIBUTING.md](CONTRIBUTING.md) for
the branching model, commit message conventions and the release process.
Release notes are tracked in [CHANGELOG.md](CHANGELOG.md) following
[Keep a Changelog](https://keepachangelog.com/) and
[Semantic Versioning](https://semver.org/).

## License

Distributed under the Apache-2.0 License. See [LICENSE](LICENSE) for more
information.
