#!/bin/bash

# Deploy Observability Stack for Zero Downtime Migration Demo
# This script deploys Prometheus Stack with Envoy metrics collection

set -e

echo "🚀 Deploying Observability Stack..."

# Create monitoring namespace
echo "📦 Creating monitoring namespace..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Add Prometheus Community Helm repository
echo "📥 Adding Prometheus Community Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Deploy Prometheus Stack
echo "🔧 Deploying Prometheus Stack..."
# Using wrapper chart with --dependency-update to download dependencies on-the-fly
helm upgrade --install prometheus ./prometheus-stack \
  --namespace monitoring \
  --dependency-update \
  --wait \
  --timeout=10m

# Wait for Prometheus to be ready
echo "⏳ Waiting for Prometheus to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=300s

# Wait for Grafana to be ready
echo "⏳ Waiting for Grafana to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s

# Apply PodMonitor resources
echo "📊 Applying PodMonitor resources..."
kubectl apply -f envoy-metrics/

# Wait for PodMonitor resources to be created
echo "⏳ Waiting for PodMonitor resources to be created..."
sleep 10

# Verify PodMonitor targets are discovered
echo "🔍 Verifying PodMonitor targets are discovered..."
echo "Checking Prometheus targets..."

# Get Prometheus pod name
PROMETHEUS_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}')

# Check if targets are healthy (retry up to 5 times)
for i in {1..5}; do
  echo "Attempt $i/5: Checking Prometheus targets..."
  
  # Get targets from Prometheus API
  TARGETS=$(kubectl exec -n monitoring $PROMETHEUS_POD -- wget -qO- 'http://localhost:9090/api/v1/targets' 2>/dev/null || echo "")
  
  if [ -n "$TARGETS" ]; then
    # Check for Envoy targets
    ENVOY_TARGETS=$(echo "$TARGETS" | grep -o '"job":"[^"]*envoy[^"]*"' | wc -l)
    if [ "$ENVOY_TARGETS" -ge 2 ]; then
      echo "✅ Found $ENVOY_TARGETS Envoy targets in Prometheus"
      break
    else
      echo "⚠️  Found only $ENVOY_TARGETS Envoy targets, waiting..."
      sleep 15
    fi
  else
    echo "⚠️  Could not query Prometheus targets, waiting..."
    sleep 15
  fi
  
  if [ $i -eq 5 ]; then
    echo "❌ Warning: Could not verify all Envoy targets are healthy"
  fi
done

# Get access information
echo "✅ Observability Stack deployed successfully!"
echo ""
echo "🔗 Access Information:"
echo "  Prometheus: kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
echo "  Grafana:    kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
echo "  Grafana Login: admin / prom-operator"
echo ""
echo "📈 Envoy Metrics will be available at:"
echo "  - Prometheus Targets: http://localhost:9090/targets"
echo "  - Look for 'envoy-routing-service' and 'envoy-app-service' targets"
echo ""
echo "📊 Grafana Dashboards:"
echo "  - Envoy Retry & Response Code SLI Dashboard"
echo "  - Access at: http://localhost:3000"
echo ""
echo "🔧 Verification Commands:"
echo "  # Check PodMonitor resources:"
echo "  kubectl get podmonitors -n monitoring"
echo ""
echo "  # Check Prometheus targets:"
echo "  kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 &"
echo "  curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job | contains(\"envoy\"))'"
echo ""
echo "  # Check Grafana dashboards:"
echo "  kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &"
echo "  # Then visit http://localhost:3000 and look for 'Envoy Retry & Response Code SLI Dashboard'"
