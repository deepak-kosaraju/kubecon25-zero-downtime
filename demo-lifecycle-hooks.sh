#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear

# Set colors
DEMO_PROMPT="${GREEN}➜ ${COLOR_RESET}"

# Set the speed (faster printing)
TYPE_SPEED=50

# Set no wait by default (can be overridden with wait command)
PROMPT_TIMEOUT=0

echo ""
echo "=========================================================================="
echo "  Zero-Downtime Migration Demo: Lifecycle Hooks for Graceful Shutdown"
echo "=========================================================================="
echo ""
wait

echo "📋 Overview:"
echo ""
echo "This demo shows how to add postStart and preStop lifecycle hooks to"
echo "drain active in-flight connections before terminating the POD."
echo ""
wait

echo "🔍 What we'll demonstrate:"
echo ""
echo "1. postStart hook: To undo actions of preStop hook"
echo "2. preStop hook: Gracefully drain connections before shutdown"
echo "   - Signal Envoy to stop accepting new connections"
echo "   - Wait for active connections to drain"
echo "   - Ensure stable draining (zero connections for 3 consecutive seconds)"
echo ""
wait

echo "📂 Let's examine the rollout-patch.yaml for after-native-sidecar:"
echo ""
wait

pei "cat k8s-app-workload/lifecycle-hooks/after-native-sidecar/rollout-patch.yaml"
wait

echo ""
echo "📝 Key points about the lifecycle hooks in this rollout patch:"
echo ""
echo "  • postStart hook: Undoes preStop actions when container restarts"
echo "  • preStop hook: Gracefully drains connections before shutdown"
echo "    - Signals Envoy to fail healthchecks (stops accepting new connections)"
echo "    - Waits 2 seconds for Kubernetes to stop sending traffic"
echo "    - Monitors active connections until they remain at zero for 3 consecutive seconds"
echo "    - Ensures stable draining before allowing pod termination"
echo ""
wait

echo "📂 Now let's compare with the before-native-sidecar rollout patch:"
echo ""
wait

pei "cat k8s-app-workload/lifecycle-hooks/before-native-sidecar/rollout-patch.yaml"
wait

echo ""
echo "📊 Key differences:"
echo ""
echo "  • before-native-sidecar: Uses shutdown-orchestrator container for coordination"
echo "  • after-native-sidecar: Direct lifecycle hooks with native sidecar support"
echo ""
wait

echo ""
echo "🚀 Now let's apply the lifecycle hooks configuration:"
echo ""
wait

# Following will add postStart and reliable preStop hook to drain any active inflight connectons before TERM'ing the POD.
p "# following will add postStart and reliable preStop hook to drain any active inflight connectons before TERM'ing the POD."
wait

pe "kubectl apply -k k8s-app-workload/lifecycle-hooks/after-native-sidecar/"

echo ""
echo "✅ Configuration applied successfully!"
echo ""
wait

echo "🔍 Let's verify the rollout has been updated with lifecycle hooks:"
echo ""
wait

pei "kubectl get rollout -o yaml | grep -A 30 'lifecycle:'"
wait

echo ""
echo "📋 Or check rollout details:"
echo ""
wait

pei "kubectl describe rollout | grep -A 20 'Lifecycle'"
wait

echo ""
echo "🔍 Let's check the pods to see if they're running with the new configuration:"
echo ""
wait

pei "kubectl get pods -o wide"
wait

echo ""
echo "📊 To verify the lifecycle hooks are working:"
echo ""
echo "1. Watch pod logs during a rollout to see preStop hook execution:"
echo "   kubectl logs -f <pod-name> -c <container-name>"
echo ""
echo "2. Trigger a rollout to see the graceful shutdown in action:"
echo "   kubectl rollout restart rollout/<rollout-name>"
echo ""
echo "3. Monitor the preStop hook logs - you should see:"
echo "   - 'Starting Drain Sequence'"
echo "   - 'Signaling Envoy to Close Connections...'"
echo "   - 'Waiting for Active Connections to Drain'"
echo "   - 'All Connections Drained... Signaling App to Shutdown'"
echo ""
wait

echo "🎯 Summary:"
echo ""
echo "✅ postStart hook: Ensures Envoy accepts connections when app container starts"
echo "✅ preStop hook: Gracefully drains connections before pod termination"
echo "   • Stops new connections"
echo "   • Waits for active connections to drain"
echo "   • Ensures stable draining (3 consecutive seconds at zero)"
echo ""
echo "This configuration ensures zero-downtime deployments by properly"
echo "draining in-flight connections before terminating pods."
echo ""
wait

echo "=========================================================================="
echo "  Demo Complete!"
echo "=========================================================================="
echo ""

