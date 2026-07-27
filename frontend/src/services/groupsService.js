import { API_ENDPOINTS, apiRequest } from './api';

export const groupsService = {
  /**
   * Fetch BuddyBoss Groups
   */
  async getGroups(page = 1, perPage = 10) {
    try {
      const data = await apiRequest(
        `${API_ENDPOINTS.BUDDYBOSS_V1}/groups?page=${page}&per_page=${perPage}`
      );
      return data;
    } catch (error) {
      console.warn('BuddyBoss groups API unavailable, returning mock groups data');
      return [
        {
          id: 101,
          name: 'Grup Restorasi & Komponen FJ40',
          description: 'Diskusi teknis perbaikan, pencarian sparepart original, dan modifikasi mesin FJ40/FJ45.',
          members_count: 342,
          privacy: 'Public Group',
          avatar: 'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?auto=format&fit=crop&w=200&q=80'
        },
        {
          id: 102,
          name: 'TITC Chapter Jawa Barat',
          description: 'Wadah koordinasi kegiatan offroad, kopdar, dan bakti sosial anggota wilayah Jawa Barat.',
          members_count: 189,
          privacy: 'Public Group',
          avatar: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?auto=format&fit=crop&w=200&q=80'
        },
        {
          id: 103,
          name: 'TOEFL & Academic Club TITC',
          description: 'Grup khusus persiapan tes TOEFL ITP, sharing materi, dan konsultasi pendaftaran.',
          members_count: 95,
          privacy: 'Private Group',
          avatar: 'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?auto=format&fit=crop&w=200&q=80'
        }
      ];
    }
  }
};
