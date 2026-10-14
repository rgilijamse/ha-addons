# Komodo Periphery (read-only)

![Supports amd64][amd64-shield] ![Supports aarch64][aarch64-shield]

A [Komodo](https://komo.do) Periphery agent for Home Assistant OS that lets Komodo Core *see*
the add-on containers on this host without being able to change them.

- Official `ghcr.io/moghtech/komodo-periphery` image, pinned to an exact version.
- Connects out to Core (Komodo v2), so no port is opened on this host.
- Docker access only through a read-only allowlist proxy: no start/stop, exec, file copy or
  container inspect.
- Trusts a private CA from Home Assistant's `/ssl` folder.

See the **Documentation** tab for setup.

[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
