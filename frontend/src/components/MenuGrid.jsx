import React from 'react';
import { useNavigate } from 'react-router-dom';
import { 
  FileText, 
  Calendar, 
  Users, 
  Award, 
  Info, 
  HelpCircle, 
  BookOpen, 
  ShieldCheck 
} from 'lucide-react';

const defaultMenuItems = [
  {
    id: 'toefl',
    title: 'TOEFL ITP',
    icon: Award,
    color: '#3b82f6',
    url: 'https://titc.or.id/toefl-itp',
    badge: 'Resmi'
  },
  {
    id: 'jadwal',
    title: 'Jadwal Tes',
    icon: Calendar,
    color: '#10b981',
    url: 'https://titc.or.id/toefl-itp',
    badge: 'Aktif'
  },
  {
    id: 'komunitas',
    title: 'Portal Feed',
    icon: Users,
    color: '#8b5cf6',
    nativeRoute: '/feed',
    badge: 'Native'
  },
  {
    id: 'berita',
    title: 'Info Beasiswa',
    icon: Info,
    color: '#06b6d4',
    url: 'https://titc.or.id/beasiswa-lpdp-tahap-2-tahun-2026/',
    badge: 'LPDP'
  },
  {
    id: 'portal_web',
    title: 'Portal Komunitas',
    icon: BookOpen,
    color: '#ec4899',
    url: 'https://titc.or.id/portal/',
    badge: 'Web'
  },
  {
    id: 'sertifikat',
    title: 'Cek Sertifikat',
    icon: ShieldCheck,
    color: '#f59e0b',
    url: 'https://titc.or.id/toefl-itp'
  },
  {
    id: 'syarat',
    title: 'Syarat & Ketentuan',
    icon: FileText,
    color: '#64748b',
    url: 'https://titc.or.id/toefl-itp'
  },
  {
    id: 'bantuan',
    title: 'Pusat Bantuan',
    icon: HelpCircle,
    color: '#ef4444',
    url: 'https://titc.or.id/'
  }
];

export default function MenuGrid({ items = defaultMenuItems }) {
  const navigate = useNavigate();

  const handleMenuClick = (item) => {
    if (item.nativeRoute) {
      navigate(item.nativeRoute);
    } else if (item.url) {
      navigate('/webview', { state: { url: item.url, title: item.title } });
    }
  };

  return (
    <div className="menu-grid">
      {items.map((item) => {
        const IconComponent = item.icon;
        return (
          <button
            key={item.id}
            className="menu-card"
            onClick={() => handleMenuClick(item)}
          >
            {item.badge && <span className="menu-badge">{item.badge}</span>}
            <div 
              className="menu-icon-wrapper"
              style={{ backgroundColor: `${item.color}15`, color: item.color }}
            >
              <IconComponent size={26} />
            </div>
            <span className="menu-title">{item.title}</span>
          </button>
        );
      })}
    </div>
  );
}
