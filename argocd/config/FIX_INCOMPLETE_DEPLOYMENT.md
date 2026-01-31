# Fixing Incomplete Deployment Manifest in ArgoCD

## Problem

The Deployment manifest in ArgoCD is incomplete:

```yaml
spec:
  replicas: 1
  template:
    spec:
      containers:
        - imagePullPolicy: Always
          name: api
```

Missing: selector, labels, image, ports, etc.

## Root Cause

**Source 3** in the ApplicationSet was applying patch files as **plain manifests**:

```yaml
# Source 3: Kustomize patches (WRONG!)
- repoURL: https://github.com/ashutosh-18k92/aggregator-service.git
  path: deploy/overlays/{{.env}}/patches
  directory:
    recurse: true
```

This treats `deployment.yaml` patch as a **complete manifest**, overwriting the Helm-generated Deployment.

## Solution Options

### Option 1: Remove Patches Source (Recommended)

Use **Helm values only** for environment-specific configuration:

**ApplicationSet** (2 sources only):

```yaml
sources:
  # Source 1: Helm chart
  - repoURL: https://github.com/ashutosh-18k92/sf-helm-registry.git
    helm:
      valueFiles:
        - $values/deploy/base/values.yaml
        - $values/deploy/overlays/{{.env}}/values.yaml

  # Source 2: Values files
  - repoURL: https://github.com/ashutosh-18k92/aggregator-service.git
    ref: values
```

**Configure in values.yaml**:

```yaml
# deploy/overlays/development/values.yaml
replicaCount: 1

image:
  pullPolicy: Always

env:
  - name: LOG_LEVEL
    value: debug
```

### Option 2: Use Post-Renderer (Advanced)

If you absolutely need Kustomize patches, use ArgoCD's Kustomize post-renderer:

**Update Helm source**:

```yaml
- repoURL: https://github.com/ashutosh-18k92/sf-helm-registry.git
  helm:
    releaseName: aggregator
    valueFiles: [...]
  kustomize:
    patches:
      - target:
          kind: Deployment
          name: aggregator-api-v1
        patch: |-
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
                    imagePullPolicy: Always
```

### Option 3: Single Kustomize Source

Use Kustomize with `helmCharts` (requires `--enable-helm`):

```yaml
# Single source
source:
  repoURL: https://github.com/ashutosh-18k92/aggregator-service.git
  path: deploy/overlays/{{.env}}
  kustomize: {}
```

**But this requires** a Helm chart repository, not a Git repo.

## Recommended Fix

**Remove Source 3** and configure everything via Helm values.

### Updated Files

1. **ApplicationSet**: Removed Source 3
2. **values.yaml**: Add all environment-specific configs

### Migration

Move patch configurations to values:

**Before** (patch file):

```yaml
# patches/deployment.yaml
spec:
  replicas: 1
  template:
    spec:
      containers:
        - name: api
          imagePullPolicy: Always
```

**After** (values file):

```yaml
# overlays/development/values.yaml
replicaCount: 1

image:
  pullPolicy: Always
```

## Verification

After applying the fixed ApplicationSet:

```bash
# Check deployment
argocd app get aggregator-service-development

# View manifests
argocd app manifests aggregator-service-development | grep -A 20 "kind: Deployment"
```

The Deployment should now be complete with all fields.

## Why This Happened

ArgoCD multi-source doesn't support **strategic merge patches** from a directory source. It treats files as complete manifests, causing overwrites.

**Helm values** are the correct way to customize Helm charts in ArgoCD multi-source applications.
