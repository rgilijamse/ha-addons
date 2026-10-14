# Home Assistant add-ons

Add this repository in Home Assistant under **Settings → Add-ons → Add-on Store → ⋮ →
Repositories**:

```
https://github.com/rgilijamse/ha-addons
```

| Add-on | What it does |
|---|---|
| [Komodo Periphery (read-only)](komodo-periphery/) | Lets Komodo Core see this host's add-on containers, without being able to change them. |

## How releases work

Images are built by GitHub Actions and pushed to `ghcr.io/rgilijamse/<add-on>-<arch>:<version>`,
so Home Assistant pulls them instead of building on the host. A build is pushed only when an
add-on's `version` in `config.yaml` is new; changing an add-on without bumping its version builds
and tests it but releases nothing.

For `komodo-periphery`, the version *is* the upstream Periphery version, with an optional `-rN`
suffix for add-on-only changes (`2.3.3`, `2.3.3-r1`, ...). Renovate opens a pull request when a new
Periphery release appears; merging it releases the add-on.
