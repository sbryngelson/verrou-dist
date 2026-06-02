#!/usr/bin/env python3
"""Resolve the Valgrind version a Verrou checkout targets.

Verrou ships a patch named ``valgrind.<version>.diff`` that applies onto exactly
that Valgrind source. That filename is the authoritative pairing signal — Verrou
DRIVES, Valgrind FOLLOWS — so we never bump Valgrind ahead of what Verrou supports.

Usage:  resolve_versions.py <verrou_checkout_dir>
Prints: VALGRIND_VERSION=<x.y.z>
Exits 1 (loudly) if a unique version can't be determined — never guesses.
"""

import glob
import os
import re
import sys


def resolve(verrou_dir: str) -> str:
    patches = glob.glob(os.path.join(verrou_dir, "valgrind.*diff"))
    versions = set()
    for p in patches:
        m = re.search(r"valgrind\.(\d+\.\d+\.\d+)\.", os.path.basename(p))
        if m:
            versions.add(m.group(1))
    if len(versions) != 1:
        names = sorted(os.path.basename(p) for p in patches)
        raise SystemExit(
            f"Could not determine a unique Valgrind version from {verrou_dir} "
            f"(found versions {sorted(versions)}; patch files {names}). "
            "Verrou's layout may have changed — resolve by hand."
        )
    return versions.pop()


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: resolve_versions.py <verrou_checkout_dir>")
    print(f"VALGRIND_VERSION={resolve(sys.argv[1])}")
