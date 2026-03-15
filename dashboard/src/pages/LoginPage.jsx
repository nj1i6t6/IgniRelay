import React, { useState } from 'react';
import { login } from '../services/api';

const styles = {
  container: {
    display: 'flex', flexDirection: 'column', alignItems: 'center',
    justifyContent: 'center', height: '100vh',
    background: 'linear-gradient(135deg, #0d0d1a 0%, #1a1a2e 100%)',
  },
  card: {
    background: '#1a1a2e', border: '1px solid #333',
    borderRadius: 12, padding: '40px 48px', width: 360, maxWidth: '90vw',
    boxShadow: '0 8px 32px rgba(0,0,0,0.5)',
  },
  title: { fontSize: 28, fontWeight: 700, color: '#ff4444', marginBottom: 4 },
  subtitle: { color: '#888', fontSize: 14, marginBottom: 32 },
  label: { display: 'block', color: '#aaa', fontSize: 12, marginBottom: 6, marginTop: 16 },
  input: {
    width: '100%', padding: '10px 12px', background: '#0d0d1a',
    border: '1px solid #333', borderRadius: 6, color: '#fff',
    fontSize: 14, outline: 'none',
  },
  button: {
    width: '100%', padding: '12px', marginTop: 28,
    background: '#cc1a1a', border: 'none', borderRadius: 6,
    color: '#fff', fontSize: 16, fontWeight: 600, cursor: 'pointer',
  },
  error: { color: '#ff6666', fontSize: 13, marginTop: 12, textAlign: 'center' },
};

export default function LoginPage({ onLogin }) {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const res = await login(username, password);
      onLogin(res.data.token);
    } catch (err) {
      setError(err.response?.data?.error || '登入失敗，請確認帳號密碼');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={styles.container}>
      <div style={styles.card}>
        <div style={styles.title}>ResQMesh</div>
        <div style={styles.subtitle}>指揮中心 — 政府緊急應變系統</div>
        <form onSubmit={handleSubmit}>
          <label style={styles.label}>帳號</label>
          <input
            style={styles.input}
            type="text"
            value={username}
            onChange={e => setUsername(e.target.value)}
            placeholder="commander"
            autoComplete="username"
            required
          />
          <label style={styles.label}>密碼</label>
          <input
            style={styles.input}
            type="password"
            value={password}
            onChange={e => setPassword(e.target.value)}
            placeholder="••••••••"
            autoComplete="current-password"
            required
          />
          {error && <div style={styles.error}>{error}</div>}
          <button style={styles.button} type="submit" disabled={loading}>
            {loading ? '登入中...' : '登入指揮中心'}
          </button>
        </form>
      </div>
    </div>
  );
}
