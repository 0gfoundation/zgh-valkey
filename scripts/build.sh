#!/usr/bin/env bash
# Build valkey-server and valkey-cli from an unpacked source tree, and lay out the stage dir.
# Usage: build.sh <src_dir> <stage_dir>
# Runs on the macOS runner and inside the Linux container.
set -euo pipefail
src=$1 stage=$2
here=$(cd "$(dirname "$0")" && pwd)

case "$(uname -s)" in
  Darwin) export MACOSX_DEPLOYMENT_TARGET=11.0; jobs=$(sysctl -n hw.ncpu) ;;
  *) jobs=$(nproc) ;;
esac

# No TLS: zgh's server listens on a unix socket only. No systemd notify.
# MALLOC is Valkey's default: jemalloc on Linux, libc on macOS.
# Make src/ directly: the top-level Makefile runs one `make -C src` per goal, and with -j
# those race on building deps/.
make -C "$src/src" -j"$jobs" BUILD_TLS=no USE_SYSTEMD=no valkey-server valkey-cli \
  >"$src/build.log" 2>&1 || {
    # Under -j the failing compile can sit anywhere in the log: show compiler errors,
    # make's own failure lines, and the end of the log.
    grep -nE -A3 'error:|\*\*\*' "$src/build.log" | tail -n 120 || true  # no match must not skip the tail below
    echo "--- end of build.log"; tail -n 40 "$src/build.log"; exit 1
  }
grep -E '^MALLOC=|^BUILD_TLS=' "$src/src/.make-settings" || true

rm -rf "$stage"; mkdir -p "$stage/bin"
for b in valkey-server valkey-cli; do
  cp "$src/src/$b" "$stage/bin/$b"
  strip "$stage/bin/$b"
done
# strip breaks the linker's ad-hoc signature; arm64 macOS kills such a binary, so sign after.
if [ "$(uname -s)" = Darwin ]; then
  for b in "$stage"/bin/*; do codesign -f -s - "$b"; done
fi

"$here/licenses.sh" "$src" "$stage/licenses"
find "$stage" -type f | LC_ALL=C sort
