'use strict';

require('dotenv').config();
const express = require('express');
const http = require('http');
const { Server: SocketIOServer } = require('socket.io');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');

const logger = require('./services/logger');
const db = require('./models/db');
const authRouter = require('./routes/auth');
const syncRouter = require('./routes/sync');
const otpRouter = require('./routes/otp');
const fidoRouter = require('./routes/fido');
const commanderRouter = require('./routes/commander');
const { initSocketHandlers } = require('./services/socketService');

const app = express();
const server = http.createServer(app);
const io = new SocketIOServer(server, {
  cors: {
    origin: process.env.FRONTEND_URL || 'http://localhost:5173',
    methods: ['GET', 'POST'],
  },
});

// ── Middleware ─────────────────────────────────────────────────────────────────
app.use(helmet());
app.use(cors({
  origin: process.env.FRONTEND_URL || 'http://localhost:5173',
  credentials: true,
}));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Global rate limiter
const limiter = rateLimit({
  windowMs: parseInt(process.env.API_RATE_LIMIT_WINDOW_MS) || 60_000,
  max: parseInt(process.env.API_RATE_LIMIT_MAX) || 100,
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/', limiter);

// Request logging
app.use((req, _res, next) => {
  logger.info(`${req.method} ${req.path}`);
  next();
});

// ── Routes ────────────────────────────────────────────────────────────────────
app.use('/api/v1/auth', authRouter);
app.use('/api/v1/sync', syncRouter);
app.use('/api/v1/otp', otpRouter);
app.use('/api/v1/fido', fidoRouter);
app.use('/api/v1/commander', commanderRouter);

// Health check
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// 404 handler
app.use((_req, res) => {
  res.status(404).json({ error: 'Not Found' });
});

// Error handler
app.use((err, _req, res, _next) => {
  logger.error(`Unhandled error: ${err.message}`, { stack: err.stack });
  res.status(500).json({ error: 'Internal Server Error' });
});

// ── WebSocket (Commander Dashboard) ───────────────────────────────────────────
initSocketHandlers(io);

// ── Start ─────────────────────────────────────────────────────────────────────
const PORT = parseInt(process.env.PORT) || 3000;
server.listen(PORT, async () => {
  try {
    await db.migrate();
    logger.info(`ResQMesh backend listening on port ${PORT}`);
  } catch (err) {
    logger.error('DB migration failed:', err);
    process.exit(1);
  }
});

module.exports = { app, io };
