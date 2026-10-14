#!/usr/bin/env bash
# Starts the read-only Docker proxy, then Periphery in outbound mode (it dials Core; nothing
# listens on this host). Exits as soon as either process dies, so Supervisor's watchdog restarts
# the add-on rather than leaving Periphery running against a dead proxy.
#
# Periphery runs as the unprivileged periphery user, not root. Komodo can make Periphery run
# shell commands (Repo on_clone/on_pull, Stack pre/post_deploy, Build pre_build), and as root those
# would sit next to the real /run/docker.sock Supervisor mounts in, bypassing the proxy entirely.
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

# The CA file comes from Home Assistant's /ssl folder. update-ca-certificates picks up anything in
# /usr/local/share/ca-certificates ending in .crt, whatever the source file is called.
if [ -n "$CA_CERTIFICATE" ]; then
    if [ ! -f "/ssl/$CA_CERTIFICATE" ]; then
        echo "[ERROR] ca_certificate: /ssl/$CA_CERTIFICATE does not exist."
        exit 1
    fi
    # update-ca-certificates silently skips anything that isn't a PEM certificate.
    if ! CA_SUBJECT="$(openssl x509 -inform PEM -in "/ssl/$CA_CERTIFICATE" -noout -subject 2>/dev/null)"; then
        echo "[ERROR] ca_certificate: /ssl/$CA_CERTIFICATE is not a PEM certificate."
        exit 1
    fi
    echo "[INFO] Trusting CA /ssl/$CA_CERTIFICATE: $CA_SUBJECT"
    mkdir -p /usr/local/share/ca-certificates
    cp "/ssl/$CA_CERTIFICATE" /usr/local/share/ca-certificates/addon-ca.crt
else
    echo "[INFO] No ca_certificate set; trusting public CAs only."
fi
update-ca-certificates >/dev/null

# Everything Periphery writes lives under /data, the only path that survives a restart or an
# update. Its Core public key defaults to <root_directory>/keys/core.pub, so it lands here too.
export PERIPHERY_ROOT_DIRECTORY=/data/periphery
export PERIPHERY_PRIVATE_KEY=file:/data/periphery/keys/periphery.key
mkdir -p /data/periphery/keys
chown -R periphery:periphery /data/periphery

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
export HOME=/data/periphery
# Not used by this add-on; unset so no command Periphery runs inherits it.
unset SUPERVISOR_TOKEN

as_periphery() {
    setpriv --reuid=periphery --regid=periphery --init-groups --no-new-privs \
        --inh-caps=-all --bounding-set=-all "$@"
}

# Fail closed: if the periphery user can open the real socket, the proxy is decoration.
if as_periphery test -r /run/docker.sock -o -w /run/docker.sock; then
    echo "[ERROR] the periphery user can access /run/docker.sock directly; refusing to start."
    exit 1
fi

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

as_periphery periphery &
PERIPHERY_PID=$!

trap 'kill -TERM "$HAPROXY_PID" "$PERIPHERY_PID" 2>/dev/null' TERM INT
set +e
wait -n "$HAPROXY_PID" "$PERIPHERY_PID"
STATUS=$?
kill -TERM "$HAPROXY_PID" "$PERIPHERY_PID" 2>/dev/null
wait
exit "$STATUS"
