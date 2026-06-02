# verrou-dist

Prebuilt [Verrou](https://github.com/edf-hpc/verrou) (the Valgrind floating-point
perturbation tool): a pinned **Valgrind + Verrou** pair, built once per arch and
published as hash-verified artifacts so you can install it in seconds instead of a
~20-min source build. Used by [MFC](https://github.com/MFlowCode/MFC)'s `./mfc.sh fp-stability`.

Linux only. x86_64 is validated; aarch64 is published but experimental.

## Install a release

```sh
ver=v1; arch=$(uname -m)
base=verrou-a58d434-valgrind-3.26.0-linux-$arch.tar.zst
url=https://github.com/sbryngelson/verrou-dist/releases/download/$ver
curl -fsSLO $url/$base && curl -fsSLO $url/$base.sha256 && sha256sum -c $base.sha256
mkdir -p ~/.local/verrou && tar -C ~/.local/verrou --zstd -xf $base
source ~/.local/verrou/env.sh        # sets VALGRIND_LIB + PYTHONPATH (relocatable)
valgrind --tool=verrou --version
```

`source env.sh` is required: Valgrind bakes its build prefix into the binary, so a
relocated tree can't find its tool without it.

## Build from source

```sh
bash build.sh --prefix ~/.local/verrou
```

## How it stays current

The pin lives in `versions.env`. Verrou ships a patch against a *specific* Valgrind
release, so Valgrind's version is derived from Verrou (`resolve_versions.py`), never
chosen independently. `watch.yml` opens a weekly bump PR; `build-test.yml` builds +
smoke-tests both arches and labels the PR `conflict` if the pair doesn't work;
releases are cut by a human merging that PR and pushing a `v*` tag.

## License

Tooling here is MIT (`LICENSE`). The published artifacts are GPL (Valgrind GPL-2.0,
Verrou GPL-3.0) — see `NOTICE.md`.
