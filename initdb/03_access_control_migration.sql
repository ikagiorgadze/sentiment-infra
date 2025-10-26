-- Migration script to add access control to existing databases
-- Run this script if you already have an existing database

-- Add role column to auth_users table if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name='auth_users' AND column_name='role'
  ) THEN
    ALTER TABLE auth_users ADD COLUMN role VARCHAR(50) DEFAULT 'user' CHECK (role IN ('user', 'admin'));
    CREATE INDEX IF NOT EXISTS idx_auth_users_role ON auth_users(role);
  END IF;
END $$;

-- Create user_post_access table if it doesn't exist
CREATE TABLE IF NOT EXISTS user_post_access (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_user_id UUID REFERENCES auth_users(id) ON DELETE CASCADE,
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  granted_at TIMESTAMP DEFAULT now(),
  granted_by UUID REFERENCES auth_users(id),
  UNIQUE(auth_user_id, post_id)
);

CREATE INDEX IF NOT EXISTS idx_user_post_access_user ON user_post_access(auth_user_id);
CREATE INDEX IF NOT EXISTS idx_user_post_access_post ON user_post_access(post_id);

-- Optional: Update existing users to have 'user' role (just to be safe)
UPDATE auth_users SET role = 'user' WHERE role IS NULL;

-- Create default admin user if it doesn't exist
-- Default password is 'admin123' - CHANGE THIS IMMEDIATELY AFTER FIRST LOGIN!
-- Password hash generated with bcrypt rounds=10
INSERT INTO auth_users (username, email, password_hash, role)
VALUES (
  'admin',
  'admin@example.com',
  '$2b$10$52dk5uhR8DtBlNgB7jccZuezJGYYU.G4qzsjMCeZ8s7ilPHgLTiWy',
  'admin'
)
ON CONFLICT (email) DO UPDATE SET role = 'admin'
WHERE auth_users.email = 'admin@example.com';

-- Optional: Promote an existing user to admin (uncomment and update the email)
-- UPDATE auth_users SET role = 'admin' WHERE email = 'your-existing-user@example.com';

