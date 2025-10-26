# Database Initialization Scripts

This directory contains SQL scripts that are automatically executed when the PostgreSQL database is first initialized via Docker Compose.

## Execution Order

Scripts are executed in alphabetical order:

1. **01_schema.sql** - Core database schema (users, posts, comments, sentiments, reactions, jobs)
2. **02_auth_schema.sql** - Authentication schema (auth_users, auth_sessions, user_post_access) + default admin user
3. **03_access_control_migration.sql** - Migration script for existing databases (optional, for upgrades)

## Default Admin User

A default admin user is automatically created during initialization:

### Credentials
- **Email:** `admin@example.com`
- **Password:** `admin123`
- **Role:** `admin`

### ⚠️ SECURITY WARNING
**CHANGE THIS PASSWORD IMMEDIATELY AFTER FIRST LOGIN!**

This default account has full administrative access to the system. Leaving it with the default password is a significant security risk.

### How to Change the Password

**Option 1: Via API**
1. Log in using the default credentials:
   ```bash
   curl -X POST http://localhost:3000/api/auth/login \
     -H "Content-Type: application/json" \
     -d '{"email": "admin@example.com", "password": "admin123"}'
   ```
2. Use the returned token and implement a password change endpoint, or:

**Option 2: Via Database**
1. Generate a new bcrypt hash for your desired password (use an online bcrypt generator or Node.js)
2. Update the database:
   ```sql
   UPDATE auth_users 
   SET password_hash = '$2b$10$YOUR_NEW_BCRYPT_HASH_HERE' 
   WHERE email = 'admin@example.com';
   ```

**Option 3: Delete and Create New Admin**
1. Log in with default credentials
2. Create a new admin user via registration
3. Grant them admin role
4. Delete the default admin account

## Migration for Existing Databases

If you already have a database and want to add access control:

```bash
psql -U appuser -d facebook_analysis -f 03_access_control_migration.sql
```

This will:
- Add `role` column to `auth_users` table
- Create `user_post_access` table for managing permissions
- Create the default admin user (if it doesn't exist)
- Set existing users to 'user' role

## Access Control Model

- **Admin users** (`role = 'admin'`): Full access to all resources
- **Regular users** (`role = 'user'`): Access only to posts explicitly granted to them
- Access to a post includes access to all its comments and sentiments
- New registrations default to 'user' role

## Need Help?

See the main documentation:
- `/ACCESS_CONTROL.md` - Detailed access control documentation
- `/IMPLEMENTATION_SUMMARY.md` - Implementation details

