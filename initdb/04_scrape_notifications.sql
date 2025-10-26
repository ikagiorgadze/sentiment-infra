-- Create scrape_notifications table for tracking scrape progress
CREATE TABLE IF NOT EXISTS scrape_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id VARCHAR(255) NOT NULL,
  auth_user_id UUID NOT NULL REFERENCES auth_users(id) ON DELETE CASCADE,
  stage VARCHAR(50) NOT NULL CHECK (stage IN ('posts_inserted', 'sentiment_complete')),
  post_count INTEGER,
  comment_count INTEGER,
  metadata JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_scrape_notifications_request_id ON scrape_notifications(request_id);
CREATE INDEX IF NOT EXISTS idx_scrape_notifications_auth_user_id ON scrape_notifications(auth_user_id);
CREATE INDEX IF NOT EXISTS idx_scrape_notifications_created_at ON scrape_notifications(created_at DESC);

-- Comment
COMMENT ON TABLE scrape_notifications IS 'Tracks the progress of scraping operations with webhook notifications from n8n';
COMMENT ON COLUMN scrape_notifications.stage IS 'Progress stage: posts_inserted (data scraped) or sentiment_complete (analysis done)';

