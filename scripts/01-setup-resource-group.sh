#!/bin/bash
###############################################################################
# Step 1: Create Azure Resource Group
###############################################################################
# Creates a resource group to hold all migration resources.
# Modify the variables below to match your environment.
###############################################################################

set -euo pipefail

# ========================= CONFIGURATION =========================
RESOURCE_GROUP="rg-app-migration"
LOCATION="eastus"            # Change to your preferred Azure region
TAGS="project=app-migration environment=production"
# =================================================================

echo "============================================"
echo "  Creating Azure Resource Group"
echo "============================================"
echo "  Resource Group: ${RESOURCE_GROUP}"
echo "  Location:       ${LOCATION}"
echo "============================================"

az group create \
  --name "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --tags ${TAGS}

echo ""
echo "Resource group '${RESOURCE_GROUP}' created successfully."
echo "Next: Run 02-setup-acr.sh to create the container registry."
