#!/usr/bin/env bash
# Starts the read-only Docker proxy, then trivy-watch as the unprivileged scanner user. Exits as
# soon as any process dies, so Supervisor's watchdog restarts the add-on rather than leaving the
# scanner running against a dead proxy.
#
# Trivy runs as the scanner user, not root, behind the proxy: its own release pipeline was
# compromised in early 2026, and as root it would sit next to the real /run/docker.sock Supervisor
# mounts in.
set -euo pipefail

OPTIONS=/data/options.json
opt() { jq -r --arg key "$1" '.[$key] // empty' "$OPTIONS"; }

TEAMS_WEBHOOK_URL="$(opt teams_webhook_url)"
HC_PING_URL="$(opt hc_ping_url)"
HOST_LABEL="$(opt host_label)"
RUN_AT="$(opt run_at)"
DIGEST_DAY="$(opt digest_day)"
DRY_RUN=0
[ "$(opt dry_run)" = "true" ] && DRY_RUN=1

# Fail closed: a scanner that quietly sends nothing looks exactly like a clean host.
if [ "$DRY_RUN" = 0 ] && { [ -z "$TEAMS_WEBHOOK_URL" ] || [ -z "$HC_PING_URL" ]; }; then
    echo "[ERROR] teams_webhook_url and hc_ping_url are both required, unless dry_run is on."
    exit 1
fi
if [ -z "$HOST_LABEL" ]; then
    echo "[ERROR] host_label is required."
    exit 1
fi

# extra_env is for settings trivy-watch gains later. Refused: what the add-on sets itself, so each
# setting has one source and the secrets can't be overridden from a clear-text option.
RESERVED=" SOCK STATE EXCEPTIONS DOCKER_HOST TMPDIR TEAMS_WEBHOOK_URL HC_PING_URL HOST_LABEL RUN_AT DIGEST_DAY DRY_RUN "
EXTRA=()
while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    key="${entry%%=*}"
    if [[ "$RESERVED" == *" $key "* ]]; then
        echo "[ERROR] extra_env: $key is set by the add-on and can't be overridden."
        exit 1
    fi
    EXTRA+=("$entry")
    echo "[INFO] extra_env: $key"
done < <(jq -r '.extra_env[]?' "$OPTIONS")

# Everything the scanner writes lives under /data. The DB, cache and temporary tarballs are left
# out of backups (backup_exclude in config.yaml); a tarball left by an interrupted scan goes now.
STATE=/data/state
TMPDIR=/data/tmp
mkdir -p "$STATE" "$TMPDIR"
find "$TMPDIR" -mindepth 1 -delete
chown -R scanner:scanner "$STATE" "$TMPDIR"

# The exceptions file is the user's to edit, in this add-on's folder of addon_configs. The script
# treats a missing file as "no exceptions", silently, so it is always there.
EXCEPTIONS=/config/exceptions.txt
if [ ! -f "$EXCEPTIONS" ]; then
    cp /usr/share/trivy-watch/exceptions.txt "$EXCEPTIONS"
    echo "[INFO] Created $EXCEPTIONS; add exceptions there."
fi
chmod 644 "$EXCEPTIONS"

as_scanner() {
    setpriv --reuid=scanner --regid=scanner --init-groups --no-new-privs \
        --inh-caps=-all --bounding-set=-all "$@"
}

# Fail closed: if the scanner user can open the real socket, the proxy is decoration.
if as_scanner test -r /run/docker.sock -o -w /run/docker.sock; then
    echo "[ERROR] the scanner user can access /run/docker.sock directly; refusing to start."
    exit 1
fi
echo "[INFO] The scanner user can't open /run/docker.sock; it reaches Docker only through the proxy."

# Container inspect with the environment redacted; only haproxy (root) connects to this socket.
socat UNIX-LISTEN:/run/inspect-redact.sock,fork,mode=600 EXEC:/usr/local/bin/inspect-redact.sh &
REDACT_PID=$!

mkdir -p /run/docker-ro
haproxy -f /etc/haproxy/scanner.cfg &
HAPROXY_PID=$!
for _ in $(seq 50); do
    [ -S /run/docker-ro/docker.sock ] && [ -S /run/inspect-redact.sock ] && break
    sleep 0.1
done
if [ ! -S /run/docker-ro/docker.sock ] || [ ! -S /run/inspect-redact.sock ]; then
    echo "[ERROR] read-only Docker proxy did not start."
    exit 1
fi

# A clean environment: nothing of the add-on's own (SUPERVISOR_TOKEN included) reaches the
# scanner. trivy-watch derives DOCKER_HOST from SOCK. nice and ionice only cover this add-on's
# work; Docker's own read of an image for an export happens outside it.
as_scanner env -i \
    PATH="$PATH" TZ="${TZ:-UTC}" HOME="$STATE" \
    SOCK=/run/docker-ro/docker.sock STATE="$STATE" TMPDIR="$TMPDIR" EXCEPTIONS="$EXCEPTIONS" \
    TEAMS_WEBHOOK_URL="$TEAMS_WEBHOOK_URL" HC_PING_URL="$HC_PING_URL" HOST_LABEL="$HOST_LABEL" \
    RUN_AT="$RUN_AT" DIGEST_DAY="$DIGEST_DAY" DRY_RUN="$DRY_RUN" \
    "${EXTRA[@]}" \
    nice -n 10 ionice -c 3 /usr/local/bin/trivy-watch &
WATCH_PID=$!

trap 'kill -TERM "$HAPROXY_PID" "$REDACT_PID" "$WATCH_PID" 2>/dev/null' TERM INT
set +e
wait -n "$HAPROXY_PID" "$REDACT_PID" "$WATCH_PID"
STATUS=$?
kill -TERM "$HAPROXY_PID" "$REDACT_PID" "$WATCH_PID" 2>/dev/null
wait
exit "$STATUS"
