[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [ValidateSet('Menu', 'List', 'Add', 'Edit', 'Remove', 'Select', 'Reset')]
    [string]$Action = 'Menu',

    [string]$Name,
    [string]$Address,
    [string]$Timezone,
    [int]$Index
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:GatewayValueName = 'Battle.net Gateways'
$script:PrimaryRegistryPath = 'HKCU:\Software\Blizzard Entertainment\Warcraft III'
$script:VirtualRegistryPath = 'HKCU:\Software\Classes\VirtualStore\MACHINE\SOFTWARE\WOW6432Node\Blizzard Entertainment\Warcraft III'

function Test-RealmName {
    param([Parameter(Mandatory)][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value) -or $Value -ne $Value.Trim()) {
        throw 'Realm name cannot be empty or surrounded by whitespace.'
    }
    foreach ($character in $Value.ToCharArray()) {
        if ([char]::IsControl($character)) {
            throw 'Realm name cannot contain control characters.'
        }
    }
}

function Test-RealmAddress {
    param([Parameter(Mandatory)][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value) -or $Value -ne $Value.Trim()) {
        throw 'Realm address cannot be empty or surrounded by whitespace.'
    }
    if ($Value.Length -gt 253 -or $Value -match '[\s\\/:\[\]]') {
        throw 'Realm address must be an IPv4 address or hostname without a scheme, path, or port.'
    }

    $parsedAddress = $null
    if ([System.Net.IPAddress]::TryParse($Value, [ref]$parsedAddress)) {
        if ($parsedAddress.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
            throw 'IPv6 addresses are not supported by this Warcraft III configuration.'
        }
        return
    }

    foreach ($label in $Value.Split('.')) {
        if ($label.Length -lt 1 -or $label.Length -gt 63 -or
            $label -notmatch '^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$') {
            throw 'Realm address contains an invalid hostname label.'
        }
    }
}

function Test-RealmTimezone {
    param([Parameter(Mandatory)][string]$Value)

    $parsedTimezone = 0
    if (-not [int]::TryParse($Value, [ref]$parsedTimezone)) {
        throw "Invalid realm timezone: $Value"
    }
}

function New-RealmEntry {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Address,
        [Parameter(Mandatory)][string]$Timezone
    )

    $normalizedName = $Name.Trim()
    $normalizedAddress = $Address.Trim()
    $normalizedTimezone = $Timezone.Trim()
    Test-RealmName -Value $normalizedName
    Test-RealmAddress -Value $normalizedAddress
    Test-RealmTimezone -Value $normalizedTimezone

    [pscustomobject]@{
        Name = $normalizedName
        Address = $normalizedAddress
        Timezone = $normalizedTimezone
    }
}

function New-EmptyRealmConfiguration {
    [pscustomobject]@{
        SelectedIndex = 0
        Realms = @()
    }
}

