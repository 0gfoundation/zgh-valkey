#!/usr/bin/env bash
# Check staged Linux binaries: arch, glibc-only libraries; print the highest GLIBC symbol version.
# Usage: check-linux.sh <stage_dir> <arch as `file` names it: x86-64|aarch64>
set -euo pipefail
stage=$1 arch=$2
max=
for b in "$stage"/bin/*; do
  echo "--- $b"
  file "$b" | tee /dev/stderr | grep -q "$arch" || { echo "$b is not $arch" >&2; exit 1; }
  ldd "$b"
  # Only glibc's own libraries (and the vDSO, which has no file).
  bad=$(ldd "$b" | awk '{print $1}' \
    | grep -vE '^(linux-vdso\.so|libc\.so|libm\.so|libpthread\.so|libdl\.so|librt\.so|/lib(64)?/ld-linux|ld-linux)' || true)
  [ -z "$bad" ] || { echo "non-glibc libraries: $bad" >&2; exit 1; }
  v=$(objdump -T "$b" | grep -oE 'GLIBC_[0-9.]+' | sed 's/GLIBC_//' | sort -uV | tail -1)
  echo "max GLIBC: $v"
  max=$(printf '%s\n%s\n' "$max" "$v" | sort -V | tail -1)
done
echo "max GLIBC over all binaries: GLIBC_$max"
