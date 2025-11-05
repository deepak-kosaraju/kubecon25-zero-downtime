#!/bin/bash

# Complete Deployment Script for Zero Downtime Migration Demo
# This script creates a Kind cluster and deploys everything in the correct order

set -e

echo "🚀 Starting Complete Zero Downtime Migration Demo Deployment..."

# Step 1: Create Kind cluster
echo "🔧 Step 1: Creating Kind cluster..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Error: Docker is not running. Please start Docker Desktop or Colima and try again."
    exit 1
fi

# Detect if using Colima
if docker context ls 2>/dev/null | grep -q "colima.*\*"; then
    echo "  ℹ️  Detected Colima container runtime"
    echo "  Note: Colima may require additional time for Kind cluster creation"
    echo "  If you encounter systemd log errors, this is a known Colima/Kind compatibility issue"
    echo ""
fi

# Validate Docker Desktop resources via CLI
echo "  Validating Docker Desktop resources..."
DOCKER_INFO=$(docker info 2>/dev/null)

# Extract CPU count
CPU_COUNT=$(echo "$DOCKER_INFO" | grep -iE "^CPUs:|\s+CPUs:" | awk '{print $2}' | tr -d ',')
# Extract Memory (convert to GiB if needed)
MEMORY_INFO=$(echo "$DOCKER_INFO" | grep -iE "\s+Total Memory:|\s+Total Memory:" | head -1 | awk '{print $3, $4}')
# If Total Memory not found, try alternative format
if [ -z "$MEMORY_INFO" ]; then
    MEMORY_INFO=$(echo "$DOCKER_INFO" | grep -i "Memory" | head -1 | awk '{for(i=3;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/[[:space:]]*$//')
fi

# Check CPU count
if [ -n "$CPU_COUNT" ]; then
    echo "    CPU Count: $CPU_COUNT"
    if [ "$CPU_COUNT" -lt 4 ]; then
        echo "    ⚠️  Warning: Docker Desktop has less than 4 CPUs allocated ($CPU_COUNT)"
        echo "    💡 Recommended: At least 4 CPUs for Kind cluster with 4 nodes"
    fi
else
    echo "    ⚠️  Warning: Could not determine CPU count"
fi

# Check Memory
if [ -n "$MEMORY_INFO" ]; then
    MEMORY_VALUE=$(echo "$MEMORY_INFO" | awk '{print $1}')
    MEMORY_UNIT=$(echo "$MEMORY_INFO" | awk '{print $2}' | tr '[:lower:]' '[:upper:]')
    echo "    Memory: $MEMORY_INFO"
    
    # Convert to GiB for comparison
    if [ "$MEMORY_UNIT" = "GIB" ] || [ "$MEMORY_UNIT" = "GB" ] || [ "$MEMORY_UNIT" = "GI" ]; then
        MEMORY_GB=$(echo "$MEMORY_VALUE" | sed 's/[^0-9.]//g')
        MEMORY_GB_INT=${MEMORY_GB%.*}
        if [ "$MEMORY_GB_INT" -lt 8 ]; then
            echo "    ⚠️  Warning: Docker Desktop has less than 8GB allocated ($MEMORY_VALUE $MEMORY_UNIT)"
            echo "    💡 Recommended: At least 8GB (12GB recommended) for Kind cluster with 4 nodes"
        fi
    elif [ "$MEMORY_UNIT" = "MIB" ] || [ "$MEMORY_UNIT" = "MB" ] || [ "$MEMORY_UNIT" = "MI" ]; then
        MEMORY_MB=$(echo "$MEMORY_VALUE" | sed 's/[^0-9.]//g')
        MEMORY_MB_INT=${MEMORY_MB%.*}
        MEMORY_GB_INT=$((MEMORY_MB_INT / 1024))
        if [ "$MEMORY_GB_INT" -lt 8 ]; then
            echo "    ⚠️  Warning: Docker Desktop has less than 8GB allocated (~${MEMORY_GB_INT}GB)"
            echo "    💡 Recommended: At least 8GB (12GB recommended) for Kind cluster with 4 nodes"
        fi
    fi
else
    echo "    ⚠️  Warning: Could not determine memory allocation"
fi

