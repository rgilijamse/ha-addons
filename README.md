# Home Assistant add-ons

Add this repository in Home Assistant under **Settings → Add-ons → Add-on Store → ⋮ →
Repositories**:

```
https://github.com/rgilijamse/ha-addons
```

| | Add-on | What it does |
|---|---|---|
| <img src="komodo-periphery/icon.png" alt="" width="48"> | [Komodo Periphery (read-only)](komodo-periphery/) | Lets Komodo Core see this host's add-on containers, without being able to change them. |
| <img src="trivy-watch/icon.png" alt="" width="48"> | [Trivy watch](trivy-watch/) | Scans this host's add-on images for vulnerabilities daily and sends new findings to Teams. |

## How releases work

Images are built by GitHub Actions and pushed to `ghcr.io/rgilijamse/<add-on>-<arch>:<version>`,
so Home Assistant pulls them instead of building on the host. A build is pushed only when an
add-on's `version` in `config.yaml` is new; changing an add-on without bumping its version builds
and tests it but releases nothing.

For `komodo-periphery`, the version *is* the upstream Periphery version, with an optional `-rN`
suffix for add-on-only changes (`2.3.3`, `2.3.3-r1`, ...). Renovate opens a pull request when a new
Periphery release appears; merging it releases the add-on.

`trivy-watch` works the same way with the Trivy version (`0.75.0`, `0.75.0-r1`, ...); a new copy of
its scan script is an add-on-only change. Renovate waits 14 days after a Trivy release before
proposing it.

## License

The files in this repository are [MIT](LICENSE)-licensed. The published images also contain
third-party software under its own license: `komodo-periphery` is built on the official
[Komodo](https://github.com/moghtech/komodo) Periphery image, which is GPL-3.0, and `trivy-watch`
on the official [Trivy](https://github.com/aquasecurity/trivy) image, which is Apache-2.0.
