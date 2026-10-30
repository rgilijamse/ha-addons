# Changelog

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
