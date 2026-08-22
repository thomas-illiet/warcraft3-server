#!/bin/sh
set -eu

repository_root=$(unset CDPATH; cd -- "$(dirname -- "$0")/.." && pwd)
package_root=$repository_root/artifacts/server/linux/warcraft3-server
container=warcraft3-linux-smoke-$$

[ -x "$package_root/bin/bnetd" ] || { printf 'Build the Linux package before running this test.\n' >&2; exit 1; }
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; }
trap cleanup EXIT INT TERM

docker run -d --name "$container" --volume "$package_root:/package" --workdir /package \
    debian:bookworm-slim ./start-server.sh >/dev/null
attempt=0
until docker exec "$container" sh -c 'grep -q "listening for bnet connections on 0.0.0.0:6112 TCP" /package/data/bnetd.log 2>/dev/null'; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge 20 ]; then docker logs "$container"; exit 1; fi
    sleep 1
done
docker exec "$container" sh -c 'test -w /package/data && test -f /package/runtime/conf/bnetd.conf'
printf 'Portable Linux server smoke test passed.\n'
