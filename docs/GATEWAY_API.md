# Gateway API Setup with cloud-provider-kind

This guide explains how to set up LoadBalancer support using Gateway API and cloud-provider-kind for accessing services without port-forwarding.

## Overview

Instead of using port-forwarding, you can use LoadBalancer IPs with Gateway API. This provides a more production-like experience where services are accessible via stable IP addresses.

## Prerequisites

1. **cloud-provider-kind** installed
   - For macOS: `brew install cloud-provider-kind`
   - For Linux: Follow [cloud-provider-kind installation](https://github.com/kubernetes-sigs/cloud-provider-kind)

2. **Kubernetes cluster** (Kind or Minikube)

## Setup Steps

### Step 1: Install Gateway API CRDs

Install the Gateway API CRDs (v1.4.0):

```bash
kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml
```

Wait for CRDs to be ready:

```bash
kubectl wait --for condition=established --timeout=60s crd/gateways.gateway.networking.k8s.io
kubectl wait --for condition=established --timeout=60s crd/httproutes.gateway.networking.k8s.io
```

### Step 2: Apply Gateway API Manifest

Apply the Gateway API manifest:

```bash
kubectl apply -f ingress/gateway-api.yaml
```

This creates:

- A `Gateway` resource named `zerodt-demo-gateway`
- Multiple `HTTPRoute` resources for different services

### Step 3: Run cloud-provider-kind

In a separate terminal, run cloud-provider-kind:

```bash
sudo cloud-provider-kind --gateway-channel standard
```

**Note**:

- On macOS, you must run this with `sudo`
- This command needs to run continuously to provide LoadBalancer functionality
- Keep this terminal open while using LoadBalancer services

### Step 4: Check Gateway Status

Wait for the Gateway to receive an IP address:

```bash
kubectl get gateway zerodt-demo-gateway
```

The output should look like:

```text
NAME                  CLASS                 ADDRESS       PROGRAMMED   AGE
zerodt-demo-gateway   cloud-provider-kind   192.168.x.x   True         2m
```

Wait until the `ADDRESS` field is populated and `PROGRAMMED` is `True`.

### Step 5: Access Services via LoadBalancer IP

Once the Gateway has an ADDRESS, you can access services directly:

- **Main Application**: `http://<GATEWAY-ADDRESS>/`
- **Grafana**: `http://<GATEWAY-ADDRESS>:3000/`
- **Prometheus**: `http://<GATEWAY-ADDRESS>:9090/`
- **Envoy Admin**: `http://<GATEWAY-ADDRESS>:9901/`

Replace `<GATEWAY-ADDRESS>` with the IP address from `kubectl get gateway`.

## Gateway Configuration

The Gateway is configured with multiple listeners:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: zerodt-demo-gateway
spec:
  gatewayClassName: cloud-provider-kind
  listeners:
  - protocol: HTTP
    port: 80
    name: main-app
  - protocol: HTTP
    port: 9901
    name: envoy
  - protocol: HTTP
    port: 3000
    name: grafana
  - protocol: HTTP
    port: 9090
    name: prometheus
```

Each listener routes to different services via HTTPRoute resources.

## HTTPRoute Configuration

HTTPRoutes define how traffic is routed from the Gateway to backend services:

- **main-app-route**: Routes port 80 traffic to `web-global` service
- **envoy-route**: Routes port 9901 traffic to Envoy admin interface
- **grafana-route**: Routes port 3000 traffic to Grafana service
- **prometheus-route**: Routes port 9090 traffic to Prometheus service

## Monitoring Gateway Status

### Check Gateway Status

```bash
kubectl get gateway zerodt-demo-gateway
kubectl describe gateway zerodt-demo-gateway
```

### Check HTTPRoute Status

```bash
kubectl get httproute -A
kubectl describe httproute main-app-route
```

### Check LoadBalancer Container

cloud-provider-kind creates Envoy containers for each LoadBalancer:

```bash
docker ps | grep kindccm
```

## Troubleshooting

### Gateway Not Getting IP Address

1. **Check cloud-provider-kind is running**:

   ```bash
   ps aux | grep cloud-provider-kind
   ```

2. **Check Gateway status**:

   ```bash
   kubectl describe gateway zerodt-demo-gateway
   ```

3. **Check for errors in cloud-provider-kind logs**:

   Review the terminal where cloud-provider-kind is running

### Services Not Accessible

1. **Verify Gateway has IP**:

   ```bash
   kubectl get gateway zerodt-demo-gateway
   ```

2. **Check HTTPRoute status**:

   ```bash
   kubectl get httproute -A
   kubectl describe httproute main-app-route
   ```

3. **Verify backend services are running**:

   ```bash
   kubectl get svc web-global
   kubectl get pods -l app.kubernetes.io/component=web,app.kubernetes.io/system=platform-service
   ```

### Port Mapping Issues (macOS/Windows)

On macOS and Windows, cloud-provider-kind uses Docker port mapping. Check the mapped ports:

```bash
docker ps | grep kindccm
```

The output shows port mappings like:

```text
0.0.0.0:42381->80/tcp
```

Use the mapped port (e.g., `42381`) instead of the LoadBalancer port (e.g., `80`).

## Automatic Setup

The `deploy-all.sh` script includes an optional step to install and configure cloud-provider-kind. When prompted, choose `y` to enable LoadBalancer support.

## Reference

For more details, see [cloud-provider-kind Gateway API support](https://github.com/kubernetes-sigs/cloud-provider-kind#gateway-api-support-alpha)
