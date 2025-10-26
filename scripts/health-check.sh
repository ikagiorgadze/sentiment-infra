#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "🏥 Running health checks..."
echo "=========================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track overall health
all_healthy=true

# Function to check if a service is running
check_service_running() {
  local service_name=$1
  echo ""
  echo "Checking ${service_name}..."
  
  if docker compose -f docker-compose.production.yml ps --services --filter "status=running" | grep -q "^${service_name}$"; then
    echo -e "${GREEN}✅ ${service_name} is running${NC}"
    return 0
  else
    echo -e "${RED}❌ ${service_name} is not running${NC}"
    all_healthy=false
    return 1
  fi
}

# Function to check PostgreSQL
check_postgres() {
  echo ""
  echo "Checking PostgreSQL health..."
  
  if docker compose -f docker-compose.production.yml exec -T postgres pg_isready -U "${POSTGRES_USER:-appuser}" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ PostgreSQL is healthy and accepting connections${NC}"
    
    # Check if database exists
    if docker compose -f docker-compose.production.yml exec -T postgres psql -U "${POSTGRES_USER:-appuser}" -lqt | cut -d \| -f 1 | grep -qw "${POSTGRES_DB:-facebook_analysis}"; then
      echo -e "${GREEN}✅ Database '${POSTGRES_DB:-facebook_analysis}' exists${NC}"
    else
      echo -e "${YELLOW}⚠️  Database '${POSTGRES_DB:-facebook_analysis}' not found${NC}"
      all_healthy=false
    fi
  else
    echo -e "${RED}❌ PostgreSQL is not healthy${NC}"
    all_healthy=false
  fi
}

# Function to check n8n
check_n8n() {
  echo ""
  echo "Checking n8n health..."
  
  local http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5678 || echo "000")
  
  if [[ "$http_code" == "200" || "$http_code" == "401" ]]; then
    echo -e "${GREEN}✅ n8n is responding (HTTP ${http_code})${NC}"
    echo -e "${GREEN}✅ n8n UI accessible at: http://localhost:5678${NC}"
  else
    echo -e "${RED}❌ n8n is not responding properly (HTTP ${http_code})${NC}"
    all_healthy=false
  fi
}

# Function to check Adminer
check_adminer() {
  echo ""
  echo "Checking Adminer health..."
  
  local http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 || echo "000")
  
  if [[ "$http_code" == "200" ]]; then
    echo -e "${GREEN}✅ Adminer is responding (HTTP ${http_code})${NC}"
    echo -e "${GREEN}✅ Adminer UI accessible at: http://localhost:8080${NC}"
  else
    echo -e "${RED}❌ Adminer is not responding properly (HTTP ${http_code})${NC}"
    all_healthy=false
  fi
}

# Run all checks
check_service_running "postgres"
check_service_running "n8n"
check_service_running "adminer"

check_postgres
check_n8n
check_adminer

# Display Docker logs summary if something is wrong
if [ "$all_healthy" = false ]; then
  echo ""
  echo -e "${YELLOW}⚠️  Some services are unhealthy. Recent logs:${NC}"
  echo ""
  docker compose -f docker-compose.production.yml logs --tail=20
fi

# Final summary
echo ""
echo "=========================================="
if [ "$all_healthy" = true ]; then
  echo -e "${GREEN}✅ All services are healthy!${NC}"
  echo "=========================================="
  echo ""
  echo "🔗 Service URLs:"
  echo "   - n8n UI: http://$(curl -s ifconfig.me):5678"
  echo "   - Adminer: http://$(curl -s ifconfig.me):8080"
  echo "   - PostgreSQL: $(curl -s ifconfig.me):5432"
  echo ""
  echo "📝 Next steps:"
  echo "   1. Log in to n8n with your credentials"
  echo "   2. Verify n8n workflows are imported"
  echo "   3. Check database schema with Adminer"
  exit 0
else
  echo -e "${RED}❌ Some services are unhealthy!${NC}"
  echo "=========================================="
  echo ""
  echo "Please check the logs above for more details."
  echo "You can also run: docker compose -f docker-compose.production.yml logs"
  exit 1
fi
