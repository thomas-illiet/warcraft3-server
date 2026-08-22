#!/bin/sh
set -eu

[ "$(id -u)" -eq 10001 ] || { printf 'Refusing to start: expected UID 10001, got %s.\n' "$(id -u)" >&2; exit 1; }
[ "$(id -g)" -eq 10001 ] || { printf 'Refusing to start: expected GID 10001, got %s.\n' "$(id -g)" >&2; exit 1; }
[ -w /var/lib/pvpgn ] || { printf 'Refusing to start: /var/lib/pvpgn is not writable by UID 10001. Fix the volume ownership; the container will not fall back to root.\n' >&2; exit 1; }
[ -w /run/pvpgn ] || { printf 'Refusing to start: /run/pvpgn is not writable by UID 10001. Check the tmpfs uid/gid options.\n' >&2; exit 1; }

export PACKAGE_ROOT=/opt/pvpgn
export CONFIG_SOURCE=/opt/pvpgn/config/base
export RUNTIME_DIR=/run/pvpgn
export DATA_DIR=/var/lib/pvpgn
export FILES_DIR=/opt/pvpgn/files
export ENV_FILE=/nonexistent

/usr/local/lib/pvpgn/configure-pvpgn.sh
exec /usr/local/bin/bnetd --foreground --config=/run/pvpgn/conf/bnetd.conf
