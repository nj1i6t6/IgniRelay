import React from 'react';

const S = {
  panel: {
    padding: '12px 16px', borderBottom: '1px solid #222',
    display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8,
  },
  stat: { textAlign: 'center' },
  value: { fontSize: 20, fontWeight: 700, color: '#ff4444' },
  label: { fontSize: 9, color: '#555', textTransform: 'uppercase' },
  sos: { color: '#ff2222' },
  yellow: { color: '#ffaa00' },
  green: { color: '#22cc44' },
  blue: { color: '#4488ff' },
};

export default function StatsPanel({ stats }) {
  if (!stats?.totals) return null;
  const t = stats.totals;
  return (
    <div style={S.panel}>
      <div style={S.stat}>
        <div style={{ ...S.value, ...S.sos }}>{t.sos_red_count}</div>
        <div style={S.label}>SOS_RED</div>
      </div>
      <div style={S.stat}>
        <div style={{ ...S.value, ...S.yellow }}>{t.sos_yellow_count}</div>
        <div style={S.label}>SOS_YELLOW</div>
      </div>
      <div style={S.stat}>
        <div style={{ ...S.value, ...S.green }}>{t.resource_count}</div>
        <div style={S.label}>RESOURCE</div>
      </div>
      <div style={S.stat}>
        <div style={{ ...S.value, color: '#aaa' }}>{t.unique_nodes}</div>
        <div style={S.label}>節點數</div>
      </div>
      <div style={S.stat}>
        <div style={{ ...S.value, color: '#aaa' }}>{t.unique_gateways}</div>
        <div style={S.label}>閘道器</div>
      </div>
      <div style={S.stat}>
        <div style={{ ...S.value, ...S.blue }}>{stats.events_last_5min}</div>
        <div style={S.label}>5分鐘事件</div>
      </div>
    </div>
  );
}
