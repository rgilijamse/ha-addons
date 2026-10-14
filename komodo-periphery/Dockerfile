ARG PERIPHERY_VERSION
FROM ghcr.io/moghtech/komodo-periphery:${PERIPHERY_VERSION}

RUN apt-get update \
    && apt-get install -y --no-install-recommends haproxy jq \
    && rm -rf /var/lib/apt/lists/*

COPY rootfs /

ARG BUILD_VERSION
ARG BUILD_ARCH
LABEL io.hass.type="addon" \
      io.hass.version="${BUILD_VERSION}" \
      io.hass.arch="${BUILD_ARCH}" \
      org.opencontainers.image.source="https://github.com/rgilijamse/ha-addons"

# Replaces upstream's entrypoint.sh; run.sh still calls it, so update-ca-certificates keeps
# running on every start.
ENTRYPOINT ["/run.sh"]
CMD []
