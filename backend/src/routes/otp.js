'use strict';

const express = require('express');
const crypto = require('crypto');
const twilio = require('twilio');
const db = require('../models/db');
const logger = require('../services/logger');

const router = express.Router();

let twilioClient = null;
if (process.env.TWILIO_ACCOUNT_SID && process.env.TWILIO_AUTH_TOKEN) {
  twilioClient = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);
}

const OTP_EXPIRY_SECONDS = parseInt(process.env.OTP_EXPIRY_SECONDS) || 300;
const OTP_MAX_ATTEMPTS = parseInt(process.env.OTP_MAX_ATTEMPTS) || 3;

/**
 * POST /api/v1/otp/send
 * Send SMS OTP to a phone number for Trust Ladder L1 upgrade.
 *
 * Body: { phone: "+886xxxxxxxx", pubkey_hex: "..." }
 */
router.post('/send', async (req, res) => {
  const { phone, pubkey_hex } = req.body;

  if (!phone || !pubkey_hex) {
    return res.status(400).json({ error: 'phone and pubkey_hex required' });
  }

  // Validate phone format (E.164)
  if (!/^\+\d{8,15}$/.test(phone)) {
    return res.status(400).json({ error: 'Invalid phone number format (E.164 required, e.g. +886912345678)' });
  }

  // Rate limit: max 3 OTPs per phone per 10 minutes
  const recentResult = await db.query(
    `SELECT COUNT(*) FROM otp_sessions
     WHERE phone = $1 AND created_at > NOW() - INTERVAL '10 minutes'`,
    [phone]
  );
  if (parseInt(recentResult.rows[0].count) >= 3) {
    return res.status(429).json({ error: 'Too many OTP requests. Please wait 10 minutes.' });
  }

  // Generate 6-digit OTP
  const otp = String(Math.floor(100000 + Math.random() * 900000));
  const otpHash = crypto.createHash('sha256').update(otp).digest('hex');
  const expiresAt = new Date(Date.now() + OTP_EXPIRY_SECONDS * 1000);

  try {
    // Save OTP session
    await db.query(
      `INSERT INTO otp_sessions (phone, pubkey_hex, otp_hash, expires_at)
       VALUES ($1, $2, $3, $4)`,
      [phone, pubkey_hex, otpHash, expiresAt]
    );

    // Send SMS
    if (twilioClient) {
      await twilioClient.messages.create({
        body: `ResQMesh 驗證碼：${otp}\n有效期 ${OTP_EXPIRY_SECONDS / 60} 分鐘。`,
        from: process.env.TWILIO_PHONE_NUMBER,
        to: phone,
      });
      logger.info(`OTP sent to ${phone} for pubkey ${pubkey_hex.slice(0, 16)}...`);
    } else {
      // Development mode: log OTP instead of sending
      logger.warn(`[DEV MODE] OTP for ${phone}: ${otp}`);
    }

    res.json({ success: true, expires_at: expiresAt.toISOString() });
  } catch (err) {
    logger.error('OTP send error:', err);
    res.status(500).json({ error: 'Failed to send OTP' });
  }
});

/**
 * POST /api/v1/otp/verify
 * Verify OTP and upgrade identity level to L1.
 *
 * Body: { phone: "+886xxxxxxxx", pubkey_hex: "...", otp: "123456" }
 */
router.post('/verify', async (req, res) => {
  const { phone, pubkey_hex, otp } = req.body;

  if (!phone || !pubkey_hex || !otp) {
    return res.status(400).json({ error: 'phone, pubkey_hex, and otp required' });
  }

  try {
    // Find latest unexpired, unverified OTP session for this phone+pubkey
    const result = await db.query(
      `SELECT id, otp_hash, attempts, expires_at
       FROM otp_sessions
       WHERE phone = $1 AND pubkey_hex = $2 AND verified = FALSE AND expires_at > NOW()
       ORDER BY created_at DESC LIMIT 1`,
      [phone, pubkey_hex]
    );

    if (result.rows.length === 0) {
      return res.status(400).json({ error: 'No valid OTP session found. Please request a new OTP.' });
    }

    const session = result.rows[0];

    // Check attempt limit
    if (session.attempts >= OTP_MAX_ATTEMPTS) {
      return res.status(429).json({ error: 'Maximum OTP attempts exceeded. Please request a new OTP.' });
    }

    const inputHash = crypto.createHash('sha256').update(otp).digest('hex');

    if (inputHash !== session.otp_hash) {
      // Increment attempt counter
      await db.query(
        'UPDATE otp_sessions SET attempts = attempts + 1 WHERE id = $1',
        [session.id]
      );
      const remaining = OTP_MAX_ATTEMPTS - (session.attempts + 1);
      return res.status(400).json({ error: `Invalid OTP. ${remaining} attempts remaining.` });
    }

    // OTP correct — mark verified
    await db.query('UPDATE otp_sessions SET verified = TRUE WHERE id = $1', [session.id]);

    // Upgrade identity level to L1 in identity_levels table
    await db.query(
      `INSERT INTO identity_levels (pubkey_hex, identity_level, phone_verified, phone_number, updated_at)
       VALUES ($1, 1, TRUE, $2, NOW())
       ON CONFLICT (pubkey_hex) DO UPDATE SET
         identity_level = GREATEST(identity_levels.identity_level, 1),
         phone_verified = TRUE,
         phone_number = $2,
         updated_at = NOW()`,
      [pubkey_hex, phone]
    );

    logger.info(`L1 upgrade: pubkey ${pubkey_hex.slice(0, 16)}... phone ${phone}`);
    res.json({ success: true, identity_level: 1, message: '手機驗證成功，已升級至信任等級 L1' });
  } catch (err) {
    logger.error('OTP verify error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * GET /api/v1/otp/level?pubkey_hex=...
 * Query current identity level for a public key.
 */
router.get('/level', async (req, res) => {
  const { pubkey_hex } = req.query;
  if (!pubkey_hex) {
    return res.status(400).json({ error: 'pubkey_hex required' });
  }
  try {
    const result = await db.query(
      'SELECT identity_level, phone_verified, community_endorsements FROM identity_levels WHERE pubkey_hex = $1',
      [pubkey_hex]
    );
    if (result.rows.length === 0) {
      return res.json({ identity_level: 0 });
    }
    res.json(result.rows[0]);
  } catch (err) {
    logger.error('Level query error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
