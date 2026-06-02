# Notice

This repository contains **build and packaging tooling only**. The software it
downloads, builds, and redistributes as release artifacts is third-party and
under its own licenses:

- **Valgrind** — GPL-2.0 — https://valgrind.org
- **Verrou** (edf-hpc/verrou) — GPL-3.0 — https://github.com/edf-hpc/verrou

Prebuilt artifacts published by this repository's releases are therefore covered
by those licenses. Their complete corresponding source is the upstream projects at
the pinned versions in `versions.env`, plus the patch shipped in the Verrou repo;
this repository's `build.sh` documents exactly how the binaries are produced.

The original scripts, workflows, and `resolve_versions.py` in this repository are
licensed under the MIT License (see `LICENSE`).