function ConvertFrom-GatewayValues {
    param([Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Values)

    if ($Values.Count -lt 2) {
        throw 'Gateway data is missing its two-value header.'
    }
    if ($Values[0] -cne '1001') {
        throw "Unsupported gateway header: $($Values[0])"
    }
    if ($Values[1] -notmatch '^\d{3}$') {
        throw "Invalid selected-realm header: $($Values[1])"
    }
    if (($Values.Count - 2) % 3 -ne 0) {
        throw 'Gateway data must contain address, timezone, and name triplets.'
    }

    $realms = @()
    for ($position = 2; $position -lt $Values.Count; $position += 3) {
        $realms += New-RealmEntry -Address $Values[$position] -Timezone $Values[$position + 1] -Name $Values[$position + 2]
    }

    $selectedIndex = [int]$Values[1]
    if ($selectedIndex -lt 0 -or $selectedIndex -gt $realms.Count) {
        throw "Selected realm index $selectedIndex is outside the configured realm list."
    }
    if ($realms.Count -eq 0 -and $selectedIndex -ne 0) {
        throw 'An empty realm list must use selected index 000.'
    }

    [pscustomobject]@{
        SelectedIndex = $selectedIndex
        Realms = @($realms)
    }
}

function ConvertTo-GatewayValues {
    param([Parameter(Mandatory)]$Configuration)

    $realmCount = @($Configuration.Realms).Count
    if ($Configuration.SelectedIndex -lt 0 -or $Configuration.SelectedIndex -gt $realmCount) {
        throw 'Selected realm index is outside the configured realm list.'
    }
    if ($realmCount -eq 0 -and $Configuration.SelectedIndex -ne 0) {
        throw 'An empty realm list must use selected index 000.'
    }

    $values = @('1001', ('{0:D3}' -f [int]$Configuration.SelectedIndex))
    foreach ($realm in @($Configuration.Realms)) {
        $validated = New-RealmEntry -Name $realm.Name -Address $realm.Address -Timezone $realm.Timezone
        $values += $validated.Address
        $values += $validated.Timezone
        $values += $validated.Name
    }
    [string[]]$values
}

function Test-StringArrayEqual {
    param([string[]]$Left, [string[]]$Right)

    if ($null -eq $Left -or $null -eq $Right) {
        return $null -eq $Left -and $null -eq $Right
    }
    if ($Left.Count -ne $Right.Count) {
        return $false
    }
    for ($position = 0; $position -lt $Left.Count; $position++) {
        if ($Left[$position] -cne $Right[$position]) {
            return $false
        }
    }
    return $true
}

function Get-RegistryValueState {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{ Exists = $false; Values = $null }
    }

    $key = Get-Item -LiteralPath $Path
    if ($key.GetValueNames() -notcontains $script:GatewayValueName) {
        return [pscustomobject]@{ Exists = $false; Values = $null }
    }
    if ($key.GetValueKind($script:GatewayValueName) -ne [Microsoft.Win32.RegistryValueKind]::MultiString) {
        throw "$Path\$($script:GatewayValueName) is not a REG_MULTI_SZ value."
    }

    [pscustomobject]@{
        Exists = $true
        Values = [string[]]$key.GetValue($script:GatewayValueName)
    }
}

function Get-RealmRegistrySnapshot {
    if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
        throw 'Realm registry management is available on Windows only.'
    }

    [pscustomobject]@{
        Primary = Get-RegistryValueState -Path $script:PrimaryRegistryPath
        Virtual = Get-RegistryValueState -Path $script:VirtualRegistryPath
    }
}

function Set-RegistryValues {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Values
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    New-ItemProperty -LiteralPath $Path -Name $script:GatewayValueName -PropertyType MultiString -Value $Values -Force | Out-Null
}

function Restore-RegistryValueState {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$State
    )

    if ($State.Exists) {
        Set-RegistryValues -Path $Path -Values $State.Values
    }
    elseif (Test-Path -LiteralPath $Path) {
        Remove-ItemProperty -LiteralPath $Path -Name $script:GatewayValueName -ErrorAction SilentlyContinue
    }
}

function Get-CurrentRealmConfiguration {
    $snapshot = Get-RealmRegistrySnapshot
    if ($snapshot.Primary.Exists) {
        $configuration = ConvertFrom-GatewayValues -Values $snapshot.Primary.Values
        if ($snapshot.Virtual.Exists -and -not (Test-StringArrayEqual -Left $snapshot.Primary.Values -Right $snapshot.Virtual.Values)) {
            Write-Warning 'Primary and VirtualStore realm values differ. The primary value will be used and the next change will synchronize both.'
        }
        return $configuration
    }
    if ($snapshot.Virtual.Exists) {
        return ConvertFrom-GatewayValues -Values $snapshot.Virtual.Values
    }
    return New-EmptyRealmConfiguration
}

