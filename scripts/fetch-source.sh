#!/usr/bin/env bash
# Download Valkey's tagged source archive and check it against a pinned sha256 and tag commit.
# Usage: fetch-source.sh <version> <sha256> <commit> <out_dir>
# The sha256 is the one valkey-io/valkey-hashes publishes for the archive.
set -euo pipefail
ver=$1 sha=$2 commit=$3 out=$4

tmp=$(mktemp -d)
url=https://github.com/valkey-io/valkey/archive/refs/tags/$ver.tar.gz
curl -fsSL --retry 5 --retry-all-errors -o "$tmp/src.tar.gz" "$url"
echo "$sha  $tmp/src.tar.gz" | shasum -a 256 -c

# GitHub's archive carries the commit it was made from (git get-tar-commit-id).
# git reads only the first header, so gzip dies of SIGPIPE: ignore its status.
got=$( (gzip -dc "$tmp/src.tar.gz" || true) | git get-tar-commit-id)
[ "$got" = "$commit" ] || { echo "archive is commit $got, want $commit" >&2; exit 1; }
echo "tag $ver is commit $got"

rm -rf "$out"; mkdir -p "$out"
tar -xzf "$tmp/src.tar.gz" -C "$out" --strip-components 1
