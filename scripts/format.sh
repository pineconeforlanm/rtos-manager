#!/usr/bin/env bash
# =============================================================================
#  format.sh — clang-format driver (the only entry point for C++ formatting).
#
#  Scope: include/ src/ test/ bench/ example/. thirdparty/ is vendored and is
#  never rewritten; --staged narrows the set to `git diff --cached`, so the
#  pre-commit hook only pays for the files you actually touched.
#
#  Exit codes: 0 = clean, 1 = formatting diff or partially-staged file refused,
#              2 = setup problem (no clang-format, not inside a work tree).
# =============================================================================
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT="$(dirname -- "${SCRIPT_DIR}")"
readonly SOURCE_DIRS=(include src test bench example)

usage() {
  cat <<'EOF'
Usage: scripts/format.sh [--check] [--staged]

  (no option)   rewrite every project source in place
  --check       verify only, never write; non-zero exit if anything differs
  --staged      restrict to the files staged for the next commit

Examples:
  scripts/format.sh --staged          # what the pre-commit hook runs
  scripts/format.sh --check           # whole-repo gate (CI / before a tag)
  scripts/format.sh                   # format everything once

clang-format is taken from $CLANG_FORMAT, then PATH, then ~/.local/bin and
~/.venvs/clang-format/bin (a pip --user install is not on a build driver's
PATH). --check needs clang-format >= 15 (it relies on --dry-run --Werror).
EOF
}

mode="fix"
scope="all"
for arg in "$@"; do
  case "$arg" in
    --check | --dry-run) mode="check" ;;
    --staged) scope="staged" ;;
    -h | --help) usage; exit 0 ;;
    *)
      printf 'format.sh: unknown option %s\n\n' "$arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

resolve_clang_format() {
  local name dir
  for name in "${CLANG_FORMAT:-}" clang-format clang-format-19 clang-format-18 clang-format-17; do
    [[ -n "$name" ]] || continue
    if command -v "$name" >/dev/null 2>&1; then
      command -v "$name"
      return 0
    fi
  done
  for dir in "$HOME/.local/bin" "$HOME/.venvs/clang-format/bin" /usr/local/bin /usr/bin; do
    for name in clang-format clang-format-19 clang-format-18 clang-format-17; do
      if [[ -x "$dir/$name" ]]; then
        printf '%s\n' "$dir/$name"
        return 0
      fi
    done
  done
  return 1
}

collect_all() {
  local dir
  for dir in "${SOURCE_DIRS[@]}"; do
    [[ -d "$ROOT/$dir" ]] || continue
    find "$ROOT/$dir" -type f \( -name '*.cc' -o -name '*.cpp' -o -name '*.hpp' -o -name '*.h' \)
  done | LC_ALL=C sort
}

collect_staged() {
  local path
  while IFS= read -r -d '' path; do
    printf '%s\n' "$ROOT/$path"
  done < <(git -C "$ROOT" diff --cached --name-only --diff-filter=ACMR -z \
             -- '*.cc' '*.cpp' '*.hpp' '*.h')
}

if ! tool="$(resolve_clang_format)"; then
  printf 'format.sh: clang-format not found — install it first:\n' >&2
  printf '  pip install --user clang-format\n' >&2
  printf '  # PEP 668 distros also need: --break-system-packages\n' >&2
  exit 2
fi

if ! git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf 'format.sh: %s is not inside a git work tree\n' "$ROOT" >&2
  exit 2
fi

mapfile -t files < <(if [[ "$scope" == "staged" ]]; then collect_staged; else collect_all; fi)
if (( ${#files[@]} == 0 )); then
  printf 'format.sh: no %s C++ sources — nothing to do\n' "$scope"
  exit 0
fi

# Formatting a file whose work tree copy differs from the index would drag the
# unstaged hunks into the commit, so ask for a fully staged file instead of
# silently committing more than the author reviewed.
if [[ "$scope" == "staged" && "$mode" == "fix" ]]; then
  partial=()
  for file in "${files[@]}"; do
    rel="${file#"$ROOT"/}"
    if [[ -n "$(git -C "$ROOT" diff --name-only -- "$rel")" ]]; then
      partial+=("$rel")
    fi
  done
  if (( ${#partial[@]} > 0 )); then
    printf 'format.sh: refusing to format — these files also have unstaged changes:\n' >&2
    printf '  %s\n' "${partial[@]}" >&2
    printf 'Stage the whole file (`git add <file>`) or stash the extra hunks, then retry.\n' >&2
    exit 1
  fi
fi

if [[ "$mode" == "check" ]]; then
  version_major="$("$tool" --version | grep -oE '[0-9]+' | head -n 1)"
  if (( version_major < 15 )); then
    printf 'format.sh: clang-format %s is too old for --check (need >= 15)\n' \
      "${version_major}" >&2
    exit 2
  fi
  if "$tool" --dry-run --Werror --style=file "${files[@]}"; then
    printf 'format.sh: OK — %d file(s) already formatted\n' "${#files[@]}"
    exit 0
  fi
  printf '\nformat.sh: the files above are not formatted.\n' >&2
  printf 'Fix with: scripts/format.sh%s\n' \
    "$([[ "$scope" == "staged" ]] && printf ' --staged')" >&2
  exit 1
fi

"$tool" -i --style=file "${files[@]}"

if [[ "$scope" == "staged" ]]; then
  # Re-stage what clang-format rewrote so the hook's result is what gets
  # committed; `git add` also refreshes the stat cache for untouched files.
  rel_paths=()
  for file in "${files[@]}"; do rel_paths+=("${file#"$ROOT"/}"); done
  git -C "$ROOT" add -- "${rel_paths[@]}"
fi

printf 'format.sh: formatted %d file(s) with %s\n' "${#files[@]}" "$tool"
