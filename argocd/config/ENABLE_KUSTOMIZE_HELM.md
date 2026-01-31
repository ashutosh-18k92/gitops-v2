# Enabling Kustomize Helm Support in ArgoCD

## Problem

ArgoCD error when using `helmCharts` in kustomization.yaml:

```
must specify --enable-helm
```

## Root Cause

The `--enable-helm` flag must be configured **globally** in the `argocd-cm` ConfigMap, not in individual ApplicationSet `buildOptions`.

## Solution

### 1. Apply ArgoCD ConfigMap Patch

```bash
kubectl apply -f gitops-v2/argocd/config/argocd-cm-kustomize-helm.yaml
```

Or patch the existing ConfigMap:

```bash
kubectl patch configmap argocd-cm -n argocd --type merge -p '
{
  "data": {
    "kustomize.buildOptions": "--enable-helm --load-restrictor LoadRestrictionsNone"
  }
}'
```

### 2. Restart ArgoCD Components

For the changes to take effect:

```bash
# Restart argocd-repo-server (handles manifest generation)
kubectl rollout restart deployment argocd-repo-server -n argocd

# Wait for rollout to complete
kubectl rollout status deployment argocd-repo-server -n argocd
```

### 3. Verify Configuration

```bash
# Check ConfigMap
kubectl get configmap argocd-cm -n argocd -o yaml | grep kustomize.buildOptions

# Expected output:
# kustomize.buildOptions: --enable-helm --load-restrictor LoadRestrictionsNone
```

### 4. Test ApplicationSet

```bash
# Apply ApplicationSet
kubectl apply -f gitops-v2/argocd/apps/aggregator-appset.yaml

# Check Application generation
argocd app list | grep aggregator-service

# View manifests (should work now)
argocd app manifests aggregator-service-development
```

## Why Global Configuration?

ArgoCD's Kustomize integration runs in the `argocd-repo-server` component. The `--enable-helm` flag must be passed to **all** `kustomize build` commands, which is controlled by the global ConfigMap setting.

Individual ApplicationSet `buildOptions` are **not supported** for Kustomize applications in ArgoCD.

## Alternative: Config Management Plugin

If global configuration is not desired, use a custom Config Management Plugin:

```yaml
# argocd-cm ConfigMap
data:
  configManagementPlugins: |
    - name: kustomize-with-helm
      generate:
        command: ["sh", "-c"]
        args:
          - kustomize build --enable-helm --load-restrictor LoadRestrictionsNone .
```

Then reference in ApplicationSet:

```yaml
source:
  plugin:
    name: kustomize-with-helm
```

## Files Updated

1. **`argocd/config/argocd-cm-kustomize-helm.yaml`** - ConfigMap patch
2. **`argocd/apps/aggregator-appset.yaml`** - Removed buildOptions
3. **`argocd/__test_apps__/aggregator-appset.yaml`** - Removed buildOptions

## Deployment Steps

```bash
# 1. Apply ConfigMap
kubectl apply -f gitops-v2/argocd/config/argocd-cm-kustomize-helm.yaml

# 2. Restart repo server
kubectl rollout restart deployment argocd-repo-server -n argocd
kubectl rollout status deployment argocd-repo-server -n argocd

# 3. Apply ApplicationSet
kubectl apply -f gitops-v2/argocd/apps/aggregator-appset.yaml

# 4. Verify
argocd app get aggregator-service-development
```

## Verification

After applying the ConfigMap and restarting, the error should be resolved and ArgoCD should successfully:

1. ✅ Read environment files from Git
2. ✅ Generate Applications for each environment
3. ✅ Inflate Helm charts using Kustomize
4. ✅ Apply patches from overlay directories
5. ✅ Deploy to Kubernetes clusters
