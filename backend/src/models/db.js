'use strict';

const { Pool } = require('pg');
const logger = require('../services/logger');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 20,
  idleTimeoutMillis: 30_000,
  connectionTimeoutMillis: 2_000,
});

pool.on('error', (err) => {
  logger.error('Unexpected PostgreSQL pool error:', err);
});

/**
 * Run a query with parameters.
 */
async function query(text, params) {
  const start = Date.now();
  const res = await pool.query(text, params);
  logger.debug(`query: ${text.slice(0, 60)}… (${Date.now() - start}ms)`);
  return res;
}

/**
 * Create schema tables if they don't exist.
 */
async function migrate() {
  logger.info('Running database migrations...');

  await pool.query(`
    CREATE TABLE IF NOT EXISTS events (
      id            BIGSERIAL PRIMARY KEY,
      event_id      VARCHAR(64) UNIQUE NOT NULL,
      sender_pubkey VARCHAR(128) NOT NULL,
      identity_level SMALLINT NOT NULL DEFAULT 0,
      event_type    VARCHAR(32) NOT NULL,
      urgency       SMALLINT NOT NULL DEFAULT 0,
      hlc_timestamp BIGINT NOT NULL,
      hlc_counter   BIGINT NOT NULL,
      ttl           SMALLINT NOT NULL DEFAULT 5,
      payload_b64   TEXT,
      signature_b64 TEXT NOT NULL,
      received_lat  DOUBLE PRECISION,
      received_lng  DOUBLE PRECISION,
      gateway_id    VARCHAR(64),
      created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_events_urgency ON events(urgency DESC, hlc_timestamp DESC);
    CREATE INDEX IF NOT EXISTS idx_events_sender ON events(sender_pubkey);
    CREATE INDEX IF NOT EXISTS idx_events_type ON events(event_type);
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS otp_sessions (
      id          BIGSERIAL PRIMARY KEY,
      phone       VARCHAR(20) NOT NULL,
      pubkey_hex  VARCHAR(128) NOT NULL,
      otp_hash    VARCHAR(64) NOT NULL,
      attempts    SMALLINT NOT NULL DEFAULT 0,
      expires_at  TIMESTAMPTZ NOT NULL,
      verified    BOOLEAN NOT NULL DEFAULT FALSE,
      created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_otp_phone ON otp_sessions(phone, verified, expires_at);
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS identity_levels (
      pubkey_hex    VARCHAR(128) PRIMARY KEY,
      identity_level SMALLINT NOT NULL DEFAULT 0,
      phone_verified BOOLEAN NOT NULL DEFAULT FALSE,
      phone_number   VARCHAR(20),
      community_endorsements INTEGER NOT NULL DEFAULT 0,
      fido_credential_id TEXT,
      updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS blacklist (
      pubkey_hex    VARCHAR(128) PRIMARY KEY,
      reason        VARCHAR(32) NOT NULL,
      total_weight  FLOAT NOT NULL DEFAULT 0,
      vote_count    INTEGER NOT NULL DEFAULT 0,
      blacklisted   BOOLEAN NOT NULL DEFAULT FALSE,
      updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_blacklist_active ON blacklist(blacklisted);
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS commander_users (
      id          BIGSERIAL PRIMARY KEY,
      username    VARCHAR(64) UNIQUE NOT NULL,
      password_hash VARCHAR(128) NOT NULL,
      role        VARCHAR(32) NOT NULL DEFAULT 'viewer',
      created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  logger.info('Database migrations complete.');
}

module.exports = { query, pool, migrate };
