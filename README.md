# verrou-dist

Build-and-distribute tooling for [Verrou](https://github.com/edf-hpc/verrou)
(the Valgrind floating-point–perturbation tool). It compiles a pinned
**Valgrind + Verrou** pair from source and publishes **prebuilt, hash-verified
artifacts** so downstream consumers (e.g. [MFC](https://github.com/MFlowCode/MFC)'s
`./mfc.sh fp-stability`) can download Verrou in seconds instead of doing a ~20-min
source build.

## The one rule: Verrou drives, Valgrind follows

Verrou ships a patch (`valgrind.<version>.diff`) written against a **specific**
Valgrind release. You can't pair latest-with-latest — Verrou lags Valgrind. So the
authoritative Valgrind version is read from Verrou's patch filename
(`resolve_versions.py`), and the pin lives in [`versions.env`](versions.env).

## Layout

| File | Role |
|------|------|
| `versions.env` | single source of truth: `VALGRIND_VERSION`, `VERROU_COMMIT`, optional `VALGRIND_SHA256` |
| `build.sh` | the canonical builder (used by CI and consumable directly by downstreams) |
| `resolve_versions.py` | reads the Valgrind version a Verrou checkout targets |
| `test/smoke.c` | proves the built Verrou actually perturbs FP (not just runs) |
| `.github/workflows/watch.yml` | weekly: detect upstream changes → open a bump PR |
| `.github/workflows/build-test.yml` | build + smoke-test on x86_64/aarch64 (the conflict gate) |
| `.github/workflows/release.yml` | on tag: build + publish prebuilt tarballs |

## Build locally

```sh
bash build.sh --prefix ~/.local/verrou   # Linux; x86_64 (aarch64 experimental)
```

## Consume a release (what MFC does)

```sh
ver=vX                                    # a release tag
arch=$(uname -m)                          # x86_64 | aarch64
base=verrou-<commit>-valgrind-<ver>-linux-$arch.tar.zst
curl -fsSLO https://github.com/sbryngelson/verrou-dist/releases/download/$ver/$base
curl -fsSLO https://github.com/sbryngelson/verrou-dist/releases/download/$ver/$base.sha256
sha256sum -c $base.sha256
mkdir -p ~/.local/verrou && tar -C ~/.local/verrou --zstd -xf $base

# Valgrind bakes its build prefix into the binary, so a relocated tree needs its
# environment. Source the (relocatable) env.sh — sets VALGRIND_LIB + PYTHONPATH:
source ~/.local/verrou/env.sh
valgrind --tool=verrou --version       # works from any path now
```

## Automation model (deliberate)

- **Auto-detect + auto-build-test + auto-PR** are hands-off (weekly `watch`).
- **Release is human-gated**: a maintainer merges the bump PR and pushes a tag.
  A green build can still hide a *behavioural* change in rounding semantics, which
  downstream numerics would silently inherit — so a human reviews before release.
- A failed build-test labels the PR `conflict` (patch didn't apply / build broke /
  Verrou stopped perturbing), so a bad pair can't be merged blind.

## Constraints

- **Linux only** — Valgrind has no working modern-macOS (incl. Apple Silicon) support.
- **x86_64** is well-validated; **aarch64** builds but Verrou's FP backends are less
  battle-tested there (artifacts are published but flagged experimental).

## One-time repo settings

- Settings → Actions → General → **Allow GitHub Actions to create and approve pull
  requests** (so `watch` can open bump PRs).
- For visibility: keep **private** while iterating, but release downloads need the
  repo **public** (unauthenticated `curl` from MFC's CI/users).

## Licensing

The scripts/workflows in this repo are MIT (see `LICENSE`). The **artifacts** they
build are GPL: Valgrind is GPL-2.0, Verrou is GPL-3.0 — redistribution is fine as
the build recipe (this repo) is public. See `NOTICE.md`.
