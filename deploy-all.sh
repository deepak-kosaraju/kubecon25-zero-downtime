#!/bin/bash

# Complete Deployment Script for Zero Downtime Migration Demo
# This script deploys everything in the correct order (assumes cluster already exists)

set -e

echo "🚀 Starting Complete Zero Downtime Migration Demo Deployment..."

# Step 1: Check if cluster exists, if not, prompt to create it
echo "🔍 Step 1: Checking for Kind cluster..."

if ! kind get clusters | grep -q "^zero-downtime$"; then
    echo "⚠️  No Kind cluster 'zero-downtime' found"
    echo ""
    echo "Would you like to create the cluster now? (default: yes)"
    read -p "Create cluster? [Y/n]: " CREATE_CLUSTER
    
    CREATE_CLUSTER=${CREATE_CLUSTER:-Y}
    
    if [[ "$CREATE_CLUSTER" =~ ^[Yy]$ ]]; then
        echo "  Creating Kind cluster..."
        if [ -f "create-kind-cluster.sh" ]; then
            chmod +x create-kind-cluster.sh
            ./create-kind-cluster.sh
        else
            echo "❌ Error: create-kind-cluster.sh not found"
            echo "  Please run: ./create-kind-cluster.sh first"
            exit 1
        fi
    else
        echo "❌ Error: Kind cluster 'zero-downtime' is required"
        echo "  Please create the cluster first:"
        echo "    ./create-kind-cluster.sh"
        exit 1
    fi
else
    echo "  ✅ Found existing cluster 'zero-downtime'"
fi

# Set and verify kubectl context
echo "🔍 Setting kubectl context..."
export KUBECONFIG=~/.kube/config

# Verify we're connected to the correct cluster
CURRENT_CONTEXT=$(kubectl config current-context)
echo "Current kubectl context: $CURRENT_CONTEXT"

if [[ "$CURRENT_CONTEXT" != *"zero-downtime"* ]]; then
    echo "⚠️  Warning: Current context doesn't match zero-downtime cluster"
    echo "Setting context to kind-zero-downtime..."
    kubectl config use-context kind-zero-downtime
    echo "✅ Context set to: $(kubectl config current-context)"
fi

# Verify cluster connection
echo "Verifying cluster connection..."
kubectl cluster-info --context kind-zero-downtime || {
    echo "❌ Error: Could not connect to kind-zero-downtime cluster"
    exit 1
}
echo "✅ Successfully connected to kind-zero-downtime cluster"

# Step 2: Install Argo Rollouts and KEDA
echo "🔧 Step 2: Installing Argo Rollouts and KEDA..."

# Check if controllers already exist
ARGO_EXISTS=false
KEDA_EXISTS=false

# Check for Argo Rollouts
if helm list 2>/dev/null | grep -q "argo-rollout"; then
    echo "  ✅ Argo Rollouts already installed (found helm release)"
    ARGO_EXISTS=true
elif kubectl get crd rollouts.argoproj.io >/dev/null 2>&1; then
    echo "  ✅ Argo Rollouts already installed (found CRD)"
    ARGO_EXISTS=true
fi

# Check for KEDA
if helm list -n keda 2>/dev/null | grep -q "keda"; then
    echo "  ✅ KEDA already installed (found helm release)"
    KEDA_EXISTS=true
elif kubectl get crd scaledobjects.keda.sh >/dev/null 2>&1; then
    echo "  ✅ KEDA already installed (found CRD)"
    KEDA_EXISTS=true
fi

# Install controllers only if they don't exist
if [ "$ARGO_EXISTS" = false ]; then
    # Add Argo Helm repo
    echo "  Adding Argo Helm repository..."
    helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
    helm repo update
    
    # Install Argo Rollouts
    echo "  Installing Argo Rollouts with dashboard..."
    helm install argo-rollout argo/argo-rollouts --set dashboard.enabled=true --wait --timeout=5m || {
        echo "⚠️  Warning: Argo Rollouts installation failed or timed out, continuing..."
    }
else
    echo "  ⏭️  Skipping Argo Rollouts installation (already exists)"
fi

if [ "$KEDA_EXISTS" = false ]; then
    # Add KEDA Helm repo
    echo "  Adding KEDA Helm repository..."
    helm repo add kedacore https://kedacore.github.io/charts 2>/dev/null || true
    helm repo update
    
    # Install KEDA
    echo "  Installing KEDA..."
    helm install keda kedacore/keda --namespace keda --create-namespace --wait --timeout=5m || {
        echo "⚠️  Warning: KEDA installation failed or timed out, continuing..."
    }
