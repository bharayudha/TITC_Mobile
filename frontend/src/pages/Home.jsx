import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import MenuGrid from '../components/MenuGrid';
import { authService } from '../services/authService';
import { LogIn, LogOut, Bell, Compass } from 'lucide-react';

export default function Home() {
  const navigate = useNavigate();
  const [user, setUser] = useState(null);

  useEffect(() => {
    if (authService.isAuthenticated()) {
      setUser(authService.getCurrentUser());
    }
  }, []);

  const handleLogout = () => {
    authService.logout();
    setUser(null);
  };

  return (
    <div className="page-container home-page">
      {/* Header Banner */}
      <header className="app-header">
        <div className="header-brand">
          <div className="brand-logo">TITC</div>
          <div>
            <h1 className="header-title">TITC Mobile</h1>
            <p className="header-subtitle">Komunitas & Layanan Resmi TITC</p>
          </div>
        </div>

        <div className="header-actions">
          {user ? (
            <button className="icon-btn logout-btn" onClick={handleLogout} title="Logout">
              <LogOut size={20} />
            </button>
          ) : (
            <button className="icon-btn login-btn" onClick={() => navigate('/login')} title="Login">
              <LogIn size={20} />
            </button>
          )}
        </div>
      </header>

      {/* Greeting Card */}
      <section className="welcome-card">
        <div className="welcome-content">
          <h2>Selamat datang, {user ? user.displayName : 'Anggota TITC'}!</h2>
          <p>Akses cepat layanan TOEFL ITP, aktivitas komunitas BuddyBoss, dan info resmi.</p>
        </div>
        <button 
          className="btn-primary"
          onClick={() => navigate('/feed')}
        >
          <Compass size={18} style={{ marginRight: 6 }} /> Jelajahi Feed Komunitas
        </button>
      </section>

      {/* Main Shortcuts Section */}
      <section className="section-container">
        <div className="section-header">
          <h3 className="section-title">Menu Utama</h3>
          <span className="section-tag">Pintas WordPress</span>
        </div>
        <MenuGrid />
      </section>
    </div>
  );
}
