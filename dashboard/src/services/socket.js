import { io } from 'socket.io-client';

let socket = null;

export function connectSocket(onEvent, onThreatIntel, onBlacklistUpdate) {
  const token = localStorage.getItem('resqmesh_token');
  if (!token) return null;

  const serverUrl = import.meta.env.VITE_SOCKET_URL || '';

  socket = io(`${serverUrl}/commander`, {
    auth: { token },
    reconnectionDelay: 2000,
    reconnectionAttempts: 10,
  });

  socket.on('connect', () => {
    console.log('[WS] Commander connected');
    // Subscribe to all regions by default
    socket.emit('subscribe_region', 'all');
  });

  socket.on('new_event', (event) => {
    if (onEvent) onEvent(event);
  });

  socket.on('threat_intel_update', (update) => {
    if (onThreatIntel) onThreatIntel(update);
  });

  socket.on('blacklist_updated', (update) => {
    if (onBlacklistUpdate) onBlacklistUpdate(update);
  });

  socket.on('disconnect', () => {
    console.log('[WS] Commander disconnected');
  });

  socket.on('connect_error', (err) => {
    console.error('[WS] Connection error:', err.message);
  });

  return socket;
}

export function disconnectSocket() {
  socket?.disconnect();
  socket = null;
}

export function issueDispatchWS(order) {
  socket?.emit('dispatch_order', order);
}

export function getSocket() {
  return socket;
}
