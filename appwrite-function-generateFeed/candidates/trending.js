const { DATABASE_ID, COLLECTIONS, POOL_SIZES, ENGAGEMENT } = require('../config/constants');
const { Query } = require('node-appwrite');

/**
 * Fetch trending posts with high engagement
 * @param {Object} databases - Appwrite Databases instance
 * @param {number} limit - Maximum posts to fetch
 * @returns {Promise<Array>} Array of posts
 */
async function getTrendingPosts(databases, limit = POOL_SIZES.TRENDING) {
    try {
        // Get posts with high engagement (using likes as proxy)
        const posts = await databases.listDocuments(
            DATABASE_ID,
            COLLECTIONS.POSTS,
            [
                Query.equal('status', 'active'),
                Query.equal('isHidden', false),
                Query.greaterThan('likes', ENGAGEMENT.HIGH_ENGAGEMENT),
                Query.orderDesc('likes'),
                Query.orderDesc('timestamp'),
                Query.limit(limit)
            ]
        );

        return posts.documents.map(p => ({
            ...p,
            sourcePool: 'trending',
            type: 'post',
            // Calculate engagement score dynamically
            engagementScore: (p.likes || 0) + (p.comments || 0) + ((p.shares || 0) * 2)
        }));
    } catch (error) {
        console.error('Error fetching trending posts:', error.message);
        return [];
    }
}

module.exports = { getTrendingPosts };
