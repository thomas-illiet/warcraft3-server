# Rootless Docker deployment

The image is built directly from the pinned PvPGN submodule and always runs as numeric user and group `10001:10001`. Its root filesystem is read-only. The only writable locations are the persistent `/var/lib/pvpgn` volume and the size-limited `/run/pvpgn` tmpfs used for generated configuration.

## Run

1. Copy `.env.example` to `.env` and set the public and LAN addresses.
2. Run `docker compose up -d --build` from this directory.
3. Check startup with `docker compose logs pvpgn`.

Compose removes every Linux capability and enables `no-new-privileges`. It does not use privileged mode, host networking, the Docker socket or host bind mounts. If a reused volume cannot be written by UID 10001, startup fails with an ownership error instead of escalating to root.

To grant administrator access after an account exists, stop the service and run:

```sh
docker compose run --rm --entrypoint /usr/local/bin/set-admin pvpgn ACCOUNT_NAME
```

Account and game data remains in the named volume. No backup or restore commands are supplied.
