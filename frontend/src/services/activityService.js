import { API_ENDPOINTS, apiRequest } from './api';

export const activityService = {
  /**
   * Fetch BuddyBoss Activity Feed
   */
  async getActivities(page = 1, perPage = 10) {
    // 1. Try public WordPress REST API for live posts
    try {
      const wpPosts = await apiRequest(
        `${API_ENDPOINTS.WP_V2}/posts?page=${page}&per_page=${perPage}`
      );
      if (Array.isArray(wpPosts) && wpPosts.length > 0) {
        return wpPosts.map((post) => {
          const rawExcerpt = post.excerpt?.rendered || post.title?.rendered || '';
          const cleanText = rawExcerpt.replace(/<[^>]+>/g, '').trim();
          return {
            id: post.id,
            user_name: 'TITC Indonesia Official',
            user_avatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=120&q=80',
            action: `Publikasi Berita: ${post.title?.rendered || ''}`,
            content: cleanText,
            date: new Date(post.date).toLocaleDateString('id-ID', {
              day: 'numeric',
              month: 'long',
              year: 'numeric'
            }),
            likes_count: 18,
            comments_count: 5,
            link: post.link
          };
        });
      }
    } catch (wpErr) {
      console.warn('WP Posts API error, attempting BuddyBoss fallback:', wpErr);
    }

    // 2. Try BuddyBoss REST API
    try {
      const data = await apiRequest(
        `${API_ENDPOINTS.BUDDYBOSS_V1}/activity?page=${page}&per_page=${perPage}`
      );
      return data;
    } catch (error) {
      console.warn('BuddyBoss activity API unavailable, using local mock data');
    }

    // 3. Fallback mock data if server is offline
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
      }
    ];
  }
};
