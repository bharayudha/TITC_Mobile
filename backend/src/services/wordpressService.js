import dotenv from 'dotenv';

dotenv.config();

const WP_API_URL = process.env.WORDPRESS_API_URL || 'https://titc.or.id/wp-json';

export const wordpressService = {
  /**
   * Fetch WordPress post details by ID
   */
  async getPostById(postId) {
    try {
      const response = await fetch(`${WP_API_URL}/wp/v2/posts/${postId}`);
      if (!response.ok) throw new Error(`Failed to fetch post #${postId}`);
      return await response.json();
    } catch (error) {
      console.error('[WP Service Error]', error);
      throw error;
    }
  },

  /**
   * Fetch WordPress user details by ID
   */
  async getUserById(userId) {
    try {
      const response = await fetch(`${WP_API_URL}/wp/v2/users/${userId}`);
      if (!response.ok) throw new Error(`Failed to fetch user #${userId}`);
      return await response.json();
    } catch (error) {
      console.error('[WP Service Error]', error);
      throw error;
    }
  }
};
