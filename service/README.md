# Oma Connect service

This directory contains the Linux-side service distributed with the Omarchy
plugin. The first version provides only local-network discovery.

## Run it manually

```sh
node service/oma-connect-service.mjs --name "My Omarchy" --verbose
```

The service listens on UDP port `45454` and answers Flutter discovery messages
with an `oma.announce` response. It also listens on TCP port `45455` for the
first pairing request. It uses only Node.js built-ins and has no npm dependencies.

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

Pairing request:

```json
{"type":"oma.pair.request","version":1,"device":{"name":"My phone"}}
```

The service replies with a temporary confirmation code:

```json
{"type":"oma.pair.challenge","version":1,"computerId":"...","computerName":"My Omarchy","code":"482913"}
```

Confirmation request:

```json
{"type":"oma.pair.confirm","version":1,"code":"482913"}
```

The code expires after two minutes and can be confirmed once.
