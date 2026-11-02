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

The station uploads at the next interval. The add-on log shows "Forwarding to Home Assistant
works" after the first upload that got through.

## Options

| Option | |
|---|---|
| **Webhook ID** | The integration's webhook ID. Anyone who has it can post data into the integration, so it is stored as a password and never logged. |
| **Log level** | `info` logs start-up and changes between working and failing; `debug` logs every upload (size and sender, not the data). |

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
