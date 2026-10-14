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
- **container inspect**. Inspect returns a container's environment, and Supervisor puts a
  `SUPERVISOR_TOKEN` in every add-on's environment. Komodo's container detail view therefore
  shows less here than on a normal Docker host.

Deploying Stacks or Deployments to this server does not work, and is not meant to.

## Requirements

- **Protection mode off.** The add-on needs `docker_api` access, which Supervisor only grants
  with protection mode off. The proxy limits what Periphery can do with it, but the container
  itself can still reach the real socket. Weigh that before installing.
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
   **Periphery Public Key** field in Core.

The keypair is kept in the add-on's data, so it survives restarts and updates. Uninstalling the
add-on deletes it; a reinstall prints a new key to paste again.

## Options

| Option | Required | Meaning |
|---|---|---|
| `core_address` | yes | Core's WebSocket address. |
| `connect_as` | yes | Name of the Server in Core. |
| `onboarding_key` | no | Lets Core create the Server on first connect. Not needed when it already exists. |
| `ca_certificate` | no | File name in `/ssl` of a CA certificate to trust. |
| `log_level` | no | `trace`, `debug`, `info` (default), `warn` or `error`. |

## Log

Denied Docker calls are logged by the proxy as `403` lines. A few at startup or when someone
opens a container's detail page in Komodo are expected. Allowed calls are not logged.
