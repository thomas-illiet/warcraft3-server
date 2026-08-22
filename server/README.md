# Server distributions

All server distributions build PvPGN from `sources/pvpgn-server` and share the configuration contract in `common/`.

- `windows/` provides PowerShell launch and account-administration scripts for the Windows x64 archive.
- `linux/` provides POSIX shell scripts and the pinned Linux x64 build environment.
- `docker/` provides the GHCR image and hardened Compose configuration.

At startup, each distribution copies immutable base configuration to a runtime directory and injects the six validated `.env` values. Persistent account and game state is separated into `data/` or the Docker named volume. No distribution contains a backup utility or service installer.
