import React, { useState } from 'react';

const S = {
  container: { padding: 16 },
  addRow: { display: 'flex', gap: 8, marginBottom: 16 },
  input: {
    flex: 1, padding: '8px 10px', background: '#0d0d1a',
    border: '1px solid #333', borderRadius: 6, color: '#fff', fontSize: 12,
    fontFamily: 'monospace', outline: 'none',
  },
  addBtn: {
    padding: '8px 12px', background: '#cc1a1a', border: 'none',
    borderRadius: 6, color: '#fff', cursor: 'pointer', fontSize: 12,
  },
  item: {
    padding: '10px 0', borderBottom: '1px solid #1a1a2e',
    display: 'flex', alignItems: 'center', gap: 8,
  },
  pubkey: { flex: 1, fontSize: 11, color: '#888', fontFamily: 'monospace' },
  reason: { fontSize: 10, padding: '2px 6px', background: '#ff222222', color: '#ff6666', borderRadius: 3 },
  weight: { fontSize: 10, color: '#555' },
  removeBtn: {
    padding: '3px 8px', background: 'none', border: '1px solid #333',
    borderRadius: 3, color: '#666', cursor: 'pointer', fontSize: 10,
  },
  empty: { textAlign: 'center', color: '#555', padding: 24, fontSize: 13 },
};

export default function BlacklistPanel({ blacklist, onAdd, onRemove }) {
  const [pubkeyInput, setPubkeyInput] = useState('');
  const [reasonInput, setReasonInput] = useState('MANUAL_BAN');

  const handleAdd = () => {
    const hex = pubkeyInput.trim();
    if (!hex) return;
    onAdd(hex, reasonInput);
    setPubkeyInput('');
  };

  return (
    <div style={S.container}>
      <div style={S.addRow}>
        <input
          style={S.input}
          type="text"
          placeholder="公鑰 hex..."
          value={pubkeyInput}
          onChange={e => setPubkeyInput(e.target.value)}
        />
        <button style={S.addBtn} onClick={handleAdd}>封鎖</button>
      </div>

      {blacklist.length === 0 ? (
        <div style={S.empty}>目前黑名單為空</div>
      ) : (
        blacklist.map((item) => (
          <div key={item.pubkey_hex} style={S.item}>
            <div style={S.pubkey}>{item.pubkey_hex?.slice(0, 24)}...</div>
            <span style={S.reason}>{item.reason}</span>
            <span style={S.weight}>{item.total_weight?.toFixed(1)}分</span>
            <button
              style={S.removeBtn}
              onClick={() => onRemove(item.pubkey_hex)}
            >
              解除
            </button>
          </div>
        ))
      )}
    </div>
  );
}
