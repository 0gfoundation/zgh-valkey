#!/usr/bin/env bash
# Write Valkey's COPYING plus one notice per directory under deps/ into <out_dir>.
# Usage: licenses.sh <src_dir> <out_dir>
# A dep dir with no licence file and no known source header fails the build.
set -euo pipefail
src=$1 out=$2

# Deps whose notice lives only in a source file's header comment.
header_file() {
  case "$1" in
    linenoise) echo linenoise.c ;;
    fast_float) echo fast_float.h ;;
    fast_float_c_interface) echo fast_float_strtod.cpp ;;
    *) return 1 ;;
  esac
}

# The file's leading comment: a /* ... */ block or a run of // lines.
leading_comment() {
  awk 'NR == 1 && /^\/\*/ { mode = "block" }
       NR == 1 && /^\/\//  { mode = "line" }
       mode == "block" { print; if (/\*\//) exit; next }
       mode == "line"  { if (/^\/\//) { print; next } exit }
       { exit }' "$1"
}

rm -rf "$out"; mkdir -p "$out/deps"
cp "$src/COPYING" "$out/COPYING"

for d in "$src"/deps/*/; do
  name=$(basename "$d")
  notice=$out/deps/$name.txt
  files=$(find "$d" -maxdepth 1 -type f \( -iname 'licen[cs]e*' -o -iname 'copying*' -o -iname 'copyright*' \) | LC_ALL=C sort)
  if [ -n "$files" ]; then
    for f in $files; do
      printf '==> deps/%s/%s <==\n\n' "$name" "$(basename "$f")"
      cat "$f"; echo
    done > "$notice"
  elif hf=$(header_file "$name") && [ -f "$d/$hf" ]; then
    { printf '==> header of deps/%s/%s <==\n\n' "$name" "$hf"; leading_comment "$d/$hf"; } > "$notice"
    grep -qiE 'copyright|licen[cs]e' "$notice" \
      || { echo "deps/$name/$hf header has no licence or copyright" >&2; exit 1; }
  else
    echo "deps/$name has no licence file and no known source header" >&2; exit 1
  fi
done
ls -l "$out" "$out/deps"
