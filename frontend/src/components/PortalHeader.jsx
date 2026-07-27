/**
 * Component: PortalHeader.jsx
 * Deskripsi: Header atas aplikasi sesuai dengan tampilan website Portal TITC Indonesia
 */

import React from 'react';
import { Menu, Sun, Moon, Search, Bell, User } from 'lucide-react';

export default function PortalHeader({ onToggleDrawer, isDarkMode, onToggleDarkMode }) {
  return (
    <header className="portal-header">
      <div className="header-left">
        <button 
          className="header-icon-btn drawer-toggle-btn"
          onClick={onToggleDrawer}
          title="Buka Menu Membership Areas"
        >
          <Menu size={22} />
        </button>
        <div className="portal-brand">
          <span className="brand-titc">TITC</span>
          <span className="brand-sub">Indonesia</span>
        </div>
      </div>

      <div className="header-right">
        {/* Tombol Toggle Theme */}
        <button 
          className="header-icon-btn" 
          onClick={onToggleDarkMode} 
          title="Ganti Mode Gelap/Terang"
        >
          {isDarkMode ? <Sun size={18} /> : <Moon size={18} />}
        </button>

        {/* Tombol Pencarian */}
        <button className="header-icon-btn" title="Cari di Portal">
          <Search size={18} />
        </button>

        {/* Tombol Notifikasi */}
        <button className="header-icon-btn notification-btn" title="Notifikasi">
          <Bell size={18} />
          <span className="notification-dot"></span>
        </button>

        {/* Avatar Profil dengan Status 20% */}
        <div className="user-profile-badge" title="Profil Anda (20% Lengkap)">
          <div className="avatar-circle">
            <span>A</span>
          </div>
          <div className="profile-progress-pill">
            <span>20%</span>
          </div>
        </div>
      </div>
    </header>
  );
}
