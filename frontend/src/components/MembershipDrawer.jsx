/**
 * Component: MembershipDrawer.jsx
 * Deskripsi: Menu Navigasi Samping Left Sidebar (Membership Areas, TOEFL Prep, ESP) dari screenshot portal
 */

import React from 'react';
import { 
  X, 
  Flame, 
  Monitor, 
  Tag, 
  FileText, 
  Rocket, 
  Lock, 
  BookOpen 
} from 'lucide-react';

export default function MembershipDrawer({ isOpen, onClose, onSelectMenu }) {
  if (!isOpen) return null;

  const membershipAreas = [
    { id: 'free_placement', title: 'FREE Placement Test', icon: Flame, color: '#ef4444' },
    { id: 'inst_prep', title: 'Institutional Prep Test', icon: Monitor, color: '#3b82f6' },
    { id: 'toefl_mockup', title: 'TOEFL - Mockup Test', icon: Monitor, color: '#06b6d4', badge: 'New' },
    { id: 'promo_member', title: 'Promo Khusus Member', icon: Tag, color: '#ef4444' },
    { id: 'update_announcement', title: 'Update - Announcement', icon: FileText, color: '#8b5cf6' },
    { id: 'update_certification', title: 'Update - Certification', icon: Rocket, color: '#ec4899' }
  ];

  const toeflPrep = [
    { id: '4h_intensive', title: '4 Hours Intensive' },
    { id: '3m_courses', title: '3 Meeting Courses' },
    { id: '7m_courses', title: '7 Meeting Courses' },
    { id: '10m_courses', title: '10 Meeting Courses' },
    { id: '15m_courses', title: '15 Meeting Courses' },
    { id: '20m_courses', title: '20 Meeting Courses' }
  ];

  return (
    <div className="drawer-overlay" onClick={onClose}>
      <aside className="membership-drawer" onClick={(e) => e.stopPropagation()}>
        <div className="drawer-header">
          <h3>Membership Areas</h3>
          <button className="icon-btn" onClick={onClose}>
            <X size={20} />
          </button>
        </div>

        <div className="drawer-body">
          {/* Section 1: Membership Areas */}
          <div className="drawer-section">
            <h4 className="drawer-section-title">Membership Areas</h4>
            <div className="drawer-menu-list">
              {membershipAreas.map((item) => {
                const Icon = item.icon;
                return (
                  <button 
                    key={item.id} 
                    className="drawer-menu-item"
                    onClick={() => onSelectMenu && onSelectMenu(item)}
                  >
                    <Icon size={16} style={{ color: item.color, marginRight: 10 }} />
                    <span>{item.title}</span>
                    {item.badge && <span className="drawer-badge">{item.badge}</span>}
                  </button>
                );
              })}
            </div>
          </div>

          {/* Section 2: TOEFL Preparation */}
          <div className="drawer-section">
            <h4 className="drawer-section-title">TOEFL Preparation</h4>
            <div className="drawer-menu-list">
              {toeflPrep.map((item) => (
                <button 
                  key={item.id} 
                  className="drawer-menu-item locked"
                  onClick={() => onSelectMenu && onSelectMenu(item)}
                >
                  <BookOpen size={16} style={{ marginRight: 10, color: '#8b5cf6' }} />
                  <span className="menu-text">{item.title}</span>
                  <Lock size={14} className="lock-icon" />
                </button>
              ))}
            </div>
          </div>

          {/* Section 3: English for Specific Purposes */}
          <div className="drawer-section">
            <h4 className="drawer-section-title">English for Specific Purposes</h4>
            <div className="drawer-menu-list">
              <button className="drawer-menu-item locked">
                <BookOpen size={16} style={{ marginRight: 10, color: '#10b981' }} />
                <span className="menu-text">Structure and Grammar</span>
                <Lock size={14} className="lock-icon" />
              </button>
            </div>
          </div>
        </div>
      </aside>
    </div>
  );
}
