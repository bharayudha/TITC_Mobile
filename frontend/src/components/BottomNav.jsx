import React from 'react';
import { NavLink } from 'react-router-dom';
import { Home, Rss, Users, UserCheck, MessageSquare } from 'lucide-react';

export default function BottomNav() {
  const navItems = [
    { path: '/', label: 'Beranda', icon: Home },
    { path: '/feed', label: 'Feed', icon: Rss },
    { path: '/groups', label: 'Grup', icon: Users },
    { path: '/members', label: 'Member', icon: UserCheck },
    { path: '/messages', label: 'Pesan', icon: MessageSquare }
  ];

  return (
    <nav className="bottom-nav">
      {navItems.map((item) => {
        const Icon = item.icon;
        return (
          <NavLink
            key={item.path}
            to={item.path}
            className={({ isActive }) =>
              isActive ? 'bottom-nav-item active' : 'bottom-nav-item'
            }
            end={item.path === '/'}
          >
            <Icon size={22} className="nav-icon" />
            <span className="nav-label">{item.label}</span>
          </NavLink>
        );
      })}
    </nav>
  );
}
