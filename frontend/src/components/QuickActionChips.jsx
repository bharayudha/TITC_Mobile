/**
 * Component: QuickActionChips.jsx
 * Deskripsi: Deretan tombol pintas horizontal sesuai screenshot (Tes TOEFL ITP, Prep Test, Check Readiness, dll.)
 */

import React from 'react';
import { useNavigate } from 'react-router-dom';
import { Star, Zap, Monitor, Radio, CheckCircle, Lightbulb } from 'lucide-react';

export default function QuickActionChips() {
  const navigate = useNavigate();

  const actionItems = [
    {
      id: 'toefl_resmi',
      title: 'Daftar Tes TOEFL ITP Resmi ETS',
      icon: Star,
      color: '#f59e0b',
      url: 'https://titc.or.id/toefl-itp'
    },
    {
      id: 'prep_online',
      title: 'Daftar Preparation Test Online',
      icon: Zap,
      color: '#ec4899',
      url: 'https://titc.or.id/toefl-itp'
    },
    {
      id: 'check_readiness',
      title: 'Check Readiness',
      icon: Monitor,
      color: '#06b6d4',
      url: 'https://titc.or.id/toefl-itp'
    },
    {
      id: 'cert_tracking',
      title: 'Certificate Tracking',
      icon: Radio,
      color: '#8b5cf6',
      url: 'https://titc.or.id/portal/'
    },
    {
      id: 'ept_verification',
      title: 'EPT Certificate Verification',
      icon: CheckCircle,
      color: '#10b981',
      url: 'https://titc.or.id/toefl-itp'
    },
    {
      id: 'free_placement',
      title: 'FREE Placement Test',
      icon: Lightbulb,
      color: '#eab308',
      url: 'https://titc.or.id/toefl-itp'
    }
  ];

  const handleChipClick = (item) => {
    navigate('/webview', { state: { url: item.url, title: item.title } });
  };

  return (
    <div className="quick-chips-scroll">
      <div className="quick-chips-wrapper">
        {actionItems.map((item) => {
          const Icon = item.icon;
          return (
            <button
              key={item.id}
              className="quick-chip-btn"
              onClick={() => handleChipClick(item)}
            >
              <Icon size={14} style={{ color: item.color, marginRight: 6 }} />
              <span>{item.title}</span>
            </button>
          );
        })}
      </div>
    </div>
  );
}
