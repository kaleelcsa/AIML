#!/bin/bash
###############################################################################
# Step 6: Deploy Application to AKS
###############################################################################
# Applies all Kubernetes manifests to deploy the application to AKS.
# Deploys in order: namespace → secrets/configs → services → deployments
# → ingress → autoscalers → network policies
###############################################################################

set -euo pipefail

# ========================= CONFIGURATION =========================
RESOURCE_GROUP="rg-app-migration"
AKS_CLUSTER_NAME="aks-app-migration"
ACR_NAME="acrappmigration"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
K8S_DIR="${PROJECT_DIR}/kubernetes"
# =================================================================

echo "============================================"
echo "  Deploying Application to AKS"
echo "============================================"

# Ensure kubectl is configured for the right cluster
echo "Getting AKS credentials..."
az aks get-credentials \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${AKS_CLUSTER_NAME}" \
  --overwrite-existing

echo ""
echo "Current cluster context:"
kubectl config current-context
echo ""

# ---- Step 1: Create Namespace ----
echo "--- Creating Namespace ---"
kubectl apply -f "${K8S_DIR}/namespace.yaml"

# ---- Step 2: Create Secrets and ConfigMaps ----
echo "--- Creating ConfigMaps ---"
kubectl apply -f "${K8S_DIR}/configmap-apache.yaml"
kubectl apply -f "${K8S_DIR}/configmap-openliberty.yaml"

echo "--- Creating Secrets ---"
echo "NOTE: Make sure you've updated the secret values in secret-db.yaml"
echo "      or create the secret manually with kubectl create secret."
kubectl apply -f "${K8S_DIR}/secret-db.yaml"

# ---- Step 3: Create Services ----
echo "--- Creating Services ---"
kubectl apply -f "${K8S_DIR}/service-apache.yaml"
kubectl apply -f "${K8S_DIR}/service-openliberty.yaml"

# ---- Step 4: Create Deployments ----
echo "--- Creating Deployments ---"
kubectl apply -f "${K8S_DIR}/deployment-openliberty.yaml"

echo "Waiting for Open Liberty pods to be ready..."
kubectl rollout status deployment/openliberty-deployment \
  -n app-migration --timeout=300s || true

kubectl apply -f "${K8S_DIR}/deployment-apache.yaml"

echo "Waiting for Apache pods to be ready..."
kubectl rollout status deployment/apache-deployment \
  -n app-migration --timeout=120s || true

# ---- Step 5: Create Ingress ----
echo "--- Creating Ingress ---"
kubectl apply -f "${K8S_DIR}/ingress.yaml"

# ---- Step 6: Create HPAs ----
echo "--- Creating Horizontal Pod Autoscalers ---"
kubectl apply -f "${K8S_DIR}/hpa-apache.yaml"
kubectl apply -f "${K8S_DIR}/hpa-openliberty.yaml"

# ---- Step 7: Create Network Policies ----
echo "--- Creating Network Policies ---"
kubectl apply -f "${K8S_DIR}/networkpolicy.yaml"

echo ""
echo "============================================"
echo "  Deployment Complete!"
echo "============================================"
echo ""

# Show deployment status
echo "--- Pod Status ---"
kubectl get pods -n app-migration -o wide
echo ""

echo "--- Service Status ---"
kubectl get services -n app-migration
echo ""

echo "--- Ingress Status ---"
kubectl get ingress -n app-migration
echo ""

echo "--- HPA Status ---"
kubectl get hpa -n app-migration
echo ""

# Get external IP if available
echo "============================================"
echo "  Access Information"
echo "============================================"
INGRESS_IP=$(kubectl get ingress app-ingress -n app-migration -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Pending...")
echo "  Ingress IP: ${INGRESS_IP}"
echo ""
echo "  If using a domain, update your DNS A record to point to: ${INGRESS_IP}"
echo "============================================"
