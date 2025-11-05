# Observability Stack for Zero Downtime Migration Demo

This directory contains the observability setup for monitoring the zero-downtime migration demo using Prometheus Stack.

## 📊 Components

### Prometheus Stack

- **Prometheus**: Metrics collection and storage
- **Grafana**: Metrics visualization and dashboards
- **AlertManager**: Alerting and notifications
- **Node Exporter**: Node-level metrics
- **Kube State Metrics**: Kubernetes cluster metrics

### Envoy Metrics Collection

- **Routing Envoy**: Edge routing service metrics
- **App Envoy**: Application-side Envoy metrics
- **FastAPI**: Application metrics

## 🚀 Quick Start

### Deploy the Observability Stack

```bash
# Deploy everything
./deploy-observability.sh

# Or deploy manually
kubectl create namespace monitoring
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values prometheus-stack/values.yaml \
  --wait
```

### Access the Services

```bash
# Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Login: admin / admin123
```

## 📈 Key Metrics

### Envoy Metrics

- **Request Rate**: `envoy_http_downstream_rq_total`
- **Response Time**: `envoy_http_downstream_rq_time`
- **Retry Attempts**: `envoy_cluster_upstream_rq_retry`
- **Circuit Breaker**: `envoy_cluster_circuit_breakers_*`
- **Upstream Health**: `envoy_cluster_upstream_cx_active`

### FastAPI Metrics

- **Request Count**: `http_requests_total`
- **Response Time**: `http_request_duration_seconds`
- **Active Connections**: `http_connections_active`

## 🔧 Configuration

### Prometheus Scrape Configs

The Prometheus configuration includes specific scrape jobs for:

- `envoy-routing-service`: Edge routing Envoy metrics
- `envoy-app-service`: Application Envoy metrics  
- `fastapi-app-metrics`: FastAPI application metrics

### ServiceMonitor Resources

- `routing-envoy-servicemonitor.yaml`: Monitors routing Envoy
- `app-envoy-servicemonitor.yaml`: Monitors app Envoy
- `fastapi-servicemonitor.yaml`: Monitors FastAPI app

## 📊 Grafana Dashboards

### Envoy Dashboards

- **Envoy Proxy Dashboard**: General Envoy metrics
- **Envoy Retry Dashboard**: Retry policy metrics
- **Envoy Circuit Breaker**: Circuit breaker status

### Application Dashboards

- **FastAPI Dashboard**: Application performance metrics
- **Zero Downtime Migration**: Custom dashboard for migration demo

## 🚨 Alerting

### Key Alerts

- **High Error Rate**: >5% 5xx responses
- **High Latency**: P95 > 1s
- **Retry Rate**: >10% requests retried
- **Circuit Breaker Open**: Upstream circuit breaker open

## 🔍 Troubleshooting

### Check Prometheus Targets

```bash
# Access Prometheus UI
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Go to Status > Targets
```

### Check ServiceMonitor Status

```bash
kubectl get servicemonitors -n zerodt-demo
kubectl describe servicemonitor routing-envoy-metrics -n zerodt-demo
```

### Check Envoy Metrics Endpoint

```bash
# Routing Envoy
curl http://localhost:8081/stats/prometheus

# App Envoy (if port-forwarded)
curl http://localhost:8080/stats/prometheus
```

## 📚 References

- [Prometheus Community Helm Charts](https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack)
- [Envoy Metrics Documentation](https://www.envoyproxy.io/docs/envoy/latest/configuration/upstream/cluster_manager/cluster_stats)
- [Grafana Envoy Dashboard](https://grafana.com/grafana/dashboards/7255)
