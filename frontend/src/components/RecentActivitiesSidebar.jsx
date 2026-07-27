/**
 * Component: RecentActivitiesSidebar.jsx
 * Deskripsi: Widget Trending Posts & Recent Activities sesuai sidebar kanan website Portal TITC
 */

import React from 'react';
import { TrendingUp, Clock } from 'lucide-react';

export default function RecentActivitiesSidebar() {
  const trendingPosts = [
    {
      id: 1,
      title: '[ Updata ] Proses sertifikasi tanggal 8-12 Juli 2026',
      author: 'TITC Indonesia',
      time: '8 jam yang lalu'
    }
  ];

  const recentActivities = [
    {
      id: 101,
      author: 'TITC Indonesia',
      action: 'published a new status',
      title: '[ Updata ] Proses sertifikasi tanggal 8-...',
      time: '8 hours ago'
    },
    {
      id: 102,
      author: 'TITC Indonesia',
      action: 'published a new status',
      title: 'Daftar Beasiswa LPDP Tahap 2 Tahun 2026 ...',
      time: '24 days ago'
    },
    {
      id: 103,
      author: 'TITC Indonesia',
      action: 'published a new status',
      title: '[ UPDATE ] Penyesuaian Score Report & Pe...',
      time: 'a month ago'
    }
  ];

  return (
    <div className="recent-activities-section">
      {/* Widget Trending Posts */}
      <div className="portal-widget-card">
        <div className="widget-header">
          <TrendingUp size={16} className="widget-icon" />
          <h4 className="widget-title">Trending Posts</h4>
        </div>
        <div className="widget-body">
          {trendingPosts.map((post) => (
            <div key={post.id} className="trending-item">
              <div className="titc-mini-logo">TITC</div>
              <div className="trending-info">
                <p className="trending-item-title">{post.title}</p>
                <span className="trending-author">{post.author}</span>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Widget Recent Activities */}
      <div className="portal-widget-card">
        <div className="widget-header">
          <Clock size={16} className="widget-icon" />
          <h4 className="widget-title">Recent Activities</h4>
        </div>
        <div className="widget-body">
          {recentActivities.map((act) => (
            <div key={act.id} className="activity-row-item">
              <div className="titc-mini-logo">TITC</div>
              <div className="activity-row-info">
                <p className="activity-row-text">
                  <strong>{act.author}</strong> {act.action} <span className="act-highlight">{act.title}</span>
                </p>
                <span className="activity-row-time">{act.time}</span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
