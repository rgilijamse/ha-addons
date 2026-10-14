#!/usr/bin/env bash
# Container inspect, with the environment redacted. socat runs this once per connection, as root,
# with the HTTP request from haproxy on stdin; haproxy only routes GET /containers/{id}/json here.
# Inspect is needed because `docker logs` (how Periphery fetches logs) inspects first, but its raw
# output includes every container's environment, and Supervisor puts SUPERVISOR_TOKEN in every
# add-on's environment.
set -uo pipefail
export LC_ALL=C   # ${#body} must count bytes, not characters, for Content-Length

respond() {   # status reason body
    printf 'HTTP/1.1 %s %s\r\nContent-Type: application/json\r\nContent-Length: %s\r\nConnection: close\r\n\r\n%s' \
        "$1" "$2" "${#3}" "$3"
    exit 0
}

read -r _method target _ || exit 0
target="${target%$'\r'}"
while IFS= read -r line; do
    [ -z "${line%$'\r'}" ] && break
done

# Checked again here, not only in haproxy: this script is the one place that talks to the real
# socket on Periphery's behalf. The query string (e.g. size=1) is dropped.
path="${target%%\?*}"
if [[ ! "$path" =~ ^(/v1\.[0-9]+)?/containers/[A-Za-z0-9][A-Za-z0-9_.-]*/json$ ]]; then
    respond 403 Forbidden '{"message":"forbidden by the read-only proxy"}'
fi

out="$(curl -sS --unix-socket /run/docker.sock -w '\n%{http_code}' "http://docker$path")" \
    || respond 502 "Bad Gateway" '{"message":"docker socket unreachable"}'
status="${out##*$'\n'}"
body="${out%$'\n'*}"

if [ "$status" = 200 ]; then
    body="$(jq -c 'if .Config.Env then .Config.Env = ["REDACTED=environment hidden by the read-only proxy"] else . end' <<<"$body")" \
        || respond 502 "Bad Gateway" '{"message":"could not redact inspect output"}'
fi
respond "$status" "-" "$body"
