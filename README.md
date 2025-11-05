# KubeCon 2025 Zero-Downtime Migration Demo

This project demonstrates zero-downtime migration techniques using Kubernetes native sidecar containers, lifecycle hooks, and graceful connection draining.

## Overview

This demo showcases how to achieve zero-downtime deployments using:

- **Native Sidecar Containers**: Envoy proxy as a native sidecar for traffic routing
- **Lifecycle Hooks**: postStart and preStop hooks for graceful connection draining
- **Health Probes**: Comprehensive health monitoring for reliability
- **Observability**: Prometheus and Grafana for monitoring and metrics

## Table of Contents

- [KubeCon 2025 Zero-Downtime Migration Demo](#kubecon-2025-zero-downtime-migration-demo)
  - [Overview](#overview)
  - [Table of Contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
    - [Required Tools](#required-tools)
    - [Optional Tools](#optional-tools)
    - [Quick Setup](#quick-setup)
  - [Getting Started](#getting-started)
    - [Step 1: Clone the Repository](#step-1-clone-the-repository)
    - [Step 2: Build the Demo Application](#step-2-build-the-demo-application)
      - [Option A: Local Build (Recommended for Quick Demos)](#option-a-local-build-recommended-for-quick-demos)
      - [Option B: Push to Docker Registry (For Production-like Scenarios)](#option-b-push-to-docker-registry-for-production-like-scenarios)
    - [Step 3: Deploy Everything](#step-3-deploy-everything)
    - [Verifying kubectl Context](#verifying-kubectl-context)
  - [Accessing the Services](#accessing-the-services)
    - [Option 1: Port-Forward (Always Available)](#option-1-port-forward-always-available)
    - [Main Application](#main-application)
    - [Grafana Dashboard](#grafana-dashboard)
    - [Prometheus](#prometheus)
    - [Envoy Admin Interface](#envoy-admin-interface)
    - [Option 2: LoadBalancer via Gateway API (Optional)](#option-2-loadbalancer-via-gateway-api-optional)
  - [Running Experiments](#running-experiments)
    - [Experiment 1: Lifecycle Hooks Demo](#experiment-1-lifecycle-hooks-demo)
    - [Experiment 2: Applying Lifecycle Hooks](#experiment-2-applying-lifecycle-hooks)
    - [Experiment 3: Load Testing](#experiment-3-load-testing)
    - [Experiment 4: Rollout Update and Shutdown Monitoring](#experiment-4-rollout-update-and-shutdown-monitoring)
      - [Step 1: Update the Application Image](#step-1-update-the-application-image)
      - [Step 2: Watch the Rollout Progress](#step-2-watch-the-rollout-progress)
      - [Step 3: Monitor Shutdown Sequence for Terminating Pods](#step-3-monitor-shutdown-sequence-for-terminating-pods)
      - [Step 4: Monitor EndpointSlice State](#step-4-monitor-endpointslice-state)
    - [Experiment 5: Traffic Splitting Migration (ASG → K8s)](#experiment-5-traffic-splitting-migration-asg--k8s)
      - [Step 1: Deploy ASG and K8s Workloads](#step-1-deploy-asg-and-k8s-workloads)
      - [Step 2: Apply Initial Canary Configuration (99% ASG, 1% K8s)](#step-2-apply-initial-canary-configuration-99-asg-1-k8s)
      - [Step 3: Gradually Increase K8s Traffic](#step-3-gradually-increase-k8s-traffic)
      - [Step 4: Complete Migration to K8s](#step-4-complete-migration-to-k8s)
      - [Step 5: Monitor During Migration](#step-5-monitor-during-migration)
  - [Project Structure](#project-structure)
  - [Zero-Downtime Migration Strategy](#zero-downtime-migration-strategy)
    - [1. Traffic Splitting (ASG → K8s Migration)](#1-traffic-splitting-asg--k8s-migration)
    - [2. Kubernetes Health Probes](#2-kubernetes-health-probes)
    - [3. Lifecycle Hooks for Graceful Shutdown](#3-lifecycle-hooks-for-graceful-shutdown)
  - [Key Features](#key-features)
    - [Native Sidecar Containers](#native-sidecar-containers)
    - [Lifecycle Hooks](#lifecycle-hooks)
    - [Health Probes](#health-probes)
  - [Troubleshooting](#troubleshooting)
    - [Common Issues](#common-issues)
    - [Debugging Commands](#debugging-commands)
  - [Cleanup](#cleanup)
  - [References](#references)

## Prerequisites

Before running the demo, ensure you have the following tools installed:

### Required Tools

1. **Docker Desktop** (or Docker Engine)
   - Version 20.10 or later
   - For macOS: Download from [Docker Desktop for Mac](https://docs.docker.com/desktop/install/mac-install/)
   - For Linux: Follow [Docker Engine installation guide](https://docs.docker.com/engine/install/)

2. **kubectl** (Kubernetes CLI)
   - Version 1.24 or later
   - Installation: [kubectl installation guide](https://kubernetes.io/docs/tasks/tools/)

3. **Kind** (Kubernetes in Docker)
   - Version 0.20.0 or later
   - Installation: [Kind installation guide](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)

4. **Helm** (Kubernetes Package Manager)
   - Version 3.0 or later
   - For macOS: `brew install helm`
   - For Linux: Follow [Helm installation guide](https://helm.sh/docs/intro/install/)

5. **siege** (Load testing tool)
   - For macOS: `brew install siege`
   - For Linux: `sudo apt-get install siege` (Debian/Ubuntu) or `sudo yum install siege` (RHEL/CentOS)

### Optional Tools

1. **cloud-provider-kind** (For LoadBalancer support via Gateway API)
   - For macOS: `brew install cloud-provider-kind`
   - For Linux: Follow [cloud-provider-kind installation](https://github.com/kubernetes-sigs/cloud-provider-kind)
   - **Note**: Required only if you want to use LoadBalancer IPs instead of port-forwarding

### Quick Setup

Run the setup script to check and install prerequisites:

```bash
chmod +x setup.sh
./setup.sh
```

This script will:

- Check if all required tools are installed
- Provide installation instructions for missing tools
- Verify all prerequisites are ready

## Getting Started

### Step 1: Clone the Repository

```bash
git clone <repository-url>
cd kubecon25-zero-downtime
```

### Step 2: Build the Demo Application

You have two options for building and using the demo application image:

#### Option A: Local Build (Recommended for Quick Demos)

Build the Docker image locally and load it into the Kind cluster:

```bash
# Build the image
cd monolith-demo-app
docker build -t monolith-demo-app:latest .
# Or use the same image name as in the deployment manifest
# Replace YOUR_USERNAME with your Docker Hub username or registry name
docker build -t YOUR_USERNAME/monolith:v0.1.0 .
cd ..

# Load the image into Kind cluster (do this after creating the cluster)
kind load docker-image YOUR_USERNAME/monolith:v0.1.0 --name zerodt-demo
```

**Important**: If you use a different image name, make sure to update the image reference in `k8s-app-workload/base-manifest/deployment.yaml` to match your image name.

**Note**: If you use this approach, make sure to load the image into Kind **after** Step 3 (creating the cluster) but **before** Step 4 (deploying the workload), or update `deploy-all.sh` to include the image loading step.

#### Option B: Push to Docker Registry (For Production-like Scenarios)

If you want to use a registry (Docker Hub, GitHub Container Registry, etc.):

1. **Login to Docker Registry**:

   ```bash
   # For Docker Hub
   docker login
   
   # For GitHub Container Registry
   docker login ghcr.io -u YOUR_USERNAME
   
   # For other registries, see: https://docs.docker.com/engine/reference/commandline/login/
   ```

2. **Build and Push the Image**:

   ```bash
   cd monolith-demo-app
   docker build -t YOUR_USERNAME/monolith:v0.1.0 .
   docker push YOUR_USERNAME/monolith:v0.1.0
   cd ..
   ```

3. **Update the Image Reference** in `k8s-app-workload/base-manifest/deployment.yaml`:

   ```yaml
   image: YOUR_USERNAME/monolith:v0.1.0
   ```

**Registry Links**:

- [Docker Hub](https://hub.docker.com/) - Free public registry
- [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry) - Free for public repos
- [AWS ECR](https://aws.amazon.com/ecr/) - AWS container registry
- [Google Container Registry](https://cloud.google.com/container-registry) - GCP container registry

### Step 3: Deploy Everything

Run the complete deployment script that creates a Kind cluster and deploys all components:

```bash
chmod +x deploy-all.sh
./deploy-all.sh
```

This script will:

1. Create a Kind cluster named `zero-downtime` (or use existing if found)
2. Set and verify the kubectl context to ensure you're connected to the correct cluster
3. Configure node taints for workload placement
4. Install Argo Rollouts and KEDA (if not already installed)
5. Deploy the K8s app workload with base configuration
6. Deploy the routing service (Envoy edge router)
7. Wait for all deployments to be ready (if cluster is new)
8. Install Kubernetes Metrics Server
9. Deploy the observability stack (Prometheus + Grafana)
10. **(Optional)** Install cloud-provider-kind and Gateway API for LoadBalancer support

**Note**: The script will prompt you if an existing cluster is found - you can choose to delete it or continue with the existing cluster.

**Note**: The deployment may take several minutes to complete. Wait for all pods to be in `Running` state before proceeding.

### Verifying kubectl Context

After running `deploy-all.sh`, the script automatically sets and verifies the kubectl context. However, if you're running commands manually in a new terminal session, you should verify you're connected to the correct cluster:

```bash
# Check current context
kubectl config current-context

# Should show: kind-zerodt-demo
# If not, set it explicitly:
kubectl config use-context kind-zerodt-demo

# Verify cluster connection
kubectl cluster-info

# List nodes to confirm
kubectl get nodes
```

**Important**: Always verify your kubectl context before running commands to avoid accidentally modifying the wrong cluster!

## Accessing the Services

After deployment completes, you can access the services using one of two methods:

### Option 1: Port-Forward (Always Available)

Port-forwarding works immediately without any additional setup:

### Main Application

```bash
kubectl port-forward -n default svc/edge-routing-service 8080:80
```

Then visit: <http://localhost:8080>

### Grafana Dashboard

```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

Then visit: <http://localhost:3000>

- **Username**: `admin`
- **Password**: `admin123` (as configured in values.yaml)

### Prometheus

```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

Then visit: <http://localhost:9090>

### Envoy Admin Interface

```bash
kubectl port-forward -n default svc/edge-routing-service 9901:9901
```

Then visit: <http://localhost:9901>

### Option 2: LoadBalancer via Gateway API (Optional)

Instead of using port-forwarding, you can use LoadBalancer IPs with Gateway API. This requires:

1. **Install cloud-provider-kind** (if not already installed):

   ```bash
   brew install cloud-provider-kind
   ```

2. **Install Gateway API CRDs**:

   ```bash
   kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml
   ```

3. **Apply Gateway API manifest**:

   ```bash
   kubectl apply -f ingress/gateway-api.yaml
   ```

4. **Run cloud-provider-kind** (in a separate terminal):

   ```bash
   sudo cloud-provider-kind --gateway-channel standard
   ```

   **Note**: On macOS, you must run this with `sudo`. This command needs to run continuously to provide LoadBalancer functionality.

5. **Check Gateway status**:

   ```bash
   kubectl get gateway zerodt-demo-gateway
   ```

   Wait until the Gateway has an `ADDRESS` assigned. The output should look like:

   ```text
   NAME                  CLASS                 ADDRESS       PROGRAMMED   AGE
   zerodt-demo-gateway   cloud-provider-kind   192.168.x.x   True         2m
   ```

6. **Access services via LoadBalancer IP**:

   Once the Gateway has an ADDRESS, you can access services directly:

   - **Main Application**: `http://<GATEWAY-ADDRESS>/`
   - **Grafana**: `http://<GATEWAY-ADDRESS>:3000/`
   - **Prometheus**: `http://<GATEWAY-ADDRESS>:9090/`
   - **Envoy Admin**: `http://<GATEWAY-ADDRESS>:9901/`

   Replace `<GATEWAY-ADDRESS>` with the IP address from `kubectl get gateway`.

**Automatic Setup**: The `deploy-all.sh` script includes an optional step to install and configure cloud-provider-kind. When prompted, choose `y` to enable LoadBalancer support.

**Reference**: For more details, see [cloud-provider-kind Gateway API support](https://github.com/kubernetes-sigs/cloud-provider-kind#gateway-api-support-alpha)

## Running Experiments

### Experiment 1: Lifecycle Hooks Demo

Demonstrate how postStart and preStop hooks enable graceful connection draining:

```bash
chmod +x demo-lifecycle-hooks.sh
./demo-lifecycle-hooks.sh
```

This demo shows:

- How to add lifecycle hooks to drain active in-flight connections
- Comparison between before-native-sidecar and after-native-sidecar approaches
- Applying lifecycle hooks configuration
- Verifying the hooks are working

### Experiment 2: Applying Lifecycle Hooks

Apply lifecycle hooks to the deployment:

```bash
# Apply lifecycle hooks for after-native-sidecar approach
kubectl apply -f k8s-app-workload/lifecycle-hooks/after-native-sidecar/
```

This will:

- Add postStart hook to signal Envoy when app container starts
- Add preStop hook to gracefully drain connections before pod termination
- Configure the rollout strategy for zero-downtime updates

### Experiment 3: Load Testing

Run load tests to observe the graceful shutdown behavior:

```bash
# Load test with siege
siege -c 2 -t 30s -i -f urls.txt
```

Or use the retry demo URLs:

```bash
siege -c 2 -t 30s -i -f retry-demo-urls.txt
```

### Experiment 4: Rollout Update and Shutdown Monitoring

This experiment demonstrates how to update the application image and monitor the graceful shutdown sequence during a rollout.

#### Step 1: Update the Application Image

Update the rollout to a new image version:

```bash
kubectl argo rollouts set image k8s-web-pool app=kosarajus/monolith:v0.1.2
```

#### Step 2: Watch the Rollout Progress

In one terminal, watch the rollout status:

```bash
kubectl argo rollouts get rollout k8s-web-pool -w
```

This will show the rollout progress in real-time, including:

- Current revision
- Replica counts
- Pod status

#### Step 3: Monitor Shutdown Sequence for Terminating Pods

In another terminal, monitor the shutdown sequence for any pod that is terminating during the rollout:

```bash
while true; do
  POD_NAME=$(kubectl get pods -l app.zerodt.com/component=web -o json | jq -r '.items[] | select(.metadata.deletionTimestamp != null) | .metadata.name' | head -1)
  [ -n "$POD_NAME" ] && echo -e "\n ---- $POD_NAME ----\n"
  kubectl logs -f $POD_NAME --since 1m -c app 2>/dev/null | egrep -iB1 'PreStop|SIGTERM|term|shut|finished|clean'
  sleep 2
done
```

This command will:

- Continuously check for pods with deletion timestamps (terminating pods)
- Show logs from the app container for terminating pods
- Filter for shutdown-related log messages (PreStop, SIGTERM, etc.)

You should see logs like:

- `[Kubernetes PreStop] START: Drain Sequence initiated`
- `[Kubernetes PreStop] Signaling Envoy to Close Connections...`
- `[Kubernetes PreStop] Waiting for Active Connections to Drain`
- `[Kubernetes PreStop] All Connections Drained... Signaling App to Shutdown`

#### Step 4: Monitor EndpointSlice State

In yet another terminal, monitor the EndpointSlice state to see how the pod's endpoint conditions change during termination:

```bash
while true; do
  POD_NAME=$(kubectl get pods -l app.zerodt.com/component=web -o json | jq -r '.items[] | select(.metadata.deletionTimestamp != null) | .metadata.name' | head -1)
  ENDPOINTSLICE_NAME=$(kubectl get endpointslice -l app.kubernetes.io/component=web -o jsonpath='{.items[0].metadata.name}')
  [ -n "$POD_NAME" ] && echo -e "\n ---- $POD_NAME ----\n"
  kubectl get endpointslice "$ENDPOINTSLICE_NAME" -o jsonpath="{range .endpoints[?(@.targetRef.name==\"$POD_NAME\")]}{\"Conditions: ready=\"}{.conditions.ready}{\", serving=\"}{.conditions.serving}{\", terminating=\"}{.conditions.terminating}{\", NodeName=\"}{.nodeName}{\", pod=\"}{.targetRef.name}{\"\\n\"}{end}"
  sleep 2
done
```

This command will show:

- **ready**: Whether the endpoint is ready to receive traffic
- **serving**: Whether the endpoint is serving traffic
- **terminating**: Whether the endpoint is in terminating state
- **NodeName**: The node where the pod is running
- **pod**: The pod name

During graceful shutdown, you should observe:

- `ready=false, serving=false, terminating=true` as the pod is being drained
- The endpoint being removed from the EndpointSlice once draining completes

**Note**: This experiment requires three terminal windows:

1. One for watching the rollout status
2. One for monitoring pod shutdown logs
3. One for monitoring EndpointSlice state

### Experiment 5: Traffic Splitting Migration (ASG → K8s)

This experiment demonstrates how to gradually migrate traffic from ASG to Kubernetes workloads using Envoy's weighted load balancing.

#### Step 1: Deploy ASG and K8s Workloads

Ensure both ASG and K8s workloads are running:

```bash
# Deploy ASG workload
kubectl apply -k asg-ec2-app-stack/base-manifest/

# Deploy K8s workload with health probes and lifecycle hooks
kubectl apply -k k8s-app-workload/lifecycle-hooks/after-native-sidecar/
```

#### Step 2: Apply Initial Canary Configuration (99% ASG, 1% K8s)

Start with minimal K8s traffic to validate the new workload:

```bash
kubectl apply -k routing-service/traffic-split/99-asg-1-k8s/
```

Monitor both workloads to ensure they're healthy:

```bash
# Check ASG workload
kubectl get pods -l app.zerodt.com/component=web,app.zerodt.com/instance=asg

# Check K8s workload
kubectl get pods -l app.zerodt.com/component=web,app.zerodt.com/instance=k8s

# Monitor traffic split via Envoy admin
kubectl port-forward -n default svc/edge-routing-service 9901:9901
curl http://localhost:9901/clusters | grep -E "(asg-web-pool|k8s-web-pool)"
```

#### Step 3: Gradually Increase K8s Traffic

Once the canary is validated, gradually increase K8s traffic:

```bash
# Move to 50% ASG, 50% K8s
kubectl apply -k routing-service/traffic-split/50-asg-50-k8s/

# Monitor traffic distribution
kubectl port-forward -n default svc/edge-routing-service 9901:9901
curl http://localhost:9901/stats | grep -E "cluster\.(asg|k8s).*upstream_rq_total"
```

#### Step 4: Complete Migration to K8s

Once K8s workload is validated at 50%, complete the migration:

```bash
# Move to 100% K8s
kubectl apply -k routing-service/traffic-split/100-k8s/

# Verify all traffic is going to K8s
kubectl port-forward -n default svc/edge-routing-service 9901:9901
curl http://localhost:9901/clusters | grep k8s-web-pool
```

#### Step 5: Monitor During Migration

During the migration, monitor:

- **Request Distribution**: Verify traffic split matches configured weights
- **Response Times**: Compare performance between ASG and K8s
- **Error Rates**: Monitor error rates for both endpoints
- **Health Status**: Ensure both endpoints remain healthy

**Key Benefits**:

- **Zero Downtime**: Traffic is gradually shifted without service interruption
- **Safe Rollback**: Can revert to previous traffic split if issues arise
- **Health Monitoring**: Both workloads are continuously monitored via health probes
- **Graceful Shutdown**: K8s pods use lifecycle hooks for clean termination

**Reference**: See `routing-service/traffic-split/README.md` for detailed traffic splitting configuration and monitoring.

## Project Structure

```text
kubecon25-zero-downtime/
├── k8s-app-workload/          # Main application workload
│   ├── base-manifest/         # Base deployment configuration
│   └── lifecycle-hooks/       # Lifecycle hook configurations
│       ├── before-native-sidecar/  # Pre-native sidecar approach
│       └── after-native-sidecar/   # Native sidecar approach
├── routing-service/           # Edge routing service (Envoy)
│   ├── base-manifest/         # Base routing configuration
│   ├── envoy-retry-policy/    # Retry policy configurations
│   └── traffic-split/         # Traffic splitting configurations for ASG→K8s migration
│       ├── 99-asg-1-k8s/      # 99% ASG, 1% K8s canary
│       ├── 50-asg-50-k8s/     # 50% ASG, 50% K8s split
│       └── 100-k8s/            # 100% K8s (full migration)
├── asg-ec2-app-stack/         # ASG/EC2 application stack (source)
│   └── base-manifest/         # ASG workload configuration
├── monolith-demo-app/         # Demo application source code
├── observability/             # Prometheus and Grafana stack
├── ingress/                    # Gateway API manifests for LoadBalancer support
│   └── gateway-api.yaml       # Gateway and HTTPRoute definitions
├── demo-lifecycle-hooks.sh    # Demo script for lifecycle hooks
├── deploy-all.sh              # Complete deployment script
└── setup.sh                   # Prerequisites setup script
```

## Zero-Downtime Migration Strategy

This demo showcases a complete zero-downtime migration strategy from ASG (Auto Scaling Group) to Kubernetes workloads using:

### 1. Traffic Splitting (ASG → K8s Migration)

The `routing-service/traffic-split/` directory contains reference configurations for gradually migrating traffic from ASG to K8s workloads:

- **99% ASG, 1% K8s**: Initial canary deployment with minimal K8s traffic
- **50% ASG, 50% K8s**: Balanced traffic split for validation
- **100% K8s**: Full migration to Kubernetes

These configurations use Envoy's weighted load balancing to split traffic between:

- **ASG Web Pool**: Existing ASG infrastructure (`asg-web-pool` service)
- **K8s Web Pool**: New Kubernetes workload (`k8s-web-pool` service)

**Deploy Traffic Split**:

```bash
# Apply canary configuration (99% ASG, 1% K8s)
kubectl apply -k routing-service/traffic-split/99-asg-1-k8s/

# Gradually increase K8s traffic
kubectl apply -k routing-service/traffic-split/50-asg-50-k8s/

# Complete migration to K8s
kubectl apply -k routing-service/traffic-split/100-k8s/
```

### 2. Kubernetes Health Probes

The `k8s-app-workload/` directory demonstrates progressive enhancement with health probes:

- **Base Manifest**: Clean deployment with native sidecar
- **Lifecycle Hooks**: Add postStart and preStop hooks for graceful shutdown

**Health Probe Configuration**:

- **Envoy Init Container**: Uses Envoy's admin interface (`/ready` endpoint)
  - `livenessProbe`: HTTP GET `/ready` on port 9901
  - `readinessProbe`: HTTP GET `/ready` on port 9901
  - `startupProbe`: HTTP GET `/ready` on port 9901 with longer timeout

- **App Container**: Uses application's health endpoint (`/health`)
  - `livenessProbe`: HTTP GET `/health` on port 8000
  - `readinessProbe`: HTTP GET `/health` on port 8000
  - `startupProbe`: TCP socket check on port 8000

**Apply Health Probes**:

```bash
# Apply lifecycle hooks with health probes
kubectl apply -k k8s-app-workload/lifecycle-hooks/after-native-sidecar/
```

### 3. Lifecycle Hooks for Graceful Shutdown

Lifecycle hooks ensure zero-downtime during pod terminations:

- **postStart Hook**: Signals Envoy that the app is ready to accept traffic
- **preStop Hook**: Gracefully drains connections before pod termination

**How It Works**:

1. **PostStart**: When app container starts, signals Envoy to accept connections
2. **PreStop**: When pod is terminating:
   - Signals Envoy to stop accepting new connections
   - Waits for Kubernetes to stop sending traffic
   - Monitors active connections until they drain
   - Ensures stable draining before allowing pod termination

This combination of traffic splitting, health probes, and lifecycle hooks ensures:

- **Zero Traffic Loss**: Traffic is gradually shifted from ASG to K8s
- **Health Monitoring**: Both ASG and K8s workloads are continuously monitored
- **Graceful Shutdown**: Pods drain connections before termination
- **Rollback Capability**: Can quickly revert to previous traffic split if issues arise

## Key Features

### Native Sidecar Containers

The Envoy proxy is implemented as a native sidecar using:

```yaml
initContainers:
- name: envoy
  restartPolicy: Always  # This makes it a native sidecar
```

Benefits:

- Sidecar doesn't block pod termination
- Proper startup ordering with init containers
- Independent lifecycle management

### Lifecycle Hooks

**postStart Hook**: Signals Envoy to accept connections when the app container starts:

```bash
curl -s -X POST "http://envoy:9901/healthcheck/ok"
```

**preStop Hook**: Gracefully drains connections before pod termination:

1. Signals Envoy to stop accepting new connections
2. Waits 2 seconds for Kubernetes to stop sending traffic
3. Monitors active connections until they remain at zero for 3 consecutive seconds
4. Ensures stable draining before allowing pod termination

### Health Probes

The `k8s-app-workload/` directory demonstrates comprehensive health monitoring:

- **Envoy Init Container**: Uses Envoy's built-in admin interface (`/ready` endpoint)
  - `livenessProbe`: Detects and restarts unhealthy Envoy containers
  - `readinessProbe`: Ensures Envoy is ready before receiving traffic
  - `startupProbe`: Allows longer initialization time for Envoy

- **App Container**: Uses application's health endpoint (`/health`)
  - `livenessProbe`: Detects and restarts unhealthy app containers
  - `readinessProbe`: Ensures app is ready before receiving traffic
  - `startupProbe`: Faster TCP socket check for app initialization

- **Separate Probe Configurations**: Different thresholds and timeouts for different health states
- **Progressive Enhancement**: Can be added incrementally using Kustomize overlays

See `k8s-app-workload/README.md` for detailed health probe configuration and usage examples.

## Troubleshooting

### Common Issues

1. **Pods not starting**
   - Check: `kubectl get pods -o wide`
   - Check: `kubectl describe pod <pod-name>`
   - Verify image is available: `docker images | grep monolith-demo-app`

2. **ConfigMap not found**
   - Ensure `kustomization.yaml` includes the `configMapGenerator`
   - Re-apply the base manifest: `kubectl apply -k k8s-app-workload/base-manifest/`

3. **Envoy admin interface not accessible**
   - Verify Envoy configuration includes admin section
   - Check Envoy logs: `kubectl logs <pod-name> -c envoy`

4. **Lifecycle hook timeouts**
   - Adjust `terminationGracePeriodSeconds` if needed
   - Check pod logs for preStop hook execution

### Debugging Commands

```bash
# Check pod status
kubectl get pods -n default

# View Envoy logs
kubectl logs -n default <pod-name> -c envoy

# Test Envoy admin interface
kubectl exec -n default <pod-name> -c envoy -- curl http://localhost:9901/ready

# Check applied configuration
kubectl get deployment -n default -o yaml
kubectl get rollout -n default -o yaml

# Check events
kubectl get events --sort-by='.lastTimestamp'
```

## Cleanup

To clean up the Kind cluster and all resources:

```bash
kind delete cluster --name zero-downtime
```

## References

- [Kubernetes Native Sidecar Containers](https://kubernetes.io/blog/2023/08/25/native-sidecar-containers/)
- [Kubernetes Container Lifecycle Hooks](https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/)
- [Kustomize Documentation](https://kubectl.docs.kubernetes.io/references/kustomize/)
- [Envoy Proxy v3 API](https://www.envoyproxy.io/docs/envoy/latest/api-v3/api)
- [cloud-provider-kind Gateway API Support](https://github.com/kubernetes-sigs/cloud-provider-kind#gateway-api-support-alpha)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
