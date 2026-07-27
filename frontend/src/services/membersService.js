import { API_ENDPOINTS, apiRequest } from './api';

export const membersService = {
  /**
   * Fetch BuddyBoss Members
   */
  async getMembers(page = 1, perPage = 10, search = '') {
    try {
      const query = `page=${page}&per_page=${perPage}${search ? `&search=${search}` : ''}`;
      const data = await apiRequest(`${API_ENDPOINTS.BUDDYBOSS_V1}/members?${query}`);
      return data;
    } catch (error) {
      console.warn('BuddyBoss members API unavailable, returning mock members data');
      return [
        {
          id: 1,
          name: 'Ahmad Ridwan',
          mention_name: '@ahmad_ridwan',
          avatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&q=80',
          role: 'Pengurus Chapter Jakarta',
          status: 'Online'
        },
        {
          id: 2,
          name: 'Budi Santoso',
          mention_name: '@budi_s',
          avatar: 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?auto=format&fit=crop&w=150&q=80',
          role: 'Anggota Resmi TITC',
          status: 'Aktif 1 jam lalu'
        },
        {
          id: 3,
          name: 'Siti Rahmawati',
          mention_name: '@siti_r',
          avatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=150&q=80',
          role: 'Koordinator TOEFL ITP',
          status: 'Online'
        },
        {
          id: 4,
          name: 'Deni Kurniawan',
          mention_name: '@deni_k',
          avatar: 'https://images.unsplash.com/photo-1527980965255-d3b416303d12?auto=format&fit=crop&w=150&q=80',
          role: 'Anggota Senior TITC',
          status: 'Aktif kemarin'
        }
      ];
    }
  }
};
