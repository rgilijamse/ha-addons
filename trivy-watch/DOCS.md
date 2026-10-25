# Trivy watch

Scans every image a running container on this host uses, once a day, with
[Trivy](https://trivy.dev), and reports to a Microsoft Teams channel:

- **New findings only.** Fixable HIGH and CRITICAL vulnerabilities that weren't there in the
  previous scan. The first scan records a baseline and sends nothing.
- **A weekly digest** of images built more than 60 days ago or on an end-of-life OS, exceptions
  due for review, totals, and whether a newer Trivy is out.

Most findings in add-on images can only be fixed by the add-on's maintainer, so a finding usually
means "update the add-on when a new version is out", and the digest tells you which add-ons have
stopped getting new versions. Findings that have disappeared are logged as `RESOLVED`, so the
add-on log is the history.

The scan logic is `trivy-watch.sh`, copied unchanged from the setup that scans other Docker hosts.
The add-on only wraps it.

## What the scanner can and can't do

Trivy needs to read every image, so this add-on needs Docker access. It gets it the same way
[Komodo Periphery (read-only)](https://github.com/rgilijamse/ha-addons/tree/main/komodo-periphery)
does: through a proxy inside the add-on that
allows six read calls and refuses everything else with a 403.

- **Allowed:** list running containers, inspect a container (with its environment replaced by a
  `REDACTED=...` marker, since Supervisor puts a `SUPERVISOR_TOKEN` in every add-on's
  environment), and inspect, read the history of and **export an image by its ID**.
- **Refused:** everything else. No starting, stopping or creating containers, no exec or attach,
  no copying files out of containers, no images by name.

An image export is a full copy of that image's filesystem, so the scanner *can* read everything
an image contains. It can't read an add-on's configuration or data: those live in volumes, not in
the image.

Trivy and the scan script run as an unprivileged user that can reach only the proxy, with no
capabilities and with only the settings below in their environment. The add-on checks on every
start that this user can't open the real Docker socket, and refuses to run if it can.

**What leaves the host:** new findings and the digest to your Teams webhook, a start, success or
failure ping per scan to your healthchecks.io check, and Trivy's own downloads of its
vulnerability database (from `mirror.gcr.io`) and of the latest release number (from GitHub).
Nothing listens on this host.

## Requirements

- **Protection mode off.** The add-on needs `docker_api` access, which Supervisor only grants
  with protection mode off. The add-on's startup script and the proxy run as root and can still
  reach the real socket; Trivy and the scan script cannot. Weigh that before installing.
- About **2 GB of free disk** for Trivy's database and cache, plus room for one image at a time:
  when an image has a layer Trivy hasn't seen yet, Docker exports the whole image as a temporary
  file (several GB for a large add-on such as Frigate). The database, cache and temporary files are
  left out of Home Assistant backups.

## Setup

1. In Teams, create an incoming webhook for the channel the findings should go to.
2. On [healthchecks.io](https://healthchecks.io), create a check with a daily period and a grace
   time of a few hours. A scanner that has stopped looks exactly like a host with nothing to
   report; the check is what tells the two apart.
3. Set **Teams webhook URL** and **healthchecks.io ping URL**. The add-on refuses to start
   without them, unless **Dry run** is on.
4. Start the add-on. The first scan runs at **Run at** (05:00 by default) and records a baseline.
   To run it right away, add `RUN_ON_START=1` to **Extra environment** for one start.

To try it without sending anything, turn on **Dry run** and add `RUN_ON_START=1`: the log then
shows the scan and the message it would have sent.

## Options

| Option | Required | Meaning |
|---|---|---|
| `teams_webhook_url` | yes | Teams incoming webhook for findings and the digest. |
| `hc_ping_url` | yes | healthchecks.io ping URL, without `/start` or `/fail`. |
| `host_label` | yes | Name of this host in the messages (default `hassio`). |
| `run_at` | yes | Daily scan time, `HH:MM` in Home Assistant's time zone (default `05:00`). |
| `digest_day` | yes | Day of the weekly digest, 1 = Monday ... 7 = Sunday (default 1). |
| `extra_env` | no | `KEY=VALUE` settings passed to the scan script as they are, for example `STALE_DAYS=90` or `RUN_ON_START=1`. Settings the add-on sets itself are refused. This option is shown in clear text: never put a secret here. |
| `dry_run` | no | Log what would be sent instead of sending it, and ping nothing. |

## Exceptions

Images you have decided to live with go in `exceptions.txt` in this add-on's folder of
`addon_configs` (reachable with the Samba or File editor add-on). They are still scanned, but
never alerted on, and the weekly digest lists each one when its review date has passed:

```
# <image reference, shell glob>  <review date YYYY-MM-DD>  <reason>
ghcr.io/example/addon-*  2027-01-31  upstream fix pending, LAN only
```

The add-on creates the file, with this format in its header, on its first start.

## Log

The scan script logs each run, every new finding (`NEW`) and every finding that disappeared
(`RESOLVED`, with the date it was first seen). The proxy logs every refused Docker call as a `403`
line, except one expected refusal per image per scan: Trivy first looks an image ID up as if it
were a Docker Hub name, and only uses the plain ID after that fails.
