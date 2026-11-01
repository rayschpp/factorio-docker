ARG FACTORIO_VERSION=2.1.23

FROM debian:stable-slim AS builder

ARG FACTORIO_VERSION

RUN apt-get update && apt-get install -y --no-install-recommends wget xz-utils ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN wget --no-verbose "https://factorio.com/get-download/${FACTORIO_VERSION}/headless/linux64" -O /tmp/factorio.tar.xz

RUN mkdir -p /opt/factorio

RUN tar -xf /tmp/factorio.tar.xz \
    -C /opt/factorio \
    --strip-components=1

RUN mkdir -p /opt/factorio/saves /opt/factorio/mods /opt/factorio/config

RUN LOADER="/lib64/ld-linux-x86-64.so.2" \
    && mkdir -p /opt/factorio-libs$(dirname "$LOADER") \
    && cp -L "$LOADER" /opt/factorio-libs"$LOADER" \
    && ldd /opt/factorio/bin/x64/factorio | awk '/=>/ {print $3}' | while read lib; do \
        mkdir -p /opt/factorio-libs$(dirname "$lib"); \
        cp -L "$lib" /opt/factorio-libs"$lib"; \
    done

FROM scratch
WORKDIR /factorio
VOLUME ["/factorio/saves", "/factorio/mods"]
EXPOSE 34197/udp
ENTRYPOINT [ "/factorio/bin/x64/factorio" ]
CMD [ "--start-server-load-latest" ]

COPY --from=builder /opt/factorio-libs /
COPY --from=builder /opt/factorio /factorio
