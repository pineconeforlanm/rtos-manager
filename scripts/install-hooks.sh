#!/usr/bin/env bash
# =============================================================================
#  install-hooks.sh — wire .githooks/* into this clone's .git/hooks.
#
#  Hooks live in the repository (.githooks/, versioned) but git only runs what
#  sits in .git/hooks, which is not part of the tree. This script symlinks one
#  into the other, so every clone opts in with a single command and the hook
#  implementation stays reviewable in diffs.
#
#  `--with-template` additionally points the clone at .gitmessage, which makes
#  `git commit` (without -m) start from the Conventional Commits template.
#
#  Exit codes: 0 = ok, 1 = refused (existing hook, use --force), 2 = setup.
# =============================================================================
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT="$(dirname -- "${SCRIPT_DIR}")"
readonly HOOK_SRC="$ROOT/.githooks"
readonly TEMPLATE="$ROOT/.gitmessage"

usage() {
  cat <<'EOF'
Usage: scripts/install-hooks.sh [--force] [--with-template] [--uninstall]

  (no option)      symlink .githooks/* into .git/hooks (never overwrites)
  --force          replace a regular, hand-written hook file
  --with-template  also run `git config --local commit.template .gitmessage`
  --uninstall      remove the symlinks this script created

Run it once per clone. `git commit --no-verify` bypasses the hooks.
EOF
}

force=0
with_template=0
uninstall=0
for arg in "$@"; do
  case "$arg" in
    --force) force=1 ;;
    --with-template) with_template=1 ;;
    --uninstall) uninstall=1 ;;
    -h | --help) usage; exit 0 ;;
    *)
      printf 'install-hooks.sh: unknown option %s\n\n' "$arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! hooks_dir="$(git -C "$ROOT" rev-parse --git-path hooks 2>/dev/null)"; then
  printf 'install-hooks.sh: %s is not a git work tree\n' "$ROOT" >&2
  exit 2
fi
[[ "$hooks_dir" = /* ]] || hooks_dir="$ROOT/$hooks_dir"
mkdir -p "$hooks_dir"

mapfile -t hooks < <(find "$HOOK_SRC" -maxdepth 1 -type f ! -name '*.md' -printf '%f\n' | LC_ALL=C sort)
if (( ${#hooks[@]} == 0 )); then
  printf 'install-hooks.sh: no hooks found in %s\n' "$HOOK_SRC" >&2
  exit 2
fi

if (( uninstall == 1 )); then
  for name in "${hooks[@]}"; do
    dest="$hooks_dir/$name"
    if [[ -L "$dest" ]]; then
      rm -- "$dest"
      printf 'removed  %s\n' "${dest#"$ROOT"/}"
    fi
  done
  printf '\nHooks uninstalled. The commit template setting, if set, is left alone.\n'
  exit 0
fi

refused=0
for name in "${hooks[@]}"; do
  src="$HOOK_SRC/$name"
  dest="$hooks_dir/$name"
  chmod +x "$src"

  if [[ -e "$dest" && ! -L "$dest" ]] && (( force == 0 )); then
    printf 'skipping %s: a regular hook file is already there (use --force)\n' "$name" >&2
    refused=1
    continue
  fi

  # Relative link so the clone can be moved or renamed; worktree layouts that
  # live outside the tree fall back to an absolute one via realpath.
  link="$(realpath --relative-to="$hooks_dir" "$src")"
  ln -sfn "$link" "$dest"
  printf 'installed %s -> %s\n' "${dest#"$ROOT"/}" "$link"
done

if (( with_template == 1 )); then
  git -C "$ROOT" config --local commit.template .gitmessage
  printf 'commit template enabled: %s\n' "${TEMPLATE#"$ROOT"/}"
else
  printf '\nOptional — start every commit message from the template:\n'
  printf '  git config --local commit.template .gitmessage\n'
  printf '  # or re-run this script with --with-template\n'
fi

(( refused == 0 )) || exit 1
exit 0
