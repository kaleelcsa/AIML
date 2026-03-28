# Azure VMs vs AKS: Cost Comparison & Pros/Cons Analysis

## Context: Your 3-Tier Application

| Tier | Component | Role |
|------|-----------|------|
| Web | Apache2 | Reverse proxy, static content |
| App | Open Liberty (Java 17) | Business logic, REST APIs |
| Database | PostgreSQL 16 | Data persistence |

---

## 1. Cost Comparison: Azure VMs vs AKS

### Scenario A: Azure VMs (Current Architecture)

Running 3 dedicated VMs (one per tier) in East US, 24/7.

| Resource | SKU | Monthly Cost (Est.) |
|----------|-----|---------------------|
| VM - Apache2 (Web) | Standard_DS2_v2 (2 vCPU, 7 GiB) | ~$137/mo |
| VM - Open Liberty (App) | Standard_DS2_v2 (2 vCPU, 7 GiB) | ~$137/mo |
| VM - PostgreSQL (DB) | Standard_DS2_v2 (2 vCPU, 7 GiB) | ~$137/mo |
| OS Disks (3 x 128 GB Premium SSD) | P10 | ~$58/mo ($19.33 each) |
| Public IP Addresses (3) | Static | ~$11/mo ($3.65 each) |
| VM Backup (3 VMs) | Standard | ~$30/mo |
| **Subtotal: Compute & Storage** | | **~$510/mo** |

**For high availability (2 VMs per tier):**

| Resource | SKU | Monthly Cost (Est.) |
|----------|-----|---------------------|
| 2x Apache2 VMs | Standard_DS2_v2 | ~$274/mo |
| 2x Open Liberty VMs | Standard_DS2_v2 | ~$274/mo |
| 1x PostgreSQL VM | Standard_DS2_v2 | ~$137/mo |
| OS Disks (5 x 128 GB) | P10 | ~$97/mo |
| Load Balancer | Standard | ~$25/mo |
| Public IPs | Static | ~$18/mo |
| VM Backup | Standard | ~$50/mo |
| **Subtotal: HA Setup** | | **~$875/mo** |

**Additional hidden costs (VMs):**
- OS patching & maintenance: ~4-8 hrs/month of admin time
- PostgreSQL administration: ~4-6 hrs/month
- Manual scaling during traffic spikes: reactive, not automatic
- Downtime during maintenance windows

---

### Scenario B: AKS (Target Architecture)

Running AKS cluster with managed PostgreSQL, as configured in your repo.

| Resource | SKU | Monthly Cost (Est.) |
|----------|-----|---------------------|
| AKS Node Pool (3 nodes) | Standard_DS2_v2 (2 vCPU, 7 GiB each) | ~$411/mo |
| AKS Management (Control Plane) | Free tier | $0/mo |
| Azure Container Registry | Standard | ~$5/mo |
| Azure Database for PostgreSQL | Standard_D2ds_v4 (2 vCPU, 8 GiB) | ~$125/mo |
| PostgreSQL Storage (128 GB) | Premium SSD | ~$15/mo |
| PostgreSQL Backup | Included (7-day retention) | $0/mo |
| Load Balancer (Ingress) | Standard | ~$25/mo |
| Public IP (1 for Ingress) | Static | ~$3.65/mo |
| Azure Monitor (AKS add-on) | Basic | ~$10/mo |
| **Subtotal: AKS Setup** | | **~$595/mo** |

**With Reserved Instances (1-year commitment):**

| Resource | On-Demand | 1-Year RI | Savings |
|----------|-----------|-----------|---------|
| AKS Nodes (3x DS2_v2) | ~$411/mo | ~$260/mo | 37% |
| PostgreSQL (D2ds_v4) | ~$125/mo | ~$80/mo | 36% |
| **Total with RI** | ~$595/mo | **~$404/mo** | **~32%** |

---

### Side-by-Side Monthly Cost Summary

| Configuration | VMs (Basic) | VMs (HA) | AKS (On-Demand) | AKS (1-Yr RI) |
|---------------|-------------|----------|------------------|----------------|
| Compute | $411 | $685 | $411 | $260 |
| Database | $137 + disk | $137 + disk | $140 | $95 |
| Networking | $11 | $43 | $29 | $29 |
| Storage/Registry | $58 | $97 | $20 | $20 |
| Monitoring/Backup | $30 | $50 | $10 | $10 |
| **Total** | **~$510/mo** | **~$875/mo** | **~$595/mo** | **~$404/mo** |
| **Annual** | **~$6,120** | **~$10,500** | **~$7,140** | **~$4,848** |

> **Key Insight:** AKS on-demand costs slightly more than basic VMs ($595 vs $510), but delivers HA capabilities that would cost $875/mo with VMs. With reserved instances, AKS is **$106/mo cheaper** than even the basic VM setup while providing far more features.

---

## 2. Total Cost of Ownership (TCO) — Beyond Compute

