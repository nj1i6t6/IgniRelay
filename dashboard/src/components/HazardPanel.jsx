import React from 'react';

const S = {
    container: { padding: '16px', color: '#fff' },
    card: { background: '#222', borderRadius: 8, padding: 12, marginBottom: 12, borderLeft: '4px solid #ffaa00' },
    highUrgencyCard: { background: '#331111', borderRadius: 8, padding: 12, marginBottom: 12, borderLeft: '4px solid #ff2222' },
    title: { fontSize: 14, fontWeight: 'bold', marginBottom: 4 },
    text: { fontSize: 12, color: '#aaa', margin: '2px 0' },
};

export default function HazardPanel({ hazards }) {
    if (!hazards || hazards.length === 0) {
        return <div style={{ padding: 20, textAlign: 'center', color: '#666' }}>無危險回報資料</div>;
    }

    return (
        <div style={S.container}>
            <div style={{ marginBottom: 16, fontSize: 15, fontWeight: 'bold' }}>⚠️ 災情與危險回報</div>
            {hazards.map(h => {
                const isJson = !!h.data && typeof h.data === 'object' && !h.data.description;
                const textDisplay = h.data?.description || JSON.stringify(h.data);
                const cardStyle = h.urgency >= 3 ? S.highUrgencyCard : S.card;

                return (
                    <div key={h.event_id} style={cardStyle}>
                        {isJson ? (
                            <>
                                <div style={S.title}>{h.data.type || '危險區域'} (嚴重度: {h.data.severity || h.urgency})</div>
                                <div style={S.text}>半徑: {h.data.radius || '未知'} 公尺</div>
                                {h.data.description && <div style={S.text}>{h.data.description}</div>}
                            </>
                        ) : (
                            <>
                                <div style={S.title}>災情通報</div>
                                <div style={S.text}>{textDisplay}</div>
                            </>
                        )}
                        <div style={S.text}>
                            時間: {new Date(Number(h.timestamp)).toLocaleString()}
                        </div>
                        <div style={S.text}>座標: {h.lat.toFixed(4)}, {h.lng.toFixed(4)}</div>
                    </div>
                );
            })}
        </div>
    );
}
