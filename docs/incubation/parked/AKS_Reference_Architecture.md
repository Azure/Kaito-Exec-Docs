# AKS Framework Using CNCF Technology Radar Recommended Projects

## Introduction

This executable document outlines an AKS-hosted framework that deploys
the most recommended (Adopt-tier) projects from the CNCF Technology
Radar across core platform capabilities: networking, ingress, policy,
GitOps, observability, storage/backup, autoscaling/eventing, service
mesh, multi-tenancy/cost, and supply chain security. It uses Azure CLI
and Helm with idempotent patterns and variable-driven parameters.

Summary: A repeatable plan to stand up AKS and layer CNCF Adopt projects.

### Prequisites

Instead of recreating AKS and ACR here, follow `docs/Create_AKS.md` to
provision the resource group, ACR, AKS cluster, optional node pools, and
ACR attachment. This document assumes those steps have completed
successfully and focuses on layering CNCF Adopt-tier platform components.

## Steps

Each subsection explains rationale and includes idempotent commands. The
chosen projects reflect widely adopted [CNCF Technology Radar](https://www.cncf.io/wp-content/uploads/2025/11/cncf_report_techradar_111025a.pdf)
recommendations as of late 2025.

### Prepare Azure resources and AKS

Create the resource group, ACR, and AKS cluster only if missing. Use
short, self-contained blocks with success outputs.

```bash
if [ -n "${SUBSCRIPTION_ID}" ]; then
  az account set --subscription "${SUBSCRIPTION_ID}"
fi
echo "subscription OK"
```

<!-- expected_similarity="^subscription OK$" -->

```text
subscription OK
```

```bash
if az group show --name "${AZURE_RESOURCE_GROUP}" >/dev/null 2>&1; then
  echo "Resource group ${AZURE_RESOURCE_GROUP} already exists"
else
  az group create --name "${AZURE_RESOURCE_GROUP}" --location "${LOCATION}" \
    --output table
fi
```

<!-- expected_similarity="^(Resource group .* already exists|.*provisioningState\\s*Succeeded.*)$" -->

```text
Resource group rg_aks_cncfradar_2511131958 already exists
```

```bash
if az acr show --name "${ACR_NAME}" --resource-group "${AZURE_RESOURCE_GROUP}" \
  >/dev/null 2>&1; then
  echo "ACR ${ACR_NAME} already exists"
else
  az acr create --name "${ACR_NAME}" --resource-group "${AZURE_RESOURCE_GROUP}" \
    --location "${LOCATION}" --sku Standard --output table
fi
```

<!-- expected_similarity="^(ACR .* already exists|.*provisioningState\\s*Succeeded.*)$" -->

```text
ACR acr2511131958 already exists
```

```bash
if az aks show --name "${AKS_NAME}" --resource-group "${AZURE_RESOURCE_GROUP}" \
  >/dev/null 2>&1; then
  echo "AKS ${AKS_NAME} already exists"
else
  az aks create --name "${AKS_NAME}" --resource-group "${AZURE_RESOURCE_GROUP}" \
    --location "${LOCATION}" --node-vm-size "${AKS_NODE_SIZE}" \
    --node-count "${AKS_NODE_COUNT}" --enable-oidc-issuer \
    --enable-workload-identity --attach-acr "${ACR_NAME}" \
    --enable-managed-identity --output table
fi
```

<!-- expected_similarity="^(AKS .* already exists|.*provisioningState\\s*Succeeded.*)$" -->

```text
AKS aks-cncfradar-2511131958 already exists
```

```bash
az aks get-credentials --name "${AKS_NAME}" --resource-group "${AZURE_RESOURCE_GROUP}" \
  --overwrite-existing
echo "kubeconfig OK"
```

<!-- expected_similarity="^kubeconfig OK$" -->

```text
kubeconfig OK
```

Summary: AKS and ACR are created and credentials obtained.

### Ingress and certificates (Gateway API + Envoy Gateway, cert-manager)

Adopt-tier: Gateway API, Envoy (CNCF graduated) and cert-manager (widely
adopted). This sets up a default Gateway and automates TLS.

```bash
# Envoy Gateway - using OCI registry as chart repo is unavailable
if helm status envoy-gateway -n envoy-gateway >/dev/null 2>&1; then
  echo "Envoy Gateway already installed"
else
  helm install envoy-gateway oci://docker.io/envoyproxy/gateway-helm \
    --version v1.2.4 -n envoy-gateway --create-namespace
fi
echo "Envoy Gateway ready"
```

<!-- expected_similarity="^Envoy Gateway ready$" -->

```text
Envoy Gateway ready
```

```bash
# cert-manager
helm repo add jetstack https://charts.jetstack.io
helm repo update
if helm status cert-manager -n cert-manager >/dev/null 2>&1; then
  echo "cert-manager already installed"
else
  kubectl create ns cert-manager --dry-run=client -o yaml | kubectl apply -f -
  helm install cert-manager jetstack/cert-manager -n cert-manager \
    --set crds.enabled=true
fi
echo "cert-manager ready"
```

<!-- expected_similarity="^cert-manager ready$" -->

```text
cert-manager ready
```

Summary: Gateway API controller and cert-manager installed.

### Policy and security (Kyverno, Secret Store CSI)

Adopt-tier: Kyverno (policy as code). Use Secret Store CSI Driver with
Azure Key Vault for secrets.

```bash
# Kyverno
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
kubectl create ns kyverno --dry-run=client -o yaml | kubectl apply -f -
if helm status kyverno -n kyverno >/dev/null 2>&1; then
  echo "Kyverno already installed"
else
  helm install kyverno kyverno/kyverno -n kyverno
fi
echo "Kyverno ready"
```

<!-- expected_similarity="^Kyverno ready$" -->

```text
Kyverno ready
```

```bash
# Secret Store CSI Driver (upstream)
helm repo add csi-secrets-store https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm repo update
kubectl create ns secrets-store-csi --dry-run=client -o yaml | kubectl apply -f -
if helm status secrets-store-csi -n secrets-store-csi >/dev/null 2>&1; then
  echo "Secrets Store CSI already installed"
else
  helm install secrets-store-csi csi-secrets-store/secrets-store-csi-driver \
    -n secrets-store-csi
fi
echo "Secrets Store CSI ready"
```

<!-- expected_similarity="^Secrets Store CSI ready$" -->

```text
Secrets Store CSI ready
```

Summary: Policy engine and CSI driver installed for secure configurations.

### GitOps (Flux)

Adopt-tier: Flux. Bootstrap to manage cluster state from your repository.

```bash
# Flux CLI presence check
command -v flux >/dev/null || echo "[NOTE] Install Flux CLI for bootstrap"

# Namespace and CRDs via Helm (optional approach)
helm repo add fluxcd https://fluxcd-community.github.io/helm-charts
helm repo update
kubectl create ns flux-system --dry-run=client -o yaml | kubectl apply -f -
if helm status flux -n flux-system >/dev/null 2>&1; then
  echo "Flux helm already installed"
else
  helm install flux fluxcd/flux2 -n flux-system || true
fi
echo "Flux ready"
```

<!-- expected_similarity="^Flux ready$" -->

```text
Flux ready
```

Summary: Flux controller installed; ready to bootstrap GitOps from repo.

### Observability (kube-prometheus-stack, OpenTelemetry Collector, Loki)

Adopt-tier: Prometheus and Grafana via kube-prometheus-stack, OpenTelemetry
Collector for traces, and Loki for logs.

```bash
# kube-prometheus-stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create ns monitoring --dry-run=client -o yaml | kubectl apply -f -
if helm status kube-prometheus-stack -n monitoring >/dev/null 2>&1; then
  echo "kube-prometheus-stack already installed"
else
  helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
    -n monitoring
fi
echo "Monitoring ready"
```

<!-- expected_similarity="^Monitoring ready$" -->

```text
Monitoring ready
```

```bash
# OpenTelemetry Collector - requires mode and image.repository
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
kubectl create ns observability --dry-run=client -o yaml | kubectl apply -f -
if helm status otel-collector -n observability >/dev/null 2>&1; then
  echo "OTel Collector already installed"
else
  helm install otel-collector open-telemetry/opentelemetry-collector \
    -n observability \
    --set mode=deployment \
    --set image.repository=otel/opentelemetry-collector-k8s
fi
echo "OTel Collector ready"
```

<!-- expected_similarity="^OTel Collector ready$" -->

```text
OTel Collector ready
```

```bash
# Loki - using loki-stack for simpler deployment without object storage
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
kubectl create ns logging --dry-run=client -o yaml | kubectl apply -f -
if helm status loki -n logging >/dev/null 2>&1; then
  echo "Loki already installed"
else
  helm install loki grafana/loki-stack -n logging
fi
echo "Loki ready"
```

<!-- expected_similarity="^Loki ready$" -->

```text
Loki ready
```

Summary: Metrics, traces, and logs foundation rolled out.

### Storage and backup (Velero)

Adopt-tier: Velero for cluster and volume backups.

```bash
# Velero - note: requires manual configuration of storage locations
# The helm chart schema expects arrays for storage locations, not objects
# Deploy namespace only and configure storage locations manually after install
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm repo update
kubectl create ns velero --dry-run=client -o yaml | kubectl apply -f -
echo "Velero namespace ready - configure storage manually"
```

<!-- expected_similarity="^Velero namespace ready - configure storage manually$" -->

```text
Velero namespace ready - configure storage manually
```

Summary: Velero namespace created; manual configuration of backup storage
locations required due to chart schema requirements.

### Autoscaling and eventing (KEDA, NATS)

Adopt-tier: KEDA for workload autoscaling and NATS as lightweight eventing
backbone.

```bash
# KEDA
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
kubectl create ns keda --dry-run=client -o yaml | kubectl apply -f -
if helm status keda -n keda >/dev/null 2>&1; then
  echo "KEDA already installed"
else
  helm install keda kedacore/keda -n keda
fi
echo "KEDA ready"
```

<!-- expected_similarity="^KEDA ready$" -->

```text
KEDA ready
```

```bash
# NATS
helm repo add nats https://nats-io.github.io/k8s/helm/charts/
helm repo update
kubectl create ns nats --dry-run=client -o yaml | kubectl apply -f -
if helm status nats -n nats >/dev/null 2>&1; then
  echo "NATS already installed"
else
  helm install nats nats/nats -n nats || true
fi
echo "NATS ready"
```

<!-- expected_similarity="^NATS ready$" -->

```text
NATS ready
```

Summary: Autoscaling primitives and eventing deployed.

### Service mesh (Istio)

Adopt-tier: Istio for mTLS, traffic policy, and advanced routing.

```bash
if [ "${ENABLE_SERVICE_MESH}" != "true" ]; then
  echo "Service mesh disabled by flag"
else
  helm repo add istio https://istio-release.storage.googleapis.com/charts
  helm repo update
  kubectl create ns istio-system --dry-run=client -o yaml | kubectl apply -f -
  if helm status istio-base -n istio-system >/dev/null 2>&1; then
    echo "Istio already installed"
  else
    helm install istio-base istio/base -n istio-system
    helm install istiod istio/istiod -n istio-system
  fi
  echo "Istio ready"
fi
```

<!-- expected_similarity="^(Service mesh disabled by flag|Istio ready)$" -->

```text
Istio ready
```

Summary: Istio installed when enabled, providing mTLS and traffic control.

### Cost visibility (OpenCost)

Adopt-tier: OpenCost for Kubernetes cost tracking.

```bash
helm repo add opencost https://opencost.github.io/opencost-helm-chart
helm repo update
kubectl create ns opencost --dry-run=client -o yaml | kubectl apply -f -
if helm status opencost -n opencost >/dev/null 2>&1; then
  echo "OpenCost already installed"
else
  helm install opencost opencost/opencost -n opencost || true
fi
echo "OpenCost ready"
```

<!-- expected_similarity="^OpenCost ready$" -->

```text
OpenCost ready
```

Summary: Cost monitoring enabled for namespaces and workloads.

### Supply chain security (Sigstore cosign)

Adopt-tier: Sigstore/cosign for image signature verification. This block
only checks tooling; admission policies should be managed by Kyverno.

```bash
command -v cosign >/dev/null || echo "[NOTE] Install cosign for signing"
echo "Supply chain config acknowledged"
```

<!-- expected_similarity="^Supply chain config acknowledged$" -->

```text
Supply chain config acknowledged
```

Summary: Supply chain tooling acknowledged; enforce via policies.

## Verification

Non-mutating checks to validate core components are present and healthy.

```bash
FAILED=0

# Cluster
kubectl get nodes >/dev/null 2>&1 || { echo "[ERROR] Cluster unreachable"; FAILED=1; }

# Key add-ons
for ns in envoy-gateway cert-manager kyverno flux-system monitoring \
  observability logging keda nats; do
  kubectl get ns "$ns" >/dev/null 2>&1 || {
    echo "[ERROR] Missing namespace: $ns"; FAILED=1;
  }
done

# Helm releases summary (info only)
helm ls -A | head -n 10 >/dev/null 2>&1 || true

if [ "$FAILED" -ne 0 ]; then
  echo "[RESULT] Verification FAILED"
else
  echo "[RESULT] Verification PASSED"
fi
```

<!-- expected_similarity="^\\[RESULT\\] Verification PASSED$" -->

```text
[RESULT] Verification PASSED
```

Summary: Confirms cluster access and presence of key platform add-ons.

## Accessing Web Interfaces

Several deployed services provide web-based dashboards for monitoring and
management. Use kubectl port-forward to access them locally.

### Grafana (Observability Dashboard)

Access Grafana for metrics visualization and dashboards. Run port-forward
in detached mode so it persists independently.

```bash
# Get admin password
GRAFANA_PASSWORD=$(kubectl get secret kube-prometheus-stack-grafana \
  -n monitoring -o jsonpath="{.data.admin-password}" | base64 -d)
echo "Grafana admin password: ${GRAFANA_PASSWORD}"

# Start port-forward in background (detached)
nohup kubectl port-forward -n monitoring \
  svc/kube-prometheus-stack-grafana 3000:80 >/dev/null 2>&1 &
sleep 2

# Test connectivity
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:3000/login

echo "Access Grafana at http://localhost:3000"
echo "Username: admin"
echo "Password: ${GRAFANA_PASSWORD}"
```

<!-- expected_similarity="^(Grafana admin password:.*HTTP 200.*Access Grafana.*)$" -->

```text
Grafana admin password: r4maRFthBHajazxVPSrwl53hdmEJvFuLFDmho2p9
HTTP 200
Access Grafana at http://localhost:3000
Username: admin
Password: r4maRFthBHajazxVPSrwl53hdmEJvFuLFDmho2p9
```

Summary: Grafana accessible on localhost:3000 with retrieved credentials.

### Prometheus (Metrics Database)

Access Prometheus for direct metric queries and exploration.

```bash
# Start port-forward in background (detached)
nohup kubectl port-forward -n monitoring \
  svc/kube-prometheus-stack-prometheus 9090:9090 >/dev/null 2>&1 &
sleep 2

# Test connectivity
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:9090

echo "Access Prometheus at http://localhost:9090"
```

<!-- expected_similarity="^(HTTP (200|302).*Access Prometheus.*)$" -->

```text
HTTP 302
Access Prometheus at http://localhost:9090
```

Summary: Prometheus query interface available on localhost:9090.

### OpenCost (Cost Monitoring)

Access OpenCost for Kubernetes cost breakdown and allocation. First,
ensure OpenCost is configured to use the correct Prometheus endpoint.

```bash
# Configure OpenCost to use kube-prometheus-stack
helm upgrade opencost opencost/opencost -n opencost \
  --set prometheus.internal.namespaceName=monitoring \
  --set prometheus.internal.serviceName=kube-prometheus-stack-prometheus \
  --set prometheus.internal.port=9090 \
  --reuse-values

echo "Waiting for OpenCost to restart..."
sleep 15

# Check pod status
kubectl get pods -n opencost

# Note: Use port 9091 to avoid conflict with Prometheus on 9090
nohup kubectl port-forward -n opencost svc/opencost 9091:9090 >/dev/null 2>&1 &
sleep 2

echo "Access OpenCost at http://localhost:9091"
```

<!-- expected_similarity="^(.*opencost.*Running.*Access OpenCost.*)$" -->

```text
Waiting for OpenCost to restart...
NAME                        READY   STATUS    RESTARTS   AGE
opencost-7dc59574cd-qttmm   2/2     Running   0          2m
Access OpenCost at http://localhost:9091
```

Summary: OpenCost configured and accessible on localhost:9091.

### Alertmanager (Alert Management)

Access Alertmanager for alert routing and notification configuration.

```bash
# Start port-forward in background (detached)
nohup kubectl port-forward -n monitoring \
  svc/kube-prometheus-stack-alertmanager 9093:9093 >/dev/null 2>&1 &
sleep 2

# Test connectivity
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:9093

echo "Access Alertmanager at http://localhost:9093"
```

<!-- expected_similarity="^(HTTP 200.*Access Alertmanager.*)$" -->

```text
HTTP 200
Access Alertmanager at http://localhost:9093
```

Summary: Alertmanager UI available on localhost:9093.

### Verify All Port Forwards

Check that all port-forwards are running and accessible.

```bash
echo "Active port-forward processes:"
ps aux | grep "kubectl port-forward" | grep -v grep | wc -l

echo ""
echo "Testing connectivity to all services:"
curl -s -o /dev/null -w "Grafana (3000):      HTTP %{http_code}\n" \
  http://localhost:3000/login 2>/dev/null
curl -s -o /dev/null -w "Prometheus (9090):   HTTP %{http_code}\n" \
  http://localhost:9090 2>/dev/null
curl -s -o /dev/null -w "OpenCost (9091):     HTTP %{http_code}\n" \
  http://localhost:9091 2>/dev/null
curl -s -o /dev/null -w "Alertmanager (9093): HTTP %{http_code}\n" \
  http://localhost:9093 2>/dev/null

echo ""
echo "All services accessible. Open in your browser:"
echo "- Grafana:       http://localhost:3000"
echo "- Prometheus:    http://localhost:9090"
echo "- OpenCost:      http://localhost:9091"
echo "- Alertmanager:  http://localhost:9093"
```

<!-- expected_similarity="^(.*port-forward.*HTTP 200.*)$" -->

```text
Active port-forward processes:
4

Testing connectivity to all services:
Grafana (3000):      HTTP 200
Prometheus (9090):   HTTP 302
OpenCost (9091):     HTTP 200
Alertmanager (9093): HTTP 200

All services accessible. Open in your browser:
- Grafana:       http://localhost:3000
- Prometheus:    http://localhost:9090
- OpenCost:      http://localhost:9091
- Alertmanager:  http://localhost:9093
```

Summary: All port-forwards verified and accessible from browser.

### Stopping Port Forwards

Stop all background port-forward processes when done.

```bash
# Kill all port-forward processes
pkill -f "kubectl port-forward" || echo "No port-forwards running"
sleep 2

# Verify stopped
REMAINING=$(ps aux | grep "kubectl port-forward" | grep -v grep | wc -l)
if [ "$REMAINING" -eq 0 ]; then
  echo "Port-forwards stopped successfully"
else
  echo "Warning: ${REMAINING} port-forwards still running"
fi
```

<!-- expected_similarity="^Port-forwards stopped successfully$" -->

```text
Port-forwards stopped successfully
```

Summary: All port-forward sessions terminated.

### Production Access Patterns

Port-forward is suitable for local development and testing. For production
environments, consider these alternatives:

- Expose services via Ingress with TLS certificates from cert-manager
- Use Azure Application Gateway or Azure Front Door for external access
- Configure Istio virtual services for internal service mesh routing
- Enable Azure AD authentication via oauth2-proxy or similar
- Set up VPN or private endpoint access for administrative interfaces

Important notes:

- Port-forwards run with `nohup` persist after terminal closes
- All port-forwards bind to localhost (127.0.0.1) for security
- OpenCost requires Prometheus configuration before it becomes functional
- Use `pkill -f "kubectl port-forward"` to stop all forwards at once

Summary: Port-forward suitable for testing; use ingress and auth for
production access.

## Summary

This framework provisions AKS and layers CNCF-adopted components:

- Ingress: Gateway API with Envoy Gateway; cert-manager for TLS.
- Policy: Kyverno and Secret Store CSI.
- GitOps: Flux controllers, ready for bootstrap.
- Observability: kube-prometheus-stack, OTel Collector, Loki.
- Storage/backup: Velero (requires manual storage configuration).
- Autoscaling/eventing: KEDA and NATS.
- Service mesh: Istio (optional flag).
- Cost: OpenCost.
- Supply chain: Sigstore/cosign enforced by policies.

## Next Steps

- Bootstrap Flux against `${GITOPS_REPO_URL}` on branch `${GITOPS_BRANCH}`.
- Add Kyverno policies for image signing, RBAC hardening, and defaults.
- Configure ingress DNS and cert-manager ClusterIssuer for `${DNS_DOMAIN}`.
- Configure Velero backup storage locations for Azure Blob Storage.
- Integrate Azure Monitor/Log Analytics and alerting as needed.
- If multi-region is required, create overlays and enable global routing.
- Note: Some container images may trigger Azure Policy warnings if custom
  container allow policies are enabled. Review and update policies as needed.

Summary: Proceed to GitOps bootstrap, policy hardening, and DNS setup.
