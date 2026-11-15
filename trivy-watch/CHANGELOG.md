# Changelog

## 0.76.1.3

- Fixed: a stop or update no longer makes Supervisor log that the add-on "did not handle
  SIGTERM". The add-on already shut its processes down on a stop, but then exited with 143; it now
  exits 0. A process that dies on its own still ends the add-on with an error, so the watchdog
  restarts it.
- Changed: haproxy no longer warns at start that it runs as root without a chroot. It still does,
  on purpose, and now says so in its configuration: it holds the Docker socket, which is root on
  the host whatever user it runs as, and the socket would have to be inside any chroot. The
  read-only allowlist and the unprivileged scanner are what keep Trivy away from the socket.

## 0.76.1.2

- Fixed: Home Assistant offers this release as an update. Add-on-only releases now add a fourth
  number to the Trivy version instead of an `-rN` suffix: Home Assistant compares versions as
  SemVer, so `0.76.1-r1` counted as a pre-release of `0.76.1`, sorted below it, and its Update
  button stayed greyed out (Supervisor would still install it through its API). No change to the
  scanner or the scan script.
- Changed: the add-on's folder is mapped as `app_config`, Supervisor's name for `addon_config`
  since 2026.07, which silences its "legacy map type" warning. Same folder, same `/config`
  mount: `exceptions.txt` stays where it is.

## 0.76.1-r1

- Added: ntfy as a channel, next to Teams or instead of it (**ntfy server URL** and **ntfy access
  token**). Known exploited findings go to topic `alerts` at priority 4, the weekly digest to
  `reports` at priority 2; `NTFY_ALERTS` and `NTFY_REPORTS` in **Extra environment** change the
  topics. A message counts as delivered once one channel took it; a channel that failed fails the
  healthchecks.io check, and is not retried, so the other never gets it twice.
- Changed: **Teams webhook URL** is no longer required. The add-on needs the healthchecks.io ping
  URL and at least one channel, and refuses an ntfy URL without a token or the other way round.
  `NTFY_URL` and `NTFY_TOKEN` are refused in **Extra environment**: the token belongs in its
  password field.
- `trivy-watch.sh` from home-network-containers commit `919c568`.

## 0.76.0-r3

- Fixed: after Docker restarted a container in place (a Docker or host restart with
  `restart: unless-stopped`, outside Home Assistant), the scanner looped on start-up with
  `socat ... "/run/inspect-redact.sock" exists`: the container keeps its `/run`, so the previous
  run's socket was still there. The redaction socket is now removed before listening
  (`unlink-early`). Home Assistant recreates add-on containers, so the add-on itself wasn't hit.

## 0.76.0-r2

- Fixed: the weekly digest listed images as "built date unknown" when their build timestamp
  carried a time-zone offset (for example `+02:00`) instead of `Z`, so their age was never
  checked against the 60-day limit. Offsets are now taken into account.
  `trivy-watch.sh` from home-network-containers commit `bf7cc06`.

## 0.76.0-r1

- Changed: no more daily message per new finding. Teams now gets a finding right away only when
  its CVE is on CISA's Known Exploited Vulnerabilities list, and the weekly digest gains a list of
  images still carrying a fixable finding 30 days after it first showed up, one line per image.
  New and resolved findings are still logged. A missing KEV list (no download for 3 days) fails
  the healthchecks.io check.
- `trivy-watch.sh` from home-network-containers commit `66e9ef9`. After updating, the first
  run sends any known exploited finding already present, once.

## 0.75.0-r2

- Fixed: no finding was ever counted on a host whose saved state was empty, which is every new
  install: the first run saved an empty baseline and every later run reported 0, without failing.
  `trivy-watch.sh` from home-network-containers commit `502e954`. After updating, the next run
  logs all current findings as new (and sends them, unless Dry run is on).

## 0.75.0-r1

- Fixed: the add-on refused to start on hosts where the Docker socket's owner or group had the
  same ID as the scanner user. The scanner user now has fixed IDs (10001) outside the system range.
- Stops with a clear message when the Docker socket is missing (Protection mode still on), instead
  of failing every scan with a 503.

## 0.75.0

First release, on Trivy 0.75.0, with `trivy-watch.sh` from home-network-containers commit
`b0fd10a`.
