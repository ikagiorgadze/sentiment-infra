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

# Clean up Docker to save space
echo ""
echo "🧹 Cleaning up Docker resources..."
echo "   - Removing unused containers..."
docker container prune -f || true
echo "   - Removing unused images..."
docker image prune -af || true
echo "   - Removing unused volumes..."
docker volume prune -f || true
echo "   - Removing build cache..."
docker builder prune -af || true
echo "   - Current disk usage:"
df -h / | tail -1 | awk '{print "   Disk: " $3 " used / " $2 " total (" $5 " full)"}'
docker system df --format "table {{.Type}}\t{{.TotalCount}}\t{{.Size}}" | tail -n +2 | awk '{print "   Docker " $1 ": " $3}'

# Ensure there is enough free disk space before continuing
MIN_FREE_KB=$((2 * 1024 * 1024)) # 2 GiB
AVAILABLE_KB=$(df --output=avail -k / | tail -1 | tr -d ' ')
if [ -z "$AVAILABLE_KB" ]; then
  echo "⚠️  Warning: Unable to determine available disk space. Continuing cautiously."
elif [ "$AVAILABLE_KB" -lt "$MIN_FREE_KB" ]; then
  AVAILABLE_GB=$(awk "BEGIN { printf \"%.2f\", $AVAILABLE_KB / 1024 / 1024 }")
  REQUIRED_GB=$(awk "BEGIN { printf \"%.0f\", $MIN_FREE_KB / 1024 / 1024 }")
  echo "❌ Error: Only ${AVAILABLE_GB}GiB free on root filesystem. At least ${REQUIRED_GB}GiB required for deployment."
  echo "💡 Tip: Run scripts/cleanup-docker.sh or expand the disk volume before redeploying."
  exit 1
fi

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
