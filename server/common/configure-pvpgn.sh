#!/bin/sh
set -eu

package_root=${PACKAGE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}
config_source=${CONFIG_SOURCE:-$package_root/config/base}
runtime_dir=${RUNTIME_DIR:-$package_root/runtime}
data_dir=${DATA_DIR:-$package_root/data}
files_dir=${FILES_DIR:-$package_root/files}
env_file=${ENV_FILE:-$package_root/.env}

read_environment() {
    [ -f "$env_file" ] || return 0
    while IFS='=' read -r key value; do
        case "$key" in
            ''|'#'*) continue ;;
            SERVER_NAME|PUBLIC_IP|LAN_CIDR|LOCAL_HOST_IP|MAX_ACCOUNTS|TZ)
                value=$(printf '%s' "$value" | sed 's/^"//;s/"$//')
                export "$key=$value"
                ;;
            *) printf 'Ignoring unknown setting in %s: %s\n' "$env_file" "$key" >&2 ;;
        esac
    done < "$env_file"
}

fail() {
    printf 'Configuration error: %s\n' "$1" >&2
    exit 1
}

replace_setting() {
    key=$1
    value=$2
    escaped=$(printf '%s' "$value" | sed 's/[\\&|]/\\&/g')
    if grep -Eq "^[[:space:]]*$key[[:space:]]*=" "$runtime_dir/conf/bnetd.conf"; then
        sed -i -E "s|^[[:space:]]*$key[[:space:]]*=.*|$key = $escaped|" "$runtime_dir/conf/bnetd.conf"
    else
        printf '%s = %s\n' "$key" "$value" >> "$runtime_dir/conf/bnetd.conf"
    fi
}

read_environment
: "${SERVER_NAME:=Warcraft III Server}"
: "${PUBLIC_IP:=127.0.0.1}"
: "${LAN_CIDR:=192.168.0.0/16}"
: "${LOCAL_HOST_IP:=127.0.0.1}"
: "${MAX_ACCOUNTS:=1000}"
: "${TZ:=UTC}"

case "$SERVER_NAME" in *\"*) fail 'SERVER_NAME must not contain a double quote.' ;; esac
printf '%s' "$PUBLIC_IP" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$' || fail 'PUBLIC_IP must be an IPv4 address.'
printf '%s' "$LOCAL_HOST_IP" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$' || fail 'LOCAL_HOST_IP must be an IPv4 address.'
printf '%s' "$LAN_CIDR" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[12][0-9]|3[0-2])$' || fail 'LAN_CIDR must be an IPv4 CIDR.'
printf '%s' "$MAX_ACCOUNTS" | grep -Eq '^[0-9]+$' || fail 'MAX_ACCOUNTS must be a non-negative integer.'
[ -r "$config_source/bnetd.conf" ] || fail "Base configuration is missing at $config_source."
[ -d "$data_dir" ] || fail "Data directory is missing at $data_dir."
[ -w "$data_dir" ] || fail "Data directory is not writable by UID $(id -u)."

mkdir -p "$runtime_dir/conf" "$data_dir/users" "$data_dir/clans" "$data_dir/teams" \
    "$data_dir/reports" "$data_dir/chanlogs" "$data_dir/userlogs" "$data_dir/bnmail" \
    "$data_dir/ladders" "$data_dir/status"
rm -rf "$runtime_dir/conf"/*
cp -R "$config_source"/. "$runtime_dir/conf/"

replace_setting servername "\"$SERVER_NAME\""
replace_setting storage_path "\"file:mode=plain;dir=$data_dir/users;clan=$data_dir/clans;team=$data_dir/teams;default=$runtime_dir/conf/bnetd_default_user.plain\""
replace_setting filedir "\"$files_dir\""
replace_setting reportdir "\"$data_dir/reports\""
replace_setting chanlogdir "\"$data_dir/chanlogs\""
replace_setting userlogdir "\"$data_dir/userlogs\""
replace_setting logfile "\"$data_dir/bnetd.log\""
replace_setting maildir "\"$data_dir/bnmail\""
replace_setting ladderdir "\"$data_dir/ladders\""
replace_setting statusdir "\"$data_dir/status\""
replace_setting i18ndir "\"$runtime_dir/conf/i18n\""
replace_setting issuefile "\"$runtime_dir/conf/bnissue.txt\""
replace_setting channelfile "\"$runtime_dir/conf/channel.conf\""
replace_setting adfile "\"$runtime_dir/conf/ad.json\""
replace_setting topicfile "\"$runtime_dir/conf/topics.conf\""
replace_setting ipbanfile "\"$runtime_dir/conf/bnban.conf\""
replace_setting mpqfile "\"$runtime_dir/conf/autoupdate.conf\""
replace_setting realmfile "\"$runtime_dir/conf/realm.conf\""
replace_setting versioncheck_file "\"$runtime_dir/conf/versioncheck.json\""
replace_setting mapsfile "\"$runtime_dir/conf/bnmaps.conf\""
replace_setting xplevelfile "\"$runtime_dir/conf/bnxplevel.conf\""
replace_setting xpcalcfile "\"$runtime_dir/conf/bnxpcalc.conf\""
replace_setting command_groups_file "\"$runtime_dir/conf/command_groups.conf\""
replace_setting tournament_file "\"$runtime_dir/conf/tournament.conf\""
replace_setting aliasfile "\"$runtime_dir/conf/bnalias.conf\""
replace_setting anongame_infos_file "\"$runtime_dir/conf/anongame_infos.conf\""
replace_setting DBlayoutfile "\"$runtime_dir/conf/sql_DB_layout.conf\""
replace_setting supportfile "\"$runtime_dir/conf/supportfile.conf\""
replace_setting transfile "\"$runtime_dir/conf/address_translation.conf\""
replace_setting customicons_file "\"$runtime_dir/conf/icons.conf\""
replace_setting allowed_clients 'war3,w3xp'
replace_setting allow_bad_version 'false'
replace_setting allow_unknown_version 'false'
replace_setting max_accounts "$MAX_ACCOUNTS"
replace_setting track '0'
replace_setting servaddrs '"0.0.0.0:6112"'
replace_setting w3routeaddr '"0.0.0.0:6200"'

cat > "$runtime_dir/conf/address_translation.conf" <<EOF
# Generated at startup. Local clients retain local addresses; other clients receive the public address.
0.0.0.0:6200 $PUBLIC_IP:6200 $LAN_CIDR ANY
$LOCAL_HOST_IP:6112 $PUBLIC_IP:6112 $LAN_CIDR ANY
EOF

export TZ
printf 'Generated PvPGN configuration for %s in %s.\n' "$SERVER_NAME" "$runtime_dir/conf"
