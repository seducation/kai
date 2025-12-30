const { Client, Databases, Storage, Query, ID } = require('node-appwrite');
const { DATABASE_ID: DEFAULT_DATABASE_ID, COLLECTIONS, POOL_SIZES, COLD_START_POOL_SIZES, FEED } = require('./config/constants');
const DATABASE_ID = process.env.APPWRITE_DATABASE_ID || DEFAULT_DATABASE_ID;

// Import candidate generators
const { getFollowedPosts } = require('./candidates/followedPosts');
const { getInterestBasedPosts } = require('./candidates/interestBased');
const { getTrendingPosts } = require('./candidates/trending');
const { getFreshPosts } = require('./candidates/fresh');
const { getViralPosts, getExplorationPosts } = require('./candidates/exploration');

// Import algorithm modules
const { rankPosts } = require('./algorithm/ranker');
const { buildCreatorCounts } = require('./algorithm/diversity');

// Import monetization modules
const { runAdAuction } = require('./monetization/adAuction');
const { checkAdFatigue } = require('./monetization/fatigue');

// Import engagement modules
const { buildSessionContext } = require('./engagement/patience');

// Import mixer and utilities
const { mixFeed, paginateFeed } = require('./mixer/feedMixer');
const { getSeenPostIds, recordSeenPosts } = require('./utils/deduplication');

/**
 * Main Cloud Function entry point
 * Generates personalized feed for a user
 */
