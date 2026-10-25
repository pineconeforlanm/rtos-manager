#!/usr/bin/env bash
# =============================================================================
#  commit-msg-check.sh — Conventional Commits gate.
#
#  Reads the message git is about to record and rejects anything git-cliff
#  cannot classify (see `cliff.toml`), so CHANGELOG.md never silently loses an
#  entry. Run standalone with -m for a dry run.
#
#  Local WIP commits stay possible — `wip:`, `fixup!`, `squash!` and `amend!`
#  pass with a reminder — because CONTRIBUTING.md asks for those to be squashed
#  into real commits before the pull request.
#
#  Exit codes: 0 = accepted, 1 = rejected, 2 = usage problem.
# =============================================================================
set -euo pipefail

readonly TYPES='feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert'
readonly SUBJECT_RE="^(${TYPES})(\([A-Za-z0-9._/-]+\))?!?: [^[:space:]].*$"
readonly MAX_SUBJECT=72
readonly TEMPLATE_HINT='  format: <type>(<scope>): <subject>      e.g. feat(http): add /healthz
  types : feat fix docs style refactor perf test build ci chore revert
  rules : lower-case type, imperative subject, no trailing period,
          blank line before the body, `BREAKING CHANGE:` in the footer'
readonly BYPASS_RE='^(Merge |Revert "|Squashed commit of|fixup! |squash! |amend! |[Ww][Ii][Pp]:|[Ww][Ii][Pp]\(|[Rr]everts? )'

usage() {
  cat <<'EOF'
Usage: scripts/commit-msg-check.sh <commit-msg-file>
       scripts/commit-msg-check.sh -m "<message>"

Validates a message against the Conventional Commits subset in cliff.toml.
Installed as the commit-msg hook; use -m to check a message before writing it.
EOF
}

if [[ "${1:-}" == "-m" ]]; then
  message="${2:-}"
elif [[ -n "${1:-}" && -f "${1}" ]]; then
  # Git prefixes the template/comment lines with '#', which never end up in
  # the recorded message.
  message="$(sed -e '/^#/d' -e 's/\r$//' -e 's/[[:space:]]*$//' "$1")"
elif [[ -z "${1:-}" ]]; then
  usage >&2
  exit 2
else
  printf 'commit-msg-check.sh: %s is not a file\n' "$1" >&2
  exit 2
fi

mapfile -t lines <<<"$message"

# Skip leading blank lines (an editor may leave the cursor below the template).
first=0
while (( first < ${#lines[@]} )) && [[ -z "${lines[first]}" ]]; do
  first=$((first + 1))
done

if (( first >= ${#lines[@]} )); then
  printf 'commit-msg-check.sh: empty commit message\n\n%s\n' "$TEMPLATE_HINT" >&2
  exit 1
fi

subject="${lines[first]}"

if [[ "$subject" =~ $BYPASS_RE ]]; then
  if [[ "$subject" =~ ^([Ww][Ii][Pp]:|[Ww][Ii][Pp]\() ]]; then
    printf 'commit-msg-check.sh: "%s" accepted — squash it into a real commit before the PR\n' \
      "$subject" >&2
  fi
  exit 0
fi

if ! [[ "$subject" =~ $SUBJECT_RE ]]; then
  printf 'commit-msg-check.sh: not a Conventional Commit:\n  %s\n\n%s\n' \
    "$subject" "$TEMPLATE_HINT" >&2
  printf '\nSee CONTRIBUTING.md and .gitmessage; abort with --no-verify only if you mean it.\n' >&2
  exit 1
fi

if (( ${#subject} > MAX_SUBJECT )); then
  printf 'commit-msg-check.sh: subject is %d characters, keep it <= %d:\n  %s\n' \
    "${#subject}" "$MAX_SUBJECT" "$subject" >&2
  exit 1
fi

if [[ "$subject" =~ [.。]$ ]]; then
  printf 'commit-msg-check.sh: drop the trailing period from the subject:\n  %s\n' \
    "$subject" >&2
  exit 1
fi

# `<subject>` then blank line then body/footer; a body glued to the subject is
# read as one over-long line by git-cliff and by `git log --oneline`.
if (( first + 1 < ${#lines[@]} )) && [[ -n "${lines[first + 1]}" ]]; then
  printf 'commit-msg-check.sh: leave line 2 blank, the body starts on line 3:\n  %s\n  %s\n' \
    "$subject" "${lines[first + 1]}" >&2
  exit 1
fi

exit 0
