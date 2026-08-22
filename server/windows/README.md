# Portable Windows server

This archive contains a console-only PvPGN server for Windows x64. It uses file account storage and has optional database, Lua and Diablo services disabled.

1. Copy `.env.example` to `.env` and review all addresses.
2. Allow TCP and UDP port `6112`, plus TCP port `6200`, through Windows Firewall and the router.
3. Run `Start-Server.ps1`; the server stays in the foreground.

Persistent state is kept under `data/`; generated configuration is kept under `runtime/`. After a player creates an account, stop the server and run `scripts/Set-Admin.ps1 ACCOUNT_NAME` to grant administrator access.

No backup, restore, service installer or generated binary is stored in this repository.
