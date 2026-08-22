# Shared server configuration

Every distribution uses the same six settings from `.env`:

| Setting | Purpose |
| --- | --- |
| `SERVER_NAME` | Realm name displayed by PvPGN |
| `PUBLIC_IP` | IPv4 address advertised to Internet clients |
| `LAN_CIDR` | Network that must keep local addresses during NAT translation |
| `LOCAL_HOST_IP` | PvPGN host address visible inside the LAN |
| `MAX_ACCOUNTS` | Account creation limit; `0` means unlimited |
| `TZ` | IANA timezone used for logs |

At every start, the launch script copies the immutable base configuration to a transient runtime directory and applies these values. It restricts clients to Warcraft III, validates version 1.28.5, listens on TCP/UDP 6112 and TCP 6200, configures NAT translation and leaves PvPGN tracking disabled.

Persistent state lives only in the distribution's designated data directory or volume. This project deliberately provides no backup or restore tooling.