module.exports = async ({ req, res, log, error }) => {
    try {
        // Parse request data
        const { sessionId, offset = 0, limit = FEED.DEFAULT_LIMIT, postType = 'all' } = JSON.parse(req.body || '{}');

        // Initialize Appwrite client
        const client = new Client();

        // Safe endpoint handling
        const endpoint = process.env.APPWRITE_FUNCTION_ENDPOINT;

        // Check if endpoint is valid and not a placeholder like 'hostname'
        if (endpoint && endpoint !== 'undefined' && !endpoint.includes('hostname')) {
            client.setEndpoint(endpoint);
        } else {
            // Fallback to Frankfurt cloud endpoint if internal one is missing or invalid
            const fallbackEndpoint = 'https://fra.cloud.appwrite.io/v1';
            log(`Warning: APPWRITE_FUNCTION_ENDPOINT is '${endpoint}'. Falling back to specific: ${fallbackEndpoint}`);
            client.setEndpoint(fallbackEndpoint);
        }

        const projectId = process.env.APPWRITE_FUNCTION_PROJECT_ID;
        if (projectId) {
            client.setProject(projectId);
        } else {
            const errorMsg = 'Critical: APPWRITE_FUNCTION_PROJECT_ID is missing';
            error(errorMsg);
            // We can't proceed without project ID
            throw new Error(errorMsg);
        }

        const apiKey = process.env.APPWRITE_API_KEY;
        if (apiKey && apiKey !== 'undefined') {
            client.setKey(apiKey);
        } else {
            const errorMsg = 'Critical: APPWRITE_API_KEY is missing. Please set this in Appwrite Console > Functions > Settings > Variables';
            error(errorMsg);
            // We can't proceed without API key
            throw new Error(errorMsg);
        }

        log(`Client config - Project: ${projectId}`);

        const databases = new Databases(client);

        // Get user ID (ownerId) from authorization header
        const ownerId = req.headers['x-appwrite-user-id'];
        if (!ownerId) {
            return res.json({ error: 'Unauthorized' }, 401);
        }

        log(`Generating feed for owner: ${ownerId}, session: ${sessionId}, postType: ${postType}`);

        // Validate pagination parameters
        const safeOffset = Math.max(0, parseInt(offset) || 0);
        const safeLimit = Math.min(FEED.MAX_LIMIT, Math.max(1, parseInt(limit) || FEED.DEFAULT_LIMIT));

        // Step 1: Get owner's profiles and recent signals
        log('Fetching profiles and signals...');
        let userProfiles, recentSignals;
        try {
            [userProfiles, recentSignals] = await Promise.all([
                databases.listDocuments(DATABASE_ID, COLLECTIONS.PROFILES, [
                    Query.equal('ownerId', ownerId),
                    Query.limit(100)
                ]),
                databases.listDocuments(DATABASE_ID, COLLECTIONS.OWNER_SIGNALS, [
                    Query.equal('ownerId', ownerId),
                    Query.orderDesc('timestamp'),
                    Query.limit(20)
                ])
            ]);
        } catch (dbErr) {
            error(`Database error during candidate fetch: ${dbErr.message}`);
            // Diagnostic log: check if it's really listDocuments
            log(`Available database methods: ${Object.keys(databases).filter(k => k.startsWith('list'))}`);
            throw dbErr;
        }

        // Extract interests from first profile (or aggregate across all profiles)
        const userInterests = userProfiles.documents.length > 0
            ? (userProfiles.documents[0].interests || [])
            : [];

        if (userInterests.length > 0) {
            log(`User interests: ${userInterests.join(', ')}`);
        } else {
            log('User has no interest tags defined');
        }

        // Step 2: Build session context (patience, engagement state)
        let sessionContext = await buildSessionContext(
            databases,
            ownerId,
            recentSignals.documents,
            { interests: userInterests }
        );

        log(`Session state: ${sessionContext.state}, Ad aggression: ${sessionContext.adAggression}`);

        // Step 3: Check ad fatigue
        const adFatigued = await checkAdFatigue(databases, ownerId, sessionId);
        sessionContext.adFatigue = adFatigued;

        // Step 4: Determine if cold start (no follows)
        const profileIds = userProfiles.documents.map(p => p.$id);
        let followsResult = { total: 0 };

        if (profileIds.length > 0) {
            followsResult = await databases.listDocuments(DATABASE_ID, COLLECTIONS.FOLLOWS, [
                Query.equal('follower_id', profileIds),
                Query.limit(1)
            ]);
        }

        const isColdStart = followsResult.total < 5;

        // Create a base query for postType if it's not 'all'
        const postTypeQueries = [];
        if (postType && postType !== 'all') {
            postTypeQueries.push(Query.equal('postType', postType));
        }

        // Step 5: Generate candidates from multiple pools (in parallel)
        log('Fetching candidates from multiple pools...');

        const [
            followedPosts,
            interestPosts,
            trendingPosts,
            freshPosts,
            viralPosts,
            explorationPosts
        ] = await Promise.all([
            isColdStart ? Promise.resolve([]) : getFollowedPosts(databases, ownerId, POOL_SIZES.FOLLOWED, ...postTypeQueries),
            getInterestBasedPosts(
                databases,
                userInterests,
                isColdStart ? COLD_START_POOL_SIZES.INTEREST : POOL_SIZES.INTEREST,
                ...postTypeQueries
            ),
            getTrendingPosts(
                databases,
                isColdStart ? COLD_START_POOL_SIZES.TRENDING : POOL_SIZES.TRENDING,
                ...postTypeQueries
            ),
            getFreshPosts(databases, POOL_SIZES.FRESH, ...postTypeQueries),
            getViralPosts(databases, POOL_SIZES.VIRAL, ...postTypeQueries),
            getExplorationPosts(
                databases,
                isColdStart ? COLD_START_POOL_SIZES.EXPLORATION : POOL_SIZES.EXPLORATION,
                ...postTypeQueries
            )
        ]);

        // Combine all candidates
        const allCandidates = [
            ...followedPosts,
            ...interestPosts,
            ...trendingPosts,
            ...freshPosts,
            ...viralPosts,
            ...explorationPosts
        ];

        log(`Total candidates: ${allCandidates.length}`);

        // Initialize creator counts for diversity scoring
        sessionContext.creatorCounts = buildCreatorCounts(allCandidates);

        // Step 6: Rank posts using multi-signal algorithm
        log('Ranking posts...');
        const rankedPosts = await rankPosts(allCandidates, databases, ownerId, sessionContext);

        // Step 7: Run ad auction
        let ads = [];
        if (!sessionContext.adFatigue && sessionContext.adAggression !== 'none') {
            log('Running ad auction...');
            ads = await runAdAuction(databases, userInterests, 5);
            log(`Selected ${ads.length} ads`);
        }

        // Step 8: Get seen posts for deduplication
        const seenPostIds = await getSeenPostIds(databases, ownerId, sessionId);
        log(`User has seen ${seenPostIds.size} posts recently`);

        // Step 9: Mix feed (organic + ads + carousels)
        log('Mixing final feed...');
        const mixedFeed = await mixFeed(
            rankedPosts,
            ads,
            databases,
            ownerId,
            sessionContext,
            seenPostIds
        );

        // Step 10: Paginate
        const paginatedFeed = paginateFeed(mixedFeed, safeOffset, safeLimit);

        // Step 11: Hydrate items with profile info and media URLs
        const uniqueProfileIds = [...new Set(paginatedFeed.items
            .filter(item => item.type === 'post')
            .map(item => {
                // profile_id comes as an array from Appwrite relationships
                if (Array.isArray(item.profile_id) && item.profile_id.length > 0) {
                    return item.profile_id[0];
                }
                return typeof item.profile_id === 'string' ? item.profile_id : null;
            })
            .filter(id => id))]; // Filter out nulls

        const profilesMap = {};
        if (uniqueProfileIds.length > 0) {
            // Fetch profiles in batches if necessary (Appwrite limit is usually 100)
            const profiles = await databases.listDocuments(
                DATABASE_ID,
                COLLECTIONS.PROFILES,
                [Query.equal('$id', uniqueProfileIds)]
            );
            profiles.documents.forEach(p => {
                profilesMap[p.$id] = p;
            });
        }

        const storage = new Storage(client);

        const hydratedItems = await Promise.all(paginatedFeed.items.map(async (item) => {
            if (item.type !== 'post') return item;

            // Normalize profile_id
            let profileId = null;
            if (Array.isArray(item.profile_id) && item.profile_id.length > 0) {
                profileId = item.profile_id[0];
            } else if (typeof item.profile_id === 'string') {
                profileId = item.profile_id;
            }

            const profile = (profileId && profilesMap[profileId]) ? profilesMap[profileId] : {};
            const bucketId = 'gvone'; // Hardcoded as per environment

            // Detect media type
            let urlSuffix = '&t=.img'; // default
            if (item.file_ids && item.file_ids.length > 0) {
                try {
                    // Fetch metadata of the first file to determine type
                    // We only check the first file for efficiency
                    const file = await storage.getFile(bucketId, item.file_ids[0]);
                    if (file.mimeType && file.mimeType.startsWith('video/')) {
                        urlSuffix = '&t=.mp4';
                    }
                } catch (e) {
                    log(`Warning: Failed to fetch file metadata for ${item.file_ids[0]}: ${e.message}`);
                }
            }

            // Construct media URLs with type hint suffix
            const mediaUrls = (item.file_ids || []).map(fileId =>
                `${client.config.endpoint}/storage/buckets/${bucketId}/files/${fileId}/view?project=${projectId}&mode=admin${urlSuffix}`
            );

            // Construct profile image URL
            let profileImageUrl = null;
            if (profile.profileImageUrl) {
                profileImageUrl = `${client.config.endpoint}/storage/buckets/${bucketId}/files/${profile.profileImageUrl}/view?project=${projectId}&mode=admin`;
            }

            return {
                ...item,
                userId: profileId || '', // Map normalized profile_id to userId for frontend
                username: profile.name || 'Unknown',
                profileImage: profileImageUrl,
                mediaUrls: mediaUrls,
                content: item.caption || '',
                postId: item.$id
            };
        }));


        log(`Feed generated: ${hydratedItems.length} items (${paginatedFeed.hasMore ? 'more available' : 'end reached'})`);

        // Step 12: Record shown posts (using original items for IDs is fine, but hydration doesn't hurt)
        await recordSeenPosts(databases, ownerId, sessionId, paginatedFeed.items);

        // Return feed
        return res.json({
            success: true,
            items: hydratedItems,
            offset: paginatedFeed.offset,
            limit: paginatedFeed.limit,
            total: paginatedFeed.total,
            hasMore: paginatedFeed.hasMore,
            sessionContext: {
                state: sessionContext.state,
                adFatigue: sessionContext.adFatigue
            }
        });

    } catch (err) {
        error('Feed generation error:', err.message, err.stack);
        return res.json({
            success: false,
            error: 'Failed to generate feed',
            message: err.message
        }, 500);
    }
};
