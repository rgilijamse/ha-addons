# Changelog

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
