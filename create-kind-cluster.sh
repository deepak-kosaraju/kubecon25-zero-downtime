#!/bin/bash

# Create Kind Cluster Script for Zero Downtime Migration Demo
# This script creates a Kind cluster with proper validation and error handling

set -e

echo "🔧 Creating Kind cluster..."

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

# Apply taints if nodes exist
echo "  Applying node taints..."
kubectl taint nodes zero-downtime-worker dedicated-web=true:NoSchedule 2>/dev/null || true
kubectl taint nodes zero-downtime-worker2 dedicated-web=true:NoSchedule 2>/dev/null || true

echo "✅ Kind cluster 'zero-downtime' is ready!"

