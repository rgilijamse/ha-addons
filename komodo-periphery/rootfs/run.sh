#!/usr/bin/env bash
# Starts the read-only Docker proxy, then Periphery in outbound mode (it dials Core; nothing
# listens on this host). Exits as soon as either process dies, so Supervisor's watchdog restarts
# the add-on rather than leaving Periphery running against a dead proxy.
set -euo pipefail

OPTIONS=/data/options.json
opt() { jq -r --arg key "$1" '.[$key] // empty' "$OPTIONS"; }

CORE_ADDRESS="$(opt core_address)"
CONNECT_AS="$(opt connect_as)"
ONBOARDING_KEY="$(opt onboarding_key)"
CA_CERTIFICATE="$(opt ca_certificate)"
LOG_LEVEL="$(opt log_level)"

if [ -z "$CORE_ADDRESS" ] || [ -z "$CONNECT_AS" ]; then
    echo "[ERROR] core_address and connect_as are both required."
    exit 1
fi

# The CA file comes from Home Assistant's /ssl folder. Upstream's entrypoint.sh runs
# update-ca-certificates, which picks up anything in /usr/local/share/ca-certificates ending in
# .crt, whatever the source file is called.
if [ -n "$CA_CERTIFICATE" ]; then
    if [ ! -f "/ssl/$CA_CERTIFICATE" ]; then
        echo "[ERROR] ca_certificate: /ssl/$CA_CERTIFICATE does not exist."
        exit 1
    fi
    mkdir -p /usr/local/share/ca-certificates
    cp "/ssl/$CA_CERTIFICATE" /usr/local/share/ca-certificates/addon-ca.crt
fi

# Everything Periphery writes lives under /data, the only path that survives a restart or an
# update. Its Core public key defaults to <root_directory>/keys/core.pub, so it lands here too.
export PERIPHERY_ROOT_DIRECTORY=/data/periphery
export PERIPHERY_PRIVATE_KEY=file:/data/periphery/keys/periphery.key
mkdir -p /data/periphery/keys

export PERIPHERY_CORE_ADDRESS="$CORE_ADDRESS"
export PERIPHERY_CONNECT_AS="$CONNECT_AS"
if [ -n "$ONBOARDING_KEY" ]; then
    export PERIPHERY_ONBOARDING_KEY="$ONBOARDING_KEY"
fi
export PERIPHERY_DISABLE_TERMINALS=true
export PERIPHERY_DISABLE_CONTAINER_TERMINALS=true
export PERIPHERY_LOGGING_LEVEL="${LOG_LEVEL:-info}"
export PERIPHERY_LOGGING_ANSI=false
export DOCKER_HOST=unix:///run/docker-ro/docker.sock

mkdir -p /run/docker-ro
haproxy -f /etc/haproxy/docker-ro.cfg &
HAPROXY_PID=$!
for _ in $(seq 50); do
    [ -S /run/docker-ro/docker.sock ] && break
    sleep 0.1
done
if [ ! -S /run/docker-ro/docker.sock ]; then
    echo "[ERROR] read-only Docker proxy did not start."
    exit 1
fi

entrypoint.sh periphery &
PERIPHERY_PID=$!

trap 'kill -TERM "$HAPROXY_PID" "$PERIPHERY_PID" 2>/dev/null' TERM INT
set +e
wait -n "$HAPROXY_PID" "$PERIPHERY_PID"
STATUS=$?
kill -TERM "$HAPROXY_PID" "$PERIPHERY_PID" 2>/dev/null
wait
exit "$STATUS"
