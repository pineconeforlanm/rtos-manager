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
├── CMakeLists.txt          # project metadata + build graph only (no policy/tooling)
├── CMakePresets.json       # configure/build/test/package/workflow presets (Conan-aware)
├── conanfile.py            # Conan 2 dependency manifest (Boost/hical/CLI11/glaze/spdlog/gtest/benchmark)
├── cmake/                  # reusable CMake modules
│   ├── project_setup.cmake     # single entry point for all configure-time setup
│   ├── project_finalize.cmake  # post-target hook: packaging (CPack) + summary
│   ├── build_options.cmake     # RTOS_ENABLE_* switches + default build type
│   ├── compiler_options.cmake  # C++26 standard, reflection, warnings, optimization
│   ├── dependencies.cmake      # Conan packages + vendored yalantinglibs (rtos::ylt)
│   ├── version_info.cmake      # Git + semver + system/build metadata -> version_info.hpp
│   ├── compile_commands.cmake  # compile_commands.json + source-root symlink for clangd
│   ├── coverage.cmake          # gcov/gcovr instrumentation + `coverage` target
│   ├── doxygen.cmake           # `docs` target helper
│   ├── openapi.cmake           # `openapi` target (npx @redocly/cli lint + build-docs)
│   ├── changelog.cmake         # `changelog` target (git-cliff)
│   ├── packaging.cmake         # systemd unit + CPack DEB + maintainer scripts + version file
│   ├── summary.cmake           # configure summary (rtos_print_build_summary)
│   └── templates/
│       ├── version_info.hpp.in
│       ├── rtos-manager.service.in      # systemd unit template
│       ├── rtos-manager.version.in      # /etc/version/<pkg>.version metadata file
│       └── maint/                       # DEB pre/postinst/prerm/postrm templates
├── include/rtos_manager/   # public headers (application/cli/version/config/logging/http_server)
├── src/                    # core library + executable
│   ├── main.cc                 # process entry: Application::Run(argc, argv)
│   ├── application.cc          # startup pipeline (request -> config -> serving)
│   ├── cli.cc                  # CLI11-backed CommandLine::Parse
│   ├── version.cc              # BuildInfo: JSON + compact-line rendering
│   ├── config.cc               # YAML -> AppConfig (glaze reflection)
│   ├── logging.cc              # easylog bootstrap
│   └── http_server.cc          # coro_http server + GET /api/v1/version
├── test/unittest/          # unit tests (ut_*.cc, GoogleTest + CTest)
├── example/                # runnable examples, one folder each (RTOS_ENABLE_EXAMPLES=ON)
│   └── api_client/
│       └── exp_api_client.cc   # coro_http client that hits GET /api/v1/version
├── bench/                  # Google Benchmark (bm_*.cc, RTOS_ENABLE_BENCH)
├── docs/                   # Doxygen config + vendored doxygen-awesome theme
│   └── doxygen-awesome/    # theme CSS (MIT, committed for offline builds)
├── scripts/                # developer tooling — deliberately outside CMake
│   ├── gate.sh                 # the commit gate: format + release + coverage ≥ 90%
│   ├── format.sh               # clang-format driver (whole repo / --check / --staged)
│   ├── build.sh                # Release build alone (-Werror + LTO + tests)
│   ├── lint.sh                 # clang-tidy driver over compile_commands.json
│   ├── commit-msg-check.sh     # Conventional Commits gate
│   └── install-hooks.sh        # symlinks .githooks/* into .git/hooks
├── .githooks/              # versioned git hooks (pre-commit, commit-msg)
├── .gitmessage             # commit message template (git config commit.template)
├── api/
│   ├── openapi.yaml                    # OpenAPI 3.1 contract (single source of truth for the REST surface)
│   └── rtos-manager.hoppscotch.json       # Hoppscotch import for the version endpoint
├── config/                 # runtime configuration (YAML)
└── thirdparty/             # vendored deps: yalantinglibs (coro_http + easylog)
    └── yalantinglibs/      # git submodule, exposed as header-only rtos::ylt
