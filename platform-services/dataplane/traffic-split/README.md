# Traffic Splitting Configuration

This directory contains Envoy configurations for splitting traffic between ASG (Auto Scaling Group) and K8s workloads during zero-downtime migration.

## Architecture

```
Internet → LoadBalancer → Routing Service (Envoy) → Traffic Split
                                                      ├── ASG Web Pool (X%)
                                                      └── K8s Web Pool (Y%)
```

## Traffic Split Iterations

### 1. 99% ASG, 1% K8s (`99-asg-1-k8s/`)

**Purpose**: Initial canary deployment with minimal K8s traffic

**Configuration**:
- ASG Web Pool: `load_balancing_weight: 99`
- K8s Web Pool: `load_balancing_weight: 1`

**Usage**:
```bash
cd 99-asg-1-k8s
kubectl apply -k .
```

### 2. 95% ASG, 5% K8s (`95-asg-5-k8s/`)

**Purpose**: Increased K8s traffic for validation

**Configuration**:
- ASG Web Pool: `load_balancing_weight: 95`
- K8s Web Pool: `load_balancing_weight: 5`

**Usage**:
```bash
cd 95-asg-5-k8s
kubectl apply -k .
```

## How It Works

### Envoy Locality Weighted Load Balancing

Based on [Envoy's locality weighted load balancing documentation](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/upstream/load_balancing/locality_weight), the traffic split is achieved using:

1. **Load Balancing Weight**: Each endpoint has a `load_balancing_weight` that determines traffic distribution
2. **Weighted Round-Robin**: Envoy uses weighted round-robin scheduling to distribute requests
3. **Health-Aware Adjustment**: Weights are adjusted based on endpoint health

### Traffic Distribution Formula

```
traffic_to_endpoint = (endpoint_weight / total_weights) * 100%
```

**Examples**:
- 99% ASG, 1% K8s: `99/(99+1) = 99%` and `1/(99+1) = 1%`
- 95% ASG, 5% K8s: `95/(95+5) = 95%` and `5/(95+5) = 5%`

## Service Dependencies

### ASG Web Pool Service
- **Name**: `asg-web-pool`
- **Namespace**: `default` (from `asg-ec2-app-stack/`)
- **Port**: `80`
- **Purpose**: Simulates existing ASG infrastructure

### K8s Web Pool Service  
- **Name**: `monolith-web-general-pool`
- **Namespace**: `zerodt-demo`
- **Port**: `80`
- **Purpose**: New Kubernetes-based workload

## Monitoring Traffic Split

### Envoy Admin Interface

```bash
# Port forward to Envoy admin
kubectl port-forward -n zerodt-demo svc/dataplane-platform-service 9901:9901

# Check cluster statistics
curl http://localhost:9901/clusters

# Check load balancing weights
curl http://localhost:9901/config_dump | jq '.configs[2].dynamic_route_configs[0].route_config.virtual_hosts[0].routes[0].route.weighted_clusters'
```

### Key Metrics to Monitor

1. **Request Distribution**: Verify traffic split matches configured weights
2. **Response Times**: Compare performance between ASG and K8s
3. **Error Rates**: Monitor error rates for both endpoints
4. **Health Status**: Ensure both endpoints are healthy

## Deployment Strategy

### Phase 1: Initial Canary (99% ASG, 1% K8s)
1. Deploy K8s workload alongside existing ASG
2. Apply 99% ASG, 1% K8s traffic split
3. Monitor K8s workload performance and stability
4. Validate application functionality

### Phase 2: Increased Validation (95% ASG, 5% K8s)
1. Increase K8s traffic to 5%
2. Monitor system performance under higher load
3. Validate scaling behavior
4. Check error rates and response times

### Phase 3: Gradual Migration (Future)
- 80% ASG, 20% K8s
- 50% ASG, 50% K8s
- 20% ASG, 80% K8s
- 0% ASG, 100% K8s

## Troubleshooting

### Common Issues

1. **Service Not Found**: Ensure both ASG and K8s services are running
2. **DNS Resolution**: Verify service names are resolvable
3. **Health Check Failures**: Check endpoint health status
4. **Traffic Not Splitting**: Verify load balancing weights are applied

### Debug Commands

```bash
# Check service status
kubectl get svc asg-web-pool
kubectl get svc -n zerodt-demo monolith-web-general-pool

# Check Envoy configuration
kubectl exec -n zerodt-demo -l app.kubernetes.io/component=dataplane -- curl http://localhost:9901/config_dump

# Test DNS resolution
kubectl exec -n zerodt-demo -l app.kubernetes.io/component=dataplane -- nslookup asg-web-pool
kubectl exec -n zerodt-demo -l app.kubernetes.io/component=dataplane -- nslookup monolith-web-general-pool.zerodt-demo.svc.cluster.local
```

## References

- [Envoy Locality Weighted Load Balancing](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/upstream/load_balancing/locality_weight)
- [Envoy Load Balancing Policies](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/upstream/load_balancing/load_balancing_policies)
- [Zero-Downtime Migration Strategies](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#rolling-update-deployment)
