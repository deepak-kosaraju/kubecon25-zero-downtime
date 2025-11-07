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

- **Routing Envoy**: Routing service metrics
- **App Envoy**: Application-side Envoy metrics

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
- **Upstream Health**: `envoy_cluster_upstream_cx_active`

## 🔧 Configuration

### Prometheus Scrape Configs

The Prometheus configuration includes specific scrape jobs for:

- `routing-envoy-metrics`: Edge routing Envoy metrics
- `web-envoy-metrics`: Application Envoy metrics  

## 🔍 Troubleshooting

### Check Prometheus Targets

```bash
# Access Prometheus UI
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Go to Status > Targets
```

## 📚 References

- [Prometheus Community Helm Charts](https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack)
- [Envoy Metrics Documentation](https://www.envoyproxy.io/docs/envoy/latest/configuration/upstream/cluster_manager/cluster_stats)
- [Grafana](https://grafana.com/docs/grafana/latest/)
