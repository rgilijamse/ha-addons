# Changelog

## 0.75.0-r1

- Fixed: the add-on refused to start on hosts where the Docker socket's owner or group had the
  same ID as the scanner user. The scanner user now has fixed IDs (10001) outside the system range.
- Stops with a clear message when the Docker socket is missing (Protection mode still on), instead
  of failing every scan with a 503.

## 0.75.0

First release, on Trivy 0.75.0, with `trivy-watch.sh` from home-network-containers commit
`b0fd10a`.
