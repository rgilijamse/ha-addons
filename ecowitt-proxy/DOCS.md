# Ecowitt proxy

## How it works

```
station --HTTP POST /log/ha--> add-on :4199 --> http://supervisor/core/api/webhook/<id> --> Ecowitt integration
```

The add-on forwards each upload through Supervisor's internal API with its own Supervisor token,
so it never needs Home Assistant's external address or certificate.

## Setup

1. Add the **Ecowitt** integration in Home Assistant (Settings → Devices & services). It shows
   a webhook URL ending in a 32-character ID. Copy just the ID.
2. Put that ID in this add-on's **Webhook ID** option and start the add-on.
3. On the station (WS View Plus or the console's *Weather Services* → *Customized*):
   - Protocol: **Ecowitt**
   - Server IP / hostname: your Home Assistant host
   - Path: `/log/ha`
   - Port: `4199` (or whatever you mapped under **Network**)
   - Upload interval: as you like; the integration takes anything from 16 s.

The station uploads at the next interval, and the add-on log shows the result:

```
INFO    Listening on port 8080 for uploads to /log/ha
INFO    Warning when no upload arrives for 10 minutes
INFO    First upload since start, from 192.168.101.189: forwarded to Home Assistant
```

## What the log shows

At the default `info` level the log stays quiet while things work, apart from an hourly summary:

| Line | Meaning |
|---|---|
| `First upload since start, from <ip>: forwarded to Home Assistant` | After every (re)start, the first upload and whether it got through. |
| `Last hour: 56 uploads from <ip>, all forwarded` | Hourly summary; `54 forwarded, 2 not` if some failed, `no uploads` if none came. |
| `Forwarding is failing: Home Assistant answered HTTP 401` (error) | Home Assistant refused or was unreachable; logged once, not per upload. |
| `Forwarding to Home Assistant works again` | The next upload after failures got through. |
| `No upload for 10 minutes; check the station` (warning) | The station went quiet: Wi-Fi, power, or its upload settings. |
| `No upload in the 10 minutes since start; ...` (warning) | Nothing has arrived since start: the station's server, port or path is probably wrong. |
| `Uploads resumed after 23 minutes` | The station is back. |

## Options

| Option | |
|---|---|
| **Webhook ID** | The integration's webhook ID. Anyone who has it can post data into the integration, so it is stored as a password and never logged. |
| **Warn after quiet minutes** | Warn when no upload has arrived for this long (default 10; a station uploads about every minute). 0 turns it off. |
| **Log level** | `info` logs what's in the table above; `debug` also logs every upload (size and sender, not the data). |

## Responses

| Request | Answer |
|---|---|
| `POST /log/ha`, Home Assistant accepted it | `200 OK` |
| `POST /log/ha`, Home Assistant refused or unreachable | `502` |
| `GET /` | `200` (for monitoring) |
| `GET /log/ha` | `405` |
| Anything else | `404`; nothing is forwarded |
| An upload over 64 KiB | `413`; a real one is about 1 KiB |

## Moving from ChrisRomp's Ecowitt HTTP Proxy

Same upload path. If the old add-on's port was 4199 the station needs no change; otherwise map
that port under **Network** here, or change the station. Both add-ons can't hold
port 4199 at once: stop the old one, start this one with the same webhook ID, and check that the
Ecowitt sensors keep updating before uninstalling the old add-on.
