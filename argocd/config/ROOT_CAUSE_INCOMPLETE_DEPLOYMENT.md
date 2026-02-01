# Real Root Cause: Incomplete Deployment in ArgoCD

## The Actual Problem

The Deployment renders incomplete because of **strategic merge patch behavior**, not `directory.recurse`.

### Why Deployment is Incomplete

**Helm generates**:

```yaml
metadata:
  name: aggregator-api-v1 # ← Name matches
```

**Patch file**:

```yaml
metadata:
  name: aggregator-api-v1 # ← Name matches!
spec:
  replicas: 1
  template:
    spec:
      containers:
        - name: api
          imagePullPolicy: Always
```

✅ **Names match** → Patch applies → **Strategic merge** replaces the entire spec

### Why Service is Complete

**Helm generates**:

```yaml
metadata:
  name: aggregator-api-v1-service # ← Different name
```

**Patch file**:

```yaml
metadata:
  name: aggregator-api-v1 # ← Doesn't match!
spec:
  type: NodePort
```

❌ **Names don't match** → Patch ignored → Service stays complete

## The Real Issue

When using ArgoCD multi-source with `directory.recurse: true`, patch files are applied as **strategic merge patches**. If the `metadata.name` matches, Kubernetes strategic merge will **replace** fields, not merge them deeply.

### Strategic Merge Behavior

```yaml
# Original (from Helm)
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    spec:
      containers:
        - name: api
          image: myapp:1.0
          ports:
            - containerPort: 3000

# Patch
spec:
  replicas: 1
  template:
    spec:
      containers:
        - name: api
          imagePullPolicy: Always

# Result (Strategic Merge)
spec:
  replicas: 1  # ← Replaced
  # selector: REMOVED! (not in patch)
  template:
    spec:
      containers:
        - name: api
          imagePullPolicy: Always
          # image: REMOVED! (not in patch)
          # ports: REMOVED! (not in patch)
```

## Solution

### Option 1: Use $patch: merge Directive

Add `$patch: merge` to preserve fields:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aggregator-api-v1
spec:
  replicas: 1
  template:
    spec:
      containers:
        - name: api
          $patch: merge # ← Tells Kubernetes to merge, not replace
          imagePullPolicy: Always
```

### Option 2: Use JSON Patch

Use JSON Patch format for precise modifications:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aggregator-api-v1
  annotations:
    argocd.argoproj.io/sync-options: "Replace=false"
spec:
  $patch: |
    - op: replace
      path: /spec/replicas
      value: 1
    - op: add
      path: /spec/template/spec/containers/0/imagePullPolicy
      value: Always
```

### Option 3: Remove Patches, Use Helm Values (Recommended)

Configure everything via Helm values:

```yaml
# deploy/overlays/development/values.yaml
replicaCount: 1

image:
  pullPolicy: Always
```

Remove the patches directory entirely.

## Why This Happens

ArgoCD's multi-source doesn't use Kustomize's strategic merge patch - it uses **Kubernetes strategic merge**, which has different behavior. Fields not present in the patch are **removed**, not preserved.

## Verification

Test if Service patch applies when name matches:

```yaml
# patches/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: aggregator-api-v1-service # ← Match Helm name
spec:
  type: NodePort
```

Now the Service will also be incomplete!

## Recommended Fix

**Remove Source 3** and use Helm values for all customization. This is the cleanest approach for ArgoCD multi-source applications.
