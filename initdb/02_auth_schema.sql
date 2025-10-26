-- Authentication table
CREATE TABLE IF NOT EXISTS auth_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username VARCHAR(255) UNIQUE NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(50) DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now(),
  last_login TIMESTAMP
);

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_auth_users_email ON auth_users(email);
CREATE INDEX IF NOT EXISTS idx_auth_users_username ON auth_users(username);
CREATE INDEX IF NOT EXISTS idx_auth_users_role ON auth_users(role);

-- Optional: sessions table for token management
CREATE TABLE IF NOT EXISTS auth_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth_users(id) ON DELETE CASCADE,
  token VARCHAR(500) UNIQUE NOT NULL,
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_auth_sessions_token ON auth_sessions(token);
CREATE INDEX IF NOT EXISTS idx_auth_sessions_user_id ON auth_sessions(user_id);

-- User post access control table
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

-- Create default admin user
-- Default credentials: admin@example.com / admin123
-- IMPORTANT: Change password immediately after first login!
INSERT INTO auth_users (username, email, password_hash, role)
VALUES (
  'admin',
  'admin@example.com',
  '$2b$10$52dk5uhR8DtBlNgB7jccZuezJGYYU.G4qzsjMCeZ8s7ilPHgLTiWy',
  'admin'
)
ON CONFLICT (email) DO NOTHING;

