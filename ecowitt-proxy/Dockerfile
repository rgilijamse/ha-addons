# Pinned by tag and digest. The tag must match config.yaml's version without its -rN suffix (CI
# checks). A digest-only Renovate PR is how Alpine package fixes arrive under the same tag: bump
# the -rN suffix in config.yaml in that PR, or it builds and releases nothing.
FROM python:3.14.10-alpine3.24@sha256:eb2c62658b8d51bff0acc408504b76521d02030de56a8a3c1e830083e89b89d2

# Upgrade whatever Alpine fixed since the base image was built; tzdata so log times follow the TZ
# Supervisor sets. The add-on uses only the standard library, so pip goes too, with the urllib3,
# msgpack etc. it vendors and the copy ensurepip keeps: that is where the base image's
# Python-package findings live.
RUN apk upgrade --no-cache \
    && apk add --no-cache tzdata \
    && rm -rf /usr/local/lib/python3*/site-packages/pip /usr/local/lib/python3*/site-packages/pip-* \
       /usr/local/lib/python3*/ensurepip /usr/local/bin/pip*

COPY rootfs /

ARG BUILD_VERSION
ARG BUILD_ARCH
LABEL io.hass.type="addon" \
      io.hass.version="${BUILD_VERSION}" \
      io.hass.arch="${BUILD_ARCH}" \
      org.opencontainers.image.source="https://github.com/rgilijamse/ha-addons" \
      org.opencontainers.image.licenses="MIT"

# Supervisor's watchdog restarts the add-on when this turns unhealthy.
HEALTHCHECK --interval=60s --timeout=5s --start-period=10s \
    CMD ["python3", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/', timeout=4)"]

ENTRYPOINT ["/usr/local/bin/ecowitt-proxy"]
