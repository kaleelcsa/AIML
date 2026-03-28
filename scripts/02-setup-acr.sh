#!/bin/bash
###############################################################################
# Step 2: Create Azure Container Registry (ACR)
###############################################################################
# Creates an ACR to store Docker images for Apache2 and Open Liberty.
###############################################################################

set -euo pipefail

# ========================= CONFIGURATION =========================
RESOURCE_GROUP="rg-app-migration"
ACR_NAME="acrappmigration"   # Must be globally unique, lowercase, alphanumeric
ACR_SKU="Standard"           # Basic, Standard, or Premium
# =================================================================

echo "============================================"
echo "  Creating Azure Container Registry"
echo "============================================"
echo "  ACR Name:       ${ACR_NAME}"
echo "  Resource Group: ${RESOURCE_GROUP}"
echo "  SKU:            ${ACR_SKU}"
echo "============================================"

az acr create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${ACR_NAME}" \
  --sku "${ACR_SKU}" \
  --admin-enabled false

echo ""
echo "ACR '${ACR_NAME}' created successfully."
echo "Login server: $(az acr show --name ${ACR_NAME} --query loginServer -o tsv)"
echo ""
echo "Next: Run 03-setup-aks.sh to create the Kubernetes cluster."
