import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { authService } from '../services/authService';
import { Lock, User, ArrowLeft, LogIn } from 'lucide-react';

export default function Login() {
  const navigate = useNavigate();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!username || !password) {
      setError('Harap isi username dan password Anda');
      return;
    }

    setLoading(true);
    setError('');

    try {
      await authService.login(username, password);
      navigate('/');
    } catch (err) {
      setError('Login gagal. Periksa kembali akun Anda.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="page-container login-page">
      <header className="login-top-bar">
        <button className="icon-btn" onClick={() => navigate(-1)}>
          <ArrowLeft size={20} />
        </button>
        <h2>Masuk Akun TITC</h2>
      </header>

      <div className="login-card">
        <div className="login-badge-icon">
          <Lock size={32} />
        </div>
        <h3>Selamat Datang Kembali</h3>
        <p className="login-subtitle">Masuk menggunakan akun portal TITC Indonesia Anda</p>

        {error && <div className="error-alert">{error}</div>}

        <form onSubmit={handleSubmit} className="login-form">
          <div className="input-group">
            <label>Username / Email</label>
            <div className="input-wrapper">
              <User size={18} className="input-icon" />
              <input
                type="text"
                placeholder="Masukkan username atau email..."
                value={username}
                onChange={(e) => setUsername(e.target.value)}
              />
            </div>
          </div>

          <div className="input-group">
            <label>Password</label>
            <div className="input-wrapper">
              <Lock size={18} className="input-icon" />
              <input
                type="password"
                placeholder="Masukkan password..."
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </div>
          </div>

          <button type="submit" className="btn-primary btn-block" disabled={loading}>
            {loading ? 'Memproses Login...' : (
              <>
                <LogIn size={18} style={{ marginRight: 6 }} /> Masuk Sekarang
              </>
            )}
          </button>
        </form>
      </div>
    </div>
  );
}
