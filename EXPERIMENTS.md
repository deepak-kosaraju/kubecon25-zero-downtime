# Experiments Guide

This document provides detailed instructions for running experiments to understand zero-downtime migration techniques.

## Table of Contents

- [Experiments Guide](#experiments-guide)
  - [Table of Contents](#table-of-contents)
  - [Applying Lifecycle Hooks](#applying-lifecycle-hooks)
  - [Load Testing](#load-testing)
  - [Rollout Update and Shutdown Monitoring](#rollout-update-and-shutdown-monitoring)
    - [Step 1: Update the Application Image](#step-1-update-the-application-image)
    - [Step 2: Watch the Rollout Progress](#step-2-watch-the-rollout-progress)
    - [Step 3: Monitor Shutdown Sequence for Terminating Pods](#step-3-monitor-shutdown-sequence-for-terminating-pods)
    - [Step 4: Monitor EndpointSlice State](#step-4-monitor-endpointslice-state)

## Applying Lifecycle Hooks

Apply lifecycle hooks to the deployment:

```bash
# Apply lifecycle hooks for after-native-sidecar approach
kubectl apply -f k8s-app-workload/lifecycle-hooks/after-native-sidecar/
```

This will:

- Add postStart hook to signal Envoy when app container starts
- Add preStop hook to gracefully drain connections before pod termination
- Configure the rollout strategy for zero-downtime updates

## Load Testing

Run load tests to observe the graceful shutdown behavior:

```bash
# Load test with siege
siege -c 500 -t 2m -i -f urls-localhost.txt
```

## Rollout Update and Shutdown Monitoring

This experiment demonstrates how to update the application image and monitor the graceful shutdown sequence during a rollout.

### Step 1: Update the Application Image

Update the rollout to a new image version:

```bash
kubectl argo rollouts set image k8s-web-pool app=kosarajus/monolith:v0.1.2
```

### Step 2: Watch the Rollout Progress

In one terminal, watch the rollout status:

```bash
kubectl argo rollouts get rollout k8s-web-pool -w
```

This will show the rollout progress in real-time, including:

- Current revision
- Replica counts
- Pod status

### Step 3: Monitor Shutdown Sequence for Terminating Pods

In another terminal, monitor the shutdown sequence for any pod that is terminating during the rollout:

```bash
while true; do
  POD_NAME=$(kubectl get pods -l app.kubernetes.io/component=web -o json | jq -r '.items[] | select(.metadata.deletionTimestamp != null) | .metadata.name' | head -1)
  [ -n "$POD_NAME" ] && echo -e "\n ---- $POD_NAME ----\n"
  kubectl logs -f $POD_NAME --since 1m -c app 2>/dev/null | egrep -iB1 'PreStop|SIGTERM|term|shut|finished|clean'
  sleep 2
done
```

This command will:

- Continuously check for pods with deletion timestamps (terminating pods)
- Show logs from the app container for terminating pods
- Filter for shutdown-related log messages (PreStop, SIGTERM, etc.)

You should see logs like:

- `[Kubernetes PreStop] START: Drain Sequence initiated`
- `[Kubernetes PreStop] Signaling Envoy to Close Connections...`
- `[Kubernetes PreStop] Waiting for Active Connections to Drain`
- `[Kubernetes PreStop] All Connections Drained... Signaling App to Shutdown`

### Step 4: Monitor EndpointSlice State

In yet another terminal, monitor the EndpointSlice state to see how the pod's endpoint conditions change during termination:

```bash
while true; do
  POD_NAME=$(kubectl get pods -l app.kubernetes.io/component=web -o json | jq -r '.items[] | select(.metadata.deletionTimestamp != null) | .metadata.name' | head -1)
  ENDPOINTSLICE_NAME=$(kubectl get endpointslice -l app.kubernetes.io/component=web -o jsonpath='{.items[0].metadata.name}')
  [ -n "$POD_NAME" ] && echo -e "\n ---- $POD_NAME ----\n"
  kubectl get endpointslice "$ENDPOINTSLICE_NAME" -o jsonpath="{range .endpoints[?(@.targetRef.name==\"$POD_NAME\")]}{\"Conditions: ready=\"}{.conditions.ready}{\", serving=\"}{.conditions.serving}{\", terminating=\"}{.conditions.terminating}{\", NodeName=\"}{.nodeName}{\", pod=\"}{.targetRef.name}{\"\\n\"}{end}"
  sleep 2
done
```

This command will show:

- **ready**: Whether the endpoint is ready to receive traffic
- **serving**: Whether the endpoint is serving traffic
- **terminating**: Whether the endpoint is in terminating state
- **NodeName**: The node where the pod is running
- **pod**: The pod name

During graceful shutdown, you should observe:

- `ready=false, serving=false, terminating=true` as the pod is being drained
- The endpoint being removed from the EndpointSlice once draining completes

**Note**: This experiment requires three terminal windows:

1. One for watching the rollout status
2. One for monitoring pod shutdown logs
3. One for monitoring EndpointSlice state