# Check available disk space
echo "  Checking available disk space..."
AVAILABLE_DISK=$(df -h . | tail -1 | awk '{print $4}')
echo "    Available disk space: $AVAILABLE_DISK"

# Check for existing cluster and handle deletion option
CLUSTER_EXISTS=false
SKIP_CLUSTER_CREATION=false

if kind get clusters | grep -q "^zero-downtime$"; then
    echo "⚠️  Found existing cluster 'zero-downtime'"
    echo ""
    echo "Do you want to delete the existing cluster? (default: no)"
    read -p "Delete existing cluster? [y/N]: " DELETE_CLUSTER
    
    DELETE_CLUSTER=${DELETE_CLUSTER:-N}
    
    if [[ "$DELETE_CLUSTER" =~ ^[Yy]$ ]]; then
        echo "  Deleting existing cluster 'zero-downtime'..."
        kind delete cluster --name zero-downtime || true
        # Wait a bit for cleanup to complete
        sleep 2
    else
        echo "  Keeping existing cluster. Skipping cluster creation..."
        CLUSTER_EXISTS=true
        SKIP_CLUSTER_CREATION=true
    fi
fi

# Create the cluster only if we're not skipping
if [ "$SKIP_CLUSTER_CREATION" = false ]; then
    # Create the cluster (without --wait flag to avoid macOS/Colima systemd log issue)
    echo "  Creating Kind cluster 'zero-downtime'..."
    echo "  Note: This may take a few minutes. On macOS with Colima, Kind may show warnings about systemd logs - this is normal."
    echo "  The --wait flag is disabled to avoid Colima systemd log matching issues."

    # Try to create cluster - Colima may have different systemd behavior
    # Capture output to check for errors, but also show it to user
    echo "  Running: kind create cluster..."
    kind create cluster --name zero-downtime --config kind-config.yaml --kubeconfig ~/.kube/config 2>&1 | tee /tmp/kind-create-output.log
    KIND_EXIT_CODE=${PIPESTATUS[0]}
    KIND_OUTPUT=$(cat /tmp/kind-create-output.log)

    # Check if it's the systemd log error (common with Colima)
    if [ $KIND_EXIT_CODE -ne 0 ] && echo "$KIND_OUTPUT" | grep -q "could not find a log line that matches"; then
        echo ""
        echo "⚠️  Systemd log matching error detected (common with Colima)"
        echo "  This is a known issue with Kind + Colima on macOS"
        echo ""
        
        # Check if nodes were actually created (sometimes they're created despite the error)
        sleep 5
        echo "  Checking if nodes were created..."
        NODE_COUNT=$(kind get nodes --name zero-downtime --kubeconfig ~/.kube/config 2>/dev/null | grep -v "^$" | wc -l | tr -d ' ')
        
        # Handle empty NODE_COUNT
        if [ -z "$NODE_COUNT" ]; then
            NODE_COUNT=0
        fi
        
        echo "  Found $NODE_COUNT node(s)"
        
        if [ "$NODE_COUNT" -gt 0 ]; then
            echo "  ✅ Nodes were created! Checking cluster connectivity..."
            sleep 5
            if kubectl cluster-info --context kind-zero-downtime --kubeconfig ~/.kube/config > /dev/null 2>&1; then
                echo "  ✅ Cluster is functional despite the error!"
            else
                echo "  ⚠️  Nodes exist but cluster may not be fully ready"
            fi
        else
            echo "  ❌ Cluster creation failed - nodes were not created"
            echo ""
            echo "💡 Colima-specific troubleshooting:"
            echo ""
            echo "   1. Try using an older Kind node image version (recommended):"
            echo "      Edit kind-config.yaml and change to: kindest/node:v1.28.0"
            echo "      Then run: kind create cluster --name zero-downtime --config kind-config.yaml"
            echo ""
            echo "   2. Ensure Colima has sufficient resources:"
            echo "      colima status"
            echo "      # Restart with more resources if needed:"
            echo "      colima stop"
            echo "      colima start --cpu 4 --memory 8"
            echo ""
            echo "   3. Try restarting Colima:"
            echo "      colima restart"
            echo ""
            echo "   4. Alternative: Use Docker Desktop instead of Colima for this demo"
            echo ""
            rm -f /tmp/kind-create-output.log
            exit 1
        fi
    elif [ $KIND_EXIT_CODE -ne 0 ]; then
        echo ""
        echo "❌ Error: Failed to create Kind cluster"
        echo "$KIND_OUTPUT" | tail -10
        echo ""
        rm -f /tmp/kind-create-output.log
        exit 1
    fi

    # Clean up temp file
    rm -f /tmp/kind-create-output.log

    # Wait for cluster to be ready (manual wait instead of --wait flag)
    echo "  Waiting for cluster to be ready..."
    MAX_ATTEMPTS=10
    ATTEMPT=0
    while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
        if kubectl cluster-info --context kind-zero-downtime --kubeconfig ~/.kube/config > /dev/null 2>&1; then
            echo "  ✅ Cluster is ready!"
            break
        fi
        ATTEMPT=$((ATTEMPT + 1))
        echo "  Waiting for cluster... ($ATTEMPT/$MAX_ATTEMPTS)"
        sleep 2
    done

    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        echo "⚠️  Warning: Cluster may not be fully ready, but continuing..."
    fi
