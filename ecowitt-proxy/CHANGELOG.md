# Changelog

## 3.14.10

- First release. Replaces ChrisRomp's Ecowitt HTTP Proxy add-on with a Python standard-library
  receiver on a pinned `python:3.14.10-alpine3.24` image, so the image can be rebuilt as its base
  gets fixes. Same upload path (`/log/ha`); the port defaults to 4199, so a station already
  pointed at the old add-on on 4199 needs no change.
