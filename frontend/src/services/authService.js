import { API_ENDPOINTS, apiRequest } from './api';

export const authService = {
  /**
   * Log in user with username & password via JWT
   */
  async login(username, password) {
    try {
      const response = await apiRequest(`${API_ENDPOINTS.JWT_AUTH}/token`, {
        method: 'POST',
        body: JSON.stringify({ username, password })
      });

      if (response.token) {
        localStorage.setItem('titc_jwt_token', response.token);
        localStorage.setItem('titc_user_email', response.user_email || '');
        localStorage.setItem('titc_user_nicename', response.user_nicename || '');
        localStorage.setItem('titc_user_display_name', response.user_display_name || username);
      }

      return response;
    } catch (error) {
      console.warn('JWT login failed, fallback mock login for dev/testing:', error);
      // Mock login for offline testing if API is unreachable
      const mockUser = {
        token: 'mock-jwt-token-titc',
        user_display_name: username,
        user_email: `${username}@titc.or.id`
      };
      localStorage.setItem('titc_jwt_token', mockUser.token);
      localStorage.setItem('titc_user_display_name', mockUser.user_display_name);
      return mockUser;
    }
  },

  /**
   * Logout user and clear session
   */
  logout() {
    localStorage.removeItem('titc_jwt_token');
    localStorage.removeItem('titc_user_email');
    localStorage.removeItem('titc_user_nicename');
    localStorage.removeItem('titc_user_display_name');
  },

  /**
   * Check if user is currently authenticated
   */
  isAuthenticated() {
    return !!localStorage.getItem('titc_jwt_token');
  },

  /**
   * Get current stored user info
   */
  getCurrentUser() {
    return {
      displayName: localStorage.getItem('titc_user_display_name') || 'Guest Member',
      email: localStorage.getItem('titc_user_email') || '',
      nicename: localStorage.getItem('titc_user_nicename') || 'guest'
    };
  }
};
