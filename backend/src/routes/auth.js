'use strict';

const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const db = require('../models/db');
const logger = require('../services/logger');

const router = express.Router();

/**
 * POST /api/v1/auth/login
 * Commander dashboard login.
 */
router.post('/login', async (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) {
    return res.status(400).json({ error: 'username and password required' });
  }

  try {
    const result = await db.query(
      'SELECT id, username, password_hash, role FROM commander_users WHERE username = $1',
      [username]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const user = result.rows[0];
    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const token = jwt.sign(
      { id: user.id, username: user.username, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: '8h' }
    );

    logger.info(`Commander login: ${username}`);
    res.json({ token, role: user.role, username: user.username });
  } catch (err) {
    logger.error('Login error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * POST /api/v1/auth/register-commander
 * Register a new commander user (admin only, or first-run bootstrap).
 * In production, guard this with a secret admin token.
 */
router.post('/register-commander', async (req, res) => {
  const { username, password, role = 'viewer', admin_secret } = req.body;

  if (admin_secret !== process.env.JWT_SECRET) {
    return res.status(403).json({ error: 'Forbidden' });
  }

  if (!username || !password) {
    return res.status(400).json({ error: 'username and password required' });
  }

  try {
    const hash = await bcrypt.hash(password, 12);
    await db.query(
      'INSERT INTO commander_users (username, password_hash, role) VALUES ($1, $2, $3) ON CONFLICT (username) DO UPDATE SET password_hash = $2, role = $3',
      [username, hash, role]
    );
    res.json({ success: true, username });
  } catch (err) {
    logger.error('Register commander error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
