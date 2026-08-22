# Portable Linux server

This archive contains a console-only PvPGN server for Linux x64. PvPGN is compiled in a pinned Debian environment; account storage is file based and optional database, Lua and Diablo services are disabled.

## Start

1. Copy `.env.example` to `.env` and review all addresses.
2. Allow TCP and UDP port `6112`, plus TCP port `6200`, through the host and router firewalls.
3. Run `./start-server.sh` in the foreground.

The launch script validates `.env`, writes effective configuration under `runtime/`, and stores all persistent state under `data/`. Run `scripts/set-admin.sh ACCOUNT_NAME` after that player has created an account and while the server is stopped.

No backup, restore, system-service or installer scripts are included.

Repository maintainers build this package on Linux with `./scripts/build-server-linux.sh VERSION`; PowerShell is not required.
