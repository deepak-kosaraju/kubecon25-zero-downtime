# Dataplane Service

This directory contains the Envoy-based dataplane service that acts as a gateway to the web application. The dataplane service provides load balancing, health checking, and circuit breaking capabilities.

**Labels**:

- `app.kubernetes.io/component: envoyproxy`
- `app.kubernetes.io/system: platform-service`

## Purpose

The platform service serves as an envoyproxy that:

- Routes traffic to the core-web-global upstream
- Implements circuit breaking and retry policies
- Offers health checking and monitoring capabilities
- Enables zero-downtime deployments by managing traffic flow

## Architecture

```
Internet → LoadBalancer → DataPlane Envoy -> POD's
```

![Old Architecture](../../images/new-full-architecture.gif "Old Full Architecture")

## Usage

### Deploy the Dataplane envoyproxy

```bash
cd platform-service
kubectl apply -k base-manifest
```

### Check Service Status

```bash
# Get service details
kubectl get svc dataplane-platform-service

# Get pod status
kubectl get pods -l app.kubernetes.io/component=envoyproxy,app.kubernetes.io/system=platform-service

# Check Envoy admin interface
kubectl port-forward svc/platform-service 9901:9901
curl http://localhost:9901/ready
```

### Test Traffic Routing

```bash
# Get LoadBalancer IP
kubectl get svc dataplane-platform-service

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

### Debug Commands

```bash
# Check dataplane service logs
kubectl logs -l app.kubernetes.io/component=envoyproxy,app.kubernetes.io/system=platform-service

# Check upstream service
kubectl get svc core-web-global

# Test DNS resolution
kubectl exec -l app.kubernetes.io/component=envoyproxy,app.kubernetes.io/system=platform-service -- nslookup core-web-global.default.svc.cluster.local

# Check Envoy configuration
kubectl exec -l app.kubernetes.io/component=envoyproxy,app.kubernetes.io/system=platform-service -- curl http://localhost:9901/config_dump
```

## Future Enhancements

- **TLS Termination**: Add SSL/TLS support
- **Rate Limiting**: Implement request rate limiting
- **Authentication**: Add authentication and authorization
- **Metrics**: Integrate with Prometheus for metrics collection
- **Tracing**: Add distributed tracing support
