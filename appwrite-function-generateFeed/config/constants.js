// Configuration constants for the feed generation system

module.exports = {
    // Database configuration
    DATABASE_ID: 'main',

    // Collection names
    COLLECTIONS: {
        POSTS: 'posts',
        PROFILES: 'profiles',          // Changed: profiles not users (multi-profile system)
        FOLLOWS: 'follows',
        LIKES: 'likes',                // Added: separate likes collection
        COMMENTS: 'comments',          // Added: separate comments collection  
        ADS: 'ads',
        OWNER_SIGNALS: 'owner_signals', // Changed: owner_signals not user_signals
        CAROUSEL_MEMORY: 'carousel_memory',
        SEEN_POSTS: 'seen_posts',
    },

    // Candidate pool sizes
    POOL_SIZES: {
        FOLLOWED: 30,
        INTEREST: 20,
        TRENDING: 15,
        FRESH: 10,
        VIRAL: 10,
        EXPLORATION: 5,
    },

    // Cold-start pool sizes (for new users)
    COLD_START_POOL_SIZES: {
        INTEREST: 40,
        TRENDING: 30,
        EXPLORATION: 10,
    },

    // Ranking weights (default)
    RANKING_WEIGHTS: {
        RECENCY: 0.25,
        ENGAGEMENT: 0.30,
        DIVERSITY: 0.15,
        AFFINITY: 0.20,
        SESSION: 0.10,
    },

    // Ad injection rules
    AD_RULES: {
        FREQUENCY_CAP: 5,        // Min posts between ads
        COOLDOWN: 4,             // Min posts after ad
        SESSION_CAP: 3,          // Max ads in first 20 posts
        FATIGUE_THRESHOLD: 2,    // Skip count to trigger fatigue
        FATIGUE_PAUSE: 10,       // Posts to skip when fatigued
    },

    // Carousel rules
    CAROUSEL_RULES: {
        INJECTION_INDEX: 5,      // Show at 5th position
        COOLDOWN_HOURS: 24,      // Don't repeat for 24 hours
    },

    // Time constants (in milliseconds)
    TIME: {
        HOUR: 3600000,
        DAY: 86400000,
        WEEK: 604800000,
    },

    // Engagement thresholds
    ENGAGEMENT: {
        VIRAL_THRESHOLD: 500,    // Engagement score to mark as viral
        HIGH_ENGAGEMENT: 100,    // Threshold for trending
        DWELL_ENGAGED: 3000,     // ms to consider engaged
        DWELL_SKIP: 1000,        // ms to consider skipped
        RAPID_SCROLL_RATE: 2,    // posts/second
    },

    // Feed parameters
    FEED: {
        DEFAULT_LIMIT: 20,       // Posts per page
        MAX_LIMIT: 50,          // Maximum posts per request
        MAX_CREATOR_REPEAT: 3,  // Max posts from same creator
    },
};
