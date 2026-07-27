/**
 * API Configuration for TITC Mobile
 * Handles WordPress REST API and BuddyBoss REST API endpoints.
 */

const BASE_URL = 'https://titc.or.id/portal/wp-json';

export const API_ENDPOINTS = {
  WP_V2: `${BASE_URL}/wp/v2`,
  BUDDYBOSS_V1: `${BASE_URL}/buddyboss/v1`,
  JWT_AUTH: `${BASE_URL}/jwt-auth/v1`
};

/**
 * Helper fetch wrapper with JWT Authorization header support
 */
export async function apiRequest(endpoint, options = {}) {
  const token = localStorage.getItem('titc_jwt_token');

  const headers = {
    'Content-Type': 'application/json',
    ...options.headers
  };

  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  try {
    const response = await fetch(endpoint, {
      ...options,
      headers
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.message || `HTTP error ${response.status}`);
    }

    return await response.json();
  } catch (error) {
    console.error('API Request error:', error);
    throw error;
  }
}
