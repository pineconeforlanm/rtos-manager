#!/usr/bin/env bash
# =============================================================================
#  lint.sh — clang-tidy driver for project translation units.
#
#  clang-tidy needs a compile_commands.json entry per file, so this script only
#  ever looks at .cc/.cpp files and requires a configured build directory. A
#  header is analysed through the TUs that include it, never on its own.
#
#  The pre-commit hook runs this only when RTOS_PRECOMMIT_LINT=1: a tidy pass
#  pays for a full front-end parse per file, which is too slow to force on
#  every commit, while `cmake --workflow ci-lint` already covers whole-tree
#  sweeps through CMAKE_CXX_CLANG_TIDY.
#
#  Exit codes: 0 = clean, 1 = findings, 2 = setup problem.
# =============================================================================
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT="$(dirname -- "${SCRIPT_DIR}")"

usage() {
  cat <<'EOF'
Usage: scripts/lint.sh [--staged] [--fix] [--build-dir <dir>]

  (no option)   check every src/*.cc
  --staged      check only the translation units staged for the next commit
  --fix         apply clang-tidy's suggested fixes in place (adds --fix-errors)
  --build-dir   directory holding compile_commands.json
                (default: first of build/debug, build/release, build/tidy)

Examples:
  scripts/lint.sh --staged                  # opt-in extra pre-commit gate
  scripts/lint.sh                          # all of src/ before opening a PR
  cmake --workflow ci-lint                 # whole-tree sweep via CMake (slower)

clang-tidy is taken from $CLANG_TIDY, then PATH, then ~/.local/bin.
Configure a build dir first: cmake --preset debug.
EOF
}

scope="all"
fix=0
build_dir=""
while (( $# > 0 )); do
  case "$1" in
    --staged) scope="staged"; shift ;;
    --fix) fix=1; shift ;;
    --build-dir)
      build_dir="${2:?--build-dir needs a value}"
      shift 2
      ;;
    -h | --help) usage; exit 0 ;;
    *)
      printf 'lint.sh: unknown option %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

resolve_clang_tidy() {
  local name dir
  for name in "${CLANG_TIDY:-}" clang-tidy clang-tidy-19 clang-tidy-18 clang-tidy-17; do
    [[ -n "$name" ]] || continue
    if command -v "$name" >/dev/null 2>&1; then
      command -v "$name"
      return 0
    fi
  done
  for dir in "$HOME/.local/bin" /usr/local/bin /usr/bin; do
    for name in clang-tidy clang-tidy-19 clang-tidy-18 clang-tidy-17; do
      if [[ -x "$dir/$name" ]]; then
        printf '%s\n' "$dir/$name"
        return 0
      fi
    done
  done
  return 1
}

if ! tool="$(resolve_clang_tidy)"; then
  printf 'lint.sh: clang-tidy not found — install it first:\n' >&2
  printf '  sudo apt install clang-tidy\n' >&2
  exit 2
fi

if [[ -z "$build_dir" ]]; then
  for candidate in build/debug build/release build/tidy; do
    if [[ -f "$ROOT/$candidate/compile_commands.json" ]]; then
      build_dir="$ROOT/$candidate"
      break
    fi
  done
fi
if [[ -z "$build_dir" || ! -f "$build_dir/compile_commands.json" ]]; then
  printf 'lint.sh: no compile_commands.json found\n' >&2
  printf '  configure a build dir first: cmake --preset debug\n' >&2
  printf '  or point at one with: scripts/lint.sh --build-dir <dir>\n' >&2
  exit 2
fi

collect_staged() {
  local path
  while IFS= read -r -d '' path; do
    [[ -f "$ROOT/$path" ]] && printf '%s\n' "$ROOT/$path"
  done < <(git -C "$ROOT" diff --cached --name-only --diff-filter=ACMR -z -- '*.cc' '*.cpp')
}

if [[ "$scope" == "staged" ]]; then
  mapfile -t files < <(collect_staged)
else
  mapfile -t files < <(find "$ROOT/src" -type f \( -name '*.cc' -o -name '*.cpp' \) | LC_ALL=C sort)
fi

if (( ${#files[@]} == 0 )); then
  printf 'lint.sh: no %s translation units — nothing to do\n' "$scope"
  exit 0
fi

args=(-p "$build_dir" --quiet)
if (( fix == 1 )); then
  args+=(--fix-errors)
fi

printf 'lint.sh: %d file(s) against %s\n' "${#files[@]}" "$build_dir/compile_commands.json"

failed=()
for file in "${files[@]}"; do
  if ! "$tool" "${args[@]}" "$file"; then
    failed+=("${file#"$ROOT"/}")
  fi
done

if (( ${#failed[@]} > 0 )); then
  printf '\nlint.sh: %d file(s) reported findings:\n' "${#failed[@]}" >&2
  printf '  %s\n' "${failed[@]}" >&2
  (( fix == 1 )) || printf 'Try scripts/lint.sh --fix, or fix them by hand.\n' >&2
  exit 1
fi

printf 'lint.sh: OK — %d file(s) clean\n' "${#files[@]}"
