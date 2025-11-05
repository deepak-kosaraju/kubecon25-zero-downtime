#!/bin/bash

# Verify Observability Stack Setup
# This script verifies that PodMonitor resources are working and dashboards are available

set -e

echo "🔍 Verifying Observability Stack Setup..."

# Check if monitoring namespace exists
echo "📦 Checking monitoring namespace..."
if kubectl get namespace monitoring >/dev/null 2>&1; then
    echo "✅ monitoring namespace exists"
else
    echo "❌ monitoring namespace not found"
    exit 1
fi

# Check PodMonitor resources
echo "📊 Checking PodMonitor resources..."
PODMONITORS=$(kubectl get podmonitors -n monitoring --no-headers | wc -l)
if [ "$PODMONITORS" -ge 2 ]; then
    echo "✅ Found $PODMONITORS PodMonitor resources"
    kubectl get podmonitors -n monitoring
else
    echo "❌ Expected at least 2 PodMonitor resources, found $PODMONITORS"
    exit 1
fi

# Check Prometheus targets
echo "🎯 Checking Prometheus targets..."
PROMETHEUS_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$PROMETHEUS_POD" ]; then
    echo "📡 Querying Prometheus targets..."
    
    # Get targets from Prometheus API
    TARGETS=$(kubectl exec -n monitoring $PROMETHEUS_POD -- wget -qO- 'http://localhost:9090/api/v1/targets' 2>/dev/null || echo "")
    
    if [ -n "$TARGETS" ]; then
        # Count Envoy targets
        ENVOY_TARGETS=$(echo "$TARGETS" | grep -o '"job":"[^"]*envoy[^"]*"' | wc -l)
        echo "✅ Found $ENVOY_TARGETS Envoy targets in Prometheus"
        
        # Show Envoy targets
        echo "📋 Envoy targets:"
        echo "$TARGETS" | jq -r '.data.activeTargets[] | select(.labels.job | contains("envoy")) | "  - \(.labels.job): \(.health)"' 2>/dev/null || echo "  (jq not available, raw output above)"
    else
        echo "❌ Could not query Prometheus targets"
        exit 1
    fi
else
    echo "❌ Prometheus pod not found"
    exit 1
fi

# Check Grafana dashboards
echo "📊 Checking Grafana dashboards..."
DASHBOARD_CM=$(kubectl get configmap -n monitoring -l grafana_dashboard=1 --no-headers | wc -l)
if [ "$DASHBOARD_CM" -ge 1 ]; then
    echo "✅ Found $DASHBOARD_CM Grafana dashboard ConfigMaps"
    kubectl get configmap -n monitoring -l grafana_dashboard=1
else
    echo "❌ No Grafana dashboard ConfigMaps found"
    exit 1
fi

# Check Grafana pod
echo "📈 Checking Grafana pod..."
GRAFANA_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$GRAFANA_POD" ]; then
    echo "✅ Grafana pod found: $GRAFANA_POD"
else
    echo "❌ Grafana pod not found"
    exit 1
fi

echo ""
echo "🎉 Observability Stack Verification Complete!"
echo ""
echo "🔗 Access Information:"
echo "  Prometheus: kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
echo "  Grafana:    kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
echo "  Grafana Login: admin / prom-operator"
echo ""
echo "📊 Available Dashboards:"
echo "  - Envoy Retry & Response Code SLI Dashboard"
echo "  - Access at: http://localhost:3000"
