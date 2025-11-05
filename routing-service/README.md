# Routing Service

This directory contains the Envoy-based routing service that acts as a gateway to the monolith application. The routing service provides load balancing, health checking, and circuit breaking capabilities.

## Purpose

The routing service serves as an external gateway that:

- Routes traffic to the monolith backend service
- Provides load balancing across multiple monolith instances
- Implements circuit breaking and retry policies
- Offers health checking and monitoring capabilities
- Enables zero-downtime deployments by managing traffic flow

## Architecture

```
Internet → LoadBalancer → Routing Service (Envoy) → Monolith ALB → Monolith Pods
```

![Old Architecture](../arc-images/old-full-architecture.gif "Old Full Architecture")

## Configuration

### Envoy Configuration (`envoy.yaml`)

**Key Features**:

- **Admin Interface**: Port 9901 for health checks and monitoring
- **HTTP Listener**: Port 80 for incoming traffic
- **Backend Cluster**: Routes to `monolith-web-general-pool.zerodt-demo.svc.cluster.local:80`
- **Load Balancing**: LEAST_REQUEST policy for optimal distribution
- **Circuit Breaking**: Prevents cascading failures
- **Health Checks**: Monitors backend health via `/health` endpoint
- **Retry Policy**: Automatic retry on failures with exponential backoff

**Circuit Breaker Settings**:

- Max Connections: 1000
- Max Pending Requests: 1000
- Max Requests: 1000
- Max Retries: 3

**Retry Policy**:

- Retry on: 5xx, reset, connect-failure, refused-stream
- Number of retries: 3
- Per-try timeout: 5s
- Total timeout: 30s

### Deployment Configuration

**Resource Limits**:

- CPU: 200m limit, 100m request
- Memory: 200Mi limit, 100Mi request

**Health Probes**:

- **Liveness**: HTTP GET `/ready` on port 9901
- **Readiness**: HTTP GET `/ready` on port 9901
- **Startup**: HTTP GET `/ready` on port 9901 with longer timeout

**Scaling**:

- Replicas: 2 (for high availability)
- Rolling Update: 50% max surge, 50% max unavailable

### Service Configuration

**Service Type**: LoadBalancer

- **HTTP Port**: 80 → 80
- **Admin Port**: 9901 → 9901

## Usage

### Deploy the Routing Service

```bash
cd routing-service
kubectl apply -k .
```

### Check Service Status

```bash
# Get service details
kubectl get svc -n zerodt-demo routing-routing-service

# Get pod status
kubectl get pods -n zerodt-demo -l app.kubernetes.io/component=routing

# Check Envoy admin interface
kubectl port-forward -n zerodt-demo svc/routing-routing-service 9901:9901
curl http://localhost:9901/ready
```

### Test Traffic Routing

```bash
# Get LoadBalancer IP
kubectl get svc -n zerodt-demo routing-routing-service

# Test routing (replace EXTERNAL-IP with actual IP)
curl http://EXTERNAL-IP/health
curl http://EXTERNAL-IP/companies
curl http://EXTERNAL-IP/projects
```

## Monitoring

### Envoy Admin Interface

Access the admin interface to monitor:

- Cluster health and statistics
- Request metrics and rates
- Circuit breaker status
- Connection pools

```bash
# Port forward to admin interface
kubectl port-forward -n zerodt-demo svc/routing-routing-service 9901:9901

# Check cluster health
curl http://localhost:9901/clusters

# Check server info
curl http://localhost:9901/server_info

# Check stats
curl http://localhost:9901/stats
```

### Health Checks

The routing service performs health checks on the backend:

- **Path**: `/health`
- **Interval**: 10s
- **Timeout**: 1s
- **Unhealthy Threshold**: 3
- **Healthy Threshold**: 2

## Integration with Zero-Downtime Migration

The routing service plays a crucial role in zero-downtime deployments:

1. **Traffic Management**: Routes traffic to healthy backend instances
2. **Health Monitoring**: Continuously monitors backend health
3. **Circuit Breaking**: Prevents traffic to unhealthy instances
4. **Load Balancing**: Distributes load across available instances
5. **Retry Logic**: Handles temporary failures gracefully

## Troubleshooting

### Common Issues

1. **Backend Unreachable**: Check if monolith service is running
2. **Health Check Failures**: Verify `/health` endpoint is accessible
3. **Circuit Breaker Open**: Check backend service health
4. **DNS Resolution**: Ensure service names are resolvable

### Debug Commands

```bash
# Check routing service logs
kubectl logs -n zerodt-demo -l app.kubernetes.io/component=routing

# Check backend service
kubectl get svc -n zerodt-demo monolith-web-general-pool

# Test DNS resolution
kubectl exec -n zerodt-demo -l app.kubernetes.io/component=routing -- nslookup monolith-web-general-pool.zerodt-demo.svc.cluster.local

# Check Envoy configuration
kubectl exec -n zerodt-demo -l app.kubernetes.io/component=routing -- curl http://localhost:9901/config_dump
```

## Future Enhancements

- **TLS Termination**: Add SSL/TLS support
- **Rate Limiting**: Implement request rate limiting
- **Authentication**: Add authentication and authorization
- **Metrics**: Integrate with Prometheus for metrics collection
- **Tracing**: Add distributed tracing support
