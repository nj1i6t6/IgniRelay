import React, { useState, useEffect, useRef, useCallback } from 'react';
import { MapContainer, TileLayer, useMap } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { connectSocket, disconnectSocket } from '../services/socket';
import {
  getStats, getEvents, getHeatmap, getBlacklist,
  addBlacklist, removeBlacklist, issueDispatch,
  getMaterials, getHazards
} from '../services/api';
import EventList from '../components/EventList';
import StatsPanel from '../components/StatsPanel';
import BlacklistPanel from '../components/BlacklistPanel';
import DispatchPanel from '../components/DispatchPanel';
import MaterialPanel from '../components/MaterialPanel';
import HazardPanel from '../components/HazardPanel';
import MarkersLayer from '../components/MarkersLayer';

const URGENCY_COLORS = {
  3: '#ff2222',
  2: '#ffaa00',
  1: '#22cc44',
  0: '#4488ff',
};
const URGENCY_LABELS = { 3: 'SOS_RED', 2: 'SOS_YELLOW', 1: 'RESOURCE', 0: 'INFO' };

// Leaflet heatmap layer component
function HeatmapLayer({ points }) {
  const map = useMap();
  const heatRef = useRef(null);

  useEffect(() => {
    if (!map || points.length === 0) return;

    const latlngs = points
      .filter(p => p.lat != null && p.lng != null)
      .map(p => [p.lat, p.lng, p.urgency === 3 ? 1.0 : 0.6]);

    if (heatRef.current) {
      map.removeLayer(heatRef.current);
    }

    // Use Leaflet.heat if available, fallback to circle markers
    if (L.heatLayer) {
      heatRef.current = L.heatLayer(latlngs, {
        radius: 25, blur: 15, maxZoom: 17,
        gradient: { 0.4: '#0044ff', 0.65: '#ffaa00', 1: '#ff0000' },
      }).addTo(map);
    } else {
      latlngs.forEach(([lat, lng, intensity]) => {
        L.circleMarker([lat, lng], {
          radius: 8,
          color: intensity >= 1 ? '#ff2222' : '#ffaa00',
          fillColor: intensity >= 1 ? '#ff2222' : '#ffaa00',
          fillOpacity: 0.7,
          weight: 1,
        }).addTo(map);
      });
    }

    return () => {
      if (heatRef.current) map.removeLayer(heatRef.current);
    };
  }, [map, points]);

  return null;
}

const S = {
  root: { display: 'flex', height: '100vh', background: '#0d0d1a', overflow: 'hidden' },
  sidebar: {
    width: 340, background: '#1a1a2e', borderRight: '1px solid #222',
    display: 'flex', flexDirection: 'column', overflow: 'hidden',
  },
  header: {
    padding: '16px 20px', background: '#0d0d1a',
    borderBottom: '1px solid #222', display: 'flex', alignItems: 'center',
    justifyContent: 'space-between',
  },
  title: { fontSize: 18, fontWeight: 700, color: '#ff4444' },
  wsIndicator: { width: 8, height: 8, borderRadius: '50%', marginRight: 6 },
  tabs: { display: 'flex', background: '#111', borderBottom: '1px solid #222' },
  tab: {
    flex: 1, padding: '10px 4px', textAlign: 'center', cursor: 'pointer',
    fontSize: 11, color: '#666', border: 'none', background: 'none',
  },
  activeTab: { color: '#ff4444', borderBottom: '2px solid #ff4444' },
  tabContent: { flex: 1, overflow: 'auto' },
  mapArea: { flex: 1, position: 'relative' },
  logoutBtn: {
    background: 'none', border: '1px solid #444', color: '#888',
    padding: '4px 10px', borderRadius: 4, cursor: 'pointer', fontSize: 12,
  },
};

