#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
    printf 'Usage: %s ACCOUNT_NAME\n' "$0" >&2
    exit 2
fi

case "$1" in ''|*[!A-Za-z0-9_\[\]-]*) printf 'Invalid account name.\n' >&2; exit 2 ;; esac
data_dir=${DATA_DIR:-$(unset CDPATH; cd -- "$(dirname -- "$0")/../data" && pwd)}
account_file=$data_dir/users/$1
[ -f "$account_file" ] || { printf 'Account not found: %s\n' "$1" >&2; exit 1; }

if grep -q '^"BNET\\\\auth\\\\admin"=' "$account_file"; then
    sed -i 's/^"BNET\\\\auth\\\\admin"=.*/"BNET\\\\auth\\\\admin"="true"/' "$account_file"
else
    printf '\n"BNET\\\\auth\\\\admin"="true"\n' >> "$account_file"
fi
printf 'Account %s is now an administrator. Restart the server if it is running.\n' "$1"
