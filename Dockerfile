ARG FACTORIO_VERSION=2.1.19

FROM debian:bookworm-slim AS builder

ARG FACTORIO_VERSION

RUN apt-get update && apt-get install -y --no-install-recommends wget xz-utils \
    && rm -rf /var/lib/apt/lists/*

# --- Exclude patterns (edit here) ---
RUN cat > /tmp/excludes.txt <<'EOF'
*/*.txt
*/*.example.json
factorio/data/base/campaigns/*
factorio/data/base/scenarios/*
EOF

RUN wget --no-verbose --no-check-certificate "https://www.factorio.com/get-download/${FACTORIO_VERSION}/headless/linux64" -O /tmp/factorio.tar.xz

RUN mkdir -p /opt/factorio

RUN tar -tf /tmp/factorio.tar.xz | grep -v '/locale/[^e]' > /tmp/include.txt

RUN tar -xf /tmp/factorio.tar.xz \
    -C /opt/factorio \
    --strip-components=1 \
    --exclude-from=/tmp/excludes.txt

RUN find /opt/factorio -path '*/locale/*' ! -path '*/locale/en*' -exec rm -rf {} +

RUN rm /tmp/factorio.tar.xz /tmp/include.txt /tmp/excludes.txt

RUN mkdir -p /opt/factorio/saves /opt/factorio/mods /opt/factorio/config

RUN LOADER="/lib64/ld-linux-x86-64.so.2" \
    && mkdir -p /opt/factorio-libs$(dirname "$LOADER") \
    && cp -L "$LOADER" /opt/factorio-libs"$LOADER" \
    && ldd /opt/factorio/bin/x64/factorio | awk '/=>/ {print $3}' | while read lib; do \
        mkdir -p /opt/factorio-libs$(dirname "$lib"); \
        cp -L "$lib" /opt/factorio-libs"$lib"; \
    done

FROM scratch

COPY --from=builder /opt/factorio /factorio
COPY --from=builder /opt/factorio-libs /

WORKDIR /factorio

VOLUME ["/factorio/saves", "/factorio/mods"]

EXPOSE 34197/udp

ENTRYPOINT ["/factorio/bin/x64/factorio"]
CMD ["--start-server-load-latest", "--server-settings", "/factorio/data/server-settings.json"]
