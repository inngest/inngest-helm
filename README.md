# Inngest Self-Hosted Helm Chart

A Helm chart for deploying Inngest on Kubernetes clusters.

## Prerequisites

- Kubernetes 1.20+
- Helm 3.0+
- Persistent Volume support for PostgreSQL and Redis
- LoadBalancer or Ingress controller for external access (optional)
- Storage class supporting ReadWriteOnce volumes
- KEDA operator (optional, for autoscaling)

## Installation

### From OCI Registry (Recommended)

```bash
# Install latest version
helm install inngest oci://ghcr.io/inngest/inngest-helm/inngest \
  --set inngest.signingKey="your-signing-key" \
  --set inngest.eventKey="your-event-key" \
  --create-namespace

# Install specific version
helm install inngest oci://ghcr.io/inngest/inngest-helm/inngest --version 0.2.0 \
  --set inngest.signingKey="your-signing-key" \
  --set inngest.eventKey="your-event-key" \
  --create-namespace

# Install with custom values file
helm install inngest oci://ghcr.io/inngest/inngest-helm/inngest -f my-values.yaml --create-namespace
```

> [!TIP]
> Review the [self-hosting documentation](https://www.inngest.com/docs/self-hosting?ref=github-helm) for configuration options including valid signing key generation.

### Quick Start with Internal Postgres and Redis

Deploy Inngest with bundled PostgreSQL and Redis instances:

```bash
# Install with required secrets (creates "inngest" namespace automatically)
helm install inngest . \
  --set inngest.eventKey="your_event_key_here" \
  --set inngest.signingKey="your_signing_key_here" \
  --create-namespace
```

**Important:** The `eventKey` and `signingKey` are required and must be hexadecimal strings for Inngest to function properly.

### Custom Values File

Create a `my-values.yaml` file:

```yaml
inngest:
  eventKey: "your_event_key_here" # Must be a hexadecimal string
  signingKey: "your_signing_key_here" # Must be a hexadecimal string

# Customize resource limits (defaults: requests cpu=500m, memory=1Gi)
resources:
  limits:
    cpu: 2000m
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 1Gi

# Adjust liveness probe for slower database connections
livenessProbe:
  initialDelaySeconds: 90
```

Install with custom values:

```bash
helm install inngest . -f my-values.yaml --create-namespace
```

## Resource Naming and Release Names

**Key Concept:** This chart uses **consistent resource naming** regardless of your chosen Helm release name.

- **Helm Release Name:** The first argument (`inngest`) is your chosen release name for Helm tracking
- **Kubernetes Resource Names:** Always consistent: `inngest`, `inngest-postgresql`, `inngest-redis`

**Examples:**

```bash
# All of these create identical Kubernetes resource names
helm install my-production-inngest . --create-namespace
helm install dev-environment . --create-namespace
helm install company-inngest . --create-namespace

# All result in the same resources:
# - service/inngest
# - deployment/inngest
# - configmap/inngest
# - service/inngest-postgresql
# - service/inngest-redis
```

**Benefits:**

- Consistent resource names across all environments
- Documentation examples work for everyone
- Scripts and automation can rely on predictable names
- Easy to reference services from applications

## Configuration Examples

### 1. Using Internal PostgreSQL and Redis (Default)

This is the simplest setup with bundled dependencies:

```yaml
# values-internal.yaml
inngest:
  eventKey: "your_event_key_here" # Must be a hexadecimal string
  signingKey: "your_signing_key_here" # Must be a hexadecimal string

# Internal PostgreSQL (enabled by default)
postgresql:
  enabled: true
  auth:
    database: inngest
    username: inngest
    password: secure_password
  persistence:
    enabled: true
    size: 20Gi

# Internal Redis (enabled by default)
redis:
  enabled: true
  persistence:
    enabled: true
    size: 8Gi

# Resource limits (defaults: requests cpu=500m, memory=1Gi)
resources:
  limits:
    cpu: 2000m
    memory: 2Gi
  requests:
    cpu: 1000m
    memory: 1Gi
```

Deploy:

```bash
helm install inngest . -f values-internal.yaml --create-namespace
```

### 2. Using External PostgreSQL and Redis

For production deployments with external managed databases:

```yaml
# values-external.yaml
inngest:
  eventKey: "your_event_key_here" # Must be a hexadecimal string
  signingKey: "your_signing_key_here" # Must be a hexadecimal string
  postgres:
    uri: "postgres://username:password@postgres.example.com:5432/inngest"
  redis:
    uri: "redis://redis.example.com:6379"

# Disable internal dependencies
postgresql:
  enabled: false

redis:
  enabled: false
```

Deploy:

```bash
helm install inngest-prod . -f values-external.yaml --create-namespace
```

### 3. Using KEDA for Autoscaling

Enable KEDA-based autoscaling using Prometheus metrics from Inngest:

**Important:** KEDA scaling uses a Prometheus sidecar container to scrape the Inngest `/metrics` endpoint. The sidecar handles Bearer token authentication using the `signingKey`, and KEDA queries the sidecar's Prometheus API for scaling decisions based on `inngest_queue_depth`.

```yaml
# values-keda.yaml
inngest:
  eventKey: "your_event_key_here" # Must be a hexadecimal string
  signingKey: "your_signing_key_here" # Must be a hexadecimal string

# Enable KEDA autoscaling
keda:
  enabled: true
  minReplicas: 2
  maxReplicas: 20
  pollingInterval: 30
  cooldownPeriod: 300
  triggers:
    - type: prometheus
      metadata:
        metricName: inngest_queue_depth
        threshold: "10"
        query: inngest_queue_depth
```

Deploy with KEDA:

```bash
# Install KEDA using Helm (recommended method)
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda --namespace keda-system --create-namespace

# Verify KEDA installation
kubectl get pods -n keda-system

# Deploy Inngest with KEDA
helm install inngest . -f values-keda.yaml --create-namespace
```

**Alternative KEDA Installation Methods:**

```bash
# Method 1: Using kubectl (if Helm method fails)
kubectl apply --server-side -f https://github.com/kedacore/keda/releases/download/v2.12.0/keda-2.12.0.yaml

# Method 2: Using specific version via Helm
helm install keda kedacore/keda --version 2.12.0 --namespace keda-system --create-namespace
```

### 4. Complete Production Example

A comprehensive production setup with external dependencies, ingress, and monitoring:

```yaml
# values-production.yaml
replicaCount: 3

inngest:
  eventKey: "your_production_event_key" # Must be a hexadecimal string
  signingKey: "your_production_signing_key" # Must be a hexadecimal string
  logLevel: "info"
  queueWorkers: 200
  postgres:
    uri: "postgres://inngest:secure_password@postgres-prod.example.com:5432/inngest"
  redis:
    uri: "redis://redis-prod.example.com:6379"

# Use external managed databases
postgresql:
  enabled: false

redis:
  enabled: false

# Liveness probe - increase for external databases that take longer to initialize
livenessProbe:
  initialDelaySeconds: 120

# External access (configure ingress separately if needed)

# KEDA autoscaling configuration
keda:
  enabled: true
  minReplicas: 3
  maxReplicas: 50
  triggers:
    - type: prometheus
      metadata:
        metricName: inngest_queue_depth
        threshold: "10"
        query: inngest_queue_depth

# Resource limits
resources:
  limits:
    cpu: 2000m
    memory: 4Gi
  requests:
    cpu: 1000m
    memory: 2Gi

# Security context
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000

podSecurityContext:
  fsGroup: 1000

# Network policy for security
networkPolicy:
  enabled: true
```

Deploy production setup:

```bash
helm install inngest-prod . -f values-production.yaml --create-namespace
```

### 5. Ingress Example with Internal Dependencies

A complete ingress setup using internal PostgreSQL and Redis for external access:

**Security Warning:** When exposing Inngest through ingress, the web UI and GraphQL endpoints are publicly accessible unless protected. This example disables the UI for security. If you need the UI, implement proper authentication/authorization at the ingress level.

```yaml
# values-ingress.yaml
inngest:
  eventKey: "your_event_key_here" # Must be a hexadecimal string
  signingKey: "your_signing_key_here" # Must be a hexadecimal string
  logLevel: "info"
  queueWorkers: 150
  noUI: true # Disable UI for security when exposed via ingress

# Internal PostgreSQL (enabled by default)
postgresql:
  enabled: true
  auth:
    database: inngest
    username: inngest
    password: secure_password
  persistence:
    enabled: true
    size: 30Gi

# Internal Redis (enabled by default)
redis:
  enabled: true
  persistence:
    enabled: true
    size: 10Gi

# Liveness probe - increase for external databases that take longer to initialize
livenessProbe:
  initialDelaySeconds: 90

# Ingress configuration for external access
ingress:
  enabled: true
  className: "nginx" # Use your ingress controller class
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    cert-manager.io/cluster-issuer: "letsencrypt-prod" # Required for automatic Let's Encrypt certificates
  hosts:
    - host: inngest.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: inngest-tls
      hosts:
        - inngest.example.com

# Security context
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000

# Network policy for additional security (optional)
networkPolicy:
  enabled: true
```

Deploy with ingress:

```bash
helm install inngest . -f values-ingress.yaml --create-namespace
```

**Access URLs after deployment:**

- Event API: `https://inngest.example.com`
- API Endpoints: `https://inngest.example.com/api/*`
- Connect Gateway: `https://inngest.example.com:8289`
- UI Dashboard: Disabled for security (noUI: true)

**Note**: Replace `inngest.example.com` with your actual domain and ensure DNS points to your ingress controller.

### 6. Using Sidecar Containers (e.g., GCP Cloud SQL Auth Proxy)

You can add sidecar containers, init containers, and extra volumes to the Inngest pod using templated strings. This is useful for database proxies, log collectors, or other sidecar services.

```yaml
# values-gcp-sql.yaml
inngest:
  eventKey: "your_event_key_here"
  signingKey: "your_signing_key_here"
  postgres:
    uri: "postgres://inngest:password@localhost:5432/inngest" # Connects via sidecar proxy

  extraContainers:
    - name: cloud-sql-proxy
      image: gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.1.0
      args:
        - "--structured-logs"
        - "my-project:us-central1:my-instance"
      securityContext:
        runAsNonRoot: true

postgresql:
  enabled: false
```

Deploy:

```bash
helm install inngest . -f values-gcp-sql.yaml --create-namespace
```

## Setting Up HTTPS with Let's Encrypt

For automatic SSL certificate provisioning using Let's Encrypt, you need to install and configure cert-manager.

### Prerequisites for HTTPS

1. **Ingress Controller**: You need an ingress controller (like nginx-ingress) already installed
2. **cert-manager**: For automatic SSL certificate management
3. **Valid Domain**: A domain name pointing to your ingress controller's IP address

### Installing cert-manager

Install cert-manager using Helm (recommended):

```bash
# Add the cert-manager repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager with CRDs
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true
```

Verify cert-manager installation:

```bash
kubectl get pods -n cert-manager
```

### Setting Up Let's Encrypt ClusterIssuer

Create a ClusterIssuer for Let's Encrypt certificate provisioning:

```yaml
# letsencrypt-clusterissuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com # CHANGE THIS TO YOUR EMAIL
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: nginx
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: your-email@example.com # CHANGE THIS TO YOUR EMAIL
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
      - http01:
          ingress:
            class: nginx
```

Apply the ClusterIssuer:

```bash
# Update the email address in the file first
kubectl apply -f letsencrypt-clusterissuer.yaml
```

### Complete HTTPS Ingress Example

Here's a complete example with automatic SSL certificate provisioning:

```yaml
# values-https-ingress.yaml
inngest:
  eventKey: "your_event_key_here" # Must be a hexadecimal string
  signingKey: "your_signing_key_here" # Must be a hexadecimal string
  noUI: true # Disable UI for security when exposed via ingress

# Ingress configuration with Let's Encrypt
ingress:
  enabled: true
  className: "nginx"
  annotations:
    # Let's Encrypt annotations for automatic SSL certificate provisioning
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    # Use letsencrypt-staging for testing, letsencrypt-prod for production
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
  hosts:
    - host: inngest.yourdomain.com # CHANGE TO YOUR DOMAIN
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: inngest-tls
      hosts:
        - inngest.yourdomain.com # CHANGE TO YOUR DOMAIN
```

Deploy with HTTPS:

```bash
helm install inngest . -f values-https-ingress.yaml --create-namespace
```

### Troubleshooting SSL Certificates

Check certificate status:

```bash
# Check certificate resource
kubectl get certificates -n inngest
kubectl describe certificate inngest-tls -n inngest

# Check certificate request
kubectl get certificaterequests -n inngest

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager
```

**Common Issues:**

1. **Certificate shows "False" for READY**: Usually DNS or HTTP-01 challenge issues

   - Verify your domain points to the ingress controller IP
   - Check ingress controller logs
   - Ensure port 80 is accessible for Let's Encrypt validation

2. **Rate limiting from Let's Encrypt**: Use `letsencrypt-staging` issuer for testing

3. **DNS propagation delays**: Wait for DNS changes to propagate globally

**Testing with Staging:**

For testing, use the staging ClusterIssuer to avoid rate limits:

```yaml
ingress:
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-staging" # Use staging for testing
```

Once working, switch to `letsencrypt-prod` for the trusted certificate.

## Namespace Configuration

The chart creates and manages its own namespace by default. You can customize this behavior:

### Default Namespace

```bash
# Uses default "inngest" namespace
helm install inngest . --create-namespace
```

### Custom Namespace

```yaml
# values-custom-namespace.yaml
namespace:
  create: true
  name: "my-inngest-ns"

inngest:
  eventKey: "your_event_key_here" # Must be a hexadecimal string
  signingKey: "your_signing_key_here" # Must be a hexadecimal string
```

```bash
helm install inngest . -f values-custom-namespace.yaml --create-namespace
```

### Use Existing Namespace

```yaml
# values-existing-namespace.yaml
namespace:
  create: false
  name: "existing-namespace"

inngest:
  eventKey: "your_event_key_here" # Must be a hexadecimal string
  signingKey: "your_signing_key_here" # Must be a hexadecimal string
```

```bash
# Create namespace first if it doesn't exist
kubectl create namespace existing-namespace
helm install inngest . -f values-existing-namespace.yaml
```

**Note:** When using an existing namespace, don't use `--create-namespace` flag.

## Accessing Inngest

After deployment, you can access Inngest through:

**Resource Names:** Regardless of your chosen release name, the Kubernetes resources are always named:

- Main service: `inngest`
- PostgreSQL: `inngest-postgresql`
- Redis: `inngest-redis`

### Port Forward (Development)

```bash
kubectl port-forward svc/inngest 8288:8288 -n inngest
# Access UI at http://localhost:8288
```

### Service URLs for Applications

Configure your applications to send events to:

- Internal: `http://inngest:8288` (within cluster)
- External: `https://inngest.example.com` (see ingress example above)

## Monitoring and Troubleshooting

### Check Pod Status

```bash
kubectl get pods -l app.kubernetes.io/name=inngest -n inngest
```

### View Logs

```bash
kubectl logs -l app.kubernetes.io/name=inngest -f -n inngest
```

### Check Configuration

```bash
kubectl get configmap inngest -o yaml -n inngest
kubectl get secret inngest -o yaml -n inngest
```

### KEDA Scaling Status

```bash
kubectl get scaledobject -n inngest
kubectl describe scaledobject inngest -n inngest
```

#### Pods stuck in "Pending" state

Check for resource constraints or storage issues:

```bash
kubectl describe pods -l app.kubernetes.io/name=inngest -n inngest
kubectl get pvc -n inngest
kubectl get storageclass
```

## Upgrading

### Upgrade Chart

```bash
helm upgrade inngest . -f your-values.yaml -n inngest
```

**Note:** Always specify the namespace when upgrading to ensure Helm finds the correct release.

### Database Migrations

Inngest handles database migrations automatically on startup. Ensure you have backups before upgrading.

## Uninstalling

```bash
helm uninstall inngest -n inngest
```

**Note:** This will not delete persistent volumes. To delete all data:

```bash
kubectl delete pvc -l app.kubernetes.io/name=inngest -n inngest
```

## Configuration Reference

### Key Configuration Options

| Parameter            | Description                  | Default     | Required |
| -------------------- | ---------------------------- | ----------- | -------- |
| `namespace.create`   | Create namespace             | `true`      | No       |
| `namespace.name`     | Namespace name               | `"inngest"` | No       |
| `inngest.eventKey`   | Event key for sending events | `""`        | **Yes**  |
| `inngest.signingKey` | Signing key for validation   | `""`        | **Yes**  |
| `postgresql.enabled` | Enable bundled PostgreSQL    | `true`      | No       |
| `redis.enabled`      | Enable bundled Redis         | `true`      | No       |
| `inngest.extraContainers` | Extra sidecar containers (template string) | `""` | No |
| `inngest.extraInitContainers` | Extra init containers (template string) | `""` | No |
| `ingress.enabled`    | Enable ingress               | `false`     | No       |
| `keda.enabled`       | Enable KEDA autoscaling      | `false`     | No       |

**Security:** This chart implements security best practices by default:

- Non-root user execution (UID 1000 for Inngest, 999 for PostgreSQL/Redis)
- Read-only root filesystem with temporary volumes for writable directories
- Dropped capabilities and disabled privilege escalation
- Database credentials stored in Kubernetes Secrets (not plain text)
- Network policies available for additional isolation

**Resource Names:** All Kubernetes resources use consistent names regardless of Helm release name:

- Main application: `inngest` (service, deployment, configmap, secret)
- PostgreSQL: `inngest-postgresql` (service, deployment, pvc)
- Redis: `inngest-redis` (service, deployment, pvc)

For a complete list of configuration options, see `values.yaml`.

## Support

- [Inngest Documentation](https://www.inngest.com/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
