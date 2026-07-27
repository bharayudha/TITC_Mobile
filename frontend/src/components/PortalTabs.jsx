/**
 * Component: PortalTabs.jsx
 * Deskripsi: Tab navigasi atas sesuai screenshot (Home, Spaces, Courses, Members, Preparation Test)
 */

import React from 'react';
import { Home, Play, BookOpen, Users, Headphones } from 'lucide-react';

export default function PortalTabs({ activeTab = 'home', onSelectTab }) {
  const tabs = [
    { id: 'home', label: 'Home', icon: Home },
    { id: 'spaces', label: 'Spaces', icon: Play },
    { id: 'courses', label: 'Courses', icon: BookOpen },
    { id: 'members', label: 'Members', icon: Users },
    { id: 'prep_test', label: 'Preparation Test', icon: Headphones }
  ];

  return (
    <div className="portal-tabs-scroll">
      <div className="portal-tabs-container">
        {tabs.map((tab) => {
          const Icon = tab.icon;
          const isActive = activeTab === tab.id;
          return (
            <button
              key={tab.id}
              className={`portal-tab-btn ${isActive ? 'active' : ''}`}
              onClick={() => onSelectTab && onSelectTab(tab.id)}
            >
              <Icon size={16} className="tab-icon" />
              <span>{tab.label}</span>
            </button>
          );
        })}
      </div>
    </div>
  );
}
