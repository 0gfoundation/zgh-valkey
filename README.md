# zgh-valkey

[Valkey](https://github.com/valkey-io/valkey) server builds for
[zgh](https://github.com/0gfoundation/zgh)'s `:redis` plugin.

When no Redis URL is configured, zgh starts a local Valkey on a unix
socket. This repo builds `valkey-server` and `valkey-cli` and publishes
them as a GitHub release, one tarball per target. zgh downloads the
tarball for the running process's arch without a token, checks the
sha256 pinned in zgh's source, and unpacks it.

## Targets

| Target         | Built on                                         |
| -------------- | ------------------------------------------------ |
| `darwin-arm64` | `macos-15`                                       |
| `darwin-amd64` | `macos-15-intel` (native Intel runner, no cross-compile) |
| `linux-amd64`  | `debian:bullseye` (glibc 2.31) on `ubuntu-latest` |
| `linux-arm64`  | `debian:bullseye` (glibc 2.31) on `ubuntu-24.04-arm` |

Every build:

- uses Valkey's tagged source archive, which the `source` job fetches
  once and checks against the sha256 that
  [valkey-io/valkey-hashes](https://github.com/valkey-io/valkey-hashes)
  publishes and against the tag's commit (`git get-tar-commit-id`);
- passes `BUILD_TLS=no USE_SYSTEMD=no`: zgh's server listens on a unix
  socket only;
- keeps Valkey's default allocator: jemalloc on Linux, libc on macOS;
- strips both binaries.

macOS builds set `MACOSX_DEPLOYMENT_TARGET=11.0` and are re-signed ad hoc
(`codesign -s -`) after `strip`, since arm64 macOS kills a binary whose
signature broke. `scripts/check-macos.sh` fails the build unless each
binary has the target's arch, `otool -L` lists only `/usr/lib` and
`/System` libraries, `minos` is 11.0 and `codesign -v` passes.

Linux builds run in `debian:bullseye`, so they need no newer glibc than
2.31. Bullseye is past its end of life, so the build installs its
compiler from `archive.debian.org`. `scripts/check-linux.sh` fails the build unless each binary has the
target's arch and `ldd` lists only glibc's own libraries (libc, libm,
libpthread, libdl, librt, the loader); it prints the highest `GLIBC_`
symbol version the binaries need (`GLIBC_2.29` for 9.0.7).

## Release assets

Release `valkey-<version>` holds `SHA256SUMS` and, per target,
`valkey-<version>-<target>.tar.gz`, which unpacks to:

```
bin/valkey-cli
bin/valkey-server
licenses/COPYING          Valkey's licence (BSD-3-Clause)
licenses/deps/<dep>.txt   one notice per directory under the tag's deps/
```

`scripts/licenses.sh` writes `licenses/`. A dep's notice is its licence
files (`LICENSE*`, `COPYING*`, `COPYRIGHT*`); for a dep without one it is
the header comment of a named source file (`linenoise`, `fast_float`,
`fast_float_c_interface`). A new dep with neither fails the build: name
its notice in the script.

## Smoke test

Before publishing, each target's job unpacks its tarball into a fresh
`/tmp` dir and runs `scripts/smoke.sh`:

1. `valkey-server --version` names the version built;
2. start `valkey-server` with `port 0`, a unix socket in that short dir
   (macOS caps socket paths below 104 bytes), `appendonly yes`,
   `save ""`;
3. `valkey-cli -s` sends `HELLO 3` (the reply's `proto` is 3), then
   `SET` and `GET`;
4. `SHUTDOWN`, start again on the same dir, and `GET` the key back from
   the AOF.

The release job runs only when all four targets pass.

## Cutting a new version

Take the new tag's archive sha256 from valkey-hashes and its commit
(`gh api repos/valkey-io/valkey/git/ref/tags/<version>`), then Actions →
**build** → Run workflow, or:

```sh
gh workflow run build.yml -R 0gfoundation/zgh-valkey \
  -f valkey_version=9.0.7 \
  -f valkey_sha256=ba3e4cd0fb90e994323212b4a49e7e454e25e02864b9b3f1bf04416699d3f5c2 \
  -f valkey_commit=fe8d406c0b5a64ec897f6455e4de684629883764
```

Only a run from `main` publishes; a run from another branch
(`--ref <branch>`) builds and smoke-tests. The release job fails if the
release already exists: published assets never change, because zgh pins
their hashes. Then update the pins in zgh.

## License

`LICENSE` is Valkey's licence (BSD-3-Clause). Every tarball ships it as
`licenses/COPYING`, with its deps' notices.
