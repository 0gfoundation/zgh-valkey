#!/usr/bin/env bash
# Tar a stage dir into <out>, files in sorted order.
# Usage: package.sh <stage_dir> <out.tar.gz>
set -euo pipefail
stage=$1 out=$2
list=$(mktemp)
(cd "$stage" && find . -type f | sed 's|^\./||' | LC_ALL=C sort) > "$list"
tar -czf "$out" -C "$stage" -T "$list"
tar -tzvf "$out"
