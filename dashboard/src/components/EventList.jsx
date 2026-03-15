import React, { useState } from 'react';

const URGENCY_COLOR = { 3: '#ff2222', 2: '#ffaa00', 1: '#22cc44', 0: '#4488ff' };
const URGENCY_LABEL = { 3: 'SOS_RED', 2: 'SOS_YELLOW', 1: 'RESOURCE', 0: 'INFO' };

const S = {
  list: { padding: 0 },
  item: {
    padding: '10px 16px', borderBottom: '1px solid #1a1a2e',
    cursor: 'pointer', transition: 'background 0.1s',
  },
  row1: { display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 },
  badge: { fontSize: 10, padding: '2px 6px', borderRadius: 3, fontWeight: 700 },
  pubkey: { fontSize: 10, color: '#666', fontFamily: 'monospace' },
  type: { fontSize: 11, color: '#888' },
  time: { fontSize: 10, color: '#555', marginLeft: 'auto' },
  location: { fontSize: 10, color: '#555' },
  banBtn: {
    fontSize: 10, padding: '2px 8px', background: 'none', cursor: 'pointer',
    border: '1px solid #555', borderRadius: 3, color: '#888',
  },
};

function formatTime(ts) {
  if (!ts) return '';
  const d = new Date(parseInt(ts));
  return d.toLocaleTimeString('zh-TW', { hour12: false });
}

export default function EventList({ events, onBlacklist }) {
  const [expanded, setExpanded] = useState(null);

  return (
    <div style={S.list}>
      {events.length === 0 && (
        <div style={{ padding: 24, textAlign: 'center', color: '#555' }}>尚無事件資料</div>
      )}
      {events.map((evt, i) => {
        const color = URGENCY_COLOR[evt.urgency] || '#666';
        const label = URGENCY_LABEL[evt.urgency] || '?';
        const isExpanded = expanded === i;
        return (
          <div
            key={evt.event_id || i}
            style={{ ...S.item, background: isExpanded ? '#111' : 'transparent' }}
            onClick={() => setExpanded(isExpanded ? null : i)}
          >
            <div style={S.row1}>
              <span style={{ ...S.badge, background: color + '22', color }}>
                {label}
              </span>
              <span style={S.type}>{evt.event_type}</span>
              <span style={S.time}>{formatTime(evt.hlc_timestamp)}</span>
            </div>
            <div style={{ ...S.row1, marginBottom: 0 }}>
              <span style={{ ...S.pubkey, color: `#${evt.identity_level >= 1 ? '22cc44' : '888'}` }}>
                L{evt.identity_level} {evt.sender_pubkey?.slice(0, 20)}...
              </span>
              {evt.received_lat && (
                <span style={S.location}>
                  {evt.received_lat?.toFixed(4)}, {evt.received_lng?.toFixed(4)}
                </span>
              )}
            </div>
            {isExpanded && (
              <div style={{ marginTop: 8, paddingTop: 8, borderTop: '1px solid #222' }}>
                <div style={{ fontSize: 10, color: '#555', marginBottom: 4 }}>
                  Event ID: <span style={{ color: '#888', fontFamily: 'monospace' }}>{evt.event_id}</span>
                </div>
                <div style={{ fontSize: 10, color: '#555', marginBottom: 4 }}>
                  Gateway: <span style={{ color: '#888' }}>{evt.gateway_id}</span>
                </div>
                <button
                  style={{ ...S.banBtn, color: '#ff6666', borderColor: '#ff4444' }}
                  onClick={(e) => {
                    e.stopPropagation();
                    if (confirm(`將 ${evt.sender_pubkey?.slice(0, 20)}... 加入黑名單?`)) {
                      onBlacklist(evt.sender_pubkey, 'COMMANDER_MANUAL');
                    }
                  }}
                >
                  🚫 封鎖此節點
                </button>
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}