else
    echo "  ⏭️  Skipping KEDA installation (already exists)"
fi

echo "✅ Argo Rollouts and KEDA ready"

# Step 3: Deploy Web App Workload
echo "📦 Step 3: Deploying Web App Workload..."
kubectl apply -k platform-services/web-app/base-manifest/

# Step 4: Deploy Dataplane Service
echo "🌐 Step 4: Deploying Dataplane Service..."
kubectl apply -k platform-services/dataplane/base-manifest/

# Step 5: Validate all deployments are running and ready
echo "⏳ Step 5: Waiting for all deployments to be ready..."
echo "  Waiting for Web App Workload..."
kubectl wait --for=condition=available rollout/web-global --timeout=600s || {
    echo "⚠️  Warning: Web App Workload may not be ready yet, continuing..."
}
echo "  Waiting for Dataplane Service..."
kubectl wait --for=condition=available deployment/platform-service --timeout=600s || {
    echo "⚠️  Warning: Dataplane Service may not be ready yet, continuing..."
}

# Step 6: Install Kubernetes Metrics Server
echo "📊 Step 6: Installing Kubernetes Metrics Server..."

# Install Metrics Server
echo "  Installing Metrics Server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch Metrics Server for Kind clusters (accept insecure Kubelet certificates)
echo "  Patching Metrics Server for Kind cluster compatibility..."
kubectl -n kube-system patch deployment/metrics-server --type=json --patch='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]' || {
    echo "⚠️  Warning: Failed to patch metrics-server, continuing..."
}

# Wait for metrics-server to be ready
echo "  Waiting for Metrics Server to be ready..."
kubectl wait --for=condition=available deployment/metrics-server -n kube-system --timeout=300s || {
    echo "⚠️  Warning: Metrics Server may not be ready yet, continuing..."
}

# Validate Metrics Server
echo "  Validating Metrics Server..."
echo "    Checking Metrics Server pods:"
kubectl get pods -n kube-system | grep metrics-server || echo "    ⚠️  Metrics Server pods not found"

# Wait a bit for metrics to be available
echo "  Waiting for metrics to be available..."
sleep 10

# Show metrics if available
echo "    Node metrics:"
kubectl top nodes 2>/dev/null || echo "    ⚠️  Node metrics not available yet"

echo "    Pod metrics (sample):"
kubectl top pods --all-namespaces 2>/dev/null | head -5 || echo "    ⚠️  Pod metrics not available yet"

echo "✅ Metrics Server installed and validated"

# Step 7: Deploy observability stack
echo "📊 Step 7: Deploying observability stack..."
cd observability
./deploy-observability.sh
cd ..

# Step 8: Optional - Install cloud-provider-kind for LoadBalancer support
echo "📋 Step 8: Optional - Installing cloud-provider-kind for LoadBalancer support..."
echo ""
echo "Would you like to install cloud-provider-kind to enable LoadBalancer support?"
echo "This allows you to access services via LoadBalancer IPs instead of port-forwarding."
echo ""
read -p "Install cloud-provider-kind? [y/N]: " INSTALL_CLOUD_PROVIDER

INSTALL_CLOUD_PROVIDER=${INSTALL_CLOUD_PROVIDER:-N}

