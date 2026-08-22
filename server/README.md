# Server distributions

All server distributions build PvPGN from `sources/pvpgn-server` and share the configuration contract in `common/`.

- `windows/` provides PowerShell launch and account-administration scripts for the Windows x64 archive.
- `linux/` provides POSIX shell scripts and the pinned Linux x64 build environment.
- `docker/` provides the GHCR image and hardened Compose configuration.
- `helm/` provides a hardened Kubernetes deployment with one NodePort Service.

At startup, each distribution copies immutable base configuration to a runtime directory and injects the six validated settings. Persistent account and game state is separated into `data/`, the Docker named volume or a Kubernetes persistent volume claim. No distribution contains a backup utility or service installer.
