BeforeAll {
    $script:realmManagerScript = Join-Path (Split-Path -Parent $PSScriptRoot) 'patch/Manage-WarcraftRealms.ps1'
    . $script:realmManagerScript
}

Describe 'Warcraft III gateway serialization' {
    It 'parses and serializes a selected realm' {
        $values = @('1001', '002', 'one.example.test', '-1', 'One', '192.0.2.20', '0', 'Two')
        $configuration = ConvertFrom-GatewayValues -Values $values

        $configuration.SelectedIndex | Should -Be 2
        $configuration.Realms.Count | Should -Be 2
        $configuration.Realms[0].Address | Should -Be 'one.example.test'
        (ConvertTo-GatewayValues -Configuration $configuration) -join '|' | Should -Be ($values -join '|')
    }

    It 'represents an empty private list with the canonical header' {
        $values = ConvertTo-GatewayValues -Configuration (New-EmptyRealmConfiguration)
        $values -join '|' | Should -Be '1001|000'
    }

    It 'rejects a malformed gateway header' {
        { ConvertFrom-GatewayValues -Values @('9999', '000') } | Should -Throw
        { ConvertFrom-GatewayValues -Values @('1001', '0') } | Should -Throw
    }

    It 'rejects incomplete realm triplets and invalid selection indexes' {
        { ConvertFrom-GatewayValues -Values @('1001', '000', 'realm.example') } | Should -Throw
        { ConvertFrom-GatewayValues -Values @('1001', '002', 'realm.example', '-1', 'Realm') } | Should -Throw
    }

    It 'rejects invalid addresses and accepts IPv4 addresses and hostnames' {
        { New-RealmEntry -Name Realm -Address 'https://realm.example' -Timezone -1 } | Should -Throw
        (New-RealmEntry -Name Realm -Address '203.0.113.10' -Timezone -1).Address | Should -Be '203.0.113.10'
        (New-RealmEntry -Name Realm -Address 'realm.example.test' -Timezone 0).Address | Should -Be 'realm.example.test'
    }
}

Describe 'Realm CRUD and selection behavior' {
    BeforeEach {
        $script:capturedConfiguration = $null
        Mock Save-RealmConfiguration {
            param($Configuration, $Description)
            $script:capturedConfiguration = $Configuration
            return $true
        }
    }

    It 'adds and selects a realm' {
        Mock Get-CurrentRealmConfiguration { New-EmptyRealmConfiguration }
        Invoke-RealmManager -Action Add -Name Europe -Address 'realm.example.test' -Timezone -1
        $script:capturedConfiguration.Realms.Count | Should -Be 1
        $script:capturedConfiguration.SelectedIndex | Should -Be 1
    }

    It 'edits an existing realm' {
        Mock Get-CurrentRealmConfiguration {
            [pscustomobject]@{ SelectedIndex = 1; Realms = @((New-RealmEntry -Name Old -Address old.example.test -Timezone -1)) }
        }
        Invoke-RealmManager -Action Edit -Index 1 -Name New -Address new.example.test -Timezone 0
        $script:capturedConfiguration.Realms[0].Name | Should -Be 'New'
        $script:capturedConfiguration.Realms[0].Timezone | Should -Be '0'
    }

    It 'removes a realm and keeps a valid selection' {
        Mock Get-CurrentRealmConfiguration {
            [pscustomobject]@{
                SelectedIndex = 2
                Realms = @(
                    (New-RealmEntry -Name One -Address one.example.test -Timezone -1),
                    (New-RealmEntry -Name Two -Address two.example.test -Timezone -1)
                )
            }
        }
        Invoke-RealmManager -Action Remove -Index 1
        $script:capturedConfiguration.Realms.Count | Should -Be 1
        $script:capturedConfiguration.Realms[0].Name | Should -Be 'Two'
        $script:capturedConfiguration.SelectedIndex | Should -Be 1
    }

    It 'selects a realm by one-based index' {
        Mock Get-CurrentRealmConfiguration {
            [pscustomobject]@{
                SelectedIndex = 1
                Realms = @(
                    (New-RealmEntry -Name One -Address one.example.test -Timezone -1),
                    (New-RealmEntry -Name Two -Address two.example.test -Timezone -1)
                )
            }
        }
        Invoke-RealmManager -Action Select -Index 2
        $script:capturedConfiguration.SelectedIndex | Should -Be 2
    }

    It 'resets to an empty list' {
        Invoke-RealmManager -Action Reset
        $script:capturedConfiguration.Realms.Count | Should -Be 0
        $script:capturedConfiguration.SelectedIndex | Should -Be 0
    }
}

Describe 'Atomic registry behavior' {
    It 'does not access the registry under WhatIf' {
        Mock Get-RealmRegistrySnapshot { throw 'Registry must not be read.' }
        Mock Set-RegistryValues { throw 'Registry must not be written.' }
        $result = Save-RealmConfiguration -Configuration (New-EmptyRealmConfiguration) -Description reset -WhatIf
        $result | Should -BeFalse
        Assert-MockCalled Get-RealmRegistrySnapshot -Times 0 -Exactly
        Assert-MockCalled Set-RegistryValues -Times 0 -Exactly
    }

    It 'rolls both values back from memory after a partial write' {
        $snapshot = [pscustomobject]@{
            Primary = [pscustomobject]@{ Exists = $true; Values = @('1001', '000') }
            Virtual = [pscustomobject]@{ Exists = $false; Values = $null }
        }
        $script:writeCount = 0
        Mock Get-RealmRegistrySnapshot { $snapshot }
        Mock Set-RegistryValues {
            $script:writeCount++
            if ($script:writeCount -eq 2) { throw 'Simulated second registry write failure.' }
        }
        Mock Restore-RegistryValueState {}

        { Save-RealmConfiguration -Configuration (New-EmptyRealmConfiguration) -Description reset -Confirm:$false } | Should -Throw
        Assert-MockCalled Restore-RegistryValueState -Times 2 -Exactly
    }

    It 'creates no backup files' {
        Push-Location $TestDrive
        try {
            $null = ConvertTo-GatewayValues -Configuration (New-EmptyRealmConfiguration)
            @(Get-ChildItem -Force).Count | Should -Be 0
        }
        finally {
            Pop-Location
        }
    }
}