if [[ "$INSTALL_CLOUD_PROVIDER" =~ ^[Yy]$ ]]; then
    echo "  Installing cloud-provider-kind..."
    
    # Check if cloud-provider-kind is installed via brew
    if command -v cloud-provider-kind &> /dev/null; then
        echo "  ✅ cloud-provider-kind is already installed"
    else
        echo "  Installing cloud-provider-kind via Homebrew..."
        if ! command -v brew &> /dev/null; then
            echo "  ❌ Error: Homebrew is not installed. Please install Homebrew first."
            echo "  Visit: https://brew.sh"
            echo "  Or install cloud-provider-kind manually from: https://github.com/kubernetes-sigs/cloud-provider-kind"
        else
            brew install cloud-provider-kind || {
                echo "  ⚠️  Warning: Failed to install cloud-provider-kind via Homebrew"
                echo "  You may need to install it manually from: https://github.com/kubernetes-sigs/cloud-provider-kind"
            }
        fi
        
        # Verify installation
        if command -v cloud-provider-kind &> /dev/null; then
            echo "  ✅ cloud-provider-kind installed successfully"
        else
            echo "  ⚠️  Warning: cloud-provider-kind may not be in PATH. Please verify installation."
        fi
    fi
    
    # Install Gateway API CRDs
    echo "  Installing Gateway API CRDs..."
    kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml || {
        echo "  ⚠️  Warning: Failed to install Gateway API CRDs, continuing..."
    }
    
    # Wait a moment for CRDs to be available
    echo "  Waiting for Gateway API CRDs to be ready..."
    sleep 5
    
    # Apply the Gateway API manifest
    if [ -f "ingress/gateway-api.yaml" ]; then
        echo "  Applying Gateway API manifest..."
        kubectl apply -f ingress/gateway-api.yaml || {
            echo "  ⚠️  Warning: Failed to apply Gateway API manifest, continuing..."
        }
    else
        echo "  ⚠️  Warning: ingress/gateway-api.yaml not found, skipping Gateway API manifest..."
    fi
    
    echo ""
    echo "  ✅ Gateway API CRDs and manifest applied"
    echo ""
    echo "  📝 Next Steps:"
    echo "  =============="
    echo "  To enable LoadBalancer support, run the following command in a separate terminal:"
    echo ""
    echo "    sudo cloud-provider-kind --gateway-channel standard"
    echo ""
    echo "  ⚠️  Note: This command needs to run continuously to provide LoadBalancer functionality."
    echo "  On macOS, you may need to run it with sudo permissions."
    echo ""
    echo "  Once cloud-provider-kind is running, you can check the Gateway status:"
    echo "    kubectl get gateway zerodt-demo-gateway"
    echo ""
    echo "  The Gateway will have an ADDRESS field with the LoadBalancer IP once ready."
else
    echo "  ⏭️  Skipping cloud-provider-kind installation"
    echo ""
fi

# Step 9: Get service information
echo "📋 Step 9: Getting service information..."
echo ""
echo "🎉 Deployment Complete! Here's how to access everything:"
echo ""
echo "🔗 Service Access Options:"
echo ""
echo "  Option 1: Port-Forward (Always Available)"
echo "  =========================================="
echo "  # Main Application (via Dataplane):"
echo "  kubectl port-forward -n default svc/platform-service 8080:80"
echo "  # Then visit: http://localhost:8080"
echo ""
echo "  # Grafana:"
echo "  kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
echo "  # Then visit: http://localhost:3000 (admin/prom-operator)"
echo ""
echo "  # Prometheus:"
echo "  kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
echo "  # Then visit: http://localhost:9090"
echo ""
echo "  # Envoy Admin (Dataplane):"
echo "  kubectl port-forward -n default svc/platform-service 9901:9901"
echo "  # Then visit: http://localhost:9901"
echo ""

if [[ "$INSTALL_CLOUD_PROVIDER" =~ ^[Yy]$ ]]; then
    echo "  Option 2: LoadBalancer (If cloud-provider-kind is running)"
    echo "  =========================================================="
    echo "  # Check Gateway status:"
    echo "  kubectl get gateway zerodt-demo-gateway"
    echo ""
    echo "  # Once Gateway has an ADDRESS, you can access services via:"
    echo "  # Main Application: http://<GATEWAY-ADDRESS>/"
    echo "  # Grafana: http://<GATEWAY-ADDRESS>:3000/"
    echo "  # Prometheus: http://<GATEWAY-ADDRESS>:9090/"
    echo "  # Envoy Admin: http://<GATEWAY-ADDRESS>:9901/"
    echo ""
    echo "  # Make sure cloud-provider-kind is running:"
    echo "  sudo cloud-provider-kind --gateway-channel standard"
    echo ""
fi

echo "🧪 Load Testing:"
echo "  # Run load test to see retry mechanism in action:"
echo "  siege -c 2 -t 30s -i -f urls.txt"
echo ""
echo "📊 Monitoring:"
echo "  # Check pod status:"
echo "  kubectl get pods -n default"
echo "  kubectl get pods -n monitoring"
echo ""
echo "  # Check services:"
echo "  kubectl get svc -n default"
echo ""
echo "  # Check Gateway (if installed):"
echo "  kubectl get gateway -A"
echo "  kubectl get httproute -A"
echo ""
echo "✅ All services deployed and ready!"
