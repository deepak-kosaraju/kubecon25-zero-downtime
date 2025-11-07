# Dataplane Service

This directory contains the Envoy-based dataplane service that acts as a gateway to the web application. The dataplane service provides load balancing, health checking, and circuit breaking capabilities.

**Labels**:

- `app.kubernetes.io/component: envoyproxy`
- `app.kubernetes.io/system: platform-service`

## Purpose

The platform service serves as an external gateway that:

- Routes traffic to the monolith backend service
- Provides load balancing across multiple monolith instances
- Implements circuit breaking and retry policies
- Offers health checking and monitoring capabilities
- Enables zero-downtime deployments by managing traffic flow

## Architecture

```
Internet → LoadBalancer → DataPlane Envoy -> POD's
```

![Old Architecture](../images/old-full-architecture.gif "Old Full Architecture")

## Usage

### Deploy the Dataplane envoyproxy

```bash
cd platform-service
kubectl apply -k dataplane/
```

### Check Service Status

```bash
# Get service details
kubectl get svc platform-service

# Get pod status
kubectl get pods -l app.kubernetes.io/component=envoyproxy,app.kubernetes.io/system=platform-service

# Check Envoy admin interface
kubectl port-forward svc/platform-service 9901:9901
curl http://localhost:9901/ready
```

### Test Traffic Routing

```bash
# Get LoadBalancer IP
kubectl get svc platform-service

# Test dataplane (replace EXTERNAL-IP with actual IP)
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
kubectl port-forward svc/platform-service 9901:9901

# Check cluster health
curl http://localhost:9901/clusters

# Check server info
curl http://localhost:9901/server_info

# Check stats
curl http://localhost:9901/stats
```

### Health Checks

The platform service performs health checks on the backend:

- **Path**: `/health`
- **Interval**: 10s
- **Timeout**: 1s
- **Unhealthy Threshold**: 3
- **Healthy Threshold**: 2

## Integration with Zero-Downtime Migration

The platform service plays a crucial role in zero-downtime deployments:

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
# Check dataplane service logs
kubectl logs -l app.kubernetes.io/component=envoyproxy,app.kubernetes.io/system=platform-service

# Check backend service
kubectl get svc web-global

# Test DNS resolution
kubectl exec -l app.kubernetes.io/component=envoyproxy,app.kubernetes.io/system=platform-service -- nslookup web-global.default.svc.cluster.local

# Check Envoy configuration
kubectl exec -l app.kubernetes.io/component=envoyproxy,app.kubernetes.io/system=platform-service -- curl http://localhost:9901/config_dump
```

## Future Enhancements

- **TLS Termination**: Add SSL/TLS support
- **Rate Limiting**: Implement request rate limiting
- **Authentication**: Add authentication and authorization
- **Metrics**: Integrate with Prometheus for metrics collection
- **Tracing**: Add distributed tracing support
