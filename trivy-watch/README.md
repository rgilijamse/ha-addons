# Trivy watch

<!-- Absolute URL: Home Assistant's add-on store shows this file too and can't resolve relative paths. -->
![Trivy watch](https://raw.githubusercontent.com/rgilijamse/ha-addons/main/trivy-watch/logo.png)

![Supports amd64][amd64-shield] ![Supports aarch64][aarch64-shield]

A daily [Trivy](https://trivy.dev) vulnerability scan of every running add-on container on this
host, with only the *new* fixable HIGH and CRITICAL findings sent to a Microsoft Teams channel.

- Official `aquasec/trivy` image, pinned by digest.
- Scans the images that are actually running, add-ons built on this host included, by image ID.
- Weekly digest of images built long ago or on an end-of-life OS: the add-ons whose maintainers
  stopped rebuilding.
- Docker access only through a read-only allowlist proxy, and Trivy runs as an unprivileged user.
- Nothing listens on this host; findings go out to Teams and a healthchecks.io check.

See the **Documentation** tab for setup.

[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
