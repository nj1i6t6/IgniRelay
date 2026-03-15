'use strict';

const nacl = require('tweetnacl');

/**
 * Verify Ed25519 signature on a mesh event.
 *
 * @param {string} pubKeyHex  - 32-byte public key as hex string
 * @param {string} payloadB64 - Base64-encoded payload bytes
 * @param {string} signatureB64 - Base64-encoded 64-byte signature
 * @returns {boolean} true if signature is valid
 */
function verifyEventSignature(pubKeyHex, payloadB64, signatureB64) {
  try {
    const pubKeyBytes = hexToBytes(pubKeyHex);
    const payloadBytes = Buffer.from(payloadB64, 'base64');
    const sigBytes = Buffer.from(signatureB64, 'base64');

    if (pubKeyBytes.length !== 32 || sigBytes.length !== 64) {
      return false;
    }

    return nacl.sign.detached.verify(
      new Uint8Array(payloadBytes),
      new Uint8Array(sigBytes),
      new Uint8Array(pubKeyBytes)
    );
  } catch (_) {
    return false;
  }
}

function hexToBytes(hex) {
  const bytes = [];
  for (let i = 0; i < hex.length; i += 2) {
    bytes.push(parseInt(hex.slice(i, i + 2), 16));
  }
  return Buffer.from(bytes);
}

module.exports = { verifyEventSignature };
