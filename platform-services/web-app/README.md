# Web Application Workload

This directory contains the Kubernetes manifests and Kustomize configurations for the web application workload. The configuration demonstrates zero-downtime migration techniques using progressive enhancement with Kustomize overlays.

**Labels**:
- `app.kubernetes.io/component: web`
- `app.kubernetes.io/system: platform-service`

## Architecture

### Current

![Current Architecture](../images/new-full-architecture.gif "Current Full Architecture")

### Future

![Future Architecture](../images/future-full-architecture.gif "Future Full Architecture")

## Directory Structure

```
zero-downtime/
├── base-manifest/                 # Phase 1: Base deployment (no probes/hooks)
│   ├── deployment.yaml           # Clean deployment with native sidecar
│   ├── deployment-full.yaml.bk   # Reference with all features
│   ├── envoy.yaml                # Envoy proxy configuration
│   ├── service.yaml              # Service definition
│   └── kustomization.yaml        # Base kustomization
├── with-kube-probes/             # Phase 2: Add health monitoring
│   ├── deployment-patch.yaml     # Health probe patches
│   └── kustomization.yaml        # References base + probe patches
├── container-lifecycle-hooks/    # Phase 3: Add graceful shutdown
│   ├── deployment-patch.yaml     # Lifecycle hook patches
│   └── kustomization.yaml        # References Phase 2 + lifecycle patches
├── urls.txt                      # Load testing URLs (references ../urls.txt)
└── README.md                     # This file
```

## Kustomize Overlay Strategy

### Phase 1: Base Manifest (`base-manifest/`)

**Purpose**: Clean deployment without health monitoring or lifecycle hooks.

**Key Features**:

- Native sidecar container (Envoy) with `restartPolicy: Always`
- Basic resource limits and requests
- Envoy proxy configuration for traffic routing
- Service definition for external access

**Files**:

- `deployment.yaml`: Core deployment with init container (Envoy) and main container (app)
- `envoy.yaml`: Envoy v3 API configuration with admin interface
- `service.yaml`: ClusterIP service exposing port 80
- `kustomization.yaml`: Base configuration with namespace, labels, and ConfigMap generation

### Phase 2: Health Probes (`with-kube-probes/`)

**Purpose**: Add comprehensive health monitoring to improve reliability.

**Patches Applied**:

- **Envoy Init Container Probes**:
  - `livenessProbe`: HTTP GET `/ready` on port 9901 (admin interface)
  - `readinessProbe`: HTTP GET `/ready` on port 9901
  - `startupProbe`: HTTP GET `/ready` on port 9901 with longer timeout

- **App Container Probes**:
  - `livenessProbe`: HTTP GET `/health` on port 8000
  - `readinessProbe`: HTTP GET `/health` on port 8000
  - `startupProbe`: TCP socket check on port 8000

**Kustomize Configuration**:

```yaml
resources:
- ../base-manifest

patches:
- path: deployment-patch.yaml
  target:
    kind: Deployment
    name: monolith-web-general-pool
```

### Phase 3: Lifecycle Hooks (`container-lifecycle-hooks/`)

**Purpose**: Add graceful shutdown capabilities for zero-downtime deployments.

**Patches Applied**:

- **PostStart Hook**: Signal Envoy that the app is ready
- **PreStop Hook**: Graceful connection draining sequence
  1. Signal Envoy to stop accepting new connections
  2. Wait for active connections to drain
  3. Complete shutdown process

**Kustomize Configuration**:

```yaml
resources:
- ../../with-kube-probes

patches:
- path: deployment-patch.yaml
  target:
    kind: Deployment
    name: monolith-web-general-pool
```

## Code Signature Analysis

### Native Sidecar Implementation

The Envoy proxy is implemented as a native sidecar using:

```yaml
initContainers:
- name: envoy
  restartPolicy: Always  # This makes it a native sidecar
```

**Benefits**:

- Sidecar doesn't block pod termination
- Proper startup ordering with init containers
- Independent lifecycle management

### Envoy Configuration (v3 API)

The Envoy proxy uses the modern v3 API with:

```yaml
typed_config:
  "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
```

**Features**:

- Admin interface on port 9901 for health checks
- HTTP connection manager with router filter
- Load balancing to backend service (port 8000)
- Proper cluster configuration with DNS resolution

### Health Probe Strategy

**Init Container (Envoy)**:

- Uses Envoy's built-in admin interface (`/ready` endpoint)
- Separate probe configuration for different health states
- Startup probe with longer timeout for initialization

**Main Container (App)**:

- Uses application's health endpoint (`/health`)
- TCP socket check for startup (faster than HTTP)
- Appropriate failure thresholds for different probe types

### Lifecycle Hook Implementation

**PostStart**:

```bash
curl -s -X POST "http://envoy:9901/healthcheck/ok"
```

**PreStop**:

```bash
# Signal Envoy to stop accepting connections
curl -s -X POST "http://envoy:9901/healthcheck/fail"

# Wait for active connections to drain
while [[ $(curl -s envoy:9901/stats | grep server.total_connections | awk '{print $2}') != 0 ]];
do sleep 1; done;
```

## Usage Examples

### Apply Base Configuration

```bash
cd base-manifest
kubectl apply -k .
```

### Apply with Health Probes

```bash
cd ../with-kube-probes
kubectl apply -k .
```

### Apply with Lifecycle Hooks

```bash
cd ../container-lifecycle-hooks
kubectl apply -k .
```

### Validate Configuration

```bash
# Check what will be applied
kubectl kustomize .

# Validate syntax
kubectl kustomize . | kubectl apply --dry-run=client -f -
```

## Advanced Features (Commented Out)

The `deployment-full.yaml.bk` contains additional production-ready features that are commented out in the base deployment:

- **Node Affinity**: Control pod placement based on node characteristics
- **Tolerations**: Handle node taints for specialized workloads
- **Topology Spread Constraints**: Distribute pods across zones and nodes
- **Priority Classes**: Control pod scheduling priority

These can be uncommented and configured for production environments.

## Troubleshooting

### Common Issues

1. **ConfigMap Not Found**: Ensure `kustomization.yaml` includes the `configMapGenerator`
2. **Envoy Admin Interface**: Verify Envoy configuration includes admin section
3. **Probe Failures**: Check that health endpoints are accessible
4. **Lifecycle Hook Timeouts**: Adjust `terminationGracePeriodSeconds` if needed

### Debugging Commands

```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/component=web,app.kubernetes.io/system=platform-service

# View Envoy logs
kubectl logs <pod-name> -c envoy

# Test Envoy admin interface
kubectl exec <pod-name> -c envoy -- curl http://localhost:9901/ready

# Check applied configuration
kubectl get rollout web-global -o yaml
```

## References

- [Kubernetes Native Sidecar Containers](https://kubernetes.io/blog/2023/08/25/native-sidecar-containers/)
- [Kubernetes Container Lifecycle Hooks](https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/)
- [Kustomize Documentation](https://kubectl.docs.kubernetes.io/references/kustomize/)
- [Envoy Proxy v3 API](https://www.envoyproxy.io/docs/envoy/latest/api-v3/api)
