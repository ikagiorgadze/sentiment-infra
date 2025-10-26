#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "📦 Importing n8n workflows..."
echo "=========================================="

SERVICE_NAME="${SERVICE_NAME:-n8n}"
WORKFLOW_SOURCE_DIR="${WORKFLOW_SOURCE_DIR:-workflows}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.production.yml}"
N8N_HOST="${N8N_HOST:-localhost}"
N8N_PORT="${N8N_PORT:-5678}"

die() {
  echo "❌ [import-n8n-workflows] $*" >&2
  exit 1
}

if ! command -v docker >/dev/null 2>&1; then
  die "Docker is not installed on this host."
fi

if ! command -v curl >/dev/null 2>&1; then
  die "curl is not installed on this host."
fi

if [ ! -f "${COMPOSE_FILE}" ]; then
  die "Compose file '${COMPOSE_FILE}' not found."
fi

if ! ls "${WORKFLOW_SOURCE_DIR}"/*.json >/dev/null 2>&1; then
  echo "ℹ️  [import-n8n-workflows] No workflow JSON files found in '${WORKFLOW_SOURCE_DIR}'. Nothing to import."
  exit 0
fi

# Load credentials from .env file
if [ -f .env ]; then
  export $(grep -v '^#' .env | grep 'N8N_BASIC_AUTH' | xargs)
fi

if [[ -z "${N8N_BASIC_AUTH_USER:-}" ]] || [[ -z "${N8N_BASIC_AUTH_PASSWORD:-}" ]]; then
  die "N8N_BASIC_AUTH_USER and N8N_BASIC_AUTH_PASSWORD must be set in .env"
fi

N8N_API_URL="http://${N8N_HOST}:${N8N_PORT}/api/v1"

echo "⏳ Waiting for n8n API to be ready..."
for i in {1..30}; do
  if curl -s -u "${N8N_BASIC_AUTH_USER}:${N8N_BASIC_AUTH_PASSWORD}" "${N8N_API_URL}/workflows" >/dev/null 2>&1; then
    echo "✅ n8n API is ready"
    break
  fi
  if [ $i -eq 30 ]; then
    die "n8n API did not become ready in time"
  fi
  echo "   Waiting... ($i/30)"
  sleep 2
done

echo "� [import-n8n-workflows] Importing workflows via API..."
imported_count=0
for file in "${WORKFLOW_SOURCE_DIR}"/*.json; do
  [ -e "$file" ] || continue
  
  workflow_name=$(basename "$file" .json)
  echo "   Processing: ${workflow_name}"
  
  # Check if workflow already exists by name
  existing_id=$(curl -s -u "${N8N_BASIC_AUTH_USER}:${N8N_BASIC_AUTH_PASSWORD}" \
    "${N8N_API_URL}/workflows" | \
    grep -o "\"id\":\"[^\"]*\"[^}]*\"name\":\"${workflow_name}\"" | \
    grep -o "\"id\":\"[^\"]*\"" | cut -d'"' -f4 | head -1 || true)
  
  if [[ -n "${existing_id}" ]]; then
    echo "      Updating existing workflow (ID: ${existing_id})"
    response=$(curl -s -w "\n%{http_code}" -u "${N8N_BASIC_AUTH_USER}:${N8N_BASIC_AUTH_PASSWORD}" \
      -X PUT \
      -H "Content-Type: application/json" \
      -d @"${file}" \
      "${N8N_API_URL}/workflows/${existing_id}")
    http_code=$(echo "$response" | tail -n1)
    if [[ "${http_code}" =~ ^2[0-9][0-9]$ ]]; then
      echo "      ✅ Updated"
      ((imported_count++))
    else
      echo "      ⚠️  Failed to update (HTTP ${http_code})"
    fi
  else
    echo "      Creating new workflow"
    response=$(curl -s -w "\n%{http_code}" -u "${N8N_BASIC_AUTH_USER}:${N8N_BASIC_AUTH_PASSWORD}" \
      -X POST \
      -H "Content-Type: application/json" \
      -d @"${file}" \
      "${N8N_API_URL}/workflows")
    http_code=$(echo "$response" | tail -n1)
    if [[ "${http_code}" =~ ^2[0-9][0-9]$ ]]; then
      echo "      ✅ Created"
      ((imported_count++))
    else
      echo "      ⚠️  Failed to create (HTTP ${http_code})"
    fi
  fi
done

echo ""
echo "✅ [import-n8n-workflows] Imported/Updated ${imported_count} workflows"
echo ""
echo "=========================================="
echo "✅ Import completed!"
echo "=========================================="
echo ""
echo "ℹ️  Note: Workflows may need credentials to be configured before they can be activated."
echo "   Visit http://${N8N_HOST}:${N8N_PORT} to configure credentials and activate workflows."
