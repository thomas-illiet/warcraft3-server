[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$PackageRoot
)

$ErrorActionPreference = 'Stop'

function Read-EnvironmentFile {
    param([string]$Path)
    $values = @{}
    if (-not (Test-Path -LiteralPath $Path)) { return $values }
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^\s*(?:#|$)') { continue }
        if ($line -notmatch '^([A-Z_]+)=(.*)$') { throw "Invalid .env line: $line" }
        if ($Matches[1] -notin @('SERVER_NAME', 'PUBLIC_IP', 'LAN_CIDR', 'LOCAL_HOST_IP', 'MAX_ACCOUNTS', 'TZ')) {
            Write-Warning "Ignoring unknown setting: $($Matches[1])"
            continue
        }
        $values[$Matches[1]] = $Matches[2].Trim('"')
    }
    return $values
}

function Set-ConfigurationValue {
    param([string]$Content, [string]$Name, [string]$Value)
    $pattern = "(?m)^\s*$([regex]::Escape($Name))\s*=.*$"
    $replacement = "$Name = $Value"
    if ([regex]::IsMatch($Content, $pattern)) {
        return [regex]::Replace($Content, $pattern, $replacement)
    }
    return "$Content`r`n$replacement`r`n"
}

$PackageRoot = [System.IO.Path]::GetFullPath($PackageRoot)
$values = Read-EnvironmentFile -Path (Join-Path $PackageRoot '.env')
$defaults = @{
    SERVER_NAME = 'Warcraft III Server'
    PUBLIC_IP = '127.0.0.1'
    LAN_CIDR = '192.168.0.0/16'
    LOCAL_HOST_IP = '127.0.0.1'
    MAX_ACCOUNTS = '1000'
    TZ = 'UTC'
}
foreach ($key in $defaults.Keys) {
    if (-not $values.ContainsKey($key)) { $values[$key] = $defaults[$key] }
}
if ($values.SERVER_NAME -match '[\r\n"]') { throw 'SERVER_NAME contains an invalid character.' }
foreach ($key in @('PUBLIC_IP', 'LOCAL_HOST_IP')) {
    $parsedAddress = $null
    if (-not [System.Net.IPAddress]::TryParse($values[$key], [ref]$parsedAddress) -or $parsedAddress.AddressFamily -ne 'InterNetwork') {
        throw "$key must be an IPv4 address."
    }
}
if ($values.LAN_CIDR -notmatch '^(?:\d{1,3}\.){3}\d{1,3}/(?:[0-9]|[12][0-9]|3[0-2])$') { throw 'LAN_CIDR must be an IPv4 CIDR.' }
if ($values.MAX_ACCOUNTS -notmatch '^\d+$') { throw 'MAX_ACCOUNTS must be a non-negative integer.' }

$configSource = Join-Path $PackageRoot 'config/base'
$runtimeConfig = Join-Path $PackageRoot 'runtime/conf'
$dataRoot = Join-Path $PackageRoot 'data'
if (-not (Test-Path -LiteralPath (Join-Path $configSource 'bnetd.conf'))) { throw 'The base PvPGN configuration is missing.' }
New-Item -ItemType Directory -Path $runtimeConfig -Force | Out-Null
New-Item -ItemType Directory -Path $dataRoot -Force | Out-Null
Get-ChildItem -LiteralPath $runtimeConfig -Force | Remove-Item -Recurse -Force
Copy-Item -Path (Join-Path $configSource '*') -Destination $runtimeConfig -Recurse -Force
foreach ($directory in @('users', 'clans', 'teams', 'reports', 'chanlogs', 'userlogs', 'bnmail', 'ladders', 'status')) {
    New-Item -ItemType Directory -Path (Join-Path $dataRoot $directory) -Force | Out-Null
}

function ConfigPath([string]$Path) { return ([System.IO.Path]::GetFullPath($Path) -replace '\\', '/') }
$conf = ConfigPath $runtimeConfig
$data = ConfigPath $dataRoot
$files = ConfigPath (Join-Path $PackageRoot 'files')
$content = Get-Content -LiteralPath (Join-Path $runtimeConfig 'bnetd.conf') -Raw
$settings = [ordered]@{
    servername = '"' + $values.SERVER_NAME + '"'
    storage_path = '"file:mode=plain;dir=' + $data + '/users;clan=' + $data + '/clans;team=' + $data + '/teams;default=' + $conf + '/bnetd_default_user.plain"'
    filedir = '"' + $files + '"'; reportdir = '"' + $data + '/reports"'; chanlogdir = '"' + $data + '/chanlogs"'
    userlogdir = '"' + $data + '/userlogs"'; logfile = '"' + $data + '/bnetd.log"'; maildir = '"' + $data + '/bnmail"'
    ladderdir = '"' + $data + '/ladders"'; statusdir = '"' + $data + '/status"'; i18ndir = '"' + $conf + '/i18n"'
    issuefile = '"' + $conf + '/bnissue.txt"'; channelfile = '"' + $conf + '/channel.conf"'; adfile = '"' + $conf + '/ad.json"'
    topicfile = '"' + $conf + '/topics.conf"'; ipbanfile = '"' + $conf + '/bnban.conf"'; mpqfile = '"' + $conf + '/autoupdate.conf"'
    realmfile = '"' + $conf + '/realm.conf"'; versioncheck_file = '"' + $conf + '/versioncheck.json"'; mapsfile = '"' + $conf + '/bnmaps.conf"'
    xplevelfile = '"' + $conf + '/bnxplevel.conf"'; xpcalcfile = '"' + $conf + '/bnxpcalc.conf"'; command_groups_file = '"' + $conf + '/command_groups.conf"'
    tournament_file = '"' + $conf + '/tournament.conf"'; aliasfile = '"' + $conf + '/bnalias.conf"'; anongame_infos_file = '"' + $conf + '/anongame_infos.conf"'
    DBlayoutfile = '"' + $conf + '/sql_DB_layout.conf"'; supportfile = '"' + $conf + '/supportfile.conf"'; transfile = '"' + $conf + '/address_translation.conf"'
    customicons_file = '"' + $conf + '/icons.conf"'; allowed_clients = 'war3,w3xp'; allow_bad_version = 'false'; allow_unknown_version = 'false'
    max_accounts = $values.MAX_ACCOUNTS; track = '0'; servaddrs = '"0.0.0.0:6112"'; w3routeaddr = '"0.0.0.0:6200"'
}
foreach ($setting in $settings.GetEnumerator()) { $content = Set-ConfigurationValue -Content $content -Name $setting.Key -Value $setting.Value }
[System.IO.File]::WriteAllText((Join-Path $runtimeConfig 'bnetd.conf'), $content, [System.Text.UTF8Encoding]::new($false))
$translation = @(
    '# Generated at startup. Local clients retain local addresses; other clients receive the public address.'
    "0.0.0.0:6200 $($values.PUBLIC_IP):6200 $($values.LAN_CIDR) ANY"
    "$($values.LOCAL_HOST_IP):6112 $($values.PUBLIC_IP):6112 $($values.LAN_CIDR) ANY"
) -join "`r`n"
[System.IO.File]::WriteAllText((Join-Path $runtimeConfig 'address_translation.conf'), "$translation`r`n", [System.Text.UTF8Encoding]::new($false))
$env:TZ = $values.TZ
Write-Output "Generated PvPGN configuration for $($values.SERVER_NAME)."
