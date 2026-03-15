'use strict';

const jwt = require('jsonwebtoken');
const logger = require('./logger');

let ioInstance = null;

/**
 * Initialize WebSocket handlers for the commander dashboard.
 */
function initSocketHandlers(io) {
  ioInstance = io;

  // Commander namespace — requires JWT auth on connect
  const commanderNs = io.of('/commander');

  commanderNs.use((socket, next) => {
    const token = socket.handshake.auth?.token;
    if (!token) return next(new Error('Unauthorized: missing token'));
    try {
      const payload = jwt.verify(token, process.env.JWT_SECRET);
      socket.user = payload;
      next();
    } catch {
      next(new Error('Unauthorized: invalid token'));
    }
  });

  commanderNs.on('connection', (socket) => {
    logger.info(`Commander connected: ${socket.user?.username} (${socket.id})`);

    socket.on('subscribe_region', (region) => {
      socket.join(`region:${region}`);
      logger.debug(`Commander ${socket.user?.username} subscribed to region: ${region}`);
    });

    socket.on('dispatch_order', (order) => {
      // Broadcast dispatch order to all commanders in same region
      commanderNs.to(`region:${order.region}`).emit('dispatch_order', {
        ...order,
        issued_by: socket.user?.username,
        issued_at: new Date().toISOString(),
      });
      logger.info(`Dispatch order from ${socket.user?.username}: ${JSON.stringify(order)}`);
    });

    socket.on('add_blacklist', (pubkeyHex) => {
      // Emit blacklist update to all commanders
      commanderNs.emit('blacklist_updated', { pubkey_hex: pubkeyHex, action: 'add' });
    });

    socket.on('disconnect', () => {
      logger.info(`Commander disconnected: ${socket.user?.username}`);
    });
  });

  // Public events namespace — for mesh event streaming
  const eventsNs = io.of('/events');
  eventsNs.on('connection', (socket) => {
    logger.debug(`Events subscriber connected: ${socket.id}`);
  });

  logger.info('WebSocket handlers initialized');
}

/**
 * Broadcast a new mesh event to all commander dashboard subscribers.
 */
function broadcastEvent(event) {
  if (!ioInstance) return;
  ioInstance.of('/commander').emit('new_event', event);
  ioInstance.of('/events').emit('new_event', event);
}

/**
 * Broadcast threat intel update (blacklist) to commander dashboard.
 */
function broadcastThreatIntel(update) {
  if (!ioInstance) return;
  ioInstance.of('/commander').emit('threat_intel_update', update);
}

module.exports = { initSocketHandlers, broadcastEvent, broadcastThreatIntel };
