-- Performance optimization: Add missing indexes for user queries
-- This fixes the timeout issue on the Users page

-- Index for comments.user_id (critical for user stats queries)
CREATE INDEX IF NOT EXISTS idx_comments_user_id ON comments(user_id);

-- Index for reactions.user_id (critical for user stats queries)
CREATE INDEX IF NOT EXISTS idx_reactions_user_id ON reactions(user_id);

-- Composite index for sentiment lookups in user stats
CREATE INDEX IF NOT EXISTS idx_sentiments_comment_user ON sentiments(comment_id) 
  INCLUDE (sentiment_category, polarity);

-- Index for posts.page_id with sentiment category (for top pages query)
CREATE INDEX IF NOT EXISTS idx_comments_user_post ON comments(user_id, post_id);

-- Analyze tables after adding indexes
ANALYZE users;
ANALYZE comments;
ANALYZE reactions;
ANALYZE sentiments;
