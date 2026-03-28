#!/bin/bash
###############################################################################
# Step 3: Create Azure Kubernetes Service (AKS) Cluster
###############################################################################
# Creates an AKS cluster and attaches it to the ACR for image pulling.
###############################################################################

set -euo pipefail

# ========================= CONFIGURATION =========================
RESOURCE_GROUP="rg-app-migration"
AKS_CLUSTER_NAME="aks-app-migration"
ACR_NAME="acrappmigration"
LOCATION="eastus"
NODE_COUNT=3
NODE_VM_SIZE="Standard_DS2_v2"     # 2 vCPU, 7 GiB RAM
K8S_VERSION="1.29"                  # Check available: az aks get-versions -l eastus
NETWORK_PLUGIN="azure"              # azure (CNI) or kubenet
# =================================================================

echo "============================================"
echo "  Creating AKS Cluster"
echo "============================================"
echo "  Cluster Name:   ${AKS_CLUSTER_NAME}"
echo "  Resource Group: ${RESOURCE_GROUP}"
echo "  Node Count:     ${NODE_COUNT}"
echo "  Node Size:      ${NODE_VM_SIZE}"
echo "  K8s Version:    ${K8S_VERSION}"
echo "============================================"

# Create AKS cluster with managed identity
az aks create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${AKS_CLUSTER_NAME}" \
  --location "${LOCATION}" \
  --node-count "${NODE_COUNT}" \
  --node-vm-size "${NODE_VM_SIZE}" \
  --kubernetes-version "${K8S_VERSION}" \
  --network-plugin "${NETWORK_PLUGIN}" \
  --enable-managed-identity \
  --enable-addons monitoring \
  --generate-ssh-keys \
  --tags project=app-migration environment=production

echo ""
echo "Attaching ACR '${ACR_NAME}' to AKS cluster..."

# Attach ACR to AKS (allows AKS to pull images from ACR)
az aks update \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${AKS_CLUSTER_NAME}" \
  --attach-acr "${ACR_NAME}"

echo ""
echo "Getting AKS credentials..."

# Get kubectl credentials
az aks get-credentials \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${AKS_CLUSTER_NAME}" \
  --overwrite-existing

echo ""
echo "AKS cluster '${AKS_CLUSTER_NAME}' created and configured."
echo "Verifying cluster connectivity..."
kubectl get nodes
echo ""
echo "Next: Run 04-setup-postgres.sh to create the managed PostgreSQL database."
