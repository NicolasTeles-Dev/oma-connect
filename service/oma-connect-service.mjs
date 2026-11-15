#!/usr/bin/env node

import crypto from 'node:crypto';
import dgram from 'node:dgram';
import fs from 'node:fs';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';

const DISCOVERY_PORT = 45454;
const SERVICE_PORT = 45455;
const PROTOCOL_VERSION = 1;

const args = process.argv.slice(2);
const nameIndex = args.indexOf('--name');
const computerName = nameIndex >= 0 ? args[nameIndex + 1] : os.hostname();
const verbose = args.includes('--verbose');
const computerId = crypto
  .createHash('sha256')
  .update(os.hostname())
  .digest('hex')
  .slice(0, 32);
const pendingChallenges = new Map();
const stateDirectory = path.join(
  process.env.XDG_STATE_HOME || path.join(os.homedir(), '.local', 'state'),
  'oma-connect',
);
const statePath = path.join(stateDirectory, 'paired-device.json');
const approvalPath = path.join(stateDirectory, 'pairing-approval.json');
const heartbeatTimeout = 30_000;

if (args.includes('--forget')) {
  try {
    fs.unlinkSync(statePath);
    console.log('Oma Connect paired device forgotten');
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
    console.log('Oma Connect had no paired device');
  }
  try { fs.unlinkSync(approvalPath); } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }
  process.exit(0);
}

if (args.includes('--approve') || args.includes('--reject')) {
  const action = args.includes('--approve') ? 'approve' : 'reject';
  const actionIndex = args.indexOf(`--${action}`);
  const code = args[actionIndex + 1];
  if (!/^\d{6}$/.test(code || '')) {
    console.error(`Usage: oma-connect-service.mjs --${action} <6-digit-code>`);
    process.exit(2);
  }
  fs.mkdirSync(stateDirectory, { recursive: true, mode: 0o700 });
  fs.writeFileSync(approvalPath, `${JSON.stringify({ code, action })}\n`, { mode: 0o600 });
  fs.chmodSync(approvalPath, 0o600);
  console.log(`Oma Connect pairing ${action} requested for ${code}`);
  process.exit(0);
}

function savePairedDevice(device) {
  fs.mkdirSync(stateDirectory, { recursive: true, mode: 0o700 });
  // Keep the same inode so Quickshell's FileView watcher receives updates
  // when heartbeat or disconnect state changes.
  fs.writeFileSync(statePath, `${JSON.stringify(device, null, 2)}\n`, {
    mode: 0o600,
  });
  fs.chmodSync(statePath, 0o600);
}

function readPairedDevice() {
  try {
    return JSON.parse(fs.readFileSync(statePath, 'utf8'));
  } catch {
    return null;
  }
}

function writePendingPairing(code, device) {
  const state = readPairedDevice() ?? {};
  savePairedDevice({
    ...state,
    connected: false,
    pendingPairing: {
      code,
      device,
      requestedAt: new Date().toISOString(),
    },
  });
}

function markStaleDeviceOffline() {
  const state = readPairedDevice();
  if (!state || state.connected !== true || !state.lastSeen) return;

  if (Date.now() - Date.parse(state.lastSeen) > heartbeatTimeout) {
    savePairedDevice({ ...state, connected: false });
    log('Marked paired device as disconnected');
  }
}

function processApproval() {
  let approval;
  try {
    approval = JSON.parse(fs.readFileSync(approvalPath, 'utf8'));
  } catch {
    return;
  }

  try { fs.unlinkSync(approvalPath); } catch { /* already consumed */ }

  const code = String(approval?.code ?? '');
  const pending = pendingChallenges.get(code);
  if (!pending || pending.expiresAt < Date.now()) {
    log(`Ignored expired or unknown pairing approval ${code}`);
    return;
  }

  pendingChallenges.delete(code);
  if (approval.action === 'reject') {
    const state = readPairedDevice() ?? {};
    const { pendingPairing, ...rest } = state;
    savePairedDevice({ ...rest, connected: false });
    pending.connection.write(`${JSON.stringify({
      type: 'oma.pair.rejected',
      version: PROTOCOL_VERSION,
      reason: 'rejected_on_computer',
    })}\n`);
    log(`Pairing rejected for ${pending.connection.remoteAddress}`);
    return;
  }

  const authToken = crypto.randomBytes(32).toString('hex');
  savePairedDevice({
    connected: true,
    computerId,
    computerName,
    authToken,
    mobileDevice: pending.device,
    pairedAt: new Date().toISOString(),
    lastSeen: new Date().toISOString(),
  });
  pending.connection.write(`${JSON.stringify({
    type: 'oma.pair.accepted',
    version: PROTOCOL_VERSION,
    computerId,
    computerName,
    token: authToken,
  })}\n`);
  log(`Pairing approved for ${pending.connection.remoteAddress}`);
}

