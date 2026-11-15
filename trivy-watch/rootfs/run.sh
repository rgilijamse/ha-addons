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
NTFY_URL="$(opt ntfy_url)"
NTFY_TOKEN="$(opt ntfy_token)"
HC_PING_URL="$(opt hc_ping_url)"
HOST_LABEL="$(opt host_label)"
RUN_AT="$(opt run_at)"
DIGEST_DAY="$(opt digest_day)"
DRY_RUN=0
[ "$(opt dry_run)" = "true" ] && DRY_RUN=1

# ntfy needs both: the script skips ntfy when either is empty, which would pass the check below
# with Teams set and lose every ntfy message without a word.
if { [ -n "$NTFY_URL" ] && [ -z "$NTFY_TOKEN" ]; } || { [ -z "$NTFY_URL" ] && [ -n "$NTFY_TOKEN" ]; }; then
    echo "[ERROR] ntfy_url and ntfy_token go together: set both, or neither."
    exit 1
fi
# Fail closed: a scanner that quietly sends nothing looks exactly like a clean host. At least one
# channel (Teams, ntfy or both) and the healthchecks.io check.
if [ "$DRY_RUN" = 0 ] && { [ -z "$HC_PING_URL" ] || { [ -z "$TEAMS_WEBHOOK_URL" ] && [ -z "$NTFY_URL" ]; }; }; then
    echo "[ERROR] hc_ping_url and a channel (teams_webhook_url, or ntfy_url with ntfy_token) are"
    echo "[ERROR] required, unless dry_run is on."
    exit 1
fi
if [ -z "$HOST_LABEL" ]; then
    echo "[ERROR] host_label is required."
    exit 1
fi

# extra_env is for settings trivy-watch gains later. Refused: what the add-on sets itself, so each
# setting has one source and the secrets can't be overridden from a clear-text option.
RESERVED=" SOCK STATE EXCEPTIONS DOCKER_HOST TMPDIR TEAMS_WEBHOOK_URL NTFY_URL NTFY_TOKEN HC_PING_URL HOST_LABEL RUN_AT DIGEST_DAY DRY_RUN "
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

# The exceptions file is the user's to edit, in this add-on's folder of addon_configs (app_config). The script
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

# Without the socket, the check below passes for the wrong reason and every scan fails with a 503.
if [ ! -S /run/docker.sock ]; then
    echo "[ERROR] /run/docker.sock is missing: turn Protection mode off on the Info tab, then restart."
    exit 1
fi

# Fail closed: if the scanner user can open the real socket, the proxy is decoration.
if as_scanner test -r /run/docker.sock -o -w /run/docker.sock; then
    echo "[ERROR] the scanner user can access /run/docker.sock directly; refusing to start."
    echo "[ERROR] socket $(stat -c 'owner %u, group %g, mode %a' /run/docker.sock); scanner $(id scanner)"
    exit 1
fi
echo "[INFO] The scanner user can't open /run/docker.sock; it reaches Docker only through the proxy."

# Container inspect with the environment redacted; only haproxy (root) connects to this socket.
# unlink-early: a container restarted in place (Docker restarting, a host reboot with restart:
# unless-stopped) keeps its /run, so the previous run's socket is still there and socat would
# refuse to listen, and run.sh exits: a restart loop.
socat UNIX-LISTEN:/run/inspect-redact.sock,fork,mode=600,unlink-early EXEC:/usr/local/bin/inspect-redact.sh &
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
    TEAMS_WEBHOOK_URL="$TEAMS_WEBHOOK_URL" NTFY_URL="$NTFY_URL" NTFY_TOKEN="$NTFY_TOKEN" \
    HC_PING_URL="$HC_PING_URL" HOST_LABEL="$HOST_LABEL" \
    RUN_AT="$RUN_AT" DIGEST_DAY="$DIGEST_DAY" DRY_RUN="$DRY_RUN" \
    "${EXTRA[@]}" \
    nice -n 10 ionice -c 3 /usr/local/bin/trivy-watch &
WATCH_PID=$!

# A stop (Supervisor sends TERM) interrupts wait -n with status 143; exit 0 then, or Supervisor
# logs that the add-on "did not handle SIGTERM". A process that died on its own still exits
# non-zero, for the watchdog.
STOPPING=0
trap 'STOPPING=1; kill -TERM "$HAPROXY_PID" "$REDACT_PID" "$WATCH_PID" 2>/dev/null' TERM INT
set +e
wait -n "$HAPROXY_PID" "$REDACT_PID" "$WATCH_PID"
STATUS=$?
kill -TERM "$HAPROXY_PID" "$REDACT_PID" "$WATCH_PID" 2>/dev/null
wait
if [ "$STOPPING" = 1 ]; then
    exit 0
fi
exit "$STATUS"
