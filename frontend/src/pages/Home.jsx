/**
 * Page: Home.jsx
 * Deskripsi: Halaman Utama Aplikasi Mobile TITC Indonesia
 * Menggabungkan seluruh elemen tampilan dari screenshot Portal (Header, Tabs, Quick Chips, Hero Banner, Feed, Sidebar)
 */

import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import PortalHeader from '../components/PortalHeader';
import PortalTabs from '../components/PortalTabs';
import QuickActionChips from '../components/QuickActionChips';
import HeroBannerCard from '../components/HeroBannerCard';
import RecentActivitiesSidebar from '../components/RecentActivitiesSidebar';
import MembershipDrawer from '../components/MembershipDrawer';
import { activityService } from '../services/activityService';
import LoadingSpinner from '../components/LoadingSpinner';
import { Heart, MessageCircle, Share2, Send, Tag } from 'lucide-react';

export default function Home() {
  const navigate = useNavigate();
  const [activeTab, setActiveTab] = useState('home');
  const [isDarkMode, setIsDarkMode] = useState(false);
  const [isDrawerOpen, setIsDrawerOpen] = useState(false);
  const [activities, setActivities] = useState([]);
  const [loading, setLoading] = useState(true);
  const [postInput, setPostInput] = useState('');

  useEffect(() => {
    async function loadActivities() {
      try {
        const data = await activityService.getActivities();
        setActivities(data);
      } catch (err) {
        console.error(err);
      } finally {
        setLoading(false);
      }
    }
    loadActivities();
  }, []);

  const handleTabSelect = (tabId) => {
    setActiveTab(tabId);
    if (tabId === 'spaces') navigate('/groups');
    if (tabId === 'courses') navigate('/webview', { state: { url: 'https://titc.or.id/portal/', title: 'Courses TITC' } });
    if (tabId === 'members') navigate('/members');
    if (tabId === 'prep_test') navigate('/webview', { state: { url: 'https://titc.or.id/toefl-itp', title: 'Preparation Test' } });
  };

  const handleDrawerMenuSelect = (item) => {
    setIsDrawerOpen(false);
    if (item.url) {
      navigate('/webview', { state: { url: item.url, title: item.title } });
    } else {
      navigate('/webview', { state: { url: 'https://titc.or.id/toefl-itp', title: item.title } });
    }
  };

  const handleCreatePost = (e) => {
    e.preventDefault();
    if (!postInput.trim()) return;

    const newFeedItem = {
      id: Date.now(),
      user_name: 'Arnanda (Anda)',
      user_avatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=120&q=80',
      action: 'Arnanda membuat status baru',
      content: postInput,
      date: 'Baru saja',
      likes_count: 0,
      comments_count: 0
    };

    setActivities([newFeedItem, ...activities]);
    setPostInput('');
  };

  return (
    <div className={`portal-app-wrapper ${isDarkMode ? 'dark' : ''}`}>
      {/* 1. Header Atas Portal */}
      <PortalHeader 
        onToggleDrawer={() => setIsDrawerOpen(true)}
        isDarkMode={isDarkMode}
        onToggleDarkMode={() => setIsDarkMode(!isDarkMode)}
      />

      {/* 2. Menu Membership Drawer (Left Sidebar untuk Mobile) */}
      <MembershipDrawer
        isOpen={isDrawerOpen}
        onClose={() => setIsDrawerOpen(false)}
        onSelectMenu={handleDrawerMenuSelect}
      />

      {/* 3. Tab Navigasi Atas (Home, Spaces, Courses, Members, Preparation Test) */}
      <PortalTabs 
        activeTab={activeTab}
        onSelectTab={handleTabSelect}
      />

      {/* 4. Sub-Bar Tombol Pintas Cepat (Daftar TOEFL ITP, Prep Test, Check Readiness, dll.) */}
      <QuickActionChips />

      {/* 5. Konten Utama Portal Feed & Hero Banner */}
      <div className="portal-main-layout">
        <div className="portal-feed-column">
          {/* Banner Hero TOEFL 2026 Promo */}
          <HeroBannerCard />

          {/* Form Pembuatan Status ("What's happening, Arnanda") */}
          <form onSubmit={handleCreatePost} className="whats-happening-box">
            <div className="whats-happening-header">
              <div className="user-avatar-circle">A</div>
              <input
                type="text"
                value={postInput}
                onChange={(e) => setPostInput(e.target.value)}
                placeholder="What's happening, Arnanda"
                className="whats-happening-input"
              />
            </div>
            {postInput.trim() && (
              <div className="whats-happening-footer">
                <button type="submit" className="btn-post-submit">
                  <Send size={14} style={{ marginRight: 6 }} /> Posting
                </button>
              </div>
            )}
          </form>

          {/* Feed Postings */}
          {loading ? (
            <LoadingSpinner message="Memuat Feed Portal TITC..." />
          ) : (
            <div className="portal-feed-list">
              {activities.map((item) => (
                <article key={item.id} className="portal-post-card">
                  <div className="post-card-header">
                    <img 
                      src={item.user_avatar} 
                      alt={item.user_name} 
                      className="post-author-avatar" 
                    />
                    <div className="post-author-meta">
                      <div className="author-row">
                        <span className="author-name-bold">{item.user_name}</span>
                        {item.action && <span className="action-tag-text">{item.action}</span>}
                      </div>
                      <span className="post-time">{item.date}</span>
                    </div>
                  </div>

                  <div className="post-card-body">
                    <p className="post-text-content">{item.content}</p>
                    {item.link && (
                      <a href={item.link} target="_blank" rel="noopener noreferrer" className="post-link-tag">
                        <Tag size={12} style={{ marginRight: 4 }} /> #certificatedistribution
                      </a>
                    )}
                  </div>

                  <div className="post-card-footer">
                    <button className="post-action-btn">
                      <Heart size={16} />
                      <span>{item.likes_count || 0}</span>
                    </button>
                    <button className="post-action-btn">
                      <MessageCircle size={16} />
                      <span>{item.comments_count || 0}</span>
                    </button>
                    <button className="post-action-btn">
                      <Share2 size={16} />
                    </button>
                  </div>
                </article>
              ))}
            </div>
          )}
        </div>

        {/* 6. Sidebar Kanan (Trending Posts & Recent Activities) */}
        <RecentActivitiesSidebar />
      </div>
    </div>
  );
}
