#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "🔧 Setting up environment variables..."
echo "=========================================="

# Read environment variables from stdin (passed from GitHub Actions)
read -r POSTGRES_USER
read -r POSTGRES_PASSWORD
read -r POSTGRES_DB
read -r N8N_ENCRYPTION_KEY
read -r N8N_BASIC_AUTH_USER
read -r N8N_BASIC_AUTH_PASSWORD
read -r WEBHOOK_URL
read -r N8N_CORS_ORIGIN

# Create .env file
cat > .env <<EOF
# PostgreSQL Configuration
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=${POSTGRES_DB}

# n8n Configuration
N8N_HOST=0.0.0.0
N8N_PORT=5678
WEBHOOK_URL=${WEBHOOK_URL}
GENERIC_TIMEZONE=UTC
N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
N8N_COMMUNITY_PACKAGES_ALLOW_TOOL_USAGE=true
N8N_CORS_ORIGIN=${N8N_CORS_ORIGIN}
N8N_CORS_ALLOW_METHODS=GET,POST,OPTIONS,PUT,PATCH,DELETE
N8N_CORS_ALLOW_HEADERS=Accept,Authorization,Content-Type,Origin,Referer,User-Agent,X-Requested-With
N8N_CORS_ALLOW_CREDENTIALS=true
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=${N8N_BASIC_AUTH_USER}
N8N_BASIC_AUTH_PASSWORD=${N8N_BASIC_AUTH_PASSWORD}
EOF

# Set secure permissions on .env file
chmod 600 .env

echo "✅ Environment file created successfully"
echo ""
echo "Configured services:"
echo "  - PostgreSQL Database: ${POSTGRES_DB}"
echo "  - n8n Webhook URL: ${WEBHOOK_URL}"
echo "  - n8n CORS Origin: ${N8N_CORS_ORIGIN}"
