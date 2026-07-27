import { API_ENDPOINTS, apiRequest } from './api';

export const messagesService = {
  /**
   * Fetch BuddyBoss Messages Threads
   */
  async getMessages(page = 1, perPage = 10) {
    try {
      const data = await apiRequest(
        `${API_ENDPOINTS.BUDDYBOSS_V1}/messages?page=${page}&per_page=${perPage}`
      );
      return data;
    } catch (error) {
      console.warn('BuddyBoss messages API unavailable, returning mock messages data');
      return [
        {
          id: 501,
          sender_name: 'Siti Rahmawati',
          sender_avatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=120&q=80',
          subject: 'Konfirmasi Pendaftaran TOEFL ITP',
          last_message: 'Halo, berkas sertifikasi Anda telah kami verifikasi.',
          date: '10:45 AM',
          unread: true
        },
        {
          id: 502,
          sender_name: 'Ahmad Ridwan',
          sender_avatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=120&q=80',
          subject: 'Kopdar TITC Minggu Ini',
          last_message: 'Titik kumpul di Rest Area KM 57 jam 07.00 WIB ya bro.',
          date: 'Kemarin',
          unread: false
        }
      ];
    }
  }
};
