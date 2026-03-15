'use strict';

const express = require('express');
const db = require('../models/db');
const logger = require('../services/logger');
const { verifyEventSignature } = require('../services/signatureVerifier');
const { broadcastEvent } = require('../services/socketService');

const router = express.Router();

/**
 * POST /api/v1/sync/events
 * Batch upload mesh events from a gateway node (Data Mule or Super Node).
 *
 * Request body:
 * {
 *   "gateway": { "id": "DEVICE_UUID", "role": "SUPER_NODE_MULE" },
 *   "events": [
 *     {
 *       "event_id": "...",
 *       "sender_pubkey": "hex",
 *       "identity_level": 0,
 *       "event_type": "REQUEST_BROADCAST",
 *       "urgency": 3,
 *       "hlc_timestamp": 1234567890000,
 *       "hlc_counter": 0,
 *       "ttl": 5,
 *       "payload_base64": "...",
 *       "signature": "base64",
 *       "received_lat": 25.045,
 *       "received_lng": 121.543
 *     }
 *   ]
 * }
 */
router.post('/events', async (req, res) => {
  const { gateway, events } = req.body;

  if (!gateway?.id || !Array.isArray(events)) {
    return res.status(400).json({ error: 'Invalid request body: missing gateway or events array' });
  }

  if (events.length === 0) {
    return res.json({ accepted: 0, rejected: 0 });
  }

  if (events.length > 500) {
    return res.status(400).json({ error: 'Batch too large: max 500 events per request' });
  }

  let accepted = 0;
  let rejected = 0;
  const rejectedIds = [];

  for (const evt of events) {
    try {
      // Check blacklist
      const bl = await db.query(
        'SELECT blacklisted FROM blacklist WHERE pubkey_hex = $1 AND blacklisted = TRUE',
        [evt.sender_pubkey]
      );
      if (bl.rows.length > 0) {
        rejected++;
        rejectedIds.push({ event_id: evt.event_id, reason: 'BLACKLISTED' });
        continue;
      }

      // Verify Ed25519 signature
      if (!verifyEventSignature(evt.sender_pubkey, evt.payload_base64, evt.signature)) {
        rejected++;
        rejectedIds.push({ event_id: evt.event_id, reason: 'INVALID_SIGNATURE' });
        logger.warn(`Invalid signature for event ${evt.event_id} from ${evt.sender_pubkey}`);
        continue;
      }

      // Insert into database (ignore duplicates via ON CONFLICT)
      await db.query(
        `INSERT INTO events (
          event_id, sender_pubkey, identity_level, event_type, urgency,
          hlc_timestamp, hlc_counter, ttl, payload_b64, signature_b64,
          received_lat, received_lng, gateway_id
        ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)
        ON CONFLICT (event_id) DO NOTHING`,
        [
          evt.event_id,
          evt.sender_pubkey,
          evt.identity_level ?? 0,
          evt.event_type,
          evt.urgency ?? 0,
          evt.hlc_timestamp,
          evt.hlc_counter ?? 0,
          evt.ttl ?? 5,
          evt.payload_base64,
          evt.signature,
          evt.received_lat ?? null,
          evt.received_lng ?? null,
          gateway.id,
        ]
      );

      accepted++;

      // Broadcast to commander dashboard in real-time
      broadcastEvent({
        event_id: evt.event_id,
        event_type: evt.event_type,
        urgency: evt.urgency,
        sender_pubkey: evt.sender_pubkey,
        identity_level: evt.identity_level,
        received_lat: evt.received_lat,
        received_lng: evt.received_lng,
        hlc_timestamp: evt.hlc_timestamp,
        gateway_id: gateway.id,
      });

    } catch (err) {
      logger.error(`Error processing event ${evt.event_id}:`, err);
      rejected++;
      rejectedIds.push({ event_id: evt.event_id, reason: 'SERVER_ERROR' });
    }
  }

  logger.info(`Sync from gateway ${gateway.id}: accepted=${accepted} rejected=${rejected}`);
  res.json({ accepted, rejected, rejected_ids: rejectedIds });
});

/**
 * GET /api/v1/sync/threat_intel
 * Download current blacklist for distribution back into the mesh.
 *
 * Query params:
 *   since_timestamp (optional): only return entries updated after this Unix ms
 */
router.get('/threat_intel', async (req, res) => {
  const { since_timestamp } = req.query;

  try {
    let q = 'SELECT pubkey_hex, reason, total_weight, vote_count, blacklisted, updated_at FROM blacklist WHERE blacklisted = TRUE';
    const params = [];

    if (since_timestamp) {
      q += ` AND updated_at > to_timestamp($1::bigint / 1000.0)`;
      params.push(since_timestamp);
    }

    q += ' ORDER BY updated_at DESC LIMIT 1000';

    const result = await db.query(q, params);
    res.json({
      version: Date.now(),
      blacklist: result.rows,
      count: result.rows.length,
    });
  } catch (err) {
    logger.error('Error fetching threat intel:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * POST /api/v1/sync/quarantine_vote
 * Receive quarantine votes relayed from mesh nodes.
 */
router.post('/quarantine_vote', async (req, res) => {
  const { target_pubkey, reason, vote_weight, voter_pubkey, voter_identity_level } = req.body;

  if (!target_pubkey || !reason || vote_weight == null) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  // Vote weight by identity level: 0=0.2, 1=0.5, 2=0.8, 3=1.0
  const WEIGHT_MAP = [0.2, 0.5, 0.8, 1.0];
  const validWeight = WEIGHT_MAP[Math.min(voter_identity_level ?? 0, 3)];

  try {
    const result = await db.query(
      `INSERT INTO blacklist (pubkey_hex, reason, total_weight, vote_count, blacklisted, updated_at)
       VALUES ($1, $2, $3, 1, $4, NOW())
       ON CONFLICT (pubkey_hex) DO UPDATE SET
         total_weight = blacklist.total_weight + $3,
         vote_count = blacklist.vote_count + 1,
         blacklisted = (blacklist.total_weight + $3) > 3.0,
         updated_at = NOW()
       RETURNING total_weight, blacklisted`,
      [target_pubkey, reason, validWeight, validWeight > 3.0]
    );

    const row = result.rows[0];
    logger.info(`Quarantine vote: ${target_pubkey} weight=${row.total_weight} blacklisted=${row.blacklisted}`);
    res.json({ total_weight: row.total_weight, blacklisted: row.blacklisted });
  } catch (err) {
    logger.error('Quarantine vote error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
