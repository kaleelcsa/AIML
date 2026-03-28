# Azure VM to AKS Migration - 3-Tier Application

Containerization and migration of a 3-tier application from Azure VMs to Azure Kubernetes Service (AKS).

## Architecture

### Current (Azure VMs)
```
[Client] → [VM: Apache2 (Web)] → [VM: Open Liberty (App)] → [VM: PostgreSQL (DB)]
```

### Target (AKS + Managed Services)
```
[Client] → [Ingress Controller] → [Pod: Apache2 (Web)] → [Pod: Open Liberty (App)] → [Azure Database for PostgreSQL]
                                         ↑                        ↑
                                    ClusterIP Svc            ClusterIP Svc
                                    HPA (2-10)               HPA (2-8)
```

## Project Structure

```
azure-k8s-migration/
├── docker/
│   ├── apache2/
│   │   ├── Dockerfile            # Apache2 reverse proxy image
│   │   ├── httpd-custom.conf     # Custom Apache configuration
│   │   └── vhost.conf            # Virtual host with reverse proxy
│   └── openliberty/
│       ├── Dockerfile            # Open Liberty application image
│       ├── server.xml            # Liberty server configuration
│       ├── bootstrap.properties  # Bootstrap properties
│       └── jvm.options           # JVM tuning for containers
├── kubernetes/
│   ├── namespace.yaml            # app-migration namespace
│   ├── configmap-apache.yaml     # Apache configuration
│   ├── configmap-openliberty.yaml # Open Liberty + DB config
│   ├── secret-db.yaml            # Database credentials
│   ├── deployment-apache.yaml    # Apache deployment (2 replicas)
│   ├── deployment-openliberty.yaml # Open Liberty deployment (2 replicas)
│   ├── service-apache.yaml       # Apache ClusterIP service
│   ├── service-openliberty.yaml  # Open Liberty ClusterIP service
│   ├── ingress.yaml              # NGINX Ingress for external access
│   ├── hpa-apache.yaml           # Auto-scaling for web layer
│   ├── hpa-openliberty.yaml      # Auto-scaling for app layer
│   └── networkpolicy.yaml        # Network isolation between tiers
├── scripts/
│   ├── 01-setup-resource-group.sh # Create Azure resource group
│   ├── 02-setup-acr.sh           # Create container registry
│   ├── 03-setup-aks.sh           # Create AKS cluster
│   ├── 04-setup-postgres.sh      # Create managed PostgreSQL
│   ├── 05-build-push-images.sh   # Build & push Docker images
│   ├── 06-deploy-to-aks.sh       # Deploy to AKS
│   └── 07-migrate-data.sh        # Migrate PostgreSQL data
└── README.md
```

## Prerequisites

- **Azure CLI** (`az`) installed and logged in
- **Docker** installed locally (for building images)
- **kubectl** installed
- **Azure Subscription** with sufficient permissions
- **Application WAR file** from your Open Liberty deployment

## Migration Steps

### Phase 1: Azure Infrastructure Setup

Run the scripts in order. Edit the configuration variables at the top of each script before running.

```bash
# Make scripts executable
chmod +x scripts/*.sh

# 1. Create resource group
./scripts/01-setup-resource-group.sh

# 2. Create Azure Container Registry
./scripts/02-setup-acr.sh

# 3. Create AKS cluster (takes ~5-10 minutes)
./scripts/03-setup-aks.sh

# 4. Create Azure Database for PostgreSQL
./scripts/04-setup-postgres.sh
```

### Phase 2: Data Migration

```bash
# 5. Migrate data from VM PostgreSQL to Azure PostgreSQL
./scripts/07-migrate-data.sh
```

**Verify the migration:**
```bash
psql "host=<your-server>.postgres.database.azure.com port=5432 \
  dbname=appdb user=pgadmin sslmode=require" -c '\dt'
```

### Phase 3: Containerize & Deploy

#### Prepare Application Artifacts

1. **Copy your WAR file** from the Open Liberty VM:
   ```bash
   # From the source VM, copy the deployed WAR/EAR
   scp user@openliberty-vm:/opt/ol/wlp/usr/servers/defaultServer/apps/app.war \
       ./docker/openliberty/app.war
   ```

2. **Copy static content** (if Apache serves static files):
   ```bash
   # From the source VM
   scp -r user@apache-vm:/var/www/html/* ./docker/apache2/static/
   ```
   Then uncomment the `COPY ./static/` line in `docker/apache2/Dockerfile`.

