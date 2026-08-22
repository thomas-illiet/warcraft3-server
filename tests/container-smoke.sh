#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
suffix=$$
image=warcraft3-server:smoke-$suffix
container=warcraft3-server-smoke-$suffix
volume=warcraft3-server-smoke-data-$suffix

cleanup() {
    docker rm -f "$container" >/dev/null 2>&1 || true
    docker volume rm "$volume" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

docker build --file "$repository_root/server/docker/Dockerfile" --tag "$image" "$repository_root"
docker volume create "$volume" >/dev/null
docker run -d --name "$container" \
    --read-only --user 10001:10001 --cap-drop ALL --security-opt no-new-privileges:true \
    --tmpfs /run/pvpgn:rw,noexec,nosuid,nodev,size=16m,uid=10001,gid=10001,mode=0700 \
    --volume "$volume:/var/lib/pvpgn" "$image" >/dev/null

attempt=0
until docker exec "$container" nc -z 127.0.0.1 6112; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge 20 ]; then
        docker logs "$container"
        exit 1
    fi
    sleep 1
done

[ "$(docker inspect --format '{{.Config.User}}' "$container")" = '10001:10001' ]
[ "$(docker inspect --format '{{.HostConfig.ReadonlyRootfs}}' "$container")" = 'true' ]
[ "$(docker exec "$container" sh -c 'printf "%s:%s" "$(id -u)" "$(id -g)"')" = '10001:10001' ]
docker exec "$container" touch /rootfs-write-test >/dev/null 2>&1 && exit 1
docker exec "$container" sh -c 'printf persistent > /var/lib/pvpgn/smoke-marker'

docker rm -f "$container" >/dev/null
docker run -d --name "$container" \
    --read-only --user 10001:10001 --cap-drop ALL --security-opt no-new-privileges:true \
    --tmpfs /run/pvpgn:rw,noexec,nosuid,nodev,size=16m,uid=10001,gid=10001,mode=0700 \
    --volume "$volume:/var/lib/pvpgn" "$image" >/dev/null
sleep 2
[ "$(docker exec "$container" cat /var/lib/pvpgn/smoke-marker)" = 'persistent' ]
printf 'Container hardening and persistence smoke test passed.\n'
