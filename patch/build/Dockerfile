FROM debian:bookworm-slim AS builder

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates clang git mingw-w64 \
    && rm -rf /var/lib/apt/lists/*

COPY sources/w3l /src
COPY patch/build/w3l-mingw.patch /build/w3l-mingw.patch
COPY patch/build/w3l-game-main.c /build/w3l-game-main.c

WORKDIR /src

RUN rm -f /src/.git \
    && find /src -type f -not -path '*/.git/*' -exec sed -i 's/\r$//' {} + \
    && git apply --check /build/w3l-mingw.patch \
    && git apply /build/w3l-mingw.patch \
    && mkdir -p /out \
    && clang --target=i686-w64-mingw32 --gcc-toolchain=/usr -m32 -Os -fms-extensions -fasm-blocks \
         -DWIN32 -DNDEBUG -D_WINDOWS -DUNICODE -D_UNICODE -mwindows -nostartfiles \
         exe/w3l.c exe/nodefaultlib.c \
         -L/usr/lib/gcc/i686-w64-mingw32/12-win32 \
         -Wl,--entry,_WinMain@16 -Wl,--image-base,0x7E540000 -Wl,--disable-dynamicbase -Wl,--disable-nxcompat \
         -o /out/w3l.exe \
    && clang --target=i686-w64-mingw32 --gcc-toolchain=/usr -m32 -O2 -fms-extensions -fasm-blocks \
         -DWIN32 -DNDEBUG -DDEBUG -D_WINDOWS -D_USRDLL -DDLL_EXPORTS -shared \
         dll/w3lh.c dll/functions.c -x c++ dll/dep.c -x c dll/nodefaultlib.c /build/w3l-game-main.c \
         -L/usr/lib/gcc/i686-w64-mingw32/12-win32 \
         -lshlwapi -Wl,--kill-at -Wl,--image-base,0x76290000 -Wl,--disable-dynamicbase \
         -o /out/w3lh.dll \
    && clang --target=i686-w64-mingw32 --gcc-toolchain=/usr -m32 -O2 -fms-extensions -fasm-blocks \
         -DWIN32 -DNDEBUG -DDEBUG -D_WINDOWS -D_USRDLL -DDLL_EXPORTS -shared \
         dll_27a/w3lh.c dll_27a/functions.c -x c++ dll_27a/dep.c -x c dll_27a/nodefaultlib.c /build/w3l-game-main.c \
         -L/usr/lib/gcc/i686-w64-mingw32/12-win32 \
         -lshlwapi -Wl,--kill-at -Wl,--image-base,0x76290000 -Wl,--disable-dynamicbase \
         -o /out/wl27.dll \
    && i686-w64-mingw32-strip /out/*.exe /out/*.dll \
    && i686-w64-mingw32-objdump -f /out/w3l.exe | grep -q 'architecture: i386' \
    && i686-w64-mingw32-objdump -f /out/w3lh.dll | grep -q 'architecture: i386' \
    && i686-w64-mingw32-objdump -f /out/wl27.dll | grep -q 'architecture: i386' \
    && i686-w64-mingw32-objdump -p /out/w3lh.dll | grep -q 'GameMain' \
    && i686-w64-mingw32-objdump -p /out/wl27.dll | grep -q 'GameMain'

FROM scratch AS export
COPY --from=builder /out/ /
