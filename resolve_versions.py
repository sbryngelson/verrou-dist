#!/usr/bin/env python3
"""Resolve the Valgrind version a Verrou checkout targets.

Verrou DRIVES the pairing - Valgrind FOLLOWS - so we never bump Valgrind ahead of
what Verrou supports. We read Verrou's own authoritative declarations of the
Valgrind release it targets and require them to agree on a single version (never
guess). Multiple independent signals are consulted for robustness against any one
of them being renamed/moved upstream:

  1. ``docker/Dockerfile``  - ``ARG VALGRIND_VERSION=<x.y.z>`` (primary; this is
     the version Verrou's own CI builds against).
  2. ``README.md``         - the documented ``valgrind-<x.y.z>+verrou-dev`` /
     ``VALGRIND_<x>_<y>_<z>`` clone instructions.
  3. ``valgrind.<x.y.z>.diff`` patch filename (legacy: Verrou used to encode the
     version here before it renamed the patch to plain ``valgrind.diff``).

Usage:  resolve_versions.py <verrou_checkout_dir>
Prints: VALGRIND_VERSION=<x.y.z>
Exits 1 (loudly) if a unique version can't be determined - never guesses.
"""

import glob
import os
import re
import sys


def _from_patch_filenames(verrou_dir: str) -> set:
    # Legacy signal: Verrou shipped valgrind.<version>.diff. Newer checkouts ship
    # plain valgrind.diff (no version), so this may legitimately find nothing.
    versions = set()
    for p in glob.glob(os.path.join(verrou_dir, "valgrind.*diff")):
        m = re.search(r"valgrind\.(\d+\.\d+\.\d+)\.", os.path.basename(p))
        if m:
            versions.add(m.group(1))
    return versions


def _from_dockerfile(verrou_dir: str) -> set:
    path = os.path.join(verrou_dir, "docker", "Dockerfile")
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except OSError:
        return set()
    # Only the ARG *default* pins the version: `ARG VALGRIND_VERSION=3.26.0`.
    # Bare re-declarations (`ARG VALGRIND_VERSION`) carry no value - skip them.
    return set(re.findall(r"^\s*ARG\s+VALGRIND_VERSION=(\d+\.\d+\.\d+)", text, re.M))


def _from_readme(verrou_dir: str) -> set:
    path = os.path.join(verrou_dir, "README.md")
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except OSError:
        return set()
    versions = set(re.findall(r"valgrind-(\d+\.\d+\.\d+)\+verrou-dev", text))
    versions |= {
        v.replace("_", ".") for v in re.findall(r"VALGRIND_(\d+_\d+_\d+)", text)
    }
    return versions


def resolve(verrou_dir: str) -> str:
    signals = {
        "docker/Dockerfile (ARG VALGRIND_VERSION)": _from_dockerfile(verrou_dir),
        "README.md (clone instructions)": _from_readme(verrou_dir),
        "valgrind.<ver>.diff filename (legacy)": _from_patch_filenames(verrou_dir),
    }
    versions = set().union(*signals.values())
    if len(versions) != 1:
        detail = "; ".join(f"{name} -> {sorted(v)}" for name, v in signals.items())
        raise SystemExit(
            f"Could not determine a unique Valgrind version from {verrou_dir} "
            f"(found versions {sorted(versions)}; signals: {detail}). "
            "Verrou's layout may have changed - resolve by hand."
        )
    return versions.pop()


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: resolve_versions.py <verrou_checkout_dir>")
    print(f"VALGRIND_VERSION={resolve(sys.argv[1])}")
