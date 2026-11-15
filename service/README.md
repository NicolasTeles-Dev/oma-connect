# Oma Connect service

This directory contains the Linux-side service distributed with the Omarchy
plugin. The first version provides only local-network discovery.

## Run it manually

```sh
node service/oma-connect-service.mjs --name "My Omarchy" --verbose
```

The service listens on UDP port `45454` and answers Flutter discovery messages
with an `oma.announce` response. It also listens on TCP port `45455` for
pairing and authenticated messages. It uses only Node.js built-ins and has no
npm dependencies.

The service is intentionally separate from the QML panel. The panel reads
connection state from this service and is the local trust boundary for pairing.

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

The service creates a temporary six-digit approval code and shows it in the
Omarchy panel. It does not send the code to the phone:

```json
{"type":"oma.pair.pending","version":1,"computerId":"...","computerName":"My Omarchy"}
```

The user must explicitly approve the request in the Omarchy panel. The panel
signals approval with:

```json
node service/oma-connect-service.mjs --approve 482913
```

The panel can also reject a request:

```json
node service/oma-connect-service.mjs --reject 482913
```

The pending TCP connection is accepted only after that local approval. The
service then returns a one-time pairing token to the waiting phone and stores
the paired device and token at `~/.local/state/oma-connect/paired-device.json`
with restrictive permissions. Heartbeats must include this token; unauthenticated
heartbeats are rejected. Pending requests expire after two minutes.

The mobile app sends `oma.heartbeat` messages while it is running. The service
updates `lastSeen` on each heartbeat so the panel can distinguish a live app
from a device that was paired previously. If no heartbeat arrives for 30
seconds, the service marks the device as disconnected.

Authenticated actions use the same paired token. The first supported action is
screen locking:

```json
{"type":"oma.action.request","version":1,"requestId":"...","token":"...","action":"lock.screen"}
```

The response is an `oma.action.response` with `ok: true` after
`omarchy-system-lock` succeeds.

The service also accepts `--forget` to remove the saved paired device. The
plugin uses this command from its panel instead of requiring a terminal.
