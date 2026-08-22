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
$artifactRoot = Join-Path $repositoryRoot 'artifacts/server/windows'
$packageRoot = Join-Path $artifactRoot 'warcraft3-server'

foreach ($command in @('cmake', 'git')) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) { throw "$command is required." }
}
if (-not $VcpkgRoot) { throw 'VcpkgRoot or VCPKG_INSTALLATION_ROOT is required.' }
$toolchain = Join-Path $VcpkgRoot 'scripts/buildsystems/vcpkg.cmake'
if (-not (Test-Path -LiteralPath $toolchain)) { throw "Vcpkg toolchain not found: $toolchain" }
$vcpkg = Join-Path $VcpkgRoot 'vcpkg.exe'
if (-not (Test-Path -LiteralPath $vcpkg)) { throw "vcpkg executable not found: $vcpkg" }

& $vcpkg install zlib:x64-windows-static
if ($LASTEXITCODE -ne 0) { throw 'Could not install static zlib with vcpkg.' }

$vcpkgInstalled = Join-Path $VcpkgRoot 'installed/x64-windows-static'
$zlibInclude = Join-Path $vcpkgInstalled 'include'
# PvPGN's legacy finder predates the current static `zs.lib` name used by vcpkg.
$zlibCandidates = @('zs.lib', 'zlib.lib', 'zlibstatic.lib', 'z.lib') |
    ForEach-Object { Join-Path $vcpkgInstalled "lib/$_" }
$zlibLibrary = $zlibCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not (Test-Path -LiteralPath (Join-Path $zlibInclude 'zlib.h'))) {
    throw "Static zlib headers were not installed under: $zlibInclude"
}
if (-not $zlibLibrary) {
    throw "Static zlib library was not found under: $(Join-Path $vcpkgInstalled 'lib')"
}

foreach ($path in @($buildRoot, $packageRoot)) {
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
}
New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null

$configureOutput = [System.Collections.Generic.List[string]]::new()
& cmake -S $sourceRoot -B $buildRoot -G 'Visual Studio 17 2022' -A x64 `
    "-DCMAKE_TOOLCHAIN_FILE=$toolchain" `
    '-DVCPKG_TARGET_TRIPLET=x64-windows-static' `
    "-DZLIB_INCLUDE_DIR=$zlibInclude" `
    "-DZLIB_LIBRARY=$zlibLibrary" `
    '-DCMAKE_POLICY_VERSION_MINIMUM=3.5' `
    '-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded' `
    '-DCMAKE_POLICY_DEFAULT_CMP0091=NEW' `
    '-DWITH_WIN32_GUI=OFF' '-DWITH_BNETD=ON' '-DWITH_D2CS=OFF' '-DWITH_D2DBS=OFF' `
    '-DWITH_LUA=OFF' '-DWITH_MYSQL=OFF' '-DWITH_SQLITE3=OFF' '-DWITH_PGSQL=OFF' '-DWITH_ODBC=OFF' 2>&1 |
    ForEach-Object {
        $line = $_.ToString()
        $configureOutput.Add($line)
        Write-Output $line
    }
$configureExitCode = $LASTEXITCODE
if ($configureExitCode -ne 0) {
    $diagnostic = ($configureOutput | Select-Object -Last 25) -join [Environment]::NewLine
    throw "Could not configure the Windows server build.$([Environment]::NewLine)$diagnostic"
}
& cmake --build $buildRoot --config Release --target bnetd --parallel
if ($LASTEXITCODE -ne 0) { throw 'Could not build the Windows server.' }

$serverBinary = Get-ChildItem -LiteralPath $buildRoot -Filter 'bnetd.exe' -File -Recurse |
    Where-Object { $_.FullName -match '[\\/]Release[\\/]bnetd\.exe$' } |
    Select-Object -First 1
if (-not $serverBinary) { throw 'The Windows build did not produce a Release bnetd.exe.' }

foreach ($directory in @('bin', 'config/base', 'files', 'data', 'scripts')) {
    New-Item -ItemType Directory -Path (Join-Path $packageRoot $directory) -Force | Out-Null
}
Copy-Item -LiteralPath $serverBinary.FullName -Destination (Join-Path $packageRoot 'bin/bnetd.exe')
Copy-Item -Path (Join-Path $buildRoot 'conf/*') -Destination (Join-Path $packageRoot 'config/base') -Recurse -Force

$runtimeFiles = @(
    'ad000001.png',
    'ad000001.smk',
    'ad000002.mng',
    'ad000002.smk',
    'bnserver-D2DV.ini',
    'bnserver-D2XP.ini',
    'bnserver-WAR3.ini',
    'bnserver.ini',
    'icons_STAR.bni',
    'icons-WAR3.bni',
    'icons.bni',
    'IX86ExtraWork.mpq',
    'IX86ver1.mpq',
    'newbie.save',
    'PMACver1.mpq',
    'ver-IX86-1.mpq',
    'XMACver1.mpq'
)
foreach ($runtimeFile in $runtimeFiles) {
    Copy-Item -LiteralPath (Join-Path $sourceRoot "files/$runtimeFile") -Destination (Join-Path $packageRoot 'files')
}
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
