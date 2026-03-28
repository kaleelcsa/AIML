#!/bin/bash
###############################################################################
# Step 4: Create Azure Database for PostgreSQL - Flexible Server
###############################################################################
# Creates a managed PostgreSQL instance and configures networking to allow
# connections from the AKS cluster.
###############################################################################

set -euo pipefail

# ========================= CONFIGURATION =========================
RESOURCE_GROUP="rg-app-migration"
PG_SERVER_NAME="pg-app-migration"    # Must be globally unique
PG_ADMIN_USER="pgadmin"
PG_SKU="Standard_D2ds_v4"           # 2 vCPU, 8 GiB RAM
PG_STORAGE_SIZE=128                   # GB
PG_VERSION="16"
PG_DB_NAME="appdb"
LOCATION="eastus"
AKS_CLUSTER_NAME="aks-app-migration"
# =================================================================

echo "============================================"
echo "  Creating Azure Database for PostgreSQL"
echo "============================================"
echo "  Server Name:    ${PG_SERVER_NAME}"
echo "  Admin User:     ${PG_ADMIN_USER}"
echo "  SKU:            ${PG_SKU}"
echo "  Storage:        ${PG_STORAGE_SIZE} GB"
echo "  PG Version:     ${PG_VERSION}"
echo "============================================"

# Prompt for password
read -sp "Enter PostgreSQL admin password: " PG_ADMIN_PASSWORD
echo ""

# Create PostgreSQL Flexible Server
az postgres flexible-server create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${PG_SERVER_NAME}" \
  --location "${LOCATION}" \
  --admin-user "${PG_ADMIN_USER}" \
  --admin-password "${PG_ADMIN_PASSWORD}" \
  --sku-name "${PG_SKU}" \
  --storage-size "${PG_STORAGE_SIZE}" \
  --version "${PG_VERSION}" \
  --tier "GeneralPurpose" \
  --public-access "None" \
  --tags project=app-migration environment=production

echo ""
echo "Creating database '${PG_DB_NAME}'..."

# Create the application database
az postgres flexible-server db create \
  --resource-group "${RESOURCE_GROUP}" \
  --server-name "${PG_SERVER_NAME}" \
  --database-name "${PG_DB_NAME}"

echo ""
echo "Configuring PostgreSQL server parameters..."

# Enable required extensions
az postgres flexible-server parameter set \
  --resource-group "${RESOURCE_GROUP}" \
  --server-name "${PG_SERVER_NAME}" \
  --name azure.extensions \
  --value "PG_TRGM,BTREE_GIST,UUID_OSSP"

# Require SSL connections
az postgres flexible-server parameter set \
  --resource-group "${RESOURCE_GROUP}" \
  --server-name "${PG_SERVER_NAME}" \
  --name require_secure_transport \
  --value "ON"

echo ""
echo "============================================"
echo "  Network Configuration"
echo "============================================"

# Get AKS VNet info for private connectivity
AKS_NODE_RG=$(az aks show --resource-group "${RESOURCE_GROUP}" --name "${AKS_CLUSTER_NAME}" --query nodeResourceGroup -o tsv)
AKS_VNET=$(az network vnet list --resource-group "${AKS_NODE_RG}" --query "[0].name" -o tsv)
AKS_SUBNET=$(az network vnet subnet list --resource-group "${AKS_NODE_RG}" --vnet-name "${AKS_VNET}" --query "[0].id" -o tsv)

echo "AKS VNet: ${AKS_VNET}"
echo "AKS Subnet: ${AKS_SUBNET}"
echo ""
echo "NOTE: For production, set up a Private Endpoint or VNet integration"
echo "      to securely connect AKS to PostgreSQL."
echo ""

# Allow AKS outbound IPs to connect to PostgreSQL (for initial setup)
AKS_OUTBOUND_IP=$(az aks show --resource-group "${RESOURCE_GROUP}" --name "${AKS_CLUSTER_NAME}" \
  --query "networkProfile.loadBalancerProfile.effectiveOutboundIPs[0].id" -o tsv)

if [ -n "${AKS_OUTBOUND_IP}" ]; then
  OUTBOUND_IP_ADDR=$(az network public-ip show --ids "${AKS_OUTBOUND_IP}" --query "ipAddress" -o tsv)
  echo "Adding AKS outbound IP (${OUTBOUND_IP_ADDR}) to PostgreSQL firewall..."
  az postgres flexible-server firewall-rule create \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${PG_SERVER_NAME}" \
    --rule-name "AllowAKS" \
    --start-ip-address "${OUTBOUND_IP_ADDR}" \
    --end-ip-address "${OUTBOUND_IP_ADDR}"
fi

echo ""
echo "============================================"
echo "  PostgreSQL Setup Complete"
echo "============================================"
echo "  Server:   ${PG_SERVER_NAME}.postgres.database.azure.com"
echo "  Database: ${PG_DB_NAME}"
echo "  User:     ${PG_ADMIN_USER}"
echo "============================================"
echo ""
echo "Create K8s secret with:"
echo "  kubectl create secret generic db-credentials \\"
echo "    --namespace=app-migration \\"
echo "    --from-literal=DB_USER='${PG_ADMIN_USER}' \\"
echo "    --from-literal=DB_PASSWORD='<your-password>'"
echo ""
echo "Update kubernetes/configmap-openliberty.yaml with:"
echo "  DB_HOST: ${PG_SERVER_NAME}.postgres.database.azure.com"
echo ""
echo "Next: Run 05-build-push-images.sh to build and push Docker images."
