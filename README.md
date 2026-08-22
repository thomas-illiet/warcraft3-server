# Warcraft III private server kit

This repository builds a Warcraft III 1.28.5 client patch and a private PvPGN server for Windows x64, Linux x64 and hardened Docker deployments. It contains source code, configuration and build automation only: downloadable executables and archives are produced by GitHub Actions and attached to tagged releases.

## What is included

| Component | Output | Purpose |
| --- | --- | --- |
| Client patch | `warcraft3-patch-<version>-windows-x86.zip` | W3L loader, DLLs and the Windows realm manager |
| Windows server | `warcraft3-server-<version>-windows-x64.zip` | Portable console PvPGN server |
| Linux server | `warcraft3-server-<version>-linux-x64.tar.gz` | Portable console PvPGN server |
| Container | `ghcr.io/thomas-illiet/warcraft3-server:<version>` | Rootless, read-only deployment |

The server accepts Warcraft III and The Frozen Throne clients, validates version 1.28.5, listens on TCP/UDP 6112 and TCP 6200, applies LAN/public-address translation and leaves public PvPGN tracking disabled.

## Repository layout

```text
patch/                  W3L build compatibility patch, realm manager and explanation
server/common/          Shared settings, version validation and configuration generator
server/windows/         Windows runtime scripts
server/linux/           Linux runtime and pinned build environment
server/docker/          Rootless read-only image and Compose deployment
sources/pvpgn-server/   Pinned PvPGN source submodule
sources/w3l/            Pinned W3L source submodule
scripts/                Source build and packaging entry points
tests/                  Pester and deployment smoke tests
.github/                CI, release and dependency maintenance
```

Generated output is written under ignored `artifacts/` and `build/` directories. No generated executable, archive or checksum is committed.

## Download and install

Download the appropriate files from [GitHub Releases](https://github.com/thomas-illiet/warcraft3-server/releases). Each release includes `SHA256SUMS.txt`.

- Read [patch/README.md](patch/README.md) before installing the client patch. It explains why W3L is required, what the compatibility patch changes and how realm registry synchronization works.
- Read [server/windows/README.md](server/windows/README.md) or [server/linux/README.md](server/linux/README.md) for a portable native server.
- Read [server/docker/README.md](server/docker/README.md) for the hardened container deployment.

All server formats use the same `.env` interface:

```dotenv
SERVER_NAME=Warcraft III Server
PUBLIC_IP=203.0.113.10
LAN_CIDR=192.168.0.0/16
LOCAL_HOST_IP=192.168.1.10
MAX_ACCOUNTS=1000
TZ=Europe/Paris
```

Persistent native data is stored under `data/`; container data is stored in its named volume. This project intentionally includes no backup or restore management.

## Build from source

Clone recursively so both pinned upstream sources are present:

```sh
git clone --recurse-submodules https://github.com/thomas-illiet/warcraft3-server.git
cd warcraft3-server
```

Build Linux on a host with Docker and standard Unix tools:

```sh
./scripts/build-server-linux.sh dev
```

Build W3L from PowerShell 7 on a host with Docker:

```powershell
./scripts/Build-Patch.ps1 -Archive -Version dev
```

The Windows server requires Windows, Visual Studio 2022, CMake and vcpkg:

```powershell
./scripts/Build-ServerWindows.ps1 -Archive -Version dev
```

The GitHub workflow runs these builds independently. A semantic `vMAJOR.MINOR.PATCH` tag publishes all three archives, checksums, the GitHub release and the GHCR image. Stable tags also update `latest`; prerelease tags do not.

## Licensing and security

This repository deliberately has no root project license. PvPGN and W3L retain their original license files in their source submodules, and those notices are copied into generated packages. Blizzard game files are never included.

See [CONTRIBUTING.md](CONTRIBUTING.md) for development rules and [SECURITY.md](SECURITY.md) for private vulnerability reporting.
