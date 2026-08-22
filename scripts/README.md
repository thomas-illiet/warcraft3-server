# Build entry points

- `Build-Patch.ps1` cross-compiles the Windows x86 W3L kit in Docker and optionally creates its ZIP archive.
- `build-server-linux.sh` builds and packages the Linux x64 server in its pinned Debian environment.
- `Build-ServerWindows.ps1` builds the Windows x64 server with Visual Studio 2022 and static vcpkg zlib.

These scripts write only to ignored `build/` and `artifacts/` directories. GitHub Actions calls the Linux shell entry point on Ubuntu and the Windows PowerShell entry points only where PowerShell or the Windows toolchain is required.
