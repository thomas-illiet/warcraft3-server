[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent $PSCommandPath
& (Join-Path $packageRoot 'scripts/Configure-PvPGN.ps1') -PackageRoot $packageRoot
& (Join-Path $packageRoot 'bin/bnetd.exe') --foreground "--config=$(Join-Path $packageRoot 'runtime/conf/bnetd.conf')"
exit $LASTEXITCODE
