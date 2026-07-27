import { API_ENDPOINTS, apiRequest } from './api';

export const activityService = {
  /**
   * Fetch BuddyBoss Activity Feed
   */
  async getActivities(page = 1, perPage = 10) {
    try {
      const data = await apiRequest(
        `${API_ENDPOINTS.BUDDYBOSS_V1}/activity?page=${page}&per_page=${perPage}`
      );
      return data;
    } catch (error) {
      console.warn('BuddyBoss activity API unavailable, attempting public WP Posts API fallback...');
      try {
        const wpPosts = await apiRequest(
          `${API_ENDPOINTS.WP_V2}/posts?page=${page}&per_page=${perPage}`
        );
        if (Array.isArray(wpPosts) && wpPosts.length > 0) {
          return wpPosts.map((post) => ({
            id: post.id,
            user_name: 'Admin TITC Portal',
            user_avatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=120&q=80',
            action: 'Postingan Berita Resmi TITC',
            content: post.title?.rendered || post.excerpt?.rendered?.replace(/<[^>]+>/g, '') || 'Berita TITC Portal',
            date: new Date(post.date).toLocaleDateString('id-ID'),
            likes_count: 5,
            comments_count: 2
          }));
        }
      } catch (wpErr) {
        console.warn('WP Posts API also unavailable, using local mock data');
      }

      return [
        {
          id: 1,
          user_name: 'Ahmad Ridwan',
          user_avatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=120&q=80',
          action: 'Ahmad Ridwan posting di forum **TITC Komunitas**',
          content: 'Selamat datang di portal mobile TITC Indonesia! Silakan jelajahi menu shortcut dan fitur komunitas.',
          date: '2 jam yang lalu',
          likes_count: 12,
          comments_count: 4
        },
        {
          id: 2,
          user_name: 'Budi Santoso',
          user_avatar: 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?auto=format&fit=crop&w=120&q=80',
          action: 'Budi Santoso memperbarui foto profilnya',
          content: 'Siap untuk kegiatan dan agenda terbaru TITC 2026! 🚀',
          date: '5 jam yang lalu',
          likes_count: 24,
          comments_count: 7
        }
      ];
    }
  }
};
