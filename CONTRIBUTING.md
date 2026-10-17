# Contributing

This guide describes the development workflow for `rtos-manager`. We use
**Git Flow**, [Conventional Commits](https://www.conventionalcommits.org/), and
[Semantic Versioning](https://semver.org/).

---

## Branch model (Git Flow)

```
       feature/...
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
| `develop`       | Integration branch for the next release. Feature work merges   | forever  |
|                 | here via pull request.                                         |          |
| `feature/*`     | New functionality. Branched from and merged into `develop`.    | temporary|
| `release/*`     | Release stabilization. Branched from `develop`, merged into    | temporary|
|                 | `main` **and** back into `develop`.                            |          |
| `hotfix/*`      | Urgent fix on production. Branched from `main`, merged into    | temporary|
|                 | `main` and `develop`.                                          |          |

### Naming conventions

```
feature/<ticket>-<short-desc>   e.g. feature/RTOS-12-add-http-server
release/<version>               e.g. release/0.2.0
hotfix/<version>-<short-desc>   e.g. hotfix/0.2.1-fix-port-bind
```

---

## Day-to-day workflow

```bash
# Start a feature from develop
git checkout develop
git pull
git checkout -b feature/RTOS-20-tls-support

# ... commit locally (see commit conventions below) ...

# Push and open a PR against develop
git push -u origin feature/RTOS-20-tls-support
```

Keep `develop` always releasable-green: before merging, run the full pipeline
locally — `cmake --workflow full` (build + tests + coverage). There is no hosted
CI; every gate is a local `cmake --workflow` / `--target` command.

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

---

## Release process

Releases are cut from `develop` through a `release/*` branch. The version lives
in **two** synchronized places:

1. `CMakeLists.txt` → `project(... VERSION x.y.z ...)`
2. `conanfile.py` → `version = "x.y.z"`

`CHANGELOG.md` is generated automatically by
[git-cliff](https://git-cliff.org) from Conventional Commits history
(see [`cliff.toml`](cliff.toml) for the template). Install locally:

```bash
# Pick your preferred method:
cargo install git-cliff
# or download the pre-built binary:
curl -sL https://github.com/orhun/git-cliff/releases/latest/download/git-cliff-<ver>-x86_64-unknown-linux-gnu.tar.gz | tar xz
# or use the CMake convenience target (no-ops if git-cliff is absent):
cmake --build build/debug --target changelog
```

Steps:

```bash
# 1. Cut the release branch from develop
git checkout develop && git pull
git checkout -b release/0.2.0

# 2. Bump the version in CMakeLists.txt and conanfile.py
git commit -am "chore(release): prepare 0.2.0"

# 3. Regenerate CHANGELOG.md (replaces manual editing)
git-cliff --config cliff.toml --output CHANGELOG.md
git add CHANGELOG.md
git commit -m "docs(changelog): regenerate for 0.2.0"

# 4. Tag on main after merging the release branch
git checkout main
git merge --no-ff release/0.2.0
git tag -a v0.2.0 -m "Release 0.2.0"

# 5. Back-merge into develop and retire the release branch
git checkout develop
git merge --no-ff release/0.2.0
git branch -d release/0.2.0

# 6. Publish
git push origin main develop --tags
```

The release is produced **locally** (this project has no hosted CI). On the
release commit / tag, run:

```bash
cmake --workflow release      # build + test + package -> build/release/*.deb
git-cliff --config cliff.toml --tag v0.2.0 -o CHANGELOG.md
```

Then, if you publish on GitHub, create the Release for the `v0.2.0` tag manually
and attach the generated `.deb`.

### Semantic versioning

Given version `MAJOR.MINOR.PATCH`:
- **MAJOR** — incompatible API changes
- **MINOR** — backward-compatible new functionality
- **PATCH** — backward-compatible bug fixes

Pre-release identifiers (`-alpha.1`, `-beta.2`, `-rc.1`) are allowed for
`release/*` candidates.

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

---

## Pull request checklist

- [ ] Branch is up to date with its target (`develop` or `main`)
- [ ] `cmake --preset debug && cmake --build --preset debug && ctest --preset debug` passes (Conan deps are auto-installed by the provider at configure time)
- [ ] New code is covered by tests (coverage does not regress)
- [ ] Conventional commit messages (git-cliff reads these for CHANGELOG.md)
- [ ] Documentation / Doxygen comments updated for public headers
