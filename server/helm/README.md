# Helm deployment

This chart deploys the GHCR image as a single rootless PvPGN pod and exposes it through one Kubernetes `NodePort` Service. The pod uses numeric UID and GID `10001:10001`, a read-only root filesystem, a runtime-default seccomp profile, no Linux capabilities and no service-account token.

The only writable locations are:

- `/var/lib/pvpgn`, backed by a persistent volume claim by default;
- `/run/pvpgn`, backed by a size-limited in-memory `emptyDir` for generated configuration.

## Install

Install a stable image tag and set the IPv4 address used by players:

```sh
helm upgrade --install warcraft3-server ./server/helm \
  --namespace warcraft3 --create-namespace \
  --set-string image.tag=1.0.0 \
  --set-string server.publicIp=203.0.113.10 \
  --set-string server.localHostIp=192.168.1.10 \
  --set-string server.lanCidr=192.168.0.0/16
```

Use a values file for repeatable deployments. Every server setting matches the native and Compose `.env` interface under the `server` key.

## NodePort routing

Kubernetes allocates the three NodePorts dynamically by default. Inspect them with:

```sh
kubectl --namespace warcraft3 get service warcraft3-server
```

Warcraft III and PvPGN advertise the standard public ports, so configure the edge firewall or router as follows:

| Public listener | Forward to |
| --- | --- |
| TCP 6112 | `game-tcp` NodePort on a cluster node |
| UDP 6112 | `game-udp` NodePort on a cluster node |
| TCP 6200 | `route-tcp` NodePort on a cluster node |

Set `server.publicIp` to the public IPv4 address of that forwarding rule. Static NodePorts can be selected with `service.ports.gameTcp.nodePort`, `service.ports.gameUdp.nodePort` and `service.ports.routeTcp.nodePort`; each value must belong to the range configured by the cluster, normally `30000-32767`.

## Storage

The chart creates a `ReadWriteOnce` 1 GiB claim. Set `persistence.storageClass`, `persistence.size` or `persistence.existingClaim` as needed. Set `persistence.enabled=false` only for disposable testing; account and game data will then disappear with the pod.

The container refuses to start if the mounted data volume is not writable by UID 10001. It never falls back to root. This chart intentionally supplies no backup or restore management.

## Validate

```sh
helm lint ./server/helm --strict
helm template warcraft3-server ./server/helm \
  --set-string server.publicIp=203.0.113.10 >/dev/null
```