function log(...values) {
  if (verbose) console.log(new Date().toISOString(), ...values);
}

function announcement() {
  return Buffer.from(JSON.stringify({
    type: 'oma.announce',
    version: PROTOCOL_VERSION,
    id: computerId,
    name: computerName,
    port: SERVICE_PORT,
  }));
}

function isDiscoveryRequest(data) {
  try {
    const message = JSON.parse(data.toString('utf8'));
    return message?.type === 'oma.discover';
  } catch {
    return false;
  }
}

const server = dgram.createSocket('udp4');
const pairingServer = net.createServer();

server.on('error', (error) => {
  console.error('Oma Connect discovery service error:', error.message);
  server.close();
  process.exitCode = 1;
});

server.on('message', (data, remote) => {
  if (!isDiscoveryRequest(data)) return;
  
  server.send(announcement(), remote.port, remote.address, (error) => {
    if (error) console.error('Could not send announcement:', error.message);
    else log(`Announced to ${remote.address}:${remote.port}`);
  });
});

pairingServer.on('connection', (connection) => {
  let buffer = '';

  connection.setEncoding('utf8');
  connection.on('data', (chunk) => {
    buffer += chunk;
    const messages = buffer.split('\n');
    buffer = messages.pop() ?? '';

    for (const rawMessage of messages) {
      if (!rawMessage.trim()) continue;

      try {
        const message = JSON.parse(rawMessage);
        if (message.type === 'oma.discover') {
          connection.write(`${announcement().toString()}\n`);
          continue;
        }

        if (message.type === 'oma.heartbeat') {
          const paired = readPairedDevice();
          if (!paired?.authToken || message.token !== paired.authToken) {
            connection.write(`${JSON.stringify({
              type: 'oma.error',
              code: 'unauthorized',
            })}\n`);
            continue;
          }
          savePairedDevice({
            connected: true,
            computerId,
            computerName,
            authToken: paired.authToken,
            mobileDevice: message.device ?? {},
            pairedAt: message.pairedAt ?? new Date().toISOString(),
            lastSeen: new Date().toISOString(),
          });
          continue;
        }

        if (message.type !== 'oma.pair.request') continue;

        const code = String(crypto.randomInt(100000, 1000000));
        pendingChallenges.set(code, {
          expiresAt: Date.now() + 120000,
          connection,
          device: message.device ?? {},
        });
        writePendingPairing(code, message.device ?? {});
        connection.write(`${JSON.stringify({
          type: 'oma.pair.pending',
          version: PROTOCOL_VERSION,
          computerId,
          computerName,
        })}\n`);
        log(`Pairing request ${code} is waiting for desktop approval`);
      } catch {
        connection.write(`${JSON.stringify({
          type: 'oma.error',
          code: 'invalid_message',
        })}\n`);
      }
    }
  });
});

server.bind(DISCOVERY_PORT, '0.0.0.0', () => {
  console.log(`Oma Connect discovery service listening on UDP ${DISCOVERY_PORT}`);
  console.log(`Advertising computer as ${computerName} (${computerId})`);
});

pairingServer.listen(SERVICE_PORT, '0.0.0.0', () => {
  console.log(`Oma Connect pairing service listening on TCP ${SERVICE_PORT}`);
});

setInterval(markStaleDeviceOffline, 5_000);
setInterval(processApproval, 500);

function shutdown() {
  server.close(() => process.exit(0));
  pairingServer.close();
}

process.once('SIGINT', shutdown);
process.once('SIGTERM', shutdown);
