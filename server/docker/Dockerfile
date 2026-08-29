FROM debian:bookworm-slim@sha256:88200866dfff7ea7f5cbcb6ec7c8a701889efe6fe859fe64d6990e4b07ea4171 AS builder

RUN apt-get update \
    && apt-get install -y --no-install-recommends cmake g++ make zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

COPY sources/pvpgn-server /src
RUN rm -f /src/.git \
    && find /src -type f -exec sed -i 's/\r$//' {} + \
    && sed -i 's/ -march=native -mtune=native//g' /src/CMakeLists.txt \
    && cmake -S /src -B /build \
         -DCMAKE_BUILD_TYPE=Release \
         -DCMAKE_INSTALL_PREFIX=/opt/pvpgn \
         -DCMAKE_CXX_FLAGS_RELEASE='-O2 -DNDEBUG -static-libgcc -static-libstdc++' \
         -DWITH_BNETD=ON -DWITH_D2CS=OFF -DWITH_D2DBS=OFF \
         -DWITH_LUA=OFF -DWITH_MYSQL=OFF -DWITH_SQLITE3=OFF -DWITH_PGSQL=OFF -DWITH_ODBC=OFF \
    && cmake --build /build --parallel \
    && cmake --install /build \
    && strip /opt/pvpgn/sbin/bnetd

FROM debian:bookworm-slim@sha256:88200866dfff7ea7f5cbcb6ec7c8a701889efe6fe859fe64d6990e4b07ea4171

LABEL org.opencontainers.image.source="https://github.com/thomas-illiet/warcraft3-server" \
      org.opencontainers.image.description="Rootless PvPGN server for Warcraft III 1.28.5" \
      org.opencontainers.image.licenses="GPL-3.0-or-later"

RUN apt-get update \
    && apt-get install -y --no-install-recommends netcat-openbsd zlib1g \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 pvpgn \
    && useradd --uid 10001 --gid 10001 --no-create-home --home-dir /var/lib/pvpgn --shell /usr/sbin/nologin pvpgn \
    && mkdir -p /opt/pvpgn/config/base /opt/pvpgn/files /run/pvpgn /var/lib/pvpgn \
    && chown 10001:10001 /run/pvpgn /var/lib/pvpgn \
    && chmod 0700 /run/pvpgn /var/lib/pvpgn

COPY --from=builder /opt/pvpgn/sbin/bnetd /usr/local/bin/bnetd
COPY --from=builder /opt/pvpgn/etc/pvpgn/ /opt/pvpgn/config/base/
COPY --from=builder /opt/pvpgn/var/pvpgn/files/ /opt/pvpgn/files/
COPY server/common/versioncheck.json /opt/pvpgn/config/base/versioncheck.json
COPY server/common/configure-pvpgn.sh /usr/local/lib/pvpgn/configure-pvpgn.sh
COPY server/common/set-admin.sh /usr/local/bin/set-admin
COPY server/docker/entrypoint.sh /usr/local/bin/entrypoint
COPY sources/pvpgn-server/LICENSE /usr/share/licenses/pvpgn/LICENSE

RUN chmod 0555 /usr/local/bin/bnetd /usr/local/bin/entrypoint /usr/local/bin/set-admin \
    /usr/local/lib/pvpgn/configure-pvpgn.sh \
    && chmod -R a-w /opt/pvpgn /usr/share/licenses/pvpgn

ENV SERVER_NAME="Warcraft III Server" \
    PUBLIC_IP="127.0.0.1" \
    LAN_CIDR="192.168.0.0/16" \
    LOCAL_HOST_IP="127.0.0.1" \
    MAX_ACCOUNTS="1000" \
    TZ="UTC"

USER 10001:10001
WORKDIR /var/lib/pvpgn
EXPOSE 6112/tcp 6112/udp 6200/tcp
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 CMD ["nc", "-z", "127.0.0.1", "6112"]
ENTRYPOINT ["/usr/local/bin/entrypoint"]
