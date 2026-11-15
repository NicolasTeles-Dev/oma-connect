#!/usr/bin/env node

import crypto from 'node:crypto';
import dgram from 'node:dgram';
import os from 'node:os';

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

server.bind(DISCOVERY_PORT, '0.0.0.0', () => {
  console.log(`Oma Connect discovery service listening on UDP ${DISCOVERY_PORT}`);
  console.log(`Advertising computer as ${computerName} (${computerId})`);
});

function shutdown() {
  server.close(() => process.exit(0));
}

process.once('SIGINT', shutdown);
process.once('SIGTERM', shutdown);
