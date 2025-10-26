#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "🔄 Running database migrations..."
echo "=========================================="

# This script applies new migration files to an existing database
# while preserving all data

MIGRATIONS_DIR="initdb"
APPLIED_MIGRATIONS_TABLE="schema_migrations"

# Check if postgres container is running
if ! docker compose -f docker-compose.production.yml ps --services --filter "status=running" | grep -q "^postgres$"; then
  echo "❌ Error: PostgreSQL container is not running"
  exit 1
fi

# Wait for postgres to be ready
echo "⏳ Waiting for PostgreSQL..."
max_attempts=30
attempt=0
until docker compose -f docker-compose.production.yml exec -T postgres pg_isready -U "${POSTGRES_USER:-appuser}" >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  if [ $attempt -eq $max_attempts ]; then
    echo "❌ Error: PostgreSQL did not become ready in time"
    exit 1
  fi
  sleep 2
done
echo "✅ PostgreSQL is ready"

# Create migrations tracking table if it doesn't exist
echo ""
echo "📋 Setting up migration tracking..."
docker compose -f docker-compose.production.yml exec -T postgres psql -U "${POSTGRES_USER:-appuser}" -d "${POSTGRES_DB:-facebook_analysis}" <<EOF
CREATE TABLE IF NOT EXISTS ${APPLIED_MIGRATIONS_TABLE} (
  id SERIAL PRIMARY KEY,
  filename VARCHAR(255) UNIQUE NOT NULL,
  applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF

echo "✅ Migration tracking table ready"

# Find all SQL files in migrations directory
echo ""
echo "🔍 Scanning for migration files..."
migration_files=$(find "${MIGRATIONS_DIR}" -name "*.sql" -type f | sort)

if [[ -z "${migration_files}" ]]; then
  echo "ℹ️  No migration files found in ${MIGRATIONS_DIR}"
  exit 0
fi

applied_count=0
skipped_count=0

# Apply each migration if not already applied
for migration_file in ${migration_files}; do
  filename=$(basename "$migration_file")
  
  # Check if this migration has already been applied
  already_applied=$(docker compose -f docker-compose.production.yml exec -T postgres psql -U "${POSTGRES_USER:-appuser}" -d "${POSTGRES_DB:-facebook_analysis}" -t -c "SELECT COUNT(*) FROM ${APPLIED_MIGRATIONS_TABLE} WHERE filename = '${filename}';" | tr -d ' ')
  
  if [[ "${already_applied}" -gt 0 ]]; then
    echo "⏭️  Skipping ${filename} (already applied)"
    ((skipped_count++))
    continue
  fi
  
  echo "🔄 Applying ${filename}..."
  
  # Apply the migration
  if docker compose -f docker-compose.production.yml exec -T postgres psql -U "${POSTGRES_USER:-appuser}" -d "${POSTGRES_DB:-facebook_analysis}" < "${migration_file}"; then
    # Record that this migration was applied
    docker compose -f docker-compose.production.yml exec -T postgres psql -U "${POSTGRES_USER:-appuser}" -d "${POSTGRES_DB:-facebook_analysis}" -c "INSERT INTO ${APPLIED_MIGRATIONS_TABLE} (filename) VALUES ('${filename}');"
    echo "✅ Applied ${filename}"
    ((applied_count++))
  else
    echo "❌ Error applying ${filename}"
    echo ""
    echo "Migration failed! Please review the error above."
    echo "You may need to:"
    echo "  1. Fix the migration file"
    echo "  2. Manually fix the database state"
    echo "  3. Re-run this script"
    exit 1
  fi
done

echo ""
echo "=========================================="
echo "✅ Migration complete!"
echo "=========================================="
echo ""
echo "Summary:"
echo "  - Applied: ${applied_count} migration(s)"
echo "  - Skipped: ${skipped_count} migration(s) (already applied)"
echo ""
echo "Note: Migrations are tracked in '${APPLIED_MIGRATIONS_TABLE}' table"
