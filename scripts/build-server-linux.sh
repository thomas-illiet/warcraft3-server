#!/bin/sh
set -eu

version=${1:-dev}
case "$version" in ''|*[!0-9A-Za-z.-]*) printf 'Invalid version: %s\n' "$version" >&2; exit 2 ;; esac

repository_root=$(unset CDPATH; cd -- "$(dirname -- "$0")/.." && pwd)
artifact_root=$repository_root/artifacts/server/linux
package_root=$artifact_root/warcraft3-server
archive_path=$artifact_root/warcraft3-server-$version-linux-x64.tar.gz

command -v docker >/dev/null 2>&1 || { printf 'Docker with Buildx is required.\n' >&2; exit 1; }
rm -rf "$package_root"
mkdir -p "$package_root"

docker buildx build \
    --file "$repository_root/server/linux/build/Dockerfile" \
    --output "type=local,dest=$package_root" \
    "$repository_root"

docker run --rm --entrypoint /bin/sh \
    -v "$package_root:/package" debian:bookworm-slim \
    -c 'chmod 0755 /package/bin/bnetd /package/start-server.sh /package/scripts/*.sh && mkdir -p /package/data'

rm -f "$archive_path"
tar -czf "$archive_path" -C "$package_root" .
printf 'Linux server archive created: %s\n' "$archive_path"
