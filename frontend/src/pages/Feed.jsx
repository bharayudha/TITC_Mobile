import React, { useEffect, useState } from 'react';
import { activityService } from '../services/activityService';
import LoadingSpinner from '../components/LoadingSpinner';
import { Heart, MessageCircle, Share2, Send } from 'lucide-react';

export default function Feed() {
  const [activities, setActivities] = useState([]);
  const [loading, setLoading] = useState(true);
  const [newPost, setNewPost] = useState('');

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

  const handlePostSubmit = (e) => {
    e.preventDefault();
    if (!newPost.trim()) return;

    const postItem = {
      id: Date.now(),
      user_name: 'Anda (Anggota TITC)',
      user_avatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=120&q=80',
      action: 'Anda membuat postingan baru',
      content: newPost,
      date: 'Baru saja',
      likes_count: 0,
      comments_count: 0
    };

    setActivities([postItem, ...activities]);
    setNewPost('');
  };

  return (
    <div className="page-container feed-page">
      <header className="page-header">
        <h1>Activity Feed</h1>
        <p className="page-subtitle">Aktivitas & Komunitas BuddyBoss TITC</p>
      </header>

      {/* New Post Input Box */}
      <form onSubmit={handlePostSubmit} className="post-create-card">
        <textarea
          value={newPost}
          onChange={(e) => setNewPost(e.target.value)}
          placeholder="Bagikan sesuatu dengan anggota komunitas..."
          rows={3}
          className="post-textarea"
        />
        <div className="post-create-footer">
          <button type="submit" className="btn-primary btn-sm">
            <Send size={16} style={{ marginRight: 6 }} /> Kirim Postingan
          </button>
        </div>
      </form>

      {loading ? (
        <LoadingSpinner message="Memuat Feed Komunitas..." />
      ) : (
        <div className="activity-list">
          {activities.map((item) => (
            <article key={item.id} className="activity-card">
              <div className="activity-header">
                <img
                  src={item.user_avatar}
                  alt={item.user_name}
                  className="avatar-img"
                />
                <div className="activity-meta">
                  <span className="author-name">{item.user_name}</span>
                  <span className="activity-date">{item.date}</span>
                </div>
              </div>

              <div className="activity-content">
                <p>{item.content}</p>
              </div>

              <div className="activity-actions">
                <button className="action-btn">
                  <Heart size={18} />
                  <span>{item.likes_count || 0} Suka</span>
                </button>
                <button className="action-btn">
                  <MessageCircle size={18} />
                  <span>{item.comments_count || 0} Komentar</span>
                </button>
                <button className="action-btn">
                  <Share2 size={18} />
                  <span>Bagikan</span>
                </button>
              </div>
            </article>
          ))}
        </div>
      )}
    </div>
  );
}
