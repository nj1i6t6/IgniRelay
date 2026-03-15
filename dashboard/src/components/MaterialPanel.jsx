import React from 'react';

const S = {
    container: { padding: '16px', color: '#fff' },
    card: { background: '#222', borderRadius: 8, padding: 12, marginBottom: 12, borderLeft: '4px solid #22cc44' },
    title: { fontSize: 14, fontWeight: 'bold', marginBottom: 4 },
    text: { fontSize: 12, color: '#aaa', margin: '2px 0' },
    tag: { display: 'inline-block', background: '#333', padding: '2px 6px', borderRadius: 4, fontSize: 10, marginRight: 6, color: '#ddd' }
};

export default function MaterialPanel({ materials }) {
    if (!materials || materials.length === 0) {
        return <div style={{ padding: 20, textAlign: 'center', color: '#666' }}>無物資請求資料</div>;
    }

    return (
        <div style={S.container}>
            <div style={{ marginBottom: 16, fontSize: 15, fontWeight: 'bold' }}>📦 離線物資需求</div>
            {materials.map(m => {
                // Handle both simple text payloads and structured JSON
                const isJson = !!m.data && typeof m.data === 'object' && !m.data.description;
                const textDisplay = m.data?.description || JSON.stringify(m.data);

                return (
                    <div key={m.event_id} style={S.card}>
                        {isJson ? (
                            <>
                                <div style={S.title}>{m.data.itemName || '物資請求'} x {m.data.quantity || 1}</div>
                                <div style={S.text}>狀態: <span style={S.tag}>{m.data.status || 'PENDING'}</span></div>
                                {m.data.contact && <div style={S.text}>聯絡方式: {m.data.contact}</div>}
                            </>
                        ) : (
                            <>
                                <div style={S.title}>需求廣播</div>
                                <div style={S.text}>{textDisplay}</div>
                            </>
                        )}
                        <div style={S.text}>
                            時間: {new Date(Number(m.timestamp)).toLocaleString()}
                        </div>
                        <div style={S.text}>來源節點: {m.origin.substring(0, 8)}...</div>
                    </div>
                );
            })}
        </div>
    );
}
