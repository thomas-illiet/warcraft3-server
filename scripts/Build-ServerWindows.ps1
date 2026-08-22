[CmdletBinding()]
param(
    [Parameter()]
    [ValidatePattern('^[0-9A-Za-z][0-9A-Za-z.-]*$')]
    [string]$Version = 'dev',

    [Parameter()]
    [switch]$Archive,

    [Parameter()]
    [string]$VcpkgRoot = $env:VCPKG_INSTALLATION_ROOT
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $repositoryRoot 'sources/pvpgn-server'
$buildRoot = Join-Path $repositoryRoot 'build/windows-pvpgn'
$installRoot = Join-Path $repositoryRoot 'build/windows-install'
$artifactRoot = Join-Path $repositoryRoot 'artifacts/server/windows'
$packageRoot = Join-Path $artifactRoot 'warcraft3-server'

foreach ($command in @('cmake', 'git')) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) { throw "$command is required." }
}
if (-not $VcpkgRoot) { throw 'VcpkgRoot or VCPKG_INSTALLATION_ROOT is required.' }
$toolchain = Join-Path $VcpkgRoot 'scripts/buildsystems/vcpkg.cmake'
if (-not (Test-Path -LiteralPath $toolchain)) { throw "Vcpkg toolchain not found: $toolchain" }

& (Join-Path $VcpkgRoot 'vcpkg.exe') install zlib:x64-windows-static
if ($LASTEXITCODE -ne 0) { throw 'Could not install static zlib with vcpkg.' }

foreach ($path in @($buildRoot, $installRoot, $packageRoot)) {
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
}
New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null

& cmake -S $sourceRoot -B $buildRoot -A x64 `
    "-DCMAKE_TOOLCHAIN_FILE=$toolchain" `
    '-DVCPKG_TARGET_TRIPLET=x64-windows-static' `
    '-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded' `
    '-DCMAKE_POLICY_DEFAULT_CMP0091=NEW' `
    '-DWITH_WIN32_GUI=OFF' '-DWITH_BNETD=ON' '-DWITH_D2CS=OFF' '-DWITH_D2DBS=OFF' `
    '-DWITH_LUA=OFF' '-DWITH_MYSQL=OFF' '-DWITH_SQLITE3=OFF' '-DWITH_PGSQL=OFF' '-DWITH_ODBC=OFF'
if ($LASTEXITCODE -ne 0) { throw 'Could not configure the Windows server build.' }
& cmake --build $buildRoot --config Release --parallel
if ($LASTEXITCODE -ne 0) { throw 'Could not build the Windows server.' }
& cmake --install $buildRoot --config Release --prefix $installRoot
if ($LASTEXITCODE -ne 0) { throw 'Could not install the Windows server staging tree.' }

foreach ($directory in @('bin', 'config/base', 'files', 'data', 'scripts')) {
    New-Item -ItemType Directory -Path (Join-Path $packageRoot $directory) -Force | Out-Null
}
Copy-Item -LiteralPath (Join-Path $installRoot 'bnetd.exe') -Destination (Join-Path $packageRoot 'bin/bnetd.exe')
Copy-Item -Path (Join-Path $installRoot 'conf/*') -Destination (Join-Path $packageRoot 'config/base') -Recurse -Force
Copy-Item -Path (Join-Path $installRoot 'var/files/*') -Destination (Join-Path $packageRoot 'files') -Recurse -Force
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'server/common/versioncheck.json') -Destination (Join-Path $packageRoot 'config/base/versioncheck.json') -Force
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'server/common/.env.example') -Destination (Join-Path $packageRoot '.env.example')
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'server/windows/Start-Server.ps1') -Destination $packageRoot
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'server/windows/Configure-PvPGN.ps1') -Destination (Join-Path $packageRoot 'scripts')
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'server/windows/Set-Admin.ps1') -Destination (Join-Path $packageRoot 'scripts')
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'server/windows/README.md') -Destination $packageRoot
Copy-Item -LiteralPath (Join-Path $sourceRoot 'LICENSE') -Destination (Join-Path $packageRoot 'LICENSE-PvPGN')

if ($Archive) {
    $archivePath = Join-Path $artifactRoot "warcraft3-server-$Version-windows-x64.zip"
    if (Test-Path -LiteralPath $archivePath) { Remove-Item -LiteralPath $archivePath -Force }
    Compress-Archive -Path (Join-Path $packageRoot '*') -DestinationPath $archivePath -CompressionLevel Optimal
    Write-Output "Windows server archive created: $archivePath"
}
