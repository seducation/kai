const { DATABASE_ID, COLLECTIONS, POOL_SIZES, TIME } = require('../config/constants');
const { Query } = require('node-appwrite');

/**
 * Fetch posts from profiles that the current owner follows
 * @param {Object} databases - Appwrite Databases instance
 * @param {string} ownerId - Current owner ID (Appwrite Auth user)
 * @param {number} limit - Maximum posts to fetch
 * @returns {Promise<Array>} Array of posts
 */
async function getFollowedPosts(databases, ownerId, limit = POOL_SIZES.FOLLOWED) {
    try {
        // Step 1: Get all profiles owned by this user
        const userProfiles = await databases.listDocuments(
            DATABASE_ID,
            COLLECTIONS.PROFILES,
            [Query.equal('ownerId', ownerId), Query.limit(100)]
        );

        const profileIds = userProfiles.documents.map(p => p.$id);

        // Step 2: Get profiles that ANY of user's profiles follow
        const follows = await databases.listDocuments(
            DATABASE_ID,
            COLLECTIONS.FOLLOWS,
            [
                Query.equal('follower_id', profileIds),
                Query.equal('target_type', 'profile'),
                Query.limit(1000)
            ]
        );

        const followedProfileIds = follows.documents.map(f => f.target_id);

        if (followedProfileIds.length === 0) {
            return [];
        }

        // Step 3: Get recent posts from followed profiles
        const posts = await databases.listDocuments(
            DATABASE_ID,
            COLLECTIONS.POSTS,
            [
                Query.equal('profile_id', followedProfileIds),
                Query.equal('status', 'active'),
                Query.equal('isHidden', false),
                Query.orderDesc('timestamp'),
                Query.limit(limit)
            ]
        );

        return posts.documents.map(p => ({
            ...p,
            sourcePool: 'followed',
            type: 'post',
            // Calculate engagement score dynamically
            engagementScore: (p.likes || 0) + (p.comments || 0) + ((p.shares || 0) * 2)
        }));
    } catch (error) {
        console.error('Error fetching followed posts:', error.message);
        return [];
    }
}

module.exports = { getFollowedPosts };
