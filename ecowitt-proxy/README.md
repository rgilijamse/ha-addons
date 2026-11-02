# Ecowitt proxy

<!-- Absolute URL: Home Assistant's add-on store shows this file too and can't resolve relative paths. -->
![Ecowitt proxy](https://raw.githubusercontent.com/rgilijamse/ha-addons/main/ecowitt-proxy/logo.png)

![Supports amd64][amd64-shield] ![Supports aarch64][aarch64-shield]

Lets an Ecowitt (Fine Offset) weather station feed Home Assistant's
[Ecowitt integration](https://www.home-assistant.io/integrations/ecowitt/) when Home Assistant
only serves HTTPS. The station's console can only upload over plain HTTP, so this add-on takes the
upload and hands it, unchanged, to the integration's webhook.

- Python standard library only, on a pinned official `python` Alpine image without pip: nothing
  extra to collect CVEs.
- A mapped port rather than host networking, and the receiver runs as `nobody`.
- Logs only when forwarding starts or stops working, not every upload.

See the **Documentation** tab for setup.

Inspired by [ChrisRomp/addon-ecowitt-proxy](https://github.com/ChrisRomp/addon-ecowitt-proxy)
(Apache-2.0); this is a rewrite that keeps its upload path.

[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
