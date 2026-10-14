ARG PERIPHERY_VERSION
FROM ghcr.io/moghtech/komodo-periphery:${PERIPHERY_VERSION}

RUN apt-get update \
    && apt-get install -y --no-install-recommends haproxy jq \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --no-create-home --home-dir /data/periphery --shell /usr/sbin/nologin periphery

COPY rootfs /

ARG BUILD_VERSION
ARG BUILD_ARCH
LABEL io.hass.type="addon" \
      io.hass.version="${BUILD_VERSION}" \
      io.hass.arch="${BUILD_ARCH}" \
      org.opencontainers.image.source="https://github.com/rgilijamse/ha-addons"

# Replaces upstream's entrypoint.sh: run.sh does its update-ca-certificates itself, as root,
# before dropping to the periphery user.
ENTRYPOINT ["/run.sh"]
CMD []
