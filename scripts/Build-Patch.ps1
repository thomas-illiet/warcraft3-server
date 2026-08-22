[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path (Split-Path $PSScriptRoot -Parent) 'artifacts/patch'),
    [string]$Version = 'dev',
    [switch]$NoCache,
    [switch]$Archive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectDirectory = Split-Path $PSScriptRoot -Parent
$resolvedOutput = [System.IO.Path]::GetFullPath($OutputDirectory)
$dockerfile = Join-Path $projectDirectory 'patch/build/Dockerfile'
$exportDirectory = Join-Path $resolvedOutput 'warcraft3-patch'

if (Test-Path -LiteralPath $exportDirectory) {
    Remove-Item -LiteralPath $exportDirectory -Recurse -Force
}
New-Item -ItemType Directory -Path $exportDirectory -Force | Out-Null

$arguments = @(
    'buildx', 'build',
    '--file', $dockerfile,
    '--target', 'export',
    '--output', "type=local,dest=$exportDirectory"
)
if ($NoCache) { $arguments += '--no-cache' }
$arguments += $projectDirectory

docker @arguments
if ($LASTEXITCODE -ne 0) {
    throw 'The W3L Docker build failed.'
}

Copy-Item -LiteralPath (Join-Path $projectDirectory 'patch/Manage-WarcraftRealms.ps1') -Destination $exportDirectory
Copy-Item -LiteralPath (Join-Path $projectDirectory 'patch/README.md') -Destination $exportDirectory
Copy-Item -LiteralPath (Join-Path $projectDirectory 'sources/w3l/LICENSE') -Destination (Join-Path $exportDirectory 'LICENSE-W3L')

$requiredFiles = 'w3l.exe', 'w3lh.dll', 'wl27.dll', 'Manage-WarcraftRealms.ps1', 'README.md', 'LICENSE-W3L'
foreach ($requiredFile in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $exportDirectory $requiredFile))) {
        throw "Missing patch artifact: $requiredFile"
    }
}

$checksums = foreach ($file in Get-ChildItem -LiteralPath $exportDirectory -File | Sort-Object Name) {
    $hash = Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName
    '{0}  {1}' -f $hash.Hash.ToLowerInvariant(), $file.Name
}
[System.IO.File]::WriteAllLines((Join-Path $exportDirectory 'SHA256SUMS.txt'), $checksums, [System.Text.UTF8Encoding]::new($false))

if ($Archive) {
    $archivePath = Join-Path $resolvedOutput "warcraft3-patch-$Version-windows-x86.zip"
    if (Test-Path -LiteralPath $archivePath) {
        Remove-Item -LiteralPath $archivePath -Force
    }
    Compress-Archive -Path (Join-Path $exportDirectory '*') -DestinationPath $archivePath -CompressionLevel Optimal
    Write-Host "Patch archive created: $archivePath"
}
else {
    Write-Host "Patch files created: $exportDirectory"
}
