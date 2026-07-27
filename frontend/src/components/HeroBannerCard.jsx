/**
 * Component: HeroBannerCard.jsx
 * Deskripsi: Card Banner Hero promo TOEFL 2026 sesuai gambar screenshot portal TITC
 */

import React from 'react';

export default function HeroBannerCard() {
  return (
    <div className="hero-banner-card">
      <div className="hero-banner-content">
        <span className="badge-coming-soon">COMING SOON</span>
        
        <h2 className="hero-banner-title">
          Belum familiar dengan TOEFL 2026?
        </h2>
        <p className="hero-banner-subtitle">
          Mau latihan tes TOEFL iBT dengan mockup tes yang live dan presisi?
        </p>

        <div className="hero-banner-actions">
          <button className="btn-free-trial">
            FREE TRIAL
          </button>
          <span className="badge-available-date">Available on 15 July</span>
        </div>
      </div>

      <div className="hero-banner-illustration">
        <div className="avatar-preview-box">
          <span className="headset-badge">🎧 TOEFL iBT</span>
        </div>
      </div>
    </div>
  );
}
