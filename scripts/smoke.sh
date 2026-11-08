#!/usr/bin/env bash
# Unpack a tarball fresh and run its valkey-server on a unix socket:
# HELLO 3, SET/GET, then restart on the same dir and read the key back from the AOF.
# Usage: smoke.sh <tarball> <version>
set -euo pipefail
tarball=$(cd "$(dirname "$1")" && pwd)/$(basename "$1") ver=$2

# Short dir: macOS caps a socket path below 104 bytes, and $TMPDIR there is long.
work=$(mktemp -d /tmp/vk.XXXXXX)
pid=
cleanup() {
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then kill "$pid"; wait "$pid" || true; fi
  rm -rf "$work"
}
trap cleanup EXIT

mkdir "$work/pkg" "$work/data"
tar -xzf "$tarball" -C "$work/pkg"
srv=$work/pkg/bin/valkey-server cli=$work/pkg/bin/valkey-cli sock=$work/s
for f in "$srv" "$cli" "$work/pkg/licenses/COPYING"; do [ -f "$f" ] || { echo "missing $f" >&2; exit 1; }; done

"$srv" --version
"$srv" --version | grep -q "v=$ver " || { echo "valkey-server is not $ver" >&2; exit 1; }

c() { "$cli" -s "$sock" "$@"; }

start() {
  "$srv" --port 0 --unixsocket "$sock" --unixsocketperm 700 --dir "$work/data" \
    --appendonly yes --save "" --logfile "$work/server.log" &
  pid=$!
  for _ in $(seq 100); do
    [ "$(c PING 2>/dev/null)" = PONG ] && return 0
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.1
  done
  cat "$work/server.log" >&2; echo "server did not come up" >&2; exit 1
}

stop() {
  c SHUTDOWN >/dev/null 2>&1 || true
  wait "$pid" || { cat "$work/server.log" >&2; echo "server exited non-zero" >&2; exit 1; }
  pid=
}

start
# valkey-cli prints a RESP3 map one "key value" pair per line (RESP2 would print them on alternate lines).
proto=$(c HELLO 3 | awk '$1 == "proto" {print $2; exit}')
echo "HELLO 3 proto: $proto"
[ "$proto" = 3 ] || { c HELLO 3 >&2; echo "HELLO 3 did not switch to RESP3" >&2; exit 1; }
[ "$(c SET zgh:smoke hello)" = OK ] || { echo "SET failed" >&2; exit 1; }
[ "$(c GET zgh:smoke)" = hello ] || { echo "GET failed" >&2; exit 1; }
stop

ls "$work/data/appendonlydir"
start
got=$(c GET zgh:smoke)
echo "after restart: $got"
[ "$got" = hello ] || { cat "$work/server.log" >&2; echo "key not restored from AOF" >&2; exit 1; }
stop
echo "smoke ok: $(basename "$tarball")"
