# Changelog

## 2.3.4

- Periphery 2.3.4. Upstream's only change bumps webpki-roots to drop the eMudhra root after an
  intermediate key compromise. Komodo Core reports a version mismatch until the agent matches it.

## 2.3.3-r4

- Container logs work in Komodo. Periphery fetches logs with `docker logs`, which inspects the
  container first, and inspect was blocked. Inspect is now allowed with the container's
  environment replaced by a `REDACTED=...` marker, so `SUPERVISOR_TOKEN` and other add-on secrets
  still never leave the host. Komodo's container detail view works too, minus the environment.

## 2.3.3-r3

- New option **Allow volume prune** (off by default). When on, Komodo's Prune Volumes removes
  unused *anonymous* volumes. Images whose Dockerfile declares a `VOLUME` leave one behind every
  time their container is recreated, and nothing ever attaches them again. Named volumes are never
  removed: the proxy drops Komodo's `all` filter, and only allows the prune on Docker API v1.42 and
  later, where an unfiltered prune leaves named volumes alone.

## 2.3.3-r2

- The **CA certificate** option is now always shown. It used to be hidden behind "Show unused
  optional configuration options", so it was easy to miss, and Periphery then failed with
  `invalid peer certificate: UnknownIssuer`.
- The log now says which CA is trusted (or that none is), and the add-on refuses to start if the
  CA file is not a PEM certificate instead of ignoring it silently.

## 2.3.3-r1

- Periphery now runs as an unprivileged user that can only reach the read-only Docker proxy.
  Before, commands Komodo can have Periphery run (Repo `on_clone`/`on_pull`, Stack
  `pre_deploy`/`post_deploy`, Build `pre_build`) ran as root next to the real Docker socket, so
  they could bypass the proxy. The add-on now refuses to start if that user can open the real
  socket.
- `SUPERVISOR_TOKEN` is removed from Periphery's environment.

## 2.3.3

First release, on Komodo Periphery 2.3.3.