| Cost Factor | Azure VMs | AKS |
|-------------|-----------|-----|
| **Infrastructure Admin** | 8-16 hrs/mo ($1,600-$3,200) | 2-4 hrs/mo ($400-$800) |
| **OS Patching** | Manual, per VM, scheduled downtime | AKS manages node OS updates |
| **DB Administration** | Self-managed: backups, tuning, HA | Managed: automated backups, HA, scaling |
| **Scaling** | Manual VM provisioning (15-30 min) | Automatic HPA (seconds) |
| **Deployment** | SSH + manual or basic CI/CD | kubectl apply, rolling updates |
| **Downtime Cost** | Higher risk (manual failover) | Lower risk (self-healing, auto-restart) |
| **Security Patching** | Manual across all VMs | Automated node image upgrades |
| **Estimated Admin Cost** | ~$2,400/mo | ~$600/mo |

### Total Monthly TCO

| | VMs (Basic) | VMs (HA) | AKS (On-Demand) | AKS (1-Yr RI) |
|---|---|---|---|---|
| Infrastructure | $510 | $875 | $595 | $404 |
| Admin/Operations | $2,400 | $3,200 | $600 | $600 |
| **Total TCO** | **$2,910** | **$4,075** | **$1,195** | **$1,004** |
| **Annual TCO** | **$34,920** | **$48,900** | **$14,340** | **$12,048** |

> **Bottom Line:** AKS with reserved instances saves **~$23,000/year** compared to basic VMs and **~$37,000/year** compared to HA VMs when factoring in operational costs.

---

## 3. Pros & Cons: Azure VMs

### Pros

| # | Advantage | Details |
|---|-----------|---------|
| 1 | **Simplicity** | Familiar VM model; no Kubernetes learning curve |
| 2 | **Full OS Control** | Root access, custom kernel modules, any software |
| 3 | **Predictable Performance** | Dedicated resources, no noisy neighbor on same node |
| 4 | **Legacy Compatibility** | Run any workload, including those not suited for containers |
| 5 | **Easier Debugging** | SSH directly into the machine, inspect processes |
| 6 | **No Container Overhead** | No Docker/K8s abstraction layers |
| 7 | **Simpler Networking** | Standard VNet, NSG rules — no K8s networking concepts |
| 8 | **Compliance** | Some regulations require dedicated VMs |

### Cons

| # | Disadvantage | Details |
|---|-------------|---------|
| 1 | **Manual Scaling** | Must provision new VMs (15-30 min), configure load balancer |
| 2 | **No Self-Healing** | VM crashes require manual restart or Azure Automation |
| 3 | **High Admin Overhead** | OS patching, security updates, package management per VM |
| 4 | **Downtime for Maintenance** | Planned maintenance windows for OS/app updates |
| 5 | **Resource Waste** | Full VM allocated even at low utilization; no bin-packing |
| 6 | **DB Management Burden** | Self-managed PostgreSQL: backups, replication, tuning, failover |
| 7 | **Slow Deployments** | SSH-based or agent-based deploys; no native rolling updates |
| 8 | **Limited Portability** | VM images are Azure-specific; harder to move to other clouds |
| 9 | **Cost at Scale** | Linear cost increase — each new instance = full VM cost |
| 10 | **HA Is Expensive** | Need 2x VMs + Load Balancer per tier for redundancy |

---

## 4. Pros & Cons: AKS

### Pros

| # | Advantage | Details |
|---|-----------|---------|
| 1 | **Auto-Scaling** | HPA scales pods in seconds (2-10 for web, 2-8 for app) |
| 2 | **Self-Healing** | K8s restarts crashed containers, replaces unhealthy pods |
| 3 | **Zero-Downtime Deploys** | Rolling updates with `maxSurge: 1, maxUnavailable: 0` |
| 4 | **Instant Rollback** | `kubectl rollout undo` reverts to previous version |
| 5 | **Managed Database** | Azure PostgreSQL: automated backups, patching, HA built-in |
| 6 | **Resource Efficiency** | Multiple pods share nodes (bin-packing); scale down at night |
| 7 | **Low Admin Overhead** | AKS manages control plane, node OS updates, monitoring |
| 8 | **Security Built-In** | Network Policies, non-root containers, Secrets, Key Vault integration |
| 9 | **Declarative Config** | All infrastructure as YAML; version-controlled, reproducible |
| 10 | **Cloud Portability** | Containers run on any K8s cluster (AWS EKS, GCP GKE, on-prem) |
| 11 | **Health Monitoring** | Liveness, readiness, startup probes — automatic traffic management |
| 12 | **Cost with RI** | 32-37% savings with 1-year reserved instances |

### Cons

| # | Disadvantage | Details |
|---|-------------|---------|
| 1 | **Learning Curve** | Kubernetes concepts: pods, services, ingress, HPA, network policies |
| 2 | **Complexity** | More moving parts: container runtime, CNI, ingress controller, etc. |
| 3 | **Debugging Difficulty** | Multi-layer debugging: container → pod → node → cluster |
| 4 | **Initial Migration Effort** | Containerizing apps, writing Dockerfiles, K8s manifests (one-time) |
| 5 | **Container Limitations** | Some workloads (stateful, kernel-dependent) are harder to containerize |
| 6 | **Networking Complexity** | K8s networking (CNI, Services, Ingress, NetworkPolicy) adds complexity |
| 7 | **Resource Overhead** | K8s system pods consume ~10-15% of node resources |
| 8 | **Shared Node Risk** | Multiple pods on same node; a noisy neighbor can affect others |
| 9 | **Persistent Storage** | Stateful workloads need PVCs, storage classes — more config |
| 10 | **Cluster Maintenance** | K8s version upgrades needed every ~12 months |

