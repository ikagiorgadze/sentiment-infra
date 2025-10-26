-- enable uuid generation
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- users
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fb_profile_id TEXT UNIQUE,
  full_name VARCHAR,
  inserted_at TIMESTAMP DEFAULT now()
);

-- pages
CREATE TABLE IF NOT EXISTS pages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  page_url TEXT UNIQUE,
  page_name TEXT UNIQUE,
  inserted_at TIMESTAMP DEFAULT now()
);

-- posts
CREATE TABLE IF NOT EXISTS posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  page_id UUID REFERENCES pages(id),
  full_url TEXT UNIQUE,
  content TEXT,
  posted_at TIMESTAMP,
  inserted_at TIMESTAMP DEFAULT now()
);

-- comments
CREATE TABLE IF NOT EXISTS comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_url TEXT UNIQUE,
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  content TEXT,
  -- parent_comment_id UUID REFERENCES comments(id) ON DELETE CASCADE,
  posted_at TIMESTAMP,
  inserted_at TIMESTAMP DEFAULT now()
);

-- sentiments for posts or comments
CREATE TABLE IF NOT EXISTS sentiments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  comment_id UUID REFERENCES comments(id) ON DELETE CASCADE,
  sentiment TEXT,
  sentiment_category TEXT,
  confidence NUMERIC(5,2),
  probabilities JSONB,
  polarity DOUBLE PRECISION,
  CHECK (post_id IS NOT NULL OR comment_id IS NOT NULL),
  inserted_at TIMESTAMP DEFAULT now()
);

-- reactions enum and table
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'reaction_type') THEN
    CREATE TYPE reaction_type AS ENUM ('like','love','sad','angry','haha','wow');
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS reactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  comment_id UUID REFERENCES comments(id) ON DELETE CASCADE,
  reaction_type reaction_type,
  inserted_at TIMESTAMP DEFAULT NOW(),
  CHECK (
    (post_id IS NOT NULL AND comment_id IS NULL) OR
    (post_id IS NULL AND comment_id IS NOT NULL)
  )
);

CREATE TABLE IF NOT EXISTS jobs (
  job_id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),  -- or uuid_generate_v4()
  idempotency_key  text UNIQUE NOT NULL,                        -- dedupe key (request_id or derived)
  resource_key     text NOT NULL,                               -- deterministic key (e.g., hash of post_url)
  job_type         text NOT NULL,                               -- e.g., 'scrape_comments'
  payload_json     jsonb NOT NULL,                              -- original normalized request body
  status           text NOT NULL CHECK (status IN ('QUEUED','RUNNING','DONE','FAILED')),
  created_at       timestamptz NOT NULL DEFAULT now(),
  started_at       timestamptz,
  finished_at      timestamptz,
  error            text
);

-- Helpful indexes / idempotency
CREATE INDEX IF NOT EXISTS idx_pages_page_url ON pages(page_url);
CREATE INDEX IF NOT EXISTS idx_pages_page_name ON pages(page_name);
CREATE INDEX IF NOT EXISTS idx_posts_page_id ON posts(page_id);
CREATE INDEX IF NOT EXISTS idx_posts_full_url ON posts(full_url);
CREATE INDEX IF NOT EXISTS idx_comments_full_url ON comments(full_url);
CREATE INDEX IF NOT EXISTS idx_users_fb_id ON users(fb_profile_id);
CREATE INDEX IF NOT EXISTS idx_comments_post_id ON comments(post_id);
CREATE INDEX IF NOT EXISTS idx_reactions_post_id ON reactions(post_id);
CREATE INDEX IF NOT EXISTS idx_reactions_comment_id ON reactions(comment_id);
CREATE INDEX IF NOT EXISTS idx_sentiments_post_id ON sentiments(post_id);
CREATE INDEX IF NOT EXISTS idx_sentiments_comment_id ON sentiments(comment_id);
-- ensure at most one sentiment row per comment
CREATE UNIQUE INDEX IF NOT EXISTS uniq_sentiment_comment
  ON sentiments(comment_id) WHERE comment_id IS NOT NULL;
-- avoid duplicate reactions from same user on same target
CREATE UNIQUE INDEX IF NOT EXISTS uniq_reaction_post
  ON reactions(user_id, post_id) WHERE comment_id IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uniq_reaction_comment
  ON reactions(user_id, comment_id) WHERE comment_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_jobs_resource_key ON jobs (resource_key);
CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs (status);

CREATE UNIQUE INDEX IF NOT EXISTS uniq_sentiment_post
  ON sentiments(post_id)
  WHERE comment_id IS NULL;

