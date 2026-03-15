'use strict';

const express = require('express');
const db = require('../models/db');
const logger = require('../services/logger');
const { requireAuth, requireCommander } = require('../middleware/auth');
const { broadcastThreatIntel } = require('../services/socketService');

const router = express.Router();

// All commander routes require authentication
router.use(requireAuth);
router.use(requireCommander);

/**
 * GET /api/v1/commander/events
 * Get recent mesh events for the command dashboard.
 * Query params: limit (default 100), urgency (filter), since_ms
 */
router.get('/events', async (req, res) => {
  const limit = Math.min(parseInt(req.query.limit) || 100, 1000);
  const { urgency, since_ms, event_type } = req.query;

  try {
    let q = `SELECT event_id, sender_pubkey, identity_level, event_type, urgency,
               hlc_timestamp, ttl, received_lat, received_lng, gateway_id, created_at, payload_b64
             FROM events WHERE 1=1`;
    const params = [];

    if (urgency != null) {
      params.push(urgency);
      q += ` AND urgency = $${params.length}`;
    }
    if (event_type) {
      params.push(event_type);
      q += ` AND event_type = $${params.length}`;
    }
    if (since_ms) {
      params.push(since_ms);
      q += ` AND hlc_timestamp > $${params.length}`;
    }

    params.push(limit);
    q += ` ORDER BY urgency DESC, hlc_timestamp DESC LIMIT $${params.length}`;

    const result = await db.query(q, params);
    res.json({ events: result.rows, count: result.rows.length });
  } catch (err) {
    logger.error('Commander events query error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * GET /api/v1/commander/stats
 * Dashboard statistics: total events, SOS count, active nodes, etc.
 */
router.get('/stats', async (_req, res) => {
  try {
    const [totals, urgencyBreakdown, recentActivity, timeline] = await Promise.all([
      db.query(`SELECT
        COUNT(*) AS total_events,
        COUNT(*) FILTER (WHERE urgency = 3) AS sos_red_count,
        COUNT(*) FILTER (WHERE urgency = 2) AS sos_yellow_count,
        COUNT(*) FILTER (WHERE urgency = 1) AS resource_count,
        COUNT(*) FILTER (WHERE urgency = 0) AS info_count,
        COUNT(DISTINCT sender_pubkey) AS unique_nodes,
        COUNT(DISTINCT gateway_id) AS unique_gateways
        FROM events`),
      db.query(`SELECT urgency, COUNT(*) as count
        FROM events WHERE created_at > NOW() - INTERVAL '24 hours'
        GROUP BY urgency ORDER BY urgency DESC`),
      db.query(`SELECT COUNT(*) AS events_last_5min
        FROM events WHERE created_at > NOW() - INTERVAL '5 minutes'`),
      db.query(`
        SELECT date_trunc('hour', created_at) AS hour, COUNT(*) AS count
        FROM events
        WHERE created_at > NOW() - INTERVAL '24 hours'
        GROUP BY hour
        ORDER BY hour ASC
      `)
    ]);

    res.json({
      totals: totals.rows[0],
      urgency_last_24h: urgencyBreakdown.rows,
      events_last_5min: parseInt(recentActivity.rows[0].events_last_5min),
      timeline_24h: timeline.rows,
    });
  } catch (err) {
    logger.error('Stats error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * GET /api/v1/commander/materials
 * Extracts and aggregates material/resource requests from payloads.
 */
router.get('/materials', async (_req, res) => {
  try {
    // Look for events that are likely text/JSON payloads and urgency <= 2
    // We attempt to decode the base64 payload to find resource requests if formatted as JSON
    const result = await db.query(
      `SELECT event_id, sender_pubkey, payload_b64, received_lat, received_lng, created_at, hlc_timestamp 
       FROM events 
       WHERE urgency = 1 OR event_type = 'RESOURCE'
       ORDER BY hlc_timestamp DESC LIMIT 200`
    );
    
    const materials = [];
    for (const row of result.rows) {
      if (row.payload_b64) {
        try {
          const jsonStr = Buffer.from(row.payload_b64, 'base64').toString('utf8');
          // Heuristic to check if it's a known resource format, or just return the text
          let parsed;
          try {
             parsed = JSON.parse(jsonStr);
          } catch(e) {
             // Fallback: It might be a plain text message describing a need
             parsed = { description: jsonStr };
          }
          
          materials.push({
            event_id: row.event_id,
            origin: row.sender_pubkey,
            lat: row.received_lat,
            lng: row.received_lng,
            created_at: row.created_at,
            timestamp: row.hlc_timestamp,
            data: parsed
          });
        } catch(e) { /* ignore parse errors */ }
      }
    }
    res.json({ materials, count: materials.length });
  } catch (err) {
    logger.error('Materials query error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * GET /api/v1/commander/hazards
 * Extracts hazard reports from payloads.
 */
router.get('/hazards', async (_req, res) => {
  try {
    const result = await db.query(
      `SELECT event_id, sender_pubkey, urgency, payload_b64, received_lat, received_lng, created_at, hlc_timestamp 
       FROM events 
       WHERE event_type = 'HAZARD' OR urgency = 2
       ORDER BY hlc_timestamp DESC LIMIT 200`
    );
    
    const hazards = [];
    for (const row of result.rows) {
      if (row.payload_b64) {
        try {
          const jsonStr = Buffer.from(row.payload_b64, 'base64').toString('utf8');
          let parsed = { description: jsonStr };
          try {
             parsed = JSON.parse(jsonStr);
          } catch(e) {}
          
          hazards.push({
            event_id: row.event_id,
            origin: row.sender_pubkey,
            lat: row.received_lat,
            lng: row.received_lng,
            created_at: row.created_at,
            timestamp: row.hlc_timestamp,
            urgency: row.urgency,
            data: parsed
          });
        } catch(e) {}
      }
    }
    res.json({ hazards, count: hazards.length });
  } catch (err) {
    logger.error('Hazards query error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * GET /api/v1/commander/blacklist
 * Get current blacklist.
 */
router.get('/blacklist', async (_req, res) => {
  try {
    const result = await db.query(
      `SELECT pubkey_hex, reason, total_weight, vote_count, blacklisted, updated_at
       FROM blacklist ORDER BY updated_at DESC LIMIT 500`
    );
    res.json({ blacklist: result.rows });
  } catch (err) {
    logger.error('Blacklist fetch error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * POST /api/v1/commander/blacklist
 * Manually add a node to the blacklist.
 * Body: { pubkey_hex: "...", reason: "MANUAL_BAN" }
 */
router.post('/blacklist', async (req, res) => {
  const { pubkey_hex, reason = 'MANUAL_BAN' } = req.body;
  if (!pubkey_hex) return res.status(400).json({ error: 'pubkey_hex required' });

  try {
    await db.query(
      `INSERT INTO blacklist (pubkey_hex, reason, total_weight, vote_count, blacklisted, updated_at)
       VALUES ($1, $2, 10.0, 1, TRUE, NOW())
       ON CONFLICT (pubkey_hex) DO UPDATE SET
         blacklisted = TRUE, reason = $2, total_weight = 10.0, updated_at = NOW()`,
      [pubkey_hex, reason]
    );

    // Broadcast blacklist update to all connected dashboards
    broadcastThreatIntel({ pubkey_hex, action: 'add', reason, source: 'commander' });

    logger.info(`Commander ${req.user.username} blacklisted ${pubkey_hex}`);
    res.json({ success: true });
  } catch (err) {
    logger.error('Blacklist add error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * DELETE /api/v1/commander/blacklist/:pubkey_hex
 * Remove a node from the blacklist.
 */
router.delete('/blacklist/:pubkey_hex', async (req, res) => {
  const { pubkey_hex } = req.params;
  try {
    await db.query(
      `UPDATE blacklist SET blacklisted = FALSE, updated_at = NOW() WHERE pubkey_hex = $1`,
      [pubkey_hex]
    );
    broadcastThreatIntel({ pubkey_hex, action: 'remove', source: 'commander' });
    logger.info(`Commander ${req.user.username} removed ${pubkey_hex} from blacklist`);
    res.json({ success: true });
  } catch (err) {
    logger.error('Blacklist remove error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * GET /api/v1/commander/heatmap
 * Get SOS/HAZARD event positions for map heatmap rendering.
 * Query: since_ms, urgency_min (default 2 = SOS_YELLOW+)
 */
router.get('/heatmap', async (req, res) => {
  const urgencyMin = parseInt(req.query.urgency_min) || 2;
  const since_ms = req.query.since_ms;

  try {
    let q = `SELECT received_lat as lat, received_lng as lng, urgency, event_type,
               hlc_timestamp, payload_b64, event_id
             FROM events
             WHERE urgency >= $1 AND received_lat IS NOT NULL AND received_lng IS NOT NULL`;
    const params = [urgencyMin];

    if (since_ms) {
      params.push(since_ms);
      q += ` AND hlc_timestamp > $${params.length}`;
    }

    q += ' ORDER BY hlc_timestamp DESC LIMIT 2000';
    const result = await db.query(q, params);
    res.json({ points: result.rows });
  } catch (err) {
    logger.error('Heatmap query error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * POST /api/v1/commander/dispatch
 * Issue a commander dispatch order (broadcast via WebSocket to all clients).
 * Body: { message: "...", region: "台北市", urgency: 3 }
 */
router.post('/dispatch', async (req, res) => {
  const { message, region, urgency = 3 } = req.body;
  if (!message) return res.status(400).json({ error: 'message required' });

  const order = {
    id: require('uuid').v4(),
    message,
    region: region || 'all',
    urgency,
    issued_by: req.user.username,
    issued_at: new Date().toISOString(),
  };

  // Broadcast via WebSocket is handled in socketService dispatch_order handler
  // Also store in DB for audit trail
  await db.query(
    `INSERT INTO events (event_id, sender_pubkey, identity_level, event_type, urgency,
       hlc_timestamp, hlc_counter, ttl, payload_b64, signature_b64, gateway_id)
     VALUES ($1, 'COMMANDER', 3, 'COMMANDER_DISPATCH', $2, $3, 0, 20, $4, 'COMMANDER_SIG', 'dashboard')
     ON CONFLICT DO NOTHING`,
    [order.id, urgency, Date.now(), JSON.stringify(order)]
  );

  logger.info(`Commander dispatch by ${req.user.username}: ${message}`);
  res.json({ success: true, order });
});

module.exports = router;
