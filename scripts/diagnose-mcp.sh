#!/usr/bin/env bash
# Diagnostic script for investigating OpenAlex MCP server issues

set -euo pipefail

echo "=========================================="
echo "🔍 MCP Server Diagnostic Tool"
echo "=========================================="
echo ""

# Check if n8n container is running
echo "1️⃣  Checking n8n container status..."
if docker ps --filter "name=n8n" --format "{{.Names}}" | grep -q "n8n"; then
  echo "   ✅ n8n container is running"
  CONTAINER_NAME=$(docker ps --filter "name=n8n" --format "{{.Names}}" | head -1)
  echo "   Container name: $CONTAINER_NAME"
else
  echo "   ❌ n8n container is not running"
  echo "   Run: docker compose -f docker-compose.production.yml up -d"
  exit 1
fi
echo ""

# Check uvx installation
echo "2️⃣  Checking uvx installation in container..."
if docker exec "$CONTAINER_NAME" which uvx >/dev/null 2>&1; then
  echo "   ✅ uvx is installed"
  docker exec "$CONTAINER_NAME" uvx --version
else
  echo "   ❌ uvx is not found in PATH"
  echo "   Checking /usr/local/bin..."
  docker exec "$CONTAINER_NAME" ls -la /usr/local/bin/ | grep -E "uv|uvx" || echo "   Not found in /usr/local/bin"
fi
echo ""

# Check git installation
echo "3️⃣  Checking git installation..."
if docker exec "$CONTAINER_NAME" which git >/dev/null 2>&1; then
  echo "   ✅ git is installed"
  docker exec "$CONTAINER_NAME" git --version
else
  echo "   ❌ git is not installed"
fi
echo ""

# Check if we can run OpenAlex MCP server
echo "4️⃣  Testing OpenAlex MCP server..."
echo "   Attempting to run: uvx mcp-server-openalex --help"
if docker exec "$CONTAINER_NAME" uvx mcp-server-openalex --help >/dev/null 2>&1; then
  echo "   ✅ OpenAlex MCP server can be executed"
else
  echo "   ❌ Failed to execute OpenAlex MCP server"
  echo "   Trying to install manually..."
  docker exec "$CONTAINER_NAME" uvx mcp-server-openalex --help 2>&1 | tail -20
fi
echo ""

# Check n8n data directory
echo "5️⃣  Checking n8n data directory structure..."
docker exec "$CONTAINER_NAME" ls -la /home/node/.n8n/ 2>/dev/null || echo "   ❌ Cannot access /home/node/.n8n/"
echo ""

# Check for credential files
echo "6️⃣  Checking for MCP credential configuration..."
if docker exec "$CONTAINER_NAME" test -d /home/node/.n8n/credentials 2>/dev/null; then
  echo "   ✅ Credentials directory exists"
  docker exec "$CONTAINER_NAME" ls -la /home/node/.n8n/credentials/ 2>/dev/null || true
else
  echo "   ⚠️  Credentials directory may not exist yet"
fi
echo ""

# Check recent n8n logs
echo "7️⃣  Recent n8n container logs (last 50 lines)..."
echo "   Looking for MCP-related errors..."
docker logs "$CONTAINER_NAME" --tail 50 2>&1 | grep -i "mcp\|openalex\|uvx\|error" || echo "   No MCP-related errors found in recent logs"
echo ""

# Check container environment
echo "8️⃣  Checking PATH and environment in container..."
docker exec "$CONTAINER_NAME" sh -c 'echo "PATH=$PATH"'
docker exec "$CONTAINER_NAME" sh -c 'echo "USER=$(whoami)"'
docker exec "$CONTAINER_NAME" sh -c 'echo "HOME=$HOME"'
echo ""

# Test manual MCP server invocation
echo "9️⃣  Testing manual MCP server execution as node user..."
docker exec -u node "$CONTAINER_NAME" sh -c 'uvx --version' 2>&1 || echo "   ❌ Cannot run uvx as node user"
echo ""

echo "=========================================="
echo "✅ Diagnostic complete"
echo "=========================================="
echo ""
echo "💡 Common issues and fixes:"
echo ""
echo "1. If uvx is missing:"
echo "   - Rebuild the n8n container: docker compose -f docker-compose.production.yml build --no-cache n8n"
echo ""
echo "2. If git is missing:"
echo "   - Check Dockerfile has: RUN apk add --no-cache git"
echo ""
echo "3. If MCP server fails to run:"
echo "   - Check the node user has execute permissions on /usr/local/bin/uvx"
echo "   - Verify internet connectivity for downloading packages"
echo ""
echo "4. If credentials are missing:"
echo "   - Configure the OpenAlex MCP credential in n8n UI"
echo "   - Check the credential points to the correct server command"
echo ""
