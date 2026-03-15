import React, { useState } from 'react';

const REGIONS = [
  'all', '台北市', '新北市', '桃園市', '台中市', '台南市', '高雄市',
  '基隆市', '新竹市', '嘉義市', '新竹縣', '苗栗縣', '彰化縣',
  '南投縣', '雲林縣', '嘉義縣', '屏東縣', '宜蘭縣', '花蓮縣', '台東縣',
];

const URGENCY_OPTIONS = [
  { value: 3, label: 'SOS_RED — 緊急', color: '#ff2222' },
  { value: 2, label: 'SOS_YELLOW — 警示', color: '#ffaa00' },
  { value: 1, label: 'RESOURCE — 物資', color: '#22cc44' },
  { value: 0, label: 'INFO — 一般通報', color: '#4488ff' },
];

const S = {
  container: { padding: 16 },
  label: { color: '#888', fontSize: 11, marginBottom: 6, marginTop: 14, display: 'block' },
  select: {
    width: '100%', padding: '8px 10px', background: '#0d0d1a',
    border: '1px solid #333', borderRadius: 6, color: '#fff', fontSize: 13, outline: 'none',
  },
  textarea: {
    width: '100%', padding: '10px 12px', background: '#0d0d1a',
    border: '1px solid #333', borderRadius: 6, color: '#fff', fontSize: 13,
    outline: 'none', resize: 'vertical', minHeight: 80, fontFamily: 'inherit',
  },
  sendBtn: {
    width: '100%', marginTop: 16, padding: '12px', background: '#cc1a1a',
    border: 'none', borderRadius: 6, color: '#fff', fontSize: 14,
    fontWeight: 700, cursor: 'pointer',
  },
  presets: { marginTop: 16 },
  presetTitle: { color: '#666', fontSize: 11, marginBottom: 8 },
  presetBtn: {
    display: 'block', width: '100%', marginBottom: 6,
    padding: '8px 12px', background: '#111', border: '1px solid #222',
    borderRadius: 6, color: '#aaa', cursor: 'pointer', fontSize: 12,
    textAlign: 'left',
  },
};

const PRESET_MESSAGES = [
  { label: '📢 搜救隊部署通知', message: '搜救隊已進入該區域，請民眾配合引導', urgency: 1 },
  { label: '🚧 道路封閉公告', message: '前方道路封閉，請改道繞行', urgency: 2 },
  { label: '🏥 緊急醫療資源調派', message: '緊急醫療資源已調派，請保持通訊暢通', urgency: 3 },
  { label: '🍱 物資分發地點公告', message: '物資分發點已設立，請前往核心指揮所領取', urgency: 1 },
  { label: '⚠️ 疏散警告', message: '該區域存在危險，請立即疏散至指定安全區', urgency: 3 },
];

export default function DispatchPanel({ onDispatch }) {
  const [message, setMessage] = useState('');
  const [region, setRegion] = useState('all');
  const [urgency, setUrgency] = useState(2);

  const handleSend = () => {
    if (!message.trim()) return;
    if (!confirm(`確認發送指令至 ${region === 'all' ? '全部區域' : region}?\n\n${message}`)) return;
    onDispatch(message.trim(), region, urgency);
    setMessage('');
  };

  return (
    <div style={S.container}>
      <label style={S.label}>目標區域</label>
      <select style={S.select} value={region} onChange={e => setRegion(e.target.value)}>
        {REGIONS.map(r => (
          <option key={r} value={r}>{r === 'all' ? '全部縣市' : r}</option>
        ))}
      </select>

      <label style={S.label}>優先等級</label>
      <select style={S.select} value={urgency} onChange={e => setUrgency(parseInt(e.target.value))}>
        {URGENCY_OPTIONS.map(o => (
          <option key={o.value} value={o.value}>{o.label}</option>
        ))}
      </select>

      <label style={S.label}>指令內容</label>
      <textarea
        style={S.textarea}
        value={message}
        onChange={e => setMessage(e.target.value)}
        placeholder="輸入指揮指令..."
        maxLength={500}
      />

      <button style={S.sendBtn} onClick={handleSend} disabled={!message.trim()}>
        📢 發送指揮指令
      </button>

      <div style={S.presets}>
        <div style={S.presetTitle}>預設指令快捷</div>
        {PRESET_MESSAGES.map((p, i) => (
          <button
            key={i}
            style={S.presetBtn}
            onClick={() => { setMessage(p.message); setUrgency(p.urgency); }}
          >
            {p.label}
          </button>
        ))}
      </div>
    </div>
  );
}
