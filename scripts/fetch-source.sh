#!/usr/bin/env bash
# Download Valkey's tagged source archive and check it against a pinned sha256 and tag commit.
# Usage: fetch-source.sh <version> <sha256> <commit> <out.tar.gz>
# The sha256 is the one valkey-io/valkey-hashes publishes for the archive.
set -euo pipefail
ver=$1 sha=$2 commit=$3 out=$4

url=https://github.com/valkey-io/valkey/archive/refs/tags/$ver.tar.gz
curl -fsSL --retry 5 --retry-all-errors -o "$out" "$url"
echo "$sha  $out" | shasum -a 256 -c

# GitHub's archive carries the commit it was made from (git get-tar-commit-id).
# git reads only the first header, so gzip dies of SIGPIPE: ignore its status.
got=$( (gzip -dc "$out" || true) | git get-tar-commit-id)
[ "$got" = "$commit" ] || { echo "archive is commit $got, want $commit" >&2; exit 1; }
echo "tag $ver is commit $got"
