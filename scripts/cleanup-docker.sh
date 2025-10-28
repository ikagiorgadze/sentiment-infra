#!/usr/bin/env bash
# Docker Cleanup Script - Run weekly via cron

echo "=========================================="
echo "🧹 Docker Cleanup - $(date)"
echo "=========================================="

echo ""
echo "📊 Disk usage BEFORE cleanup:"
df -h / | grep -v "Filesystem" | awk '{print "   " $3 " used / " $2 " total (" $5 " full)"}'

echo ""
echo "📊 Docker usage BEFORE cleanup:"
docker system df

echo ""
echo "🗑️  Removing unused Docker resources..."

# Remove stopped containers older than 24 hours
docker container prune -f --filter "until=24h"

# Remove dangling images
docker image prune -f

# Remove unused images older than 7 days
docker image prune -a -f --filter "until=168h"

# Remove build cache older than 7 days
docker builder prune -f --filter "until=168h"

# Remove unused volumes (be careful with this!)
# Uncomment if you want to remove unused volumes
# docker volume prune -f

echo ""
echo "✅ Cleanup complete!"

echo ""
echo "📊 Disk usage AFTER cleanup:"
df -h / | grep -v "Filesystem" | awk '{print "   " $3 " used / " $2 " total (" $5 " full)"}'

echo ""
echo "📊 Docker usage AFTER cleanup:"
docker system df

echo ""
echo "=========================================="
