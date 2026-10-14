# Komodo Periphery (read-only)

Runs a [Komodo](https://komo.do) Periphery agent on your Home Assistant host, so Komodo Core can
show the add-on containers here (status, CPU and memory, logs, images) next to your other servers.

It is **read-only by construction**. Supervisor owns every container on this host, so Komodo
should watch them and never change them. Periphery reaches Docker only through a proxy inside
the add-on that allows a short list of read calls. Everything else is refused with a 403, both
for Periphery and for anyone using it through Komodo:

- starting, stopping, restarting or removing containers;
- exec, attach and terminals;
- copying files out of containers, or exporting containers and images;
- **container environments**. Inspect is allowed, but the add-on replaces each container's
  environment with a `REDACTED=...` marker before Komodo sees it: Supervisor puts a
  `SUPERVISOR_TOKEN` in every add-on's environment. Everything else in Komodo's container view,
  logs included, works as on a normal Docker host.

Commands Komodo can have Periphery run (Repo `on_clone`/`on_pull`, Stack
`pre_deploy`/`post_deploy`, Build `pre_build`) run as an unprivileged user that can reach only the
proxy, never the real Docker socket. The add-on checks this on every start and refuses to run if
that user can open the real socket. `SUPERVISOR_TOKEN` is removed from Periphery's environment.

Deploying Stacks or Deployments to this server does not work, and is not meant to.

### The one opt-in write: volume prune

Images whose Dockerfile declares a `VOLUME` get a new anonymous volume every time their container
is recreated, and Supervisor recreates containers on every add-on start and update. Docker never
attaches an old anonymous volume to a new container, so they pile up unused. With **Allow volume
prune** on, Komodo's **Prune Volumes** removes them.

It removes only unused *anonymous* volumes. Komodo asks for all unused volumes, named ones
included; the proxy drops that part of the request, so Docker falls back to its default of
anonymous only. Named volumes are never removed. Image prune stays blocked: Supervisor removes a
stopped add-on's container, so its image looks unused and a prune would delete it.

## Requirements

- **Protection mode off.** The add-on needs `docker_api` access, which Supervisor only grants
  with protection mode off. The add-on's own startup script and the proxy run as root and can
  still reach the real socket; Periphery and everything it runs cannot. Weigh that before
  installing.
- Komodo Core v2. Periphery connects **out** to Core, so nothing listens on this host and no port
  is opened.

## Setup

1. In Komodo Core, create a Server (for example `homeassistant`). Leave its address empty;
   Periphery connects to Core, not the other way round.
2. If Core's certificate is issued by a private CA, put the CA certificate in Home Assistant's
   `/ssl` folder (with the Samba or File editor add-on) and set **CA certificate** to its file
   name.
3. Set **Core address** to Core's WebSocket address, for example
   `wss://komodo.example.lan:9120`. Use a host name that is in Core's certificate.
4. Set **Connect as** to the Server's name from step 1.
5. Start the add-on and open its log. Periphery prints `Public Key: ...` on its first start.
   If Core pins a Periphery public key (globally or per Server), paste that key into the Server's
   **Periphery Public Key** field in Core. Until then Core turns the connection away and
   Periphery retries several times a second, so do this right after the first start.

The keypair is kept in the add-on's data, so it survives restarts and updates. Uninstalling the
add-on deletes it; a reinstall prints a new key to paste again.

## Options

| Option | Required | Meaning |
|---|---|---|
| `core_address` | yes | Core's WebSocket address. |
| `connect_as` | yes | Name of the Server in Core. |
| `onboarding_key` | no | Lets Core create the Server on first connect. Not needed when it already exists. |
| `ca_certificate` | no | File name in `/ssl` of a CA certificate to trust. |
| `allow_volume_prune` | no | Let Komodo prune unused anonymous volumes (off by default). |
| `log_level` | no | `trace`, `debug`, `info` (default), `warn` or `error`. |

## Troubleshooting

`invalid peer certificate: UnknownIssuer` means Periphery doesn't trust Core's certificate. Check
the first lines of the log: `Trusting CA ...` should name your CA (the root, not an intermediate).
If it says `No ca_certificate set`, set **CA certificate**.

## Log

Denied Docker calls and volume prunes are logged by the proxy; denials show as `403` lines.
Allowed reads are not logged.
