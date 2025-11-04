-- Create chat_messages table for storing user chat history
CREATE TABLE IF NOT EXISTS chat_messages (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth_users(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL CHECK (role IN ('user', 'assistant')),
    content TEXT NOT NULL,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for efficient querying
CREATE INDEX idx_chat_messages_user_id ON chat_messages(user_id);
CREATE INDEX idx_chat_messages_created_at ON chat_messages(created_at DESC);
CREATE INDEX idx_chat_messages_user_created ON chat_messages(user_id, created_at DESC);

-- Add updated_at trigger
CREATE OR REPLACE FUNCTION update_chat_messages_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_chat_messages_timestamp
    BEFORE UPDATE ON chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION update_chat_messages_updated_at();

-- Add comment
COMMENT ON TABLE chat_messages IS 'Stores chat history for authenticated users';
COMMENT ON COLUMN chat_messages.role IS 'Message role: user or assistant';
COMMENT ON COLUMN chat_messages.content IS 'The actual message content';
COMMENT ON COLUMN chat_messages.metadata IS 'Additional metadata like tokens, sources, model info';
