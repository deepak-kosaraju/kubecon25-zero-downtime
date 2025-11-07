# KubeCon 2025 Zero-Downtime Migration Demo

This project demonstrates zero-downtime migration techniques using Kubernetes native sidecar containers, lifecycle hooks, and graceful connection draining.

## Overview

This demo showcases how to achieve zero-downtime deployments using:

- **Native Sidecar Containers**: Envoy proxy as a native sidecar for traffic routing
- **Lifecycle Hooks**: postStart and preStop hooks for graceful connection draining
- **Health Probes**: Comprehensive health monitoring for reliability
- **Traffic Splitting**: Gradual migration from ASG to Kubernetes workloads
- **Observability**: Prometheus and Grafana for monitoring and metrics

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Key Concepts](#key-concepts)
- [Accessing Services](#accessing-services)
- [Documentation](#documentation)
- [Project Structure](#project-structure)
- [References](#references)

## Prerequisites

Before running the demo, ensure you have the following tools installed:

### Required Tools

1. **Docker Desktop** (or Docker Engine) - Version 20.10+
2. **kubectl** - Version 1.24+
3. **Kind** - Version 0.20.0+ ([Installation guide](https://kind.sigs.k8s.io/docs/user/quick-start/#installation))
4. **Helm** - Version 3.0+ ([Installation guide](https://helm.sh/docs/intro/install/))
5. **siege** - Load testing tool (`brew install siege` on macOS)

### Optional Tools

- **cloud-provider-kind** - For LoadBalancer support via Gateway API (`brew install cloud-provider-kind`)

**Note**: You can also use [minikube](https://minikube.sigs.k8s.io/docs/start/) instead of Kind. Use minikube [ingress addon](https://minikube.sigs.k8s.io/docs/tutorials/nginx_tcp_udp_ingress/) to access your service.

### Quick Setup

Run the setup script to check and install prerequisites:

```bash
chmod +x setup.sh
./setup.sh
```

## Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd kubecon25-zero-downtime
```

### 2. Build the Demo Application

Build the Docker image locally:

```bash
cd monolith-demo-app
docker build -t monolith:v0.1.0 .
cd ..
```

**Note**: Make sure to update the image reference in `platform-services/web-app/base-manifest/deployment.yaml` to match your image name.

### 3. Deploy Everything

Run the complete deployment script:

```bash
chmod +x deploy-all.sh
./deploy-all.sh
```

This script will:

1. Create a Kind cluster named `zero-downtime` (or use existing if found)
2. Install Argo Rollouts and KEDA (if not already installed)
3. Deploy the web application workload with base configuration
4. Deploy the dataplane service (Envoy edge router)
5. Install Kubernetes Metrics Server
6. Deploy the observability stack (Prometheus + Grafana)
7. **(Optional)** Install cloud-provider-kind and Gateway API for LoadBalancer support

**Note**: The script will prompt you if an existing cluster is found - you can choose to delete it or continue with the existing cluster.

### 4. Verify Deployment

```bash
# Check pod status
kubectl get pods -n default
kubectl get pods -n monitoring

# Verify kubectl context
kubectl config current-context
# Should show: kind-zero-downtime
```

## Key Concepts

### Native Sidecar Containers

The Envoy proxy is implemented as a native sidecar using `restartPolicy: Always` in init containers. This ensures the sidecar doesn't block pod termination and has proper startup ordering.

**Learn more**: See [ARCHITECTURE.md](ARCHITECTURE.md#native-sidecar-containers)

### Lifecycle Hooks

- **postStart Hook**: Signals Envoy to accept connections when the app container starts
- **preStop Hook**: Gracefully drains connections before pod termination

**Learn more**: See [ARCHITECTURE.md](ARCHITECTURE.md#lifecycle-hooks)

### Health Probes

Comprehensive health monitoring for both Envoy and app containers:

- Envoy uses `/ready` endpoint on port 9901
- App uses `/health` endpoint on port 8000

**Learn more**: See [ARCHITECTURE.md](ARCHITECTURE.md#health-probes)

### Traffic Splitting

Gradual migration from ASG to Kubernetes workloads using Envoy's weighted load balancing:

- 99% ASG, 1% K8s (canary)
- 50% ASG, 50% K8s (validation)
- 100% K8s (full migration)

**Learn more**: See [ARCHITECTURE.md](ARCHITECTURE.md#traffic-splitting)

## Accessing Services

### Port-Forward (Always Available)

Port-forwarding works immediately without any additional setup:

```bash
# Main Application (via Dataplane)
kubectl port-forward -n default svc/platform-service 8080:80
# Visit: http://localhost:8080

# Grafana Dashboard
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Visit: http://localhost:3000 (admin/admin123)

# Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Visit: http://localhost:9090

# Envoy Admin Interface (Dataplane)
kubectl port-forward -n default svc/platform-service 9901:9901
# Visit: http://localhost:9901
```

### LoadBalancer via Gateway API (Optional)

For LoadBalancer IPs instead of port-forwarding, see [Gateway API Setup Guide](docs/GATEWAY_API.md).

**Quick Setup**: The `deploy-all.sh` script includes an optional step to install and configure cloud-provider-kind. When prompted, choose `y` to enable LoadBalancer support.

## Documentation

- **[EXPERIMENTS.md](EXPERIMENTS.md)** - Detailed experiment instructions

  - Applying lifecycle hooks
  - Load testing
  - Rollout update and shutdown monitoring
  - Traffic splitting migration (ASG → K8s)

- **[docs/GATEWAY_API.md](docs/GATEWAY_API.md)** - Gateway API setup guide

  - Installing Gateway API CRDs
  - Configuring cloud-provider-kind
  - Accessing services via LoadBalancer IPs

- **Component-Specific READMEs**:

  - [platform-services/web-app/README.md](platform-services/web-app/README.md) - Web application workload configuration
  - [platform-services/dataplane/README.md](platform-services/dataplane/README.md) - Dataplane service configuration
  - [observability/README.md](observability/README.md) - Observability stack configuration

## Project Structure

```text
kubecon25-zero-downtime/
├── platform-services/          # Platform services
│   ├── web-app/                # Web application workload
│   │   ├── base-manifest/       # Base deployment configuration
│   │   └── lifecycle-hooks/    # Lifecycle hook configurations
│   └── dataplane/              # Dataplane service in the Platform
│       ├── base-manifest/      # Base routing configuration
│       └── traffic-split/     # Traffic splitting configurations for ASG→K8s migration (only for reference)
├── monolith-demo-app/          # Demo application source code
├── observability/              # Prometheus and Grafana stack
├── ingress/                     # Gateway API manifests for LoadBalancer support
├── docs/                        # Additional documentation
│   └── GATEWAY_API.md          # Gateway API setup guide
├── EXPERIMENTS.md               # Detailed experiment instructions
├── deploy-all.sh                # Complete deployment script
└── setup.sh                     # Prerequisites setup script
```

## References

- [Kubernetes Native Sidecar Containers](https://kubernetes.io/blog/2023/08/25/native-sidecar-containers/)
- [Kubernetes Container Lifecycle Hooks](https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/)
- [Kustomize Documentation](https://kubectl.docs.kubernetes.io/references/kustomize/)
- [cloud-provider-kind Gateway API Support](https://github.com/kubernetes-sigs/cloud-provider-kind#gateway-api-support-alpha)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
