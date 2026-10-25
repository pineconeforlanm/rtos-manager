#!/usr/bin/env bash
# =============================================================================
#  gate.sh — the pre-commit gate: format the tree, then prove both pipelines.
#
#  Stages, in order (each one aborts the commit on failure):
#    1. format    every project source rewritten in place per .clang-format;
#                 staged files are re-staged, unstaged ones only rewritten
#    2. release   `cmake --workflow release` — configure + build + tests + DEB.
#                 This is the strictest configuration (-Werror, LTO).
#    3. coverage  `cmake --workflow full` — coverage build + tests + gcovr
#                 report, then the line-coverage threshold is enforced
#    4. lint      clang-tidy on the staged units, opt-in
#
#  Cost: the first run after a clone compiles the tree twice (release + coverage)
#  and takes minutes; afterwards both are incremental. A commit that touches
#  nothing is still two no-op checks plus one gcovr pass.
#
#  Exit codes: 0 = every stage passed, 1 = a stage failed, 2 = setup problem.
# =============================================================================
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT="$(dirname -- "${SCRIPT_DIR}")"

usage() {
  cat <<'EOF'
Usage: scripts/gate.sh [--skip-format] [--skip-release] [--skip-coverage]
                       [--skip-lint] [--min-coverage <pct>]

  (no option)     format + release workflow + coverage workflow + 90% line gate
  --skip-format   do not touch the sources (CI already formats/checks its own)
  --skip-release  skip `cmake --workflow release`
  --skip-coverage skip `cmake --workflow full` and the coverage threshold
  --skip-lint     skip clang-tidy (it is off by default anyway)
  --min-coverage  fail below this line-coverage percentage (default: 90)

Environment equivalents (for the pre-commit hook):
  RTOS_GATE_FORMAT=0  RTOS_GATE_RELEASE=0  RTOS_GATE_COVERAGE=0
  RTOS_GATE_MIN_COVERAGE=90   RTOS_PRECOMMIT_LINT=1

Examples:
  scripts/gate.sh                  # what the hook runs
  scripts/gate.sh --skip-coverage  # quick loop while iterating
  scripts/gate.sh --min-coverage 95
EOF
}

skip_format=0
skip_release=0
skip_coverage=0
skip_lint=0
min_coverage="${RTOS_GATE_MIN_COVERAGE:-90}"

while (( $# > 0 )); do
  case "$1" in
    --skip-format) skip_format=1; shift ;;
    --skip-release) skip_release=1; shift ;;
    --skip-coverage) skip_coverage=1; shift ;;
    --skip-lint) skip_lint=1; shift ;;
    --min-coverage) min_coverage="${2:?--min-coverage needs a value}"; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    *)
      printf 'gate.sh: unknown option %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

# Hook-side switches, so a commit can tune the gate without editing the hook.
if [[ "${RTOS_GATE_FORMAT:-1}" == "0" ]]; then skip_format=1; fi
if [[ "${RTOS_GATE_RELEASE:-1}" == "0" ]]; then skip_release=1; fi
if [[ "${RTOS_GATE_COVERAGE:-1}" == "0" ]]; then skip_coverage=1; fi
if [[ "${RTOS_PRECOMMIT_LINT:-0}" != "1" ]]; then skip_lint=1; fi

if ! command -v cmake >/dev/null 2>&1; then
  printf 'gate.sh: cmake not found on PATH\n' >&2
  exit 2
fi
if ! git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf 'gate.sh: %s is not inside a git work tree\n' "$ROOT" >&2
  exit 2
fi

log="$(mktemp)"
trap 'rm -f -- "$log"' EXIT

report_failure() {
  printf '\n---- last 40 lines of the %s log ----\n' "$1"
  tail -n 40 "$log" >&2
  printf '\ngate.sh: %s FAILED — commit aborted (`git commit --no-verify` to bypass)\n' \
    "$1" >&2
}

run_workflow() {
  local name="$1" label="$2"
  local start=$SECONDS
  printf 'gate.sh: %s — cmake --workflow %s\n' "$label" "$name"
  if ! (cd "$ROOT" && cmake --workflow "$name") >"$log" 2>&1; then
    report_failure "$label"
    exit 1
  fi
  printf 'gate.sh: %s OK (%ds)\n' "$label" "$((SECONDS - start))"
}

# --- 1. formatting ----------------------------------------------------------
# Two passes on purpose: --staged guards against partially staged files (it
# refuses to reformat a file whose work tree copy differs from the index) and
# re-stages what it rewrote; the second pass formats the rest of the tree so the
# whole working copy is clean, without ever adding those files to the commit.
if (( skip_format == 0 )); then
  bash "$ROOT/scripts/format.sh" --staged
  bash "$ROOT/scripts/format.sh"
fi

# --- 2. release pipeline ----------------------------------------------------
if (( skip_release == 0 )); then
  run_workflow release "release workflow (build + tests + DEB)"
  # Newest package in the build dir; `|| true` keeps pipefail quiet when head
  # closes the pipe before sort finishes.
  package="$(find "$ROOT/build/release" -maxdepth 1 -name '*.deb' -printf '%T@ %p\n' 2>/dev/null |
    sort -nr | head -n 1 | cut -d' ' -f2- || true)"
  if [[ -n "$package" ]]; then
    printf 'gate.sh:   package: %s\n' "${package#"$ROOT"/}"
  fi
fi

# --- 3. coverage pipeline + threshold --------------------------------------
if (( skip_coverage == 0 )); then
  run_workflow full "coverage workflow (build + tests + gcovr)"

  report="$ROOT/build/coverage/coverage/coverage.xml"
  if [[ ! -f "$report" ]]; then
    printf 'gate.sh: no coverage report at %s — is gcovr installed?\n' \
      "${report#"$ROOT"/}" >&2
    printf '  pip install gcovr\n' >&2
    exit 2
  fi
  rate="$(awk -F'"' '/<coverage line-rate=/{print $2; exit}' "$report")"
  if [[ -z "$rate" ]]; then
    printf 'gate.sh: cannot read line-rate from %s\n' "${report#"$ROOT"/}" >&2
    exit 2
  fi
  percent="$(awk -v r="$rate" 'BEGIN { printf "%.1f", r * 100 }')"
  if awk -v p="$percent" -v m="$min_coverage" 'BEGIN { exit !(p + 0 >= m + 0) }'; then
    printf 'gate.sh: coverage %s%% >= %s%% OK\n' "$percent" "$min_coverage"
  else
    printf 'gate.sh: coverage %s%% < %s%% — commit aborted\n' \
      "$percent" "$min_coverage" >&2
    printf '\n---- per-file table (%s) ----\n' \
      "build/coverage/coverage/coverage.txt" >&2
    tail -n 25 "$ROOT/build/coverage/coverage/coverage.txt" >&2 2>/dev/null || true
    exit 1
  fi
fi

# --- 4. optional clang-tidy -------------------------------------------------
if (( skip_lint == 0 )); then
  bash "$ROOT/scripts/lint.sh" --staged
fi

printf 'gate.sh: all gates passed\n'
