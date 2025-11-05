# Prometheus Stack Wrapper Chart

This is a wrapper chart for `kube-prometheus-stack` that adds custom templates (e.g., custom Grafana dashboards).

### Prerequisites

1. Add the Prometheus Community Helm repository:

   ```bash
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm repo update
   ```

### Deployment Options

```bash
helm upgrade --install prometheus ./prometheus-stack \
  --namespace monitoring \
  --dependency-update \
  --values values.yaml
```

### Troubleshooting

#### Dependencies Not Downloading

If dependencies fail to download, ensure the repository is added and updated:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

#### Chart Validation

To validate the chart without deploying:

```bash
helm lint ./prometheus-stack --dependency-update
```

#### Template Debugging

To see rendered templates:

```bash
helm template prometheus ./prometheus-stack \
  --namespace monitoring \
  --dependency-update \
  --values values.yaml \
  --debug
```