3. **Update configuration**:
   - Edit `kubernetes/configmap-openliberty.yaml` → set `DB_HOST` to your Azure PostgreSQL hostname
   - Edit `kubernetes/secret-db.yaml` → set base64-encoded DB credentials
   - Edit `kubernetes/ingress.yaml` → set your domain name
   - Edit `docker/openliberty/server.xml` → adjust features/datasource if needed

#### Build, Push, and Deploy

```bash
# 5. Build Docker images and push to ACR
./scripts/05-build-push-images.sh

# 6. Deploy everything to AKS
./scripts/06-deploy-to-aks.sh
```

### Phase 4: Verification

```bash
# Check pod status
kubectl get pods -n app-migration

# Check services
kubectl get svc -n app-migration

# Check ingress (get external IP)
kubectl get ingress -n app-migration

# View logs
kubectl logs -f deployment/apache-deployment -n app-migration
kubectl logs -f deployment/openliberty-deployment -n app-migration

# Test health endpoints
kubectl exec -it deployment/openliberty-deployment -n app-migration -- \
  curl http://localhost:9080/health
```

## Customization Guide

### Scaling Configuration

Edit `kubernetes/hpa-*.yaml` to adjust:
- `minReplicas` / `maxReplicas` — pod count range
- `averageUtilization` — CPU/memory thresholds for scaling

### Resource Limits

Edit `kubernetes/deployment-*.yaml` to adjust:
- `resources.requests` — minimum guaranteed resources
- `resources.limits` — maximum allowed resources

**Recommended starting points:**

| Layer | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-------|------------|-----------|----------------|--------------|
| Apache2 | 100m | 500m | 128Mi | 256Mi |
| Open Liberty | 500m | 2000m | 512Mi | 1Gi |

### TLS/SSL Setup

1. Install cert-manager:
   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml
   ```

2. Create a ClusterIssuer for Let's Encrypt:
   ```yaml
   apiVersion: cert-manager.io/v1
   kind: ClusterIssuer
   metadata:
     name: letsencrypt-prod
   spec:
     acme:
       server: https://acme-v02.api.letsencrypt.org/directory
       email: your-email@example.com
       privateKeySecretRef:
         name: letsencrypt-prod
       solvers:
         - http01:
             ingress:
               class: nginx
   ```

3. Uncomment the TLS section in `kubernetes/ingress.yaml`.

### Azure Key Vault Integration (Recommended for Production)

Instead of storing secrets in Kubernetes Secret YAML files, use Azure Key Vault:

```bash
# Install CSI driver
az aks enable-addons \
  --addons azure-keyvault-secrets-provider \
  --resource-group rg-app-migration \
  --name aks-app-migration

# Create Key Vault
az keyvault create \
  --resource-group rg-app-migration \
  --name kv-app-migration \
  --location eastus

# Store secrets
az keyvault secret set --vault-name kv-app-migration --name db-user --value "pgadmin"
az keyvault secret set --vault-name kv-app-migration --name db-password --value "your-password"
```

Then create a `SecretProviderClass` to sync secrets into K8s.

## Troubleshooting

### Pods not starting
```bash
kubectl describe pod <pod-name> -n app-migration
kubectl logs <pod-name> -n app-migration --previous
```

### Database connection issues
```bash
# Test connectivity from a pod
kubectl exec -it deployment/openliberty-deployment -n app-migration -- \
  bash -c 'curl -v telnet://${DB_HOST}:${DB_PORT}'
```

### Apache not proxying
```bash
# Check Apache error logs
kubectl logs deployment/apache-deployment -n app-migration

# Verify backend connectivity
kubectl exec -it deployment/apache-deployment -n app-migration -- \
  curl http://openliberty-service:9080/health
```

### Image pull errors
```bash
# Verify ACR attachment
az aks check-acr --resource-group rg-app-migration \
  --name aks-app-migration \
  --acr acrappmigration.azurecr.io
```

## Rollback

To roll back a deployment:
```bash
# Check rollout history
kubectl rollout history deployment/openliberty-deployment -n app-migration

# Rollback to previous version
kubectl rollout undo deployment/openliberty-deployment -n app-migration

# Rollback to specific revision
kubectl rollout undo deployment/openliberty-deployment -n app-migration --to-revision=2
```