```

---

## Architecture

Startup is a chain of single-responsibility layers; each one knows only the
layer below it, and `main()` holds none of the logic:

```
main()
 └─▶ Application::Run(argc, argv)          lifecycle: which stage, in which order
      ├─ CommandLine::Parse(argc, argv)    argv  -> request value object
      ├─ LoadConfig(path) -> AppConfig     YAML  -> settings (defaults for missing keys)
      └─ RunHttpServer(server_config)      settings -> sockets (blocks)
```

| Layer | Type | Header | Responsibility |
|-------|------|--------|----------------|
| Process entry | `main()` | `src/main.cc` | `return Application::Run(argc, argv);` — nothing else |
| Lifecycle | `rtos_manager::Application` | `application.hpp` | Stage order, exit status, config lifetime |
| Argument parsing | `rtos_manager::CommandLine` | `cli.hpp` | argv → request data; CLI11 stays private to `cli.cc` |
| Configuration | `rtos_manager::AppConfig` | `config.hpp` | YAML → settings, defaults for missing keys |
| Build metadata | `rtos_manager::BuildInfo` | `version.hpp` | Read-only accessors + `ToString()` / `ToReport()` / `ToJson()` |
| HTTP surface | `RunHttpServer()` | `http_server.hpp` | coro_http server, `GET /api/v1/version` |

Two rules keep the layering honest:

* **No upward calls.** `CommandLine` never opens files, `BuildInfo` never logs,
  `Application` never invents metadata — the layer that owns the concern (config,
  output, lifecycle) does the work. `-v`/`--version` therefore print from
  `Application::ShowVersion()`, using the strings `BuildInfo` renders.
* **Data over procedures.** Every stage hands back a value (a `CommandLine`, an
  exit status) instead of mutating globals, so each one can be tested on its own
  — see `test/unittest/ut_cli.cc`.

---

## Getting started

### Prerequisites

```bash
# Conan 2
pip install conan
# gcovr + doxygen (Debian/Ubuntu)
pip install gcovr
sudo apt install doxygen ninja-build
# clang-format for scripts/format.sh + the pre-commit hook
# (pip --user installs into ~/.local/bin; PEP 668 distros need
#  --break-system-packages, or use apt install clang-format)
pip install --user clang-format
# optional: clang-tidy for scripts/lint.sh, graphviz (Doxygen diagrams),
# dpkg-dev (DEB auto shlib deps)
sudo apt install clang-tidy graphviz dpkg-dev
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
./build/release/bin/rtos-manager -v               # one version line
./build/release/bin/rtos-manager --version        # full build report
./build/release/bin/rtos-manager -c config/rtos_manager.yaml   # run HTTP daemon
```

> The CLI accepts four flags: `-h` (help), `-v` (version line), `--version`
> (full report) and `-c` (config path). Everything else — listen host/port, IO
> threads, logging — is configured through the YAML file.

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

> Formatting is **not** a CMake target — it lives in [`scripts/format.sh`](scripts/format.sh).
> The commit gate that composes formatting, the Release workflow and the coverage
> workflow lives in [`scripts/gate.sh`](scripts/gate.sh) and runs from the
> pre-commit hook. See [Developer tooling](#developer-tooling).

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
| `/usr/include/rtos_manager/*`                       | public headers (incl. the generated `version_info.hpp`) |
| `/usr/lib/librtos_manager_core.a`                   | static library for embedders         |

### Semantic versioning

The version is parsed from the latest annotated Git tag matching
`v?MAJOR.MINOR.PATCH[-(alpha|beta|rc).N]`. With no tag present, it falls
back to `project(... VERSION 0.1.0)` declared in `CMakeLists.txt`. The
resolved values are baked into:

- `rtos_manager::BuildInfo` accessors (`BuildInfo::Get().Semver()` …), populated from the generated `constexpr` aggregate `rtos_manager::build::kMetadata` in `version_info.hpp`
- the DEB file name: `rtos-manager-<semver>[-Debug-<branch>-<hash>[-dirty]]-<arch>.deb`
- the DEB control `Version:`, with a pre-release written as `~rc.N` rather than
  `-rc.N` (`v0.1.2-rc.1` → `0.1.2~rc.1`). This is not cosmetic: dpkg treats
  everything after the **last** `-` as the Debian revision, so a literal
  `0.1.2-rc.1` sorts *after* `0.1.2` and the final release could never upgrade
  over its own candidate.
- `/etc/version/rtos-manager.version`
- the HTTP `GET /api/v1/version` JSON response (`prerelease: true|false`)

Tag commits according to Git Flow (see `CONTRIBUTING.md`): `v0.2.0`,
`v0.2.0-rc.1`, etc. Release candidates are published artifacts too — each one is
tagged on `main`, keeps its own `CHANGELOG.md` section, and is never retagged;
the procedure and the artifact/version mapping are in
[CONTRIBUTING.md](CONTRIBUTING.md#release-candidates-rcn).

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
| `hooks`      | once per clone      | `scripts/install-hooks.sh` (gate + message gate)    |
| `gate`       | before every commit | `scripts/gate.sh` — what the `pre-commit` hook runs |
| `format`     | inside the gate     | `scripts/format.sh` (whole tree; `--staged`, `--check`) |
| `release`    | inside the gate     | `cmake --workflow release` (build + tests + `.deb`) |
| `coverage`   | inside the gate     | `cmake --workflow full` + a ≥ 90% line threshold    |
| `build`      | ad hoc              | `scripts/build.sh --staged` (Release only, no coverage) |
| `lint`       | before a PR         | `scripts/lint.sh` (clang-tidy, staged: `--staged`)  |
| `sanitize`   | before a release    | `cmake --workflow sanitize`                         |

To add a new pipeline shape, drop a step into `CMakePresets.json`'s
`workflowPresets` — there is no other tooling to keep in sync.

### Developer tooling

Formatting, linting and commit-message rules live in [`scripts/`](scripts/) and
[`.githooks/`](.githooks/), **not** in the CMake graph: they are per-developer
concerns that should not slow down or gate a plain `cmake --build`.

```bash
scripts/install-hooks.sh              # once per clone: symlink .githooks/* -> .git/hooks
scripts/install-hooks.sh --with-template   # also set commit.template = .gitmessage

scripts/gate.sh                       # the commit gate: format + release + coverage
scripts/gate.sh --skip-coverage       # quick loop while iterating
scripts/gate.sh --min-coverage 95     # stricter bar for one run

scripts/format.sh                     # format every project source in place
scripts/format.sh --check             # gate: non-zero if anything is unformatted
scripts/format.sh --staged            # only the staged files (the hook runs both)

scripts/build.sh                      # Release build alone: -Werror + LTO + tests
scripts/build.sh --test               # ... and run ctest for that preset
scripts/build.sh --staged             # skip when the staged files cannot affect it

scripts/lint.sh                       # clang-tidy over src/*.cc (needs a build dir)
scripts/lint.sh --staged --fix        # only what is staged, apply suggested fixes

scripts/commit-msg-check.sh -m "feat(http): add /healthz"   # try a message first
```

| Hook | What it does | Bypass |
|------|--------------|--------|
| `pre-commit` | runs `scripts/gate.sh`: formats the **whole tree** (staged files are re-staged, unstaged ones only rewritten — and it refuses a staged file that also has unstaged hunks), then the Release workflow and the coverage workflow with its 90% threshold | `git commit --no-verify` |
| `commit-msg` | rejects messages git-cliff cannot classify (bad `type`, no `(scope):`, > 72 chars, trailing period, body glued to the subject) | `git commit --no-verify` |

The gate proves two complete pipelines before the commit exists:

1. **Release** — `cmake --workflow release`: configure, build with
   warnings-as-errors + LTO (stricter than Debug), run the test suite, and build
   the `.deb`. A `-Werror` regression, a missing include or a broken preset
   cannot reach `develop`.
2. **Coverage** — `cmake --workflow full`: instrumented build, the same tests,
   the gcovr report, then `gate.sh` reads `coverage.xml` and refuses to commit
   below **90% line coverage** (it prints the per-file table on failure).

Cost: both stages are `cmake --workflow` calls, so they reconfigure first, and a
configure rewrites `version_info.hpp` (it embeds the build timestamp) — a dozen
translation units and the LTO link are redone even when nothing changed. Expect
roughly a minute per commit once warm; the first run in a fresh clone compiles
two full builds and takes minutes.

`RTOS_GATE_FORMAT=0`, `RTOS_GATE_RELEASE=0` and `RTOS_GATE_COVERAGE=0` skip a
stage for one commit, `RTOS_GATE_MIN_COVERAGE=95` raises the bar, and
`RTOS_PRECOMMIT_LINT=1` adds clang-tidy on the staged translation units. Tidy
stays off by default: it re-parses every file, so it belongs on a PR — use
`scripts/lint.sh` or `cmake --workflow ci-lint` for that.

Why no `cpplint`: it encodes the *Google* style (2-space indent, 80 columns,
`.cc`/`.h` pairing) rather than this project's `.clang-format`, it has no
awareness of C++26 constructs, and `clang-tidy` already covers its useful checks
(`google-*`, `readability-*`) on the real AST — so running it would only add
false positives and a second style source of truth.

`wip:` / `fixup!` / `squash!` / `amend!` messages pass the hook on purpose
(local work in progress); squash them into Conventional Commits before opening
the PR, as [CONTRIBUTING.md](CONTRIBUTING.md) asks.


### Sanitizers & static analysis

```bash
cmake --workflow sanitize          # ASan + UBSan build & tests
cmake --preset tsan                # ThreadSanitizer (run ctest manually)
cmake --workflow ci-lint           # clang-tidy across all TUs (needs clang-tidy on PATH)
scripts/lint.sh                    # the same checks for src/*.cc, without a full rebuild
```

`scripts/format.sh` walks `include/`, `src/`, `test/`, `bench/` and `example/` at
run time — never `thirdparty/` — so a newly added file needs no re-configure.
`--check` implements the gate through `clang-format --dry-run --Werror`
(clang-format ≥ 15); the pre-commit hook runs the `--staged` variant.

---

## Version / build metadata

At configure time, `cmake/version_info.cmake` collects **Git** information
(commit hash, branch, tag, commit count, commit date, dirty flag) together with
**system / toolchain** information (build type, build time, OS, CPU
architecture, compiler id/version, C++ standard) and generates
`build/generated/rtos_manager/version_info.hpp`.

These values are compiled into the binary and surfaced through
`rtos_manager::BuildInfo` (`ToString()` for the one-line banner, `ToReport()`
for the full report, `ToJson()` for the HTTP response). Two flags expose them,
and both write plain text to **stdout** — no log prefix, no log file — so the
output stays greppable and diffable between builds:

```bash
$ rtos-manager -v
rtos_manager 0.1.2-rc.1 (c2a0dff on main)

$ rtos-manager --version
rtos_manager 0.1.2-rc.1
  description : RTOS Manager — an HTTP service for managing RTOS devices
  homepage    : https://github.com/pineconeforlanm/rtos-manager
  git         : v0.1.2-rc.1 [hash=c2a0dff… branch=main tag=v0.1.2-rc.1 commits=28 dirty=false date=…]
  build       : type=Release time=2026-10-25 09:20:28 UTC
  system      : Linux 6.18.40 (x86_64)
  compiler    : GNU 16.2.0 (C++26)
```

`-v` is the brief form ("which build am I running?", the one a post-install
script can parse); `--version` is the full report a bug report needs. Give both
and `--version` wins, since it is a superset.

The printing lives in `Application::ShowVersion()`: `BuildInfo` renders the text
but never writes to a stream or a logger, so the report also works with logging
not initialised.

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

Two seams keep the suite socket-free and sleep-free: `Application::Run()` takes
the server backend as a parameter (`Application::ServerRunner`, defaulting to the
real `RunHttpServer`), and the `/api/v1/version` handler is a named function
(`HandleVersionRequest`) driven with a plain `coro_http_response`. The lifecycle,
the configuration overlay, the logging levels and the HTTP payload are therefore
all unit-testable, with no ports, threads or timing.

Coverage is measured over `src/` with **`src/main.cc` excluded**
(`cmake/coverage.cmake`): `main()` is the process entry point — exercised by
running the binary, not by unit tests — so counting it would turn the number into
a statement about argv plumbing. `scripts/gate.sh` refuses to commit below
**90% line coverage**; the per-file table lives in
`build/coverage/coverage/coverage.txt`.

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
