#!/usr/bin/env bash
# Check staged macOS binaries: arch, system-only libraries, minimum macOS, valid signature.
# Usage: check-macos.sh <stage_dir> <arch: arm64|x86_64>
set -euo pipefail
stage=$1 arch=$2
for b in "$stage"/bin/*; do
  echo "--- $b"
  file "$b"
  [ "$(lipo -archs "$b")" = "$arch" ] || { echo "$b is $(lipo -archs "$b"), want $arch" >&2; exit 1; }
  otool -L "$b"
  # Anything outside /usr/lib and /System would not exist on a user's Mac.
  bad=$(otool -L "$b" | tail -n +2 | awk '{print $1}' | grep -vE '^/(usr/lib|System)/' || true)
  [ -z "$bad" ] || { echo "non-system libraries: $bad" >&2; exit 1; }
  minos=$(otool -l "$b" | awk '/LC_BUILD_VERSION/ {f=1} f && $1 == "minos" {print $2; exit}')
  echo "minos $minos"
  [ "$minos" = 11.0 ] || { echo "minos $minos, want 11.0" >&2; exit 1; }
  codesign -v --strict "$b"
  echo "codesign ok"
done
