#!/bin/bash
###############################################################################
# Step 7: Migrate PostgreSQL Data from VM to Azure Database for PostgreSQL
###############################################################################
# Exports data from the source PostgreSQL on the VM and imports it into
# Azure Database for PostgreSQL Flexible Server.
#
# Prerequisites:
#   - pg_dump and psql installed locally
#   - Network access to both source VM and target Azure PostgreSQL
#   - Azure PostgreSQL firewall rules configured
###############################################################################

set -euo pipefail

# ========================= CONFIGURATION =========================
# Source (VM) PostgreSQL
SOURCE_HOST="<source-vm-ip-or-hostname>"
SOURCE_PORT="5432"
SOURCE_DB="appdb"
SOURCE_USER="postgres"

# Target (Azure) PostgreSQL
TARGET_HOST="<your-server>.postgres.database.azure.com"
TARGET_PORT="5432"
TARGET_DB="appdb"
TARGET_USER="pgadmin"

# Dump file location
DUMP_DIR="/tmp/pg-migration"
DUMP_FILE="${DUMP_DIR}/appdb_dump.sql"
# =================================================================

echo "============================================"
echo "  PostgreSQL Data Migration"
echo "============================================"
echo "  Source: ${SOURCE_HOST}:${SOURCE_PORT}/${SOURCE_DB}"
echo "  Target: ${TARGET_HOST}:${TARGET_PORT}/${TARGET_DB}"
echo "============================================"

# Create dump directory
mkdir -p "${DUMP_DIR}"

# ---- Step 1: Export from source ----
echo ""
echo "--- Step 1: Exporting data from source PostgreSQL ---"
echo "You will be prompted for the source database password."

pg_dump \
  -h "${SOURCE_HOST}" \
  -p "${SOURCE_PORT}" \
  -U "${SOURCE_USER}" \
  -d "${SOURCE_DB}" \
  --no-owner \
  --no-privileges \
  --clean \
  --if-exists \
  -F p \
  -f "${DUMP_FILE}"

echo "Dump file created: ${DUMP_FILE}"
echo "Dump size: $(du -h "${DUMP_FILE}" | cut -f1)"

# ---- Step 2: Import to target ----
echo ""
echo "--- Step 2: Importing data to Azure PostgreSQL ---"
echo "You will be prompted for the target database password."

psql \
  "host=${TARGET_HOST} port=${TARGET_PORT} dbname=${TARGET_DB} user=${TARGET_USER} sslmode=require" \
  -f "${DUMP_FILE}"

echo ""
echo "============================================"
echo "  Data Migration Complete"
echo "============================================"
echo ""
echo "Verify the migration:"
echo "  psql \"host=${TARGET_HOST} port=${TARGET_PORT} dbname=${TARGET_DB} user=${TARGET_USER} sslmode=require\" -c '\\dt'"
echo ""
echo "After verification, update the K8s configmap and secret with the"
echo "Azure PostgreSQL connection details, then deploy to AKS."
