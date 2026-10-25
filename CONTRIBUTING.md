# Contributing

This guide describes the development workflow for `rtos-manager`. We use
**Git Flow**, [Conventional Commits](https://www.conventionalcommits.org/), and
[Semantic Versioning](https://semver.org/).

---

## Branch model (Git Flow)

```
       feat/..., fix/..., docs/...
          │  merge back
   ┌──────▼───────┐
   │   develop    │  ← integration branch (daily work, next release)
   └──────┬───────┘
          │  cut release/...
   ┌──────▼───────┐        ┌───────────────┐
   │     main     │◄───────┤  hotfix/...   │  ← production + emergency fixes
   └──────────────┘        └───────────────┘
```

| Branch          | Purpose                                                        | Lifetime |
|-----------------|----------------------------------------------------------------|----------|
| `main`          | Production-ready code. Every tip is a releasable, tagged SHA.  | forever  |
|                 | Advances **only** through a `release/*` or `hotfix/*` merge.   |          |
| `develop`       | Integration branch for the next release. Feature work merges   | forever  |
|                 | here via pull request — never by pushing directly.             |          |
| `<type>/*`      | Feature, fix or documentation work. Branched from and merged   | temporary|
|                 | into `develop` through a PR.                                   |          |
| `release/*`     | Release stabilization. Branched from `develop`, merged into    | temporary|
|                 | `main` **and** back into `develop`.                            |          |
| `hotfix/*`      | Urgent fix on production. Branched from `main`, merged into    | temporary|
|                 | `main` and `develop`.                                          |          |

### Naming conventions

```
<type>/<short-desc>             e.g. feat/version-flags, fix/deb-version
release/<version>               e.g. release/0.2.0
hotfix/<version>-<short-desc>   e.g. hotfix/0.2.1-fix-port-bind
```

The prefix mirrors the Conventional Commit type of the work (`feat`, `fix`,
`docs`, `build`, `test`, `refactor`), so the branch reads like the commits it
will carry; `feature/*` is accepted as a synonym of `feat/*`. The description is
kebab-case with no ticket number — the issue belongs in the PR, not in the ref.

---

## Day-to-day workflow (branch → PR → develop)

Every change reaches `develop` through a short-lived `<type>/*` branch and a
pull request; direct commits to `develop` or `main` are not part of the model.
Keep history readable: commit freely while working, then **squash into a few
Conventional Commits before opening the PR**.

```bash
# 1. Branch off develop
git checkout develop && git pull
git checkout -b feat/version-flags

# 2. Work — commit as often as you like (wip / fix / ... are fine locally)
git commit -m "wip: sketch tls context"
git commit -m "fix: leak on error path"

# 3. Stay in sync with develop by REBASING (not merging) -> linear history
git fetch origin && git rebase origin/develop

# 4. Tidy: squash / reword into Conventional Commits before review
git rebase -i origin/develop      # squash/fixup/reword -> e.g. feat(http): ...

# 5. Push and open a PR against develop
git push -u origin feat/version-flags

# 6. After the PR is merged, retire the branch
git checkout develop && git pull
git branch -d feat/version-flags
git push origin --delete feat/version-flags
```

### Rules

- **Squash before the PR, not after.** Once reviewers start commenting, do **not**
  rewrite the pushed history. Address feedback with new commits (or
  `git commit --fixup=<sha>` + `git rebase --autosquash`) and force-update only
  with `git push --force-with-lease` (never bare `--force`).
- **PR merge strategy:** the default is GitHub's *Create a merge commit* (`--no-ff`),
  because it keeps the branch's several Conventional Commits visible (git-cliff
  turns each into a CHANGELOG line) and the merge point records that the work went
  through review. Use *Squash and merge* only for a single tiny change. Never
  rebase-merge a branch that several people have pulled.
- **`develop` and `main` only move through the model:** a PR (or, for `main`, a
  `release/*` / `hotfix/*` merge). If a commit landed on `develop` directly, the
  fix is a follow-up PR that contains the missing change — not a force-push over
  shared history.
- Keep `develop` always releasable-green: before merging, run the full pipeline
  locally — `scripts/gate.sh` (formatting + Release workflow + coverage workflow
  with its 90% threshold). There is no hosted CI; every gate is a local
  `cmake --workflow`, `--target` or `scripts/*` command.

---

## Local gates: hooks, formatting, linting

The gates live in [`scripts/`](scripts/) and [`.githooks/`](.githooks/), **not** in
CMake, so a plain `cmake --build` stays a build. Enable them once per clone:

```bash
scripts/install-hooks.sh                  # symlink .githooks/* into .git/hooks
scripts/install-hooks.sh --with-template  # ... and start every message from .gitmessage
```

| Gate | When | Where |
|------|------|-------|
| `pre-commit` | every commit | [`scripts/gate.sh`](scripts/gate.sh): formats the **whole tree** (staged files re-staged), then the Release workflow and the coverage workflow with a ≥ 90% line threshold |
| `commit-msg` | every commit | [Conventional Commits](#commit-message-conventions-conventional-commits) gate (`scripts/commit-msg-check.sh`) |
| `scripts/gate.sh` | by hand, same as the hook | the full gate without staging anything |
| `scripts/lint.sh` | before a PR | clang-tidy over `src/*.cc`, reusing `build/debug/compile_commands.json` |
| `scripts/format.sh --check` | before a PR / release | whole-repo formatting gate (`--dry-run --Werror`) |
| `scripts/build.sh --test` | before a PR / release | Release build **and** the full test suite, without the coverage workflow |
| `cmake --workflow ci-lint` | before a release | clang-tidy through `CMAKE_CXX_CLANG_TIDY` (full rebuild) |

Rules of engagement:

- The pre-commit hook formats the whole tree so the working copy cannot drift
  from `.clang-format`, but only the **staged** files are re-added. It **refuses**
  to format a staged file that also has unstaged hunks: `git add` the whole file
  (or `git stash push` the extra changes) instead of letting unreviewed code slip
  into the commit.
- Formatting runs first, then `cmake --workflow release` (warnings-as-errors +
  LTO + tests + `.deb`) and `cmake --workflow full` (instrumented build, the same
  tests, gcovr). Together they are the cheapest way to catch a `-Werror`
  regression, a missing include, a broken preset or an untested branch before it
  reaches `develop`. Both are `cmake --workflow`, so they reconfigure each time —
  and a configure rewrites the timestamped `version_info.hpp`, which rebuilds a
  dozen TUs plus the LTO link. Expect about a minute per commit once warm, minutes
  on the first run in a fresh clone.
- Lines are the coverage currency: the gate reads `coverage.xml` and aborts below
  **90%**, printing the per-file table from `build/coverage/coverage/coverage.txt`.
  `src/main.cc` is excluded — it is the process entry point, covered by running
  the binary, not by unit tests. New code therefore comes with tests, or with a
  reason in the PR why it does not.
- Per-commit escape hatches: `RTOS_GATE_FORMAT=0`, `RTOS_GATE_RELEASE=0`,
  `RTOS_GATE_COVERAGE=0` skip one stage, `RTOS_GATE_MIN_COVERAGE=95` raises the
  bar, `RTOS_PRECOMMIT_BUILD=0`/`RTOS_PRECOMMIT_TEST=1` still work through
  `scripts/build.sh` when it is called directly.
- clang-tidy is **not** part of the commit hook by default — a tidy run re-parses
  every file per change. Opt in with `RTOS_PRECOMMIT_LINT=1 git commit …`, or call
  `scripts/lint.sh --staged` yourself.
- `cpplint` is deliberately absent: it enforces the Google style rather than
  `.clang-format`, knows nothing about C++26, and its useful checks are already
  covered by `clang-tidy`'s `google-*` / `readability-*` families.
- `git commit --no-verify` skips both hooks — reserve it for throwaway commits.

---

## Commit message conventions (Conventional Commits)

```
<type>(<scope>): <subject>

<body>

<footer>
```

Allowed `type`: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`,
`build`, `ci`, `chore`, `revert`.

Examples:
```
feat(http): add GET /healthz endpoint
fix(build): guard git describe when no tags exist
docs(readme): document coverage preset
```

A `BREAKING CHANGE:` footer (or `!` after the type) signals a major bump.

The `commit-msg` hook enforces this shape: allowed `type`, optional `(<scope>)`,
`!` for breaking changes, ≤ 72 characters, no trailing period, and a blank line
before the body. `wip:`, `fixup!`, `squash!` and `amend!` pass on purpose for
local work in progress — squash them before the PR.

[`.gitmessage`](.gitmessage) documents every type and the CHANGELOG group it maps
to. Enable it with `git config --local commit.template .gitmessage` (or
`scripts/install-hooks.sh --with-template`), and preview a message without
committing with `scripts/commit-msg-check.sh -m "feat(http): add /healthz"`.

Types mirror `cliff.toml`: `style`, `ci` and `chore` are accepted but skipped in
`CHANGELOG.md`; an unknown type would silently drop the entry, which is exactly
what the hook prevents.

---

## Packaging (DEB) & artifacts

CPack produces two artifact flavours and the **file name encodes how the build
should be treated**, so a throwaway debug build can never masquerade as (or
overwrite) a release package:

| Build | One command | Artifact name |
|-------|-------------|---------------|
| **Release** (对外发布) | `cmake --workflow release` | `rtos-manager-<semver>-<arch>.deb` — clean, **no hash** |
| **Debug** (日常部署/调试) | `cmake --workflow package-debug` | `rtos-manager-<semver>-Debug-<branch>-<hash>[-dirty]-<arch>.deb` — traceable |
| RelWithDebInfo | `cmake --workflow release` 改配 preset / `cpack --preset deb-relwithdebinfo` | `rtos-manager-<semver>-RelWithDebInfo-<arch>.deb` |

- The **debug** name carries branch (truncated to 20 chars) + short commit hash
  and a `-dirty` marker when the working tree is uncommitted, so a build is
  always traceable to a commit.
- Every package installs `/etc/version/rtos-manager.version` with full metadata
  (semver, `git describe`, commit, branch, tag, dirty, build type/time, compiler,
  arch); `rtos-manager --version` prints the same data baked into the binary.

---

## Release process

Releases are cut from `develop` through a `release/*` branch. The version lives
in **two** synchronized places:

1. `CMakeLists.txt` → `project(... VERSION x.y.z ...)`
2. `conanfile.py` → `version = "x.y.z"`

`CHANGELOG.md` is **curated prose on a generated skeleton**: git-cliff
([`cliff.toml`](cliff.toml)) turns the Conventional Commits since the previous
tag into the section for the version being released, and the release commit
rewrites that section into readable notes. Never regenerate the whole file —
`git-cliff -o CHANGELOG.md` replaces every earlier hand-written section with its
terse skeleton (the sections already in the file are hand-written prose). Install locally:

```bash
# Pick your preferred method:
cargo install git-cliff
# or download the pre-built binary:
curl -sL https://github.com/orhun/git-cliff/releases/latest/download/git-cliff-<ver>-x86_64-unknown-linux-gnu.tar.gz | tar xz
# or use the CMake convenience target (no-ops if git-cliff is absent):
cmake --build build/debug --target changelog
```

Generation always runs with `--offline`: the template's `commit.remote.*`
references would otherwise make git-cliff call the GitHub API for author handles,
and a network timeout aborts the run instead of writing the file.

Steps:

```bash
# 1. Cut the release branch from develop
git checkout develop && git pull
git checkout -b release/0.2.0

# 2. Bump the version in CMakeLists.txt and conanfile.py
git commit -am "chore(release): prepare 0.2.0"

# 3. Generate the section for this version, then splice it in by hand
git-cliff --config cliff.toml --offline --unreleased --tag v0.2.0 --strip header
#    -> review it, enrich it from the commit bodies, paste it into CHANGELOG.md
#       directly below the header (newest section first)
git add CHANGELOG.md
git commit -m "docs(changelog): add 0.2.0 release notes"

# 4. Tag on main after merging the release branch
git checkout main
git merge --no-ff release/0.2.0
git tag -a v0.2.0 -m "Release 0.2.0"

# 5. Back-merge MAIN into develop (this is what carries the tag), retire the branch
git checkout develop
git merge --no-ff main          # merge main, NOT release/0.2.0 — the tag sits on main's merge commit
git branch -d release/0.2.0

# 6. Publish
git push origin main develop --tags

# 7. Point the docs at the release you just shipped
#    README badges + sample output, api/openapi.yaml info.version and examples,
#    CONTRIBUTING.md examples — anything still naming the previous version.
```

> **Step 7 is part of the release, not cleanup.** Version strings scattered through
> the docs are the one thing `scripts/gate.sh` cannot check, and they go stale
> silently: `v0.1.2` shipped with a `version-0.1.0` README badge, a `0.1.0`
> `info.version` in `api/openapi.yaml` and sample output from `v0.1.2-rc.1`.
> Prefer placeholders (`<previous>`) over version literals in instructions that
> outlive a single release.

> **Why merge `main`, not the release branch?** `v0.2.0` is tagged on the merge
> commit that step 4 creates on `main`. Back-merging only `release/0.2.0` into
> `develop` skips that commit, so `git describe --tags` from `develop` cannot
> find the tag — `tag` shows empty in `/api/v1/version`. Merging `main`
> **forward** (never rewriting pushed history) makes the tag reachable from
> `develop` and every branch cut from it.

### Release candidates (`-rc.N`)

A release candidate is a **published artifact**, not a local dress rehearsal: this
project ships `vX.Y.Z-rc.N` whenever a release touches something a changelog
cannot vouch for (version plumbing, DEB layout, gate or hooks) or when the change
needs feedback from a real install. A candidate therefore goes through the *same*
flow as a final release — merge into `main`, tag the merge commit, back-merge
`main` into `develop`, push the tag, open a GitHub Release marked
**pre-release** — and differs only in the tag suffix and the Debian control
version:

| Tag | `.deb` file | control `Version:` |
|-----|-------------|--------------------|
| `v0.1.2-rc.1` | `rtos-manager-0.1.2-rc.1-x86_64.deb` | `0.1.2~rc.1` |
| `v0.1.2` | `rtos-manager-0.1.2-x86_64.deb` | `0.1.2` |

`~`, not `-`: dpkg reads the **last** `-` as the Debian revision, so a literal
`0.1.2-rc.1` would mean upstream `0.1.2-rc` with revision `1` and sort *after*
`0.1.2` — the final release would never upgrade over its own candidate. Both
strings come from the tag (`cmake/version_info.cmake` → `cmake/packaging.cmake`),
never from `project(... VERSION ...)`.

Rules for candidates:

- **Tag on `main`, on the release-merge commit** — every published tag so far
  (`v0.1.0`, `v0.1.1`, `v0.1.2`) is an annotated tag on
  `chore(release): merge release/* into main`. Never tag the release-branch tip:
  the tag must stay reachable from `develop` afterwards, and `main` is the branch
  every published artifact passes through.
- **Published tags are immutable.** Once an `-rc.N` is pushed, do not retag, move
  or delete it: the `.deb`, its CHANGELOG section and every installed
  `/etc/version` file reference it. Fix the defect on the same `release/*` branch
  and ship `-rc.(N+1)`.
- **Keep the branch alive** between candidates. `release/0.1.2` stays checked out
  for the fixes and is retired only after the final `v0.1.2` ships.
- **Every candidate keeps its CHANGELOG section**, curated like any other
  release. `cliff.toml` deliberately lets `vX.Y.Z-rc.N` match `tag_pattern`; do
  not add `skip_tags = "rc"`. The final release then lists only what changed
  since the last candidate, and the candidate sections are its history.
- **Candidates run the full gate** like any commit (`scripts/gate.sh`, ≥ 90 % line
  coverage), plus `cmake --workflow sanitize` when the candidate touches threads,
  I/O or serialization.

```bash
# Cut the candidate — steps 1-3 above, with the rc name.
git checkout -b release/0.1.2
# ... bump CMakeLists.txt + conanfile.py to 0.1.2, commit "chore(release): prepare 0.1.2"
git-cliff --config cliff.toml --offline --unreleased --tag v0.1.2-rc.1 --strip header
#    -> paste (and enrich) the `## [0.1.2-rc.1]` section at the top of CHANGELOG.md
git commit -am "docs(changelog): add 0.1.2-rc.1 release notes"

# Tag on main (step 4), then build the artifact from the tag.
git checkout main && git merge --no-ff release/0.1.2
git tag -a v0.1.2-rc.1 -m "Release 0.1.2-rc.1"
cmake --workflow release      # -> build/release/rtos-manager-0.1.2-rc.1-x86_64.deb

# Verify exactly what ops will see: install → run → inspect → roll back.
sudo apt install ./build/release/rtos-manager-0.1.2-rc.1-x86_64.deb
dpkg -s rtos-manager | grep ^Version      # 0.1.2~rc.1
rtos-manager --version                    # tag=v0.1.2-rc.1, dirty=false
cat /etc/version/rtos-manager.version
systemctl status rtos-manager
curl -s localhost:8080/api/v1/version     # default config, port 8080

# Roll back to the shipped release (no package repo: point at the .deb you kept;
# the candidate sorts above <previous>, hence --allow-downgrades).
sudo apt install --allow-downgrades ./rtos-manager-<previous>-x86_64.deb

# Carry the tag into develop (step 5) and publish (step 6).
git checkout develop && git merge --no-ff main
git push origin main develop --tags
```

> The tag must exist **before** the build: artifacts take their version from
> `git describe`, so building first produces a package named after the previous
> release.

Fix whatever the candidate turns up on `release/0.1.2` and repeat with `-rc.2`;
the final `vX.Y.Z` is the same flow once more, after which the branch is deleted.

The release is produced **locally** (this project has no hosted CI). On the
release commit / tag, run:

```bash
cmake --workflow release      # build + test + package -> build/release/*.deb
```

The changelog section is written *before* the tag (step 3), so the notes a
release points at are exactly the ones reviewed on the release branch.

Then, if you publish on GitHub, create the Release for the `v0.2.0` tag manually
and attach the generated `.deb`.

### Semantic versioning

Given version `MAJOR.MINOR.PATCH`:
- **MAJOR** — incompatible API changes
- **MINOR** — backward-compatible new functionality
- **PATCH** — backward-compatible bug fixes

Pre-release identifiers (`-alpha.1`, `-beta.2`, `-rc.1`) are published from a
`release/*` branch like any other version — see
[Release candidates](#release-candidates-rcn) for the tag placement, the Debian
version mapping and the no-retagging rule.

---

## Hotfix process

```bash
git checkout main && git pull
git checkout -b hotfix/0.2.1-fix-port-bind
# fix + test + bump PATCH version + CHANGELOG
git checkout main && git merge --no-ff hotfix/0.2.1-fix-port-bind
git tag -a v0.2.1 -m "Hotfix 0.2.1"
git checkout develop && git merge --no-ff hotfix/0.2.1-fix-port-bind
git push origin main develop --tags
```

That is the *emergency* shape: `main` moves first because installed systems are
already broken. When a fix batch does not have to be in an operator's hands
today — documentation, metadata, a defect found while preparing the next
release — cut the `hotfix/*` branch from `main` all the same, but send it to
`develop` through a pull request and let the next `release/*` carry it to `main`.
Nothing is tagged twice, `main` still only advances through a release merge, and
the batch is reviewed like any other change.

---

## Pull request checklist

- [ ] Branch is up to date with its target (`develop` or `main`)
- [ ] `cmake --preset debug && cmake --build --preset debug && ctest --preset debug` passes (Conan deps are auto-installed by the provider at configure time)
- [ ] `scripts/install-hooks.sh` has been run in this clone (pre-commit + commit-msg active)
- [ ] `scripts/gate.sh` passes end to end (format + Release workflow + coverage ≥ 90%)
- [ ] `scripts/format.sh --check` and `scripts/lint.sh` are clean
- [ ] New code is covered by tests: line coverage over `src/` (minus `main.cc`) stays ≥ 90%
- [ ] Conventional commit messages (git-cliff reads these for CHANGELOG.md)
- [ ] Documentation / Doxygen comments updated for public headers
