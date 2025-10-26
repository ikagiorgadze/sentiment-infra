#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "📦 Importing n8n workflows..."
echo "=========================================="

SERVICE_NAME="${SERVICE_NAME:-n8n}"
WORKFLOW_SOURCE_DIR="${WORKFLOW_SOURCE_DIR:-workflows}"
TMP_DIR="/tmp/n8n-workflows-import"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.production.yml}"

die() {
  echo "❌ [import-n8n-workflows] $*" >&2
  exit 1
}

if ! command -v docker >/dev/null 2>&1; then
  die "Docker is not installed on this host."
fi

if ! docker compose version >/dev/null 2>&1; then
  die "docker compose plugin is not available."
fi

if [ ! -f "${COMPOSE_FILE}" ]; then
  die "Compose file '${COMPOSE_FILE}' not found."
fi

if ! docker compose -f "${COMPOSE_FILE}" ps --services | grep -qx "${SERVICE_NAME}"; then
  die "Service '${SERVICE_NAME}' not found in docker-compose stack."
fi

if ! ls "${WORKFLOW_SOURCE_DIR}"/*.json >/dev/null 2>&1; then
  echo "ℹ️  [import-n8n-workflows] No workflow JSON files found in '${WORKFLOW_SOURCE_DIR}'. Nothing to import."
  exit 0
fi

CONTAINER_ID="$(docker compose -f "${COMPOSE_FILE}" ps -q "${SERVICE_NAME}")"
if [[ -z "${CONTAINER_ID}" ]]; then
  die "Service '${SERVICE_NAME}' is not running. Start docker compose first."
fi

echo "✅ [import-n8n-workflows] Preparing container workspace..."
docker exec "${CONTAINER_ID}" rm -rf "${TMP_DIR}"
docker exec "${CONTAINER_ID}" mkdir -p "${TMP_DIR}"

echo "📋 [import-n8n-workflows] Copying workflows into container..."
for file in "${WORKFLOW_SOURCE_DIR}"/*.json; do
  [ -e "$file" ] || continue
  docker cp "$file" "${CONTAINER_ID}:${TMP_DIR}/$(basename "$file")"
done

echo "🔄 [import-n8n-workflows] Importing workflows..."
docker exec "${CONTAINER_ID}" n8n import:workflow \
  --separate \
  --input="${TMP_DIR}" \
  --overwrite \
  --allow-root

echo "🚀 [import-n8n-workflows] Activating workflows..."
# Get list of all workflow IDs and activate them
WORKFLOW_IDS=$(docker exec "${CONTAINER_ID}" n8n list:workflow --allow-root | grep -oP '(?<=id: )\d+' || true)

if [[ -n "${WORKFLOW_IDS}" ]]; then
  for workflow_id in ${WORKFLOW_IDS}; do
    echo "   Activating workflow ID: ${workflow_id}"
    docker exec "${CONTAINER_ID}" n8n update:workflow \
      --id="${workflow_id}" \
      --active=true \
      --allow-root 2>/dev/null || echo "   ⚠️  Could not activate workflow ${workflow_id} (may require credentials)"
  done
  echo "✅ [import-n8n-workflows] Workflow activation complete"
else
  echo "ℹ️  [import-n8n-workflows] No workflows found to activate"
fi

echo "🧹 [import-n8n-workflows] Cleaning up temporary files..."
docker exec "${CONTAINER_ID}" rm -rf "${TMP_DIR}"

echo "✅ [import-n8n-workflows] Workflows imported successfully."
echo ""
echo "=========================================="
echo "✅ Import completed!"
echo "=========================================="
