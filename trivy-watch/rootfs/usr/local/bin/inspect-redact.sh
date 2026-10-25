#!/usr/bin/env bash
# Container inspect, with the environment redacted. socat runs this once per connection, as root,
# with the HTTP request from haproxy on stdin; haproxy only routes GET /containers/{id}/json here.
# trivy-watch inspects every running container for its name and image, but the raw output
# includes the container's environment, and Supervisor puts SUPERVISOR_TOKEN in every add-on's
# environment. Same script as komodo-periphery's; keep the two in step.
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
# socket on the scanner's behalf. The query string (e.g. size=1) is dropped.
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
