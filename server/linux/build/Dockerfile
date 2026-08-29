FROM debian:bookworm-slim@sha256:88200866dfff7ea7f5cbcb6ec7c8a701889efe6fe859fe64d6990e4b07ea4171 AS builder

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates cmake g++ make zlib1g-dev \
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

FROM scratch AS export
COPY --from=builder /opt/pvpgn/sbin/bnetd /bin/bnetd
COPY --from=builder /opt/pvpgn/etc/pvpgn/ /config/base/
COPY --from=builder /opt/pvpgn/var/pvpgn/files/ /files/
COPY server/common/versioncheck.json /config/base/versioncheck.json
COPY server/common/.env.example /.env.example
COPY server/common/configure-pvpgn.sh /scripts/configure-pvpgn.sh
COPY server/common/set-admin.sh /scripts/set-admin.sh
COPY server/linux/start-server.sh /start-server.sh
COPY server/linux/README.md /README.md
COPY sources/pvpgn-server/LICENSE /LICENSE-PvPGN
