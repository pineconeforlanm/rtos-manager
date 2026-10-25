#!/usr/bin/env bash
# =============================================================================
#  build.sh — compile gate: prove the tree still builds in a Release config.
#
#  The pre-commit hook runs this for every commit that can affect the build, so
#  a `-Werror` regression, a missing include or a stale preset is caught before
#  it lands instead of after a push. The Release preset is the strictest one the
#  project has: warnings-as-errors, LTO and the tests compiled in.
#
#  The build is incremental — an untouched tree costs one ninja no-op check, an
#  edited translation unit costs that unit plus the link.
#
#  Exit codes: 0 = built (or skipped as irrelevant), 1 = build/test failure,
#              2 = setup problem (no cmake, bad preset).
# =============================================================================
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT="$(dirname -- "${SCRIPT_DIR}")"

usage() {
  cat <<'EOF'
Usage: scripts/build.sh [--preset <name>] [--build-dir <dir>] [--target <t>]
                        [--test] [--staged]

  (no option)   incremental build of the Release preset (the commit gate)
  --preset      configure/build preset to use (default: release)
  --build-dir   override the binary dir (default: build/<preset>)
  --target      build a single target instead of everything
  --test        also run `ctest --preset <name>` after a successful build
  --staged      skip when the staged changes cannot affect the build
                (what the pre-commit hook passes; docs-only commits stay fast)

Examples:
  scripts/build.sh                    # the hook's Release gate
  scripts/build.sh --test             # Release build + tests, before a release
  scripts/build.sh --preset debug     # same gate in Debug
  scripts/build.sh --staged --test    # hook + tests: RTOS_PRECOMMIT_TEST=1

The build directory is configured on demand when it does not exist yet.
EOF
}

preset="release"
build_dir=""
target=""
run_tests=0
staged=0
while (( $# > 0 )); do
  case "$1" in
    --preset) preset="${2:?--preset needs a value}"; shift 2 ;;
    --build-dir) build_dir="${2:?--build-dir needs a value}"; shift 2 ;;
    --target) target="${2:?--target needs a value}"; shift 2 ;;
    --test) run_tests=1; shift ;;
    --staged) staged=1; shift ;;
    -h | --help) usage; exit 0 ;;
    *)
      printf 'build.sh: unknown option %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! command -v cmake >/dev/null 2>&1; then
  printf 'build.sh: cmake not found on PATH\n' >&2
  exit 2
fi
[[ -n "$build_dir" ]] || build_dir="$ROOT/build/$preset"

# A commit that only touches documentation, packaging text or the changelog has
# no way of breaking the build, and paying for a compile there is pure friction.
collect_staged() {
  git -C "$ROOT" diff --cached --name-only --diff-filter=ACMR -z
}

if (( staged == 1 )); then
  if ! git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'build.sh: %s is not inside a git work tree\n' "$ROOT" >&2
    exit 2
  fi
  mapfile -d '' -t staged_files < <(collect_staged)
  if (( ${#staged_files[@]} == 0 )); then
    printf 'build.sh: nothing staged — skipping %s build\n' "$preset"
    exit 0
  fi
  relevant=()
  for path in "${staged_files[@]}"; do
    case "$path" in
      *.c | *.cc | *.cpp | *.cxx | *.h | *.hh | *.hpp | *.hxx | *.inl | *.ipp) relevant+=("$path") ;;
      CMakeLists.txt | */CMakeLists.txt) relevant+=("$path") ;;
      CMakePresets.json | conanfile.py | conanfile.txt | conan_provider.cmake) relevant+=("$path") ;;
      cmake/* | thirdparty/*) relevant+=("$path") ;;
    esac
  done
  if (( ${#relevant[@]} == 0 )); then
    printf 'build.sh: %d staged file(s), none can affect the build — skipping %s build\n' \
      "${#staged_files[@]}" "$preset"
    exit 0
  fi
  printf 'build.sh: %d staged build input(s) — gating on the %s build\n' \
    "${#relevant[@]}" "$preset"
fi

log="$(mktemp)"
trap 'rm -f -- "$log"' EXIT

report_failure() {
  printf '\n---- last 40 lines of the %s log ----\n' "$1"
  tail -n 40 "$log" >&2
  printf '\nbuild.sh: %s FAILED — commit aborted (fix it, or `--no-verify` to force)\n' \
    "$1" >&2
}

start=$SECONDS

if [[ ! -f "$build_dir/CMakeCache.txt" ]]; then
  printf 'build.sh: no configured build dir at %s — configuring %s\n' \
    "${build_dir#"$ROOT"/}" "$preset"
  if ! (cd "$ROOT" && cmake --preset "$preset") >"$log" 2>&1; then
    report_failure "configure ($preset)"
    exit 1
  fi
fi

build_args=(--build --preset "$preset")
[[ -n "$target" ]] && build_args+=(--target "$target")

printf 'build.sh: building %s%s\n' "$preset" "${target:+ (target $target)}"
if ! (cd "$ROOT" && cmake "${build_args[@]}") >"$log" 2>&1; then
  report_failure "build ($preset)"
  exit 1
fi
tail -n 2 "$log"
printf 'build.sh: %s build OK (%ds)\n' "$preset" "$((SECONDS - start))"

if (( run_tests == 1 )); then
  printf 'build.sh: running ctest --preset %s\n' "$preset"
  if ! (cd "$ROOT" && ctest --preset "$preset") >"$log" 2>&1; then
    report_failure "test ($preset)"
    exit 1
  fi
  tail -n 3 "$log"
  printf 'build.sh: %s tests OK (%ds total)\n' "$preset" "$((SECONDS - start))"
fi