---

## 5. Feature-by-Feature Comparison

| Feature | Azure VMs | AKS | Winner |
|---------|-----------|-----|--------|
| **Scaling Speed** | 15-30 minutes (new VM) | 10-30 seconds (new pod) | AKS |
| **Auto-Scaling** | Azure VM Scale Sets (limited) | HPA + Cluster Autoscaler | AKS |
| **Self-Healing** | Azure Automation (manual setup) | Built-in (automatic) | AKS |
| **Deployments** | Manual / SSH / CI-CD agent | Rolling update (native) | AKS |
| **Rollback** | VM snapshot restore (slow) | `kubectl rollout undo` (instant) | AKS |
| **Health Checks** | Custom scripts needed | Liveness/Readiness probes (native) | AKS |
| **Load Balancing** | Azure LB (separate config) | Ingress Controller (native) | AKS |
| **Network Security** | NSG rules per VM | Network Policies (pod-level) | AKS |
| **Secrets Management** | Azure Key Vault + VM agent | K8s Secrets + Key Vault CSI | Tie |
| **Monitoring** | Azure Monitor agent per VM | Azure Monitor add-on (built-in) | AKS |
| **Resource Utilization** | ~30-50% average | ~60-80% with bin-packing | AKS |
| **Learning Curve** | Low (familiar model) | High (K8s concepts) | VMs |
| **Debugging** | SSH + standard tools | kubectl + container logs | VMs |
| **OS Customization** | Full control | Limited (node image) | VMs |
| **Compliance (strict)** | Dedicated VMs, full audit | Shared nodes (can use dedicated) | VMs |
| **Legacy App Support** | Any workload | Must be containerizable | VMs |
| **Portability** | Azure-specific | Any K8s cluster | AKS |
| **Initial Setup** | Quick (provision VMs) | Medium (cluster + manifests) | VMs |
| **Ongoing Operations** | High effort | Low effort | AKS |
| **Cost (HA setup)** | $875+/mo | $595/mo (on-demand) | AKS |
| **TCO (with admin)** | $2,910+/mo | $1,195/mo | AKS |

---

## 6. Cost Optimization Tips for AKS

| Strategy | Savings | How |
|----------|---------|-----|
| **Reserved Instances (1-year)** | 32-37% | Commit to 1-year for AKS nodes and PostgreSQL |
| **Reserved Instances (3-year)** | 50-55% | Commit to 3-year for maximum savings |
| **Spot Instances** | Up to 90% | Use for non-critical, fault-tolerant workloads |
| **Scale Down at Night** | 20-30% | Reduce min replicas during off-hours with KEDA or CronJobs |
| **Right-Size Nodes** | 10-20% | Monitor actual usage and adjust node SKU |
| **Cluster Autoscaler** | Variable | Add/remove nodes based on pending pod demand |
| **Pod Resource Tuning** | 10-15% | Optimize requests/limits to improve bin-packing |
| **Dev/Test Pricing** | Up to 55% | Use Azure Dev/Test subscription for non-prod |

---

## 7. Migration Cost (One-Time)

| Activity | Estimated Effort | Cost (at $200/hr) |
|----------|-----------------|-----|
| Infrastructure scripts (already in repo) | 8-16 hrs | $1,600-$3,200 |
| Containerization (Dockerfiles done) | 4-8 hrs | $800-$1,600 |
| K8s manifests (already in repo) | 8-16 hrs | $1,600-$3,200 |
| Data migration & testing | 4-8 hrs | $800-$1,600 |
| Integration testing & validation | 8-16 hrs | $1,600-$3,200 |
| Team training on Kubernetes | 16-24 hrs | $3,200-$4,800 |
| **Total One-Time Migration** | **48-88 hrs** | **$9,600-$17,600** |

> **Payback Period:** With ~$1,700/mo TCO savings (vs VM HA), the migration pays for itself in **6-10 months**.

---

## 8. Recommendation

| Criteria | Recommendation |
|----------|----------------|
| **Short-term (< 6 months)** | Stay on VMs if team lacks K8s experience |
| **Medium-term (6-18 months)** | Migrate to AKS with on-demand pricing |
| **Long-term (18+ months)** | AKS with Reserved Instances for maximum savings |
| **High-traffic / variable load** | AKS — auto-scaling is critical |
| **Strict compliance / legacy apps** | VMs — full control required |
| **Cost-sensitive** | AKS with RI — lowest TCO by far |
| **Small team / limited K8s skills** | Start with AKS + managed add-ons, invest in training |

**For your 3-tier application:** AKS is the clear winner for production workloads that need scalability, reliability, and lower operational overhead. The migration scripts and K8s manifests in your repo are already production-ready, making the transition straightforward.
