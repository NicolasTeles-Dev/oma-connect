# Oma Connect service

This directory contains the Linux-side service distributed with the Omarchy
plugin. The first version provides only local-network discovery.

## Run it manually

```sh
node service/oma-connect-service.mjs --name "My Omarchy" --verbose
```

The service listens on UDP port `45454` and answers Flutter discovery messages
with an `oma.announce` response. It uses only Node.js built-ins and has no npm
dependencies.

The service is intentionally separate from the QML panel. The panel will later
read connection state from this service, while the service will own pairing,
authentication, file transfer, and computer actions.

## Protocol

Request:

```json
{"type":"oma.discover","version":1}
```

Response:

```json
{
  "type": "oma.announce",
  "version": 1,
  "id": "stable-computer-id",
  "name": "My Omarchy",
  "port": 45455
}
```
