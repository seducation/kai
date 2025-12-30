const { DATABASE_ID, COLLECTIONS, POOL_SIZES } = require('../config/constants');
const { Query } = require('node-appwrite');

/**
 * Fetch posts based on user's interest tags
 * @param {Object} databases - Appwrite Databases instance
 * @param {Array} userInterests - User's interest tags
 * @param {number} limit - Maximum posts to fetch
 * @returns {Promise<Array>} Array of posts
 */
async function getInterestBasedPosts(databases, userInterests, limit = POOL_SIZES.INTEREST) {
    try {
        if (!userInterests || userInterests.length === 0) {
            return [];
        }

        // Get posts matching user interests
        const posts = await databases.listDocuments(
            DATABASE_ID,
            COLLECTIONS.POSTS,
            [
                Query.equal('tags', userInterests),
                Query.equal('status', 'active'),
                Query.equal('isHidden', false),
                Query.orderDesc('timestamp'),
                Query.limit(limit)
            ]
        );

        return posts.documents.map(p => ({
            ...p,
            sourcePool: 'interest',
            type: 'post',
            // Calculate engagement score dynamically
            engagementScore: (p.likes || 0) + (p.comments || 0) + ((p.shares || 0) * 2)
        }));
    } catch (error) {
        console.error('Error fetching interest-based posts:', error.message);
        return [];
    }
}

module.exports = { getInterestBasedPosts };
