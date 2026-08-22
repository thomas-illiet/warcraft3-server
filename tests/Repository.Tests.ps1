BeforeAll {
    $script:repositoryRoot = Split-Path -Parent $PSScriptRoot
}

Describe 'Source-only repository policy' {
    It 'tracks no generated binary or archive files' {
        $tracked = & git -C $script:repositoryRoot ls-files
        $forbidden = @($tracked | Where-Object {
            $_ -match '(?i)\.(exe|dll|zip|7z|tar|gz|msi|pdb|so|a|lib)$' -or
            $_ -match '^(artifacts|build|dist|out)/'
        })
        $forbidden -join "`n" | Should -BeNullOrEmpty
    }

    It 'pins both source submodules at the expected commits' {
        (& git -C $script:repositoryRoot rev-parse HEAD:sources/pvpgn-server).Trim() | Should -Be '9e7c471e0f6ca03f51842e8511f94948febe6711'
        (& git -C $script:repositoryRoot rev-parse HEAD:sources/w3l).Trim() | Should -Be 'd4b0bf403891c6528024e0375c81c2d6d6652f0a'
    }

    It 'contains no backup or restore public realm action' {
        $script = Get-Content -LiteralPath (Join-Path $script:repositoryRoot 'patch/Manage-WarcraftRealms.ps1') -Raw
        $script | Should -Not -Match "ValidateSet\([^)]*'Backup'"
        $script | Should -Not -Match "ValidateSet\([^)]*'Restore'"
    }
}

Describe 'Hardened Compose deployment' {
    BeforeAll {
        $script:compose = Get-Content -LiteralPath (Join-Path $script:repositoryRoot 'server/docker/compose.yaml') -Raw
    }

    It 'uses a numeric rootless identity and read-only root filesystem' {
        $script:compose | Should -Match 'user:\s*"10001:10001"'
        $script:compose | Should -Match 'read_only:\s*true'
    }

    It 'drops capabilities and prevents privilege escalation' {
        $script:compose | Should -Match 'cap_drop:\s*\r?\n\s*- ALL'
        $script:compose | Should -Match 'no-new-privileges:true'
    }

    It 'does not expose sensitive host integration' {
        $script:compose | Should -Not -Match 'privileged:\s*true'
        $script:compose | Should -Not -Match 'network_mode:\s*host'
        $script:compose | Should -Not -Match 'docker\.sock'
    }
}
