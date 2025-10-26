#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "🚀 Starting deployment process..."
echo "=========================================="

# Check if Docker is installed
if ! command -v docker >/dev/null 2>&1; then
  echo "❌ Error: Docker is not installed on this host."
  exit 1
fi

# Check if Docker Compose is available
if ! docker compose version >/dev/null 2>&1; then
  echo "❌ Error: docker compose plugin is not available."
  exit 1
fi

# Check if .env file exists
if [ ! -f .env ]; then
  echo "❌ Error: .env file not found. Please run setup-env.sh first."
  exit 1
fi

echo "✅ Prerequisites checked"

# Stop existing containers if they exist
echo ""
echo "🛑 Stopping existing containers..."
if docker compose -f docker-compose.production.yml ps --services 2>/dev/null | grep -q .; then
  # Stop containers but preserve volumes (no -v flag)
  docker compose -f docker-compose.production.yml down
  echo "✅ Existing containers stopped (volumes preserved)"
else
  echo "ℹ️  No existing containers found"
fi

# Clean up dangling images to save space
echo ""
echo "🧹 Cleaning up dangling images..."
docker image prune -f || true

# Build and start services
echo ""
echo "🏗️  Building and starting services..."
docker compose -f docker-compose.production.yml up -d --build

# Wait for services to be ready
echo ""
echo "⏳ Waiting for services to be healthy..."
sleep 10

# Check if services are running
echo ""
echo "🔍 Checking service status..."
docker compose -f docker-compose.production.yml ps

# Wait for postgres to be fully ready
echo ""
echo "⏳ Waiting for PostgreSQL to be ready..."
max_attempts=30
attempt=0
until docker compose -f docker-compose.production.yml exec -T postgres pg_isready -U "${POSTGRES_USER:-appuser}" >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  if [ $attempt -eq $max_attempts ]; then
    echo "❌ Error: PostgreSQL did not become ready in time"
    exit 1
  fi
  echo "   Attempt $attempt/$max_attempts..."
  sleep 2
done
echo "✅ PostgreSQL is ready"

# Check if database needs schema updates
echo ""
echo "🔄 Checking for database schema updates..."
# Note: PostgreSQL initdb scripts only run on empty database (first deploy)
# For schema updates on existing databases, add migration scripts to initdb/ folder
# with higher numbered prefixes (e.g., 06_new_migration.sql)
# They will be automatically picked up if database is recreated

echo "⏳ Waiting for n8n to be ready..."
max_attempts=30
attempt=0
until curl -s -o /dev/null -w "%{http_code}" http://localhost:5678 | grep -q "200\|401"; do
  attempt=$((attempt + 1))
  if [ $attempt -eq $max_attempts ]; then
    echo "❌ Error: n8n did not become ready in time"
    exit 1
  fi
  echo "   Attempt $attempt/$max_attempts..."
  sleep 2
done
echo "✅ n8n is ready"

echo ""
echo "=========================================="
echo "✅ Deployment completed successfully!"
echo "=========================================="
echo ""
echo "Services status:"
docker compose -f docker-compose.production.yml ps
