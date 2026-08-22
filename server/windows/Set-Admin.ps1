[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidatePattern('^[A-Za-z0-9_\[\]-]+$')]
    [string]$AccountName
)

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$accountFile = Join-Path $packageRoot "data/users/$AccountName"
if (-not (Test-Path -LiteralPath $accountFile -PathType Leaf)) { throw "Account not found: $AccountName" }
$content = Get-Content -LiteralPath $accountFile -Raw
$line = '"BNET\\auth\\admin"="true"'
if ($content -match '(?m)^"BNET\\\\auth\\\\admin"=.*$') {
    $updated = [regex]::Replace($content, '(?m)^"BNET\\\\auth\\\\admin"=.*$', $line)
} else {
    $updated = $content.TrimEnd() + "`r`n$line`r`n"
}
if ($PSCmdlet.ShouldProcess($AccountName, 'Grant PvPGN administrator access')) {
    [System.IO.File]::WriteAllText($accountFile, $updated, [System.Text.UTF8Encoding]::new($false))
    Write-Output "Account $AccountName is now an administrator. Restart the server if it is running."
}