function Save-RealmConfiguration {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]$Configuration,
        [Parameter(Mandatory)][string]$Description
    )

    $values = ConvertTo-GatewayValues -Configuration $Configuration
    if (-not $PSCmdlet.ShouldProcess('Warcraft III realm registry values', $Description)) {
        return $false
    }

    $snapshot = Get-RealmRegistrySnapshot
    try {
        Set-RegistryValues -Path $script:PrimaryRegistryPath -Values $values
        Set-RegistryValues -Path $script:VirtualRegistryPath -Values $values
    }
    catch {
        $writeError = $_
        try {
            Restore-RegistryValueState -Path $script:PrimaryRegistryPath -State $snapshot.Primary
            Restore-RegistryValueState -Path $script:VirtualRegistryPath -State $snapshot.Virtual
        }
        catch {
            throw "Realm update failed and the in-memory rollback also failed: $($writeError.Exception.Message); $($_.Exception.Message)"
        }
        throw $writeError
    }
    return $true
}

function Assert-RealmIndex {
    param([Parameter(Mandatory)]$Configuration, [Parameter(Mandatory)][int]$Index)

    if ($Index -lt 1 -or $Index -gt @($Configuration.Realms).Count) {
        throw "Realm index $Index does not exist."
    }
}

function Assert-UniqueRealm {
    param(
        [Parameter(Mandatory)]$Configuration,
        [Parameter(Mandatory)]$Realm,
        [int]$IgnoredIndex = 0
    )

    for ($position = 0; $position -lt @($Configuration.Realms).Count; $position++) {
        if (($position + 1) -eq $IgnoredIndex) {
            continue
        }
        $existing = $Configuration.Realms[$position]
        if ($existing.Name -ieq $Realm.Name) {
            throw "A realm named '$($Realm.Name)' already exists."
        }
        if ($existing.Address -ieq $Realm.Address) {
            throw "A realm using '$($Realm.Address)' already exists."
        }
    }
}

function Get-RealmRows {
    param([Parameter(Mandatory)]$Configuration)

    for ($position = 0; $position -lt @($Configuration.Realms).Count; $position++) {
        $realm = $Configuration.Realms[$position]
        [pscustomobject]@{
            Index = $position + 1
            Selected = ($Configuration.SelectedIndex -eq ($position + 1))
            Name = $realm.Name
            Address = $realm.Address
            Timezone = $realm.Timezone
        }
    }
}

function Invoke-RealmMenu {
    while ($true) {
        Write-Host ''
        Write-Host 'Warcraft III Realm Manager'
        Write-Host '1. List realms'
        Write-Host '2. Add a realm'
        Write-Host '3. Edit a realm'
        Write-Host '4. Remove a realm'
        Write-Host '5. Select a realm'
        Write-Host '6. Reset to an empty list'
        Write-Host '0. Exit'
        $choice = Read-Host 'Choose an action'

        try {
            switch ($choice) {
                '1' { Invoke-RealmManager -Action List | Format-Table -AutoSize | Out-Host }
                '2' {
                    $menuName = Read-Host 'Realm name'
                    $menuAddress = Read-Host 'Realm address'
                    $menuTimezone = Read-Host 'Timezone offset [-1]'
                    if ([string]::IsNullOrWhiteSpace($menuTimezone)) { $menuTimezone = '-1' }
                    Invoke-RealmManager -Action Add -Name $menuName -Address $menuAddress -Timezone $menuTimezone
                }
                '3' {
                    $menuIndex = [int](Read-Host 'Realm index')
                    $menuName = Read-Host 'New name (leave empty to keep current)'
                    $menuAddress = Read-Host 'New address (leave empty to keep current)'
                    $menuTimezone = Read-Host 'New timezone (leave empty to keep current)'
                    Invoke-RealmManager -Action Edit -Index $menuIndex -Name $menuName -Address $menuAddress -Timezone $menuTimezone
                }
                '4' { Invoke-RealmManager -Action Remove -Index ([int](Read-Host 'Realm index')) }
                '5' { Invoke-RealmManager -Action Select -Index ([int](Read-Host 'Realm index')) }
                '6' {
                    if ((Read-Host 'Type RESET to clear every configured realm') -ceq 'RESET') {
                        Invoke-RealmManager -Action Reset
                    }
                }
                '0' { return }
                default { Write-Warning 'Unknown menu choice.' }
            }
        }
        catch {
            Write-Warning $_.Exception.Message
        }
    }
}

