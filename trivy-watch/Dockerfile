# Pinned by digest: nothing updates Trivy but a deliberate bump, and its own release pipeline was
# compromised in early 2026, so take releases at least two weeks old (Renovate waits 14 days). The
# tag must match config.yaml's version without its -rN suffix; CI checks.
FROM aquasec/trivy:0.75.0@sha256:af6acf9a6b85dfe389a1941505c0ce9efef52a4719635e1a962f022a3d855daa

# bash and socat for inspect-redact.sh; setpriv and ionice (util-linux) for run.sh; curl, jq and
# tzdata for trivy-watch, which then skips installing them at start. The scanner user gets fixed
# IDs well above the host's system range: Alpine's next free system IDs (101/102) can be the owner
# or group of the Docker socket Supervisor mounts in, which would hand the scanner direct access.
RUN apk add --no-cache bash curl haproxy jq setpriv socat tzdata util-linux-misc \
    && addgroup -S -g 10001 scanner \
    && adduser -S -D -H -u 10001 -G scanner -h /data/state -s /sbin/nologin scanner

COPY rootfs /

ARG BUILD_VERSION
ARG BUILD_ARCH
LABEL io.hass.type="addon" \
      io.hass.version="${BUILD_VERSION}" \
      io.hass.arch="${BUILD_ARCH}" \
      org.opencontainers.image.source="https://github.com/rgilijamse/ha-addons" \
      org.opencontainers.image.licenses="MIT AND Apache-2.0"

ENTRYPOINT ["/run.sh"]
CMD []
