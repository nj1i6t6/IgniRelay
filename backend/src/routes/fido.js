'use strict';

/**
 * FidO / TW FidO API Stub
 *
 * This module implements the API surface for government FidO2 (TW FidO)
 * identity verification (Trust Ladder Level 3). The actual integration
 * with the Taiwan government TW FidO service requires:
 *
 *   1. Registration with MOEACA (內政部憑證管理中心) TW FidO service
 *   2. Obtaining RP credentials and TW FidO SDK
 *   3. Implementing WebAuthn challenge/response flow
 *
 * All endpoints are stubbed here with the correct API shape so that:
 *   - The Flutter app can call these endpoints
 *   - Future integration only requires filling in the implementation
 *   - The endpoints return 503 with clear guidance
 *
 * Reference: https://fido.moi.gov.tw/
 */

const express = require('express');
const db = require('../models/db');
const logger = require('../services/logger');

const router = express.Router();

const FIDO_NOT_CONFIGURED = {
  error: 'TW_FIDO_NOT_CONFIGURED',
  message: 'TW FidO政府身分驗證服務尚未設定。需向內政部憑證管理中心申請RP憑證後方可啟用。',
  docs: 'https://fido.moi.gov.tw/',
  status: 503,
};

/**
 * GET /api/v1/fido/status
 * Check if FidO integration is configured.
 */
router.get('/status', (_req, res) => {
  const configured = !!(process.env.FIDO2_RELYING_PARTY_ID &&
    process.env.FIDO2_RELYING_PARTY_ID !== 'resqmesh.network');

  res.json({
    configured,
    rp_id: process.env.FIDO2_RELYING_PARTY_ID,
    rp_name: process.env.FIDO2_RELYING_PARTY_NAME,
  });
});

/**
 * POST /api/v1/fido/register/begin
 * Begin FidO2 registration challenge (stub).
 *
 * Body: { pubkey_hex: "...", user_display_name: "..." }
 */
router.post('/register/begin', async (req, res) => {
  const { pubkey_hex } = req.body;
  if (!pubkey_hex) {
    return res.status(400).json({ error: 'pubkey_hex required' });
  }

  // TODO: Replace with actual TW FidO WebAuthn challenge generation
  // using @simplewebauthn/server or equivalent library with TW FidO RP credentials
  logger.warn('FidO register/begin called but not configured');
  res.status(503).json({
    ...FIDO_NOT_CONFIGURED,
    endpoint: '/api/v1/fido/register/begin',
    // Stub challenge shape for frontend development
    stub_challenge: {
      challenge: 'STUB_CHALLENGE_NOT_FOR_PRODUCTION',
      rp: {
        id: process.env.FIDO2_RELYING_PARTY_ID,
        name: process.env.FIDO2_RELYING_PARTY_NAME,
      },
      user: {
        id: pubkey_hex.slice(0, 32),
        name: pubkey_hex.slice(0, 16) + '...',
        displayName: 'ResQMesh User',
      },
      pubKeyCredParams: [{ alg: -7, type: 'public-key' }],
      authenticatorSelection: {
        authenticatorAttachment: 'platform',
        userVerification: 'required',
      },
      timeout: 60000,
    },
  });
});

/**
 * POST /api/v1/fido/register/complete
 * Complete FidO2 registration (stub).
 *
 * Body: { pubkey_hex: "...", credential: { ... WebAuthn response } }
 */
router.post('/register/complete', async (req, res) => {
  const { pubkey_hex } = req.body;
  if (!pubkey_hex) {
    return res.status(400).json({ error: 'pubkey_hex required' });
  }

  // TODO: Verify WebAuthn attestation with TW FidO RP credentials
  // On success: upgrade identity_level to 3 in identity_levels table
  logger.warn('FidO register/complete called but not configured');
  res.status(503).json(FIDO_NOT_CONFIGURED);
});

/**
 * POST /api/v1/fido/authenticate/begin
 * Begin FidO2 authentication challenge (stub).
 */
router.post('/authenticate/begin', async (_req, res) => {
  logger.warn('FidO authenticate/begin called but not configured');
  res.status(503).json(FIDO_NOT_CONFIGURED);
});

/**
 * POST /api/v1/fido/authenticate/complete
 * Complete FidO2 authentication (stub).
 */
router.post('/authenticate/complete', async (_req, res) => {
  logger.warn('FidO authenticate/complete called but not configured');
  res.status(503).json(FIDO_NOT_CONFIGURED);
});

/**
 * GET /api/v1/fido/credential?pubkey_hex=...
 * Check if a public key has a registered FidO credential (L3).
 */
router.get('/credential', async (req, res) => {
  const { pubkey_hex } = req.query;
  if (!pubkey_hex) return res.status(400).json({ error: 'pubkey_hex required' });

  try {
    const result = await db.query(
      'SELECT identity_level, fido_credential_id FROM identity_levels WHERE pubkey_hex = $1',
      [pubkey_hex]
    );
    if (result.rows.length === 0 || result.rows[0].identity_level < 3) {
      return res.json({ has_credential: false, identity_level: result.rows[0]?.identity_level ?? 0 });
    }
    res.json({ has_credential: true, identity_level: 3 });
  } catch (err) {
    logger.error('FidO credential check error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
