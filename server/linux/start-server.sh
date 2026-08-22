#!/bin/sh
set -eu

package_root=$(unset CDPATH; cd -- "$(dirname -- "$0")" && pwd)
export PACKAGE_ROOT="$package_root"
export CONFIG_SOURCE="$package_root/config/base"
export RUNTIME_DIR="$package_root/runtime"
export DATA_DIR="$package_root/data"
export FILES_DIR="$package_root/files"
export ENV_FILE="$package_root/.env"

"$package_root/scripts/configure-pvpgn.sh"
exec "$package_root/bin/bnetd" --foreground --config="$RUNTIME_DIR/conf/bnetd.conf"