function Invoke-RealmManager {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [ValidateSet('Menu', 'List', 'Add', 'Edit', 'Remove', 'Select', 'Reset')]
        [string]$Action = 'Menu',
        [string]$Name,
        [string]$Address,
        [string]$Timezone,
        [int]$Index
    )

    if ($Action -eq 'Menu') {
        Invoke-RealmMenu
        return
    }
    if ($Action -eq 'Reset') {
        if (Save-RealmConfiguration -Configuration (New-EmptyRealmConfiguration) -Description 'reset the realm list') {
            Write-Host 'Realm list reset to an empty private list.'
        }
        return
    }

    $configuration = Get-CurrentRealmConfiguration
    switch ($Action) {
        'List' {
            Get-RealmRows -Configuration $configuration
        }
        'Add' {
            if ([string]::IsNullOrWhiteSpace($Name) -or [string]::IsNullOrWhiteSpace($Address)) {
                throw 'Add requires -Name and -Address.'
            }
            if ([string]::IsNullOrWhiteSpace($Timezone)) { $Timezone = '-1' }
            $realm = New-RealmEntry -Name $Name -Address $Address -Timezone $Timezone
            Assert-UniqueRealm -Configuration $configuration -Realm $realm
            $configuration.Realms = @($configuration.Realms) + $realm
            $configuration.SelectedIndex = @($configuration.Realms).Count
            if (Save-RealmConfiguration -Configuration $configuration -Description "add and select realm '$($realm.Name)'") {
                Write-Host "Realm added and selected: $($realm.Name)"
            }
        }
        'Edit' {
            Assert-RealmIndex -Configuration $configuration -Index $Index
            $existing = $configuration.Realms[$Index - 1]
            if ([string]::IsNullOrWhiteSpace($Name)) { $Name = $existing.Name }
            if ([string]::IsNullOrWhiteSpace($Address)) { $Address = $existing.Address }
            if ([string]::IsNullOrWhiteSpace($Timezone)) { $Timezone = $existing.Timezone }
            $realm = New-RealmEntry -Name $Name -Address $Address -Timezone $Timezone
            Assert-UniqueRealm -Configuration $configuration -Realm $realm -IgnoredIndex $Index
            $configuration.Realms[$Index - 1] = $realm
            if (Save-RealmConfiguration -Configuration $configuration -Description "edit realm '$($realm.Name)'") {
                Write-Host "Realm updated: $($realm.Name)"
            }
        }
        'Remove' {
            Assert-RealmIndex -Configuration $configuration -Index $Index
            $removedName = $configuration.Realms[$Index - 1].Name
            $remainingRealms = for ($realmIndex = 0; $realmIndex -lt $configuration.Realms.Count; $realmIndex++) {
                if ($realmIndex -ne ($Index - 1)) {
                    $configuration.Realms[$realmIndex]
                }
            }
            $configuration.Realms = @($remainingRealms)
            if (@($configuration.Realms).Count -eq 0) {
                $configuration.SelectedIndex = 0
            }
            elseif ($configuration.SelectedIndex -gt $Index) {
                $configuration.SelectedIndex--
            }
            elseif ($configuration.SelectedIndex -eq $Index) {
                $configuration.SelectedIndex = [Math]::Min($Index, @($configuration.Realms).Count)
            }
            if (Save-RealmConfiguration -Configuration $configuration -Description "remove realm '$removedName'") {
                Write-Host "Realm removed: $removedName"
            }
        }
        'Select' {
            Assert-RealmIndex -Configuration $configuration -Index $Index
            $configuration.SelectedIndex = $Index
            $selectedName = $configuration.Realms[$Index - 1].Name
            if (Save-RealmConfiguration -Configuration $configuration -Description "select realm '$selectedName'") {
                Write-Host "Realm selected: $selectedName"
            }
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-RealmManager @PSBoundParameters
}
