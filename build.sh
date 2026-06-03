#!/bin/bash
#
# Canonical builder for Valgrind + Verrou. Reads the pinned versions from
# versions.env, builds from source, and installs into a prefix. Used by the
# repo's CI (build-test, release) AND consumable directly by downstreams
# (e.g. MFC's bootstrap) as the one source of truth for the build recipe.
#
#   bash build.sh [--prefix DIR] [--force]
#
# Default prefix: $VERROU_HOME or ~/.local/verrou.
# Linux only (Valgrind has no modern-macOS support); x86_64 best-validated,
# aarch64 builds but Verrou's FP backends are less battle-tested there.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$here/versions.env"

PREFIX="${VERROU_HOME:-$HOME/.local/verrou}"
FORCE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --prefix) PREFIX="$2"; shift 2 ;;
        --force) FORCE=1; shift ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
done

echo "==> Valgrind ${VALGRIND_VERSION} + edf-hpc/verrou@${VERROU_COMMIT} -> ${PREFIX}"

if [ -z "$FORCE" ] && [ -x "${PREFIX}/bin/valgrind" ] && "${PREFIX}/bin/valgrind" --tool=verrou --version >/dev/null 2>&1; then
    echo "==> Already installed at ${PREFIX} (use --force to rebuild)."
    exit 0
fi

if [ "$(uname -s)" != "Linux" ]; then
    echo "ERROR: Linux required (Valgrind does not support modern macOS / Apple Silicon)." >&2
    exit 1
fi
case "$(uname -m)" in
    x86_64) ;;
    aarch64|arm64) echo "WARNING: $(uname -m) - Verrou FP backends are best-validated on x86_64; treat as experimental." >&2 ;;
    *) echo "WARNING: unrecognised arch $(uname -m); build may fail." >&2 ;;
esac

missing=""
for t in tar git make patch autoconf automake; do command -v "$t" >/dev/null 2>&1 || missing="$missing $t"; done
command -v cc >/dev/null 2>&1 || command -v gcc >/dev/null 2>&1 || missing="$missing gcc"
command -v wget >/dev/null 2>&1 || command -v curl >/dev/null 2>&1 || missing="$missing wget/curl"
[ -n "$missing" ] && { echo "ERROR: missing build deps:$missing (apt: build-essential automake autoconf libtool patch)" >&2; exit 1; }

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT; cd "$work"

tarball="valgrind-${VALGRIND_VERSION}.tar.bz2"
url="https://sourceware.org/pub/valgrind/${tarball}"
echo "==> Downloading ${tarball}"
if command -v wget >/dev/null 2>&1; then wget -q "$url"; else curl -fsSL -o "$tarball" "$url"; fi

if [ -n "${VALGRIND_SHA256:-}" ]; then
    echo "==> Verifying SHA-256"
    echo "${VALGRIND_SHA256}  ${tarball}" | sha256sum -c -
fi
tar xf "$tarball"

echo "==> Cloning Verrou @ ${VERROU_COMMIT}"
git clone --quiet https://github.com/edf-hpc/verrou.git
git -C verrou checkout --quiet "$VERROU_COMMIT"

cp -r verrou "valgrind-${VALGRIND_VERSION}/verrou"
cd "valgrind-${VALGRIND_VERSION}"
echo "==> Applying Verrou patch (a failure here = version conflict)"
cat verrou/valgrind.*diff | patch -p1

echo "==> Building (~20 min)"
./autogen.sh
./configure --enable-only64bit --prefix="$PREFIX"
make -j"$(nproc)"
make install

# Valgrind bakes its install prefix into the binary (VG_LIBDIR), so a prebuilt
# tree extracted elsewhere can't find its tools. Verrou's stock env.sh hardcodes
# the build prefix too. Overwrite it with a self-locating one so the artifact is
# relocatable: sourcing it sets VALGRIND_LIB (the tool loader) + PYTHONPATH (the
# verrou_dd_* drivers) relative to wherever the tree actually lives.
echo "==> Writing relocatable env.sh"
cat > "${PREFIX}/env.sh" <<'ENVEOF'
# Relocatable environment for this Valgrind+Verrou install (verrou-dist).
# Usage:  source /path/to/env.sh   - then valgrind --tool=verrou and verrou_dd_* work from any path.
_vd_root="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd)"
export VALGRIND_LIB="${_vd_root}/libexec/valgrind"
export PATH="${_vd_root}/bin:${PATH}"
export LD_LIBRARY_PATH="${_vd_root}/lib/valgrind${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
for _vd_pp in "${_vd_root}"/lib/python*/site-packages; do
    [ -d "${_vd_pp}" ] && export PYTHONPATH="${_vd_pp}:${_vd_pp}/valgrind${PYTHONPATH:+:${PYTHONPATH}}"
done
unset _vd_root _vd_pp
ENVEOF

echo "==> Verifying"
"${PREFIX}/bin/valgrind" --tool=verrou --version
echo "==> Done: ${PREFIX}"
