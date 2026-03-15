import axios from 'axios';

const BASE_URL = import.meta.env.VITE_API_URL || '/api/v1';

const api = axios.create({ baseURL: BASE_URL });

// Attach JWT token to all requests
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('resqmesh_token');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

// Redirect to login on 401
api.interceptors.response.use(
  (res) => res,
  (err) => {
    if (err.response?.status === 401) {
      localStorage.removeItem('resqmesh_token');
      window.location.href = '/login';
    }
    return Promise.reject(err);
  }
);

export const login = (username, password) =>
  api.post('/auth/login', { username, password });

export const getEvents = (params) =>
  api.get('/commander/events', { params });

export const getStats = () =>
  api.get('/commander/stats');

export const getMaterials = (params) =>
  api.get('/commander/materials', { params });

export const getHazards = (params) =>
  api.get('/commander/hazards', { params });

export const getHeatmap = (params) =>
  api.get('/commander/heatmap', { params });

export const getBlacklist = () =>
  api.get('/commander/blacklist');

export const addBlacklist = (pubkey_hex, reason) =>
  api.post('/commander/blacklist', { pubkey_hex, reason });

export const removeBlacklist = (pubkey_hex) =>
  api.delete(`/commander/blacklist/${pubkey_hex}`);

export const issueDispatch = (message, region, urgency) =>
  api.post('/commander/dispatch', { message, region, urgency });

export const getThreatIntel = (since_timestamp) =>
  api.get('/sync/threat_intel', { params: { since_timestamp } });

export default api;