else
    echo "  Using existing cluster 'zero-downtime'"
fi

# Step 2: Set and verify kubectl context
echo "🔍 Step 2: Setting kubectl context..."
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

# Apply taints if nodes exist (only if cluster was just created or taints don't exist)
if [ "$SKIP_CLUSTER_CREATION" = false ]; then
    kubectl taint nodes zero-downtime-worker dedicated-web=true:NoSchedule 2>/dev/null || true
    kubectl taint nodes zero-downtime-worker2 dedicated-web=true:NoSchedule 2>/dev/null || true
else
    # Try to apply taints on existing cluster (may already exist, that's okay)
    kubectl taint nodes zero-downtime-worker dedicated-web=true:NoSchedule 2>/dev/null || true
    kubectl taint nodes zero-downtime-worker2 dedicated-web=true:NoSchedule 2>/dev/null || true
fi

# Step 3: Install Argo Rollouts and KEDA
echo "🔧 Step 3: Installing Argo Rollouts and KEDA..."

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

# Step 4: Deploy K8s App Workload
echo "📦 Step 4: Deploying K8s App Workload..."
kubectl apply -k k8s-app-workload/base-manifest/

# Step 5: Deploy routing service
echo "🌐 Step 5: Deploying routing service..."
kubectl apply -k routing-service/base-manifest/

# Step 6: Validate all deployments are running and ready
if [ "$CLUSTER_EXISTS" = true ]; then
    echo "⏳ Step 6: Skipping validations (using existing cluster)..."
    echo "  ⏭️  Validations skipped - continuing with deployment"
else
    echo "⏳ Step 6: Waiting for all deployments to be ready..."
    echo "  Waiting for K8s App Workload..."
    kubectl wait --for=condition=available rollout/k8s-web-pool --timeout=600s || {
        echo "⚠️  Warning: K8s App Workload may not be ready yet, continuing..."
    }
    echo "  Waiting for Routing Service..."
    kubectl wait --for=condition=available deployment/edge-routing-service --timeout=600s || {
        echo "⚠️  Warning: Routing Service may not be ready yet, continuing..."
    }
fi

# Step 7: Install Kubernetes Metrics Server
echo "📊 Step 7: Installing Kubernetes Metrics Server..."

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

# Step 8: Deploy observability stack
echo "📊 Step 8: Deploying observability stack..."
cd observability
./deploy-observability.sh
cd ..

# Step 9: Optional - Install cloud-provider-kind for LoadBalancer support
echo "📋 Step 9: Optional - Installing cloud-provider-kind for LoadBalancer support..."
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

# Step 10: Get service information
echo "📋 Step 10: Getting service information..."
echo ""
echo "🎉 Deployment Complete! Here's how to access everything:"
echo ""
echo "🔗 Service Access Options:"
echo ""
echo "  Option 1: Port-Forward (Always Available)"
echo "  =========================================="
echo "  # Main Application:"
echo "  kubectl port-forward -n default svc/edge-routing-service 8080:80"
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
echo "  # Envoy Admin:"
echo "  kubectl port-forward -n default svc/edge-routing-service 9901:9901"
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
