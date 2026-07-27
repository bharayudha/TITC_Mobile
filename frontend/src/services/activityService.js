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
      console.warn('BuddyBoss activity API unavailable, returning mock feed data');
      return [
        {
          id: 1,
          user_name: 'Ahmad Ridwan',
          user_avatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=120&q=80',
          action: 'Ahmad Ridwan posting di forum **Toyota FJ40 Restorasi**',
          content: 'Halo teman-teman komunitas TITC, ada rekomendasi tempat restorasi karburator FJ40 yang trusted di area Jabodetabek?',
          date: '2 jam yang lalu',
          likes_count: 12,
          comments_count: 4
        },
        {
          id: 2,
          user_name: 'Budi Santoso',
          user_avatar: 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?auto=format&fit=crop&w=120&q=80',
          action: 'Budi Santoso memperbarui foto profilnya',
          content: 'Siap untuk Touring Nasional TITC 2026! 🚜💨',
          date: '5 jam yang lalu',
          likes_count: 24,
          comments_count: 7
        },
        {
          id: 3,
          user_name: 'Deni Kurniawan',
          user_avatar: 'https://images.unsplash.com/photo-1527980965255-d3b416303d12?auto=format&fit=crop&w=120&q=80',
          action: 'Deni Kurniawan menambahkan berita baru',
          content: 'Jadwal sertifikasi dan jadwal kelas TOEFL ITP untuk anggota bulan depan telah diperbarui.',
          date: '1 hari yang lalu',
          likes_count: 8,
          comments_count: 1
        }
      ];
    }
  }
};
