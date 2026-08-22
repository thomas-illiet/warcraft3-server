BeforeAll {
    $script:repositoryRoot = Split-Path -Parent $PSScriptRoot
}

Describe 'Source-only repository policy' {
    It 'tracks no generated binary or archive files' {
        $tracked = & git -C $script:repositoryRoot ls-files
        $forbidden = @($tracked | Where-Object {
            $_ -match '(?i)\.(exe|dll|zip|7z|tar|gz|msi|pdb|so|a|lib)$' -or
            $_ -match '^(artifacts|build|dist|out)/' -or
            $_ -match '(^|/)SHA256SUMS\.txt$'
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

Describe 'Portable Windows server launcher' {
    BeforeAll {
        $script:windowsLauncher = Get-Content -LiteralPath (Join-Path $script:repositoryRoot 'server/windows/Start-Server.ps1') -Raw
    }

    It 'does not treat an uninitialized native exit code as a configuration failure' {
        $script:windowsLauncher | Should -Not -Match '(?s)Configure-PvPGN\.ps1.*?if\s*\(\$LASTEXITCODE\s*-ne\s*0\)'
    }

    It 'still returns the PvPGN process exit code' {
        $script:windowsLauncher | Should -Match '(?s)bin/bnetd\.exe.*?exit\s+\$LASTEXITCODE'
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

Describe 'Hardened Helm deployment' {
    BeforeAll {
        $script:helmDeployment = Get-Content -LiteralPath (Join-Path $script:repositoryRoot 'server/helm/templates/deployment.yaml') -Raw
        $script:helmService = Get-Content -LiteralPath (Join-Path $script:repositoryRoot 'server/helm/templates/service.yaml') -Raw
        $script:helmValues = Get-Content -LiteralPath (Join-Path $script:repositoryRoot 'server/helm/values.yaml') -Raw
    }

    It 'exposes one NodePort service with all PvPGN transports' {
        $script:helmService | Should -Match 'kind:\s*Service'
        $script:helmValues | Should -Match 'type:\s*NodePort'
        $script:helmService | Should -Match 'name:\s*game-tcp'
        $script:helmService | Should -Match 'name:\s*game-udp'
        $script:helmService | Should -Match 'name:\s*route-tcp'
    }

    It 'uses a numeric rootless identity and read-only root filesystem' {
        $script:helmDeployment | Should -Match 'runAsNonRoot:\s*true'
        $script:helmDeployment | Should -Match 'runAsUser:\s*10001'
        $script:helmDeployment | Should -Match 'runAsGroup:\s*10001'
        $script:helmDeployment | Should -Match 'readOnlyRootFilesystem:\s*true'
    }

    It 'drops capabilities and prevents privilege escalation' {
        $script:helmDeployment | Should -Match 'allowPrivilegeEscalation:\s*false'
        $script:helmDeployment | Should -Match 'drop:\s*\r?\n\s*- ALL'
        $script:helmDeployment | Should -Match 'automountServiceAccountToken:\s*false'
    }

    It 'limits writes to data and an in-memory runtime directory' {
        $script:helmDeployment | Should -Match 'mountPath:\s*/var/lib/pvpgn'
        $script:helmDeployment | Should -Match 'mountPath:\s*/run/pvpgn'
        $script:helmDeployment | Should -Match 'medium:\s*Memory'
        $script:helmDeployment | Should -Not -Match 'hostPath:'
        $script:helmDeployment | Should -Not -Match 'privileged:\s*true'
        $script:helmDeployment | Should -Not -Match 'hostNetwork:\s*true'
    }
}
