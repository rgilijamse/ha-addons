# Changelog

## 3.14.10-r1

- The log now shows that uploads arrive, not only problems:
  - the first upload after a (re)start: `First upload since start, from 192.168.x.y: forwarded to
    Home Assistant`, or why it wasn't;
  - an hourly summary: `Last hour: 56 uploads from 192.168.x.y, all forwarded`;
  - a warning when the station goes quiet (`No upload for 10 minutes; check the station`) and a
    line when uploads resume. New option **Warn after quiet minutes** (default 10, 0 = off).

## 3.14.10

- First release. Replaces ChrisRomp's Ecowitt HTTP Proxy add-on with a Python standard-library
  receiver on a pinned `python:3.14.10-alpine3.24` image, so the image can be rebuilt as its base
  gets fixes. Same upload path (`/log/ha`); the port defaults to 4199, so a station already
  pointed at the old add-on on 4199 needs no change.