export default function DashboardPage({ onLogout }) {
  const [tab, setTab] = useState('events');
  const [events, setEvents] = useState([]);
  const [heatPoints, setHeatPoints] = useState([]);
  const [materials, setMaterials] = useState([]);
  const [hazards, setHazards] = useState([]);
  const [stats, setStats] = useState(null);
  const [blacklist, setBlacklist] = useState([]);
  const [wsConnected, setWsConnected] = useState(false);

  // Map Filters
  const [showHeatmap, setShowHeatmap] = useState(true);
  const [showMaterials, setShowMaterials] = useState(true);
  const [showHazards, setShowHazards] = useState(true);

  // Load initial data
  useEffect(() => {
    const load = async () => {
      try {
        const [evtRes, statRes, heatRes, blRes, matRes, hazRes] = await Promise.all([
          getEvents({ limit: 50 }),
          getStats(),
          getHeatmap({ urgency_min: 2 }),
          getBlacklist(),
          getMaterials(),
          getHazards()
        ]);
        setEvents(evtRes.data.events || []);
        setStats(statRes.data);
        setHeatPoints(heatRes.data.points || []);
        setBlacklist(blRes.data.blacklist || []);
        setMaterials(matRes.data.materials || []);
        setHazards(hazRes.data.hazards || []);
      } catch (err) {
        console.error('Load error:', err);
      }
    };
    load();
  }, []);

  // Connect WebSocket
  useEffect(() => {
    const sock = connectSocket(
      (newEvent) => {
        setEvents(prev => [newEvent, ...prev.slice(0, 199)]);
        if (newEvent.received_lat && newEvent.received_lng) {
          setHeatPoints(prev => [newEvent, ...prev.slice(0, 1999)]);
        }
        // Refresh stats periodically
        getStats().then(r => setStats(r.data)).catch(() => { });
      },
      (update) => {
        console.log('Threat intel update:', update);
      },
      (update) => {
        if (update.action === 'add') {
          setBlacklist(prev => [{ pubkey_hex: update.pubkey_hex, reason: update.reason, blacklisted: true }, ...prev]);
        } else {
          setBlacklist(prev => prev.filter(b => b.pubkey_hex !== update.pubkey_hex));
        }
      }
    );

    if (sock) {
      sock.on('connect', () => setWsConnected(true));
      sock.on('disconnect', () => setWsConnected(false));
    }

    return () => disconnectSocket();
  }, []);

  const handleAddBlacklist = useCallback(async (pubkeyHex, reason) => {
    try {
      await addBlacklist(pubkeyHex, reason);
      const res = await getBlacklist();
      setBlacklist(res.data.blacklist || []);
    } catch (err) {
      alert('加入黑名單失敗: ' + (err.response?.data?.error || err.message));
    }
  }, []);

  const handleRemoveBlacklist = useCallback(async (pubkeyHex) => {
    try {
      await removeBlacklist(pubkeyHex);
      setBlacklist(prev => prev.filter(b => b.pubkey_hex !== pubkeyHex));
    } catch (err) {
      alert('移除黑名單失敗: ' + (err.response?.data?.error || err.message));
    }
  }, []);

  const handleDispatch = useCallback(async (message, region, urgency) => {
    try {
      await issueDispatch(message, region, urgency);
      alert(`指令已發送: ${message}`);
    } catch (err) {
      alert('發送指令失敗: ' + (err.response?.data?.error || err.message));
    }
  }, []);

  return (
    <div style={S.root}>
      {/* Sidebar */}
      <div style={S.sidebar}>
        <div style={S.header}>
          <div style={S.title}>⚡ ResQMesh 指揮中心</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <div style={{
              display: 'flex', alignItems: 'center',
              fontSize: 11, color: wsConnected ? '#22cc44' : '#888'
            }}>
              <div style={{ ...S.wsIndicator, background: wsConnected ? '#22cc44' : '#555' }} />
              {wsConnected ? '即時連線' : '離線'}
            </div>
            <button style={S.logoutBtn} onClick={onLogout}>登出</button>
          </div>
        </div>

        {/* Stats */}
        {stats && <StatsPanel stats={stats} />}

        {/* Tabs */}
        <div style={{ ...S.tabs, overflowX: 'auto' }}>
          {['events', 'materials', 'hazards', 'blacklist', 'dispatch'].map(t => {
            let label = '';
            if (t === 'events') label = '📡 事件流';
            else if (t === 'materials') label = '📦 物資';
            else if (t === 'hazards') label = '⚠️ 災情';
            else if (t === 'blacklist') label = '🚫 黑名單';
            else label = '📢 指令';

            return (
              <button
                key={t}
                style={{ ...S.tab, ...(tab === t ? S.activeTab : {}) }}
                onClick={() => setTab(t)}
              >
                {label}
              </button>
            )
          })}
        </div>

        <div style={S.tabContent}>
          {tab === 'events' && <EventList events={events} onBlacklist={handleAddBlacklist} />}
          {tab === 'materials' && <MaterialPanel materials={materials} />}
          {tab === 'hazards' && <HazardPanel hazards={hazards} />}
          {tab === 'blacklist' && (
            <BlacklistPanel
              blacklist={blacklist}
              onAdd={handleAddBlacklist}
              onRemove={handleRemoveBlacklist}
            />
          )}
          {tab === 'dispatch' && <DispatchPanel onDispatch={handleDispatch} />}
        </div>
      </div>

      {/* Map */}
      <div style={S.mapArea}>
        {/* Map Toggles Overlay */}
        <div style={{
          position: 'absolute', top: 20, right: 20, zIndex: 1000,
          background: 'rgba(13,13,26,0.9)', border: '1px solid #333',
          borderRadius: 8, padding: '12px', display: 'flex', flexDirection: 'column', gap: 8
        }}>
          <label style={{ color: '#fff', fontSize: 13, display: 'flex', alignItems: 'center', cursor: 'pointer' }}>
            <input type="checkbox" checked={showHeatmap} onChange={e => setShowHeatmap(e.target.checked)} style={{ marginRight: 8 }} />
            SOS 熱力圖
          </label>
          <label style={{ color: '#fff', fontSize: 13, display: 'flex', alignItems: 'center', cursor: 'pointer' }}>
            <input type="checkbox" checked={showHazards} onChange={e => setShowHazards(e.target.checked)} style={{ marginRight: 8 }} />
            災情標記 (⚠️)
          </label>
          <label style={{ color: '#fff', fontSize: 13, display: 'flex', alignItems: 'center', cursor: 'pointer' }}>
            <input type="checkbox" checked={showMaterials} onChange={e => setShowMaterials(e.target.checked)} style={{ marginRight: 8 }} />
            物資請求 (📦)
          </label>
        </div>

        <MapContainer
          center={[23.6, 120.9]}
          zoom={8}
          style={{ height: '100%', width: '100%', background: '#0d0d1a' }}
          zoomControl={true}
        >
          <TileLayer
            url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
            attribution='&copy; <a href="https://carto.com/">CARTO</a>'
            maxZoom={19}
          />
          {showHeatmap && <HeatmapLayer points={heatPoints} />}
          <MarkersLayer
            materials={materials}
            hazards={hazards}
            showMaterials={showMaterials}
            showHazards={showHazards}
          />
        </MapContainer>

        {/* Legend */}
        <div style={{
          position: 'absolute', bottom: 20, right: 20, zIndex: 1000,
          background: 'rgba(13,13,26,0.9)', border: '1px solid #333',
          borderRadius: 8, padding: '12px 16px', fontSize: 12,
        }}>
          <div style={{ color: '#aaa', marginBottom: 8, fontWeight: 600 }}>圖例</div>
          {Object.entries(URGENCY_LABELS).reverse().map(([u, label]) => (
            <div key={u} style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
              <div style={{ width: 12, height: 12, borderRadius: '50%', background: URGENCY_COLORS[u] }} />
              <span style={{ color: URGENCY_COLORS[u] }}>{label}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
