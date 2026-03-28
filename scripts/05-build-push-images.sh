#!/bin/bash
###############################################################################
# Step 5: Build and Push Docker Images to ACR
###############################################################################
# Builds Docker images for Apache2 and Open Liberty, then pushes them to ACR.
#
# Prerequisites:
#   - Docker installed locally
#   - Azure CLI logged in
#   - ACR created (02-setup-acr.sh)
#   - Application WAR file available
###############################################################################

set -euo pipefail

# ========================= CONFIGURATION =========================
ACR_NAME="acrappmigration"
ACR_LOGIN_SERVER="${ACR_NAME}.azurecr.io"
IMAGE_TAG="v1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
# =================================================================

echo "============================================"
echo "  Building and Pushing Docker Images"
echo "============================================"
echo "  ACR:       ${ACR_LOGIN_SERVER}"
echo "  Tag:       ${IMAGE_TAG}"
echo "  Project:   ${PROJECT_DIR}"
echo "============================================"

# Login to ACR
echo ""
echo "Logging in to ACR..."
az acr login --name "${ACR_NAME}"

# ---- Build and Push Apache2 Image ----
echo ""
echo "============================================"
echo "  Building Apache2 Web Layer Image"
echo "============================================"

docker build \
  -t "${ACR_LOGIN_SERVER}/web-apache:${IMAGE_TAG}" \
  -t "${ACR_LOGIN_SERVER}/web-apache:latest" \
  -f "${PROJECT_DIR}/docker/apache2/Dockerfile" \
  "${PROJECT_DIR}/docker/apache2/"

echo "Pushing Apache2 image..."
docker push "${ACR_LOGIN_SERVER}/web-apache:${IMAGE_TAG}"
docker push "${ACR_LOGIN_SERVER}/web-apache:latest"

# ---- Build and Push Open Liberty Image ----
echo ""
echo "============================================"
echo "  Building Open Liberty App Layer Image"
echo "============================================"
echo ""
echo "NOTE: Make sure your application WAR file is at:"
echo "  ${PROJECT_DIR}/docker/openliberty/app.war"
echo ""

# Check if WAR file exists
if [ ! -f "${PROJECT_DIR}/docker/openliberty/app.war" ]; then
  echo "WARNING: app.war not found!"
  echo "Please copy your application WAR file to:"
  echo "  ${PROJECT_DIR}/docker/openliberty/app.war"
  echo ""
  read -p "Continue anyway? (y/n): " CONTINUE
  if [ "${CONTINUE}" != "y" ]; then
    echo "Exiting. Please add the WAR file and re-run."
    exit 1
  fi
fi

docker build \
  -t "${ACR_LOGIN_SERVER}/app-openliberty:${IMAGE_TAG}" \
  -t "${ACR_LOGIN_SERVER}/app-openliberty:latest" \
  -f "${PROJECT_DIR}/docker/openliberty/Dockerfile" \
  "${PROJECT_DIR}/docker/openliberty/"

echo "Pushing Open Liberty image..."
docker push "${ACR_LOGIN_SERVER}/app-openliberty:${IMAGE_TAG}"
docker push "${ACR_LOGIN_SERVER}/app-openliberty:latest"

echo ""
echo "============================================"
echo "  Images Pushed Successfully"
echo "============================================"
echo ""
echo "Verify images in ACR:"
echo "  az acr repository list --name ${ACR_NAME} --output table"
echo ""
echo "Next: Run 06-deploy-to-aks.sh to deploy to the Kubernetes cluster."
