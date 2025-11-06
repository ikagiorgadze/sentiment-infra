-- Backfill multi-chat support: projects, chat sessions, and per-session history

-- Ensure chat_projects table exists with latest schema
CREATE TABLE IF NOT EXISTS chat_projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth_users(id) ON DELETE CASCADE,
    name VARCHAR(120) NOT NULL,
    description TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, name)
);

CREATE INDEX IF NOT EXISTS idx_chat_projects_user_id ON chat_projects(user_id);

-- Ensure chat_sessions table exists with latest schema
CREATE TABLE IF NOT EXISTS chat_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth_users(id) ON DELETE CASCADE,
    project_id UUID REFERENCES chat_projects(id) ON DELETE SET NULL,
    title VARCHAR(160),
    system_prompt TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    archived_at TIMESTAMPTZ,
    last_message_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_chat_sessions_user_id ON chat_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_sessions_project_id ON chat_sessions(project_id);
CREATE INDEX IF NOT EXISTS idx_chat_sessions_last_message ON chat_sessions(user_id, COALESCE(last_message_at, created_at) DESC);

ALTER TABLE chat_sessions
    ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS last_message_at TIMESTAMPTZ;

-- Add chat_id column for existing chat_messages rows
ALTER TABLE chat_messages
    ADD COLUMN IF NOT EXISTS chat_id UUID;

-- Backfill chat sessions for historical messages lacking chat_id
DO $$
DECLARE
    message_group RECORD;
    created_session_id UUID;
BEGIN
    FOR message_group IN
        SELECT
            user_id,
            MIN(created_at) AS first_message_at,
            MAX(created_at) AS last_message_at,
            COUNT(*) AS total_messages
        FROM chat_messages
        WHERE chat_id IS NULL
        GROUP BY user_id
    LOOP
        INSERT INTO chat_sessions (user_id, title, created_at, updated_at, last_message_at)
        VALUES (
            message_group.user_id,
            CONCAT('Conversation ', TO_CHAR(COALESCE(message_group.first_message_at, NOW()), 'YYYY-MM-DD')),
            COALESCE(message_group.first_message_at, NOW()),
            NOW(),
            message_group.last_message_at
        )
        RETURNING id INTO created_session_id;

        UPDATE chat_messages
        SET chat_id = created_session_id
        WHERE user_id = message_group.user_id
          AND chat_id IS NULL;
    END LOOP;
END $$;

-- After backfill, enforce NOT NULL on chat_id
ALTER TABLE chat_messages
    ALTER COLUMN chat_id SET NOT NULL;

-- Ensure metadata has jsonb default for legacy installations
ALTER TABLE chat_messages
    ALTER COLUMN metadata SET DEFAULT '{}'::jsonb;

-- Attach FK constraint if missing
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'chat_messages'
          AND constraint_name = 'chat_messages_chat_id_fkey'
    ) THEN
        ALTER TABLE chat_messages
            ADD CONSTRAINT chat_messages_chat_id_fkey
            FOREIGN KEY (chat_id)
            REFERENCES chat_sessions(id)
            ON DELETE CASCADE;
    END IF;
END $$;

-- Replace legacy trigger/function with shared updated_at helper
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'trigger_update_chat_messages_timestamp'
    ) THEN
        EXECUTE 'DROP TRIGGER trigger_update_chat_messages_timestamp ON chat_messages';
    END IF;
END $$;

DROP FUNCTION IF EXISTS update_chat_messages_updated_at();

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'trg_chat_projects_updated_at'
    ) THEN
        EXECUTE 'CREATE TRIGGER trg_chat_projects_updated_at BEFORE UPDATE ON chat_projects FOR EACH ROW EXECUTE FUNCTION update_updated_at_column()';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'trg_chat_sessions_updated_at'
    ) THEN
        EXECUTE 'CREATE TRIGGER trg_chat_sessions_updated_at BEFORE UPDATE ON chat_sessions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column()';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'trg_chat_messages_updated_at'
    ) THEN
        EXECUTE 'CREATE TRIGGER trg_chat_messages_updated_at BEFORE UPDATE ON chat_messages FOR EACH ROW EXECUTE FUNCTION update_updated_at_column()';
    END IF;
END $$;

-- Indexes to support per-chat access patterns
CREATE INDEX IF NOT EXISTS idx_chat_messages_chat_id ON chat_messages(chat_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_user_id ON chat_messages(user_id);
