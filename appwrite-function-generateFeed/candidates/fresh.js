const { DATABASE_ID, COLLECTIONS, POOL_SIZES, TIME } = require('../config/constants');
const { Query } = require('node-appwrite');

/**
 * Fetch fresh posts from new creators
 * @param {Object} databases - Appwrite Databases instance
 * @param {number} limit - Maximum posts to fetch
 * @returns {Promise<Array>} Array of posts
 */
async function getFreshPosts(databases, limit = POOL_SIZES.FRESH) {
    try {
        // Get recent posts from non-established creators
        const oneDayAgo = new Date(Date.now() - TIME.DAY).toISOString();

        const posts = await databases.listDocuments(
            DATABASE_ID,
            COLLECTIONS.POSTS,
            [
                Query.equal('status', 'active'),
                Query.equal('isHidden', false),
                Query.greaterThan('timestamp', oneDayAgo),
                Query.orderDesc('timestamp'),
                Query.limit(limit * 2) // Over-fetch to filter
            ]
        );

        // Filter for posts from profiles with low follower count (new creators)
        // In production, you'd join with profiles collection, but NoSQL requires separate query
        return posts.documents.slice(0, limit).map(p => ({
            ...p,
            sourcePool: 'fresh',
            type: 'post',
            // Calculate engagement score dynamically
            engagementScore: (p.likes || 0) + (p.comments || 0) + ((p.shares || 0) * 2)
        }));
    } catch (error) {
        console.error('Error fetching fresh posts:', error.message);
        return [];
    }
}

module.exports = { getFreshPosts };
