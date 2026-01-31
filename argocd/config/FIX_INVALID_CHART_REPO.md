# Fixing "Invalid Chart Repository" Error

## Problem

Kustomize's `helmCharts` feature expects a **Helm chart repository** (with `index.yaml`), but we're using a **Git repository**.

Error:

```
"https://github.com/ashutosh-18k92/sf-helm-registry.git" is not a valid chart repository
failed to fetch https://github.com/ashutosh-18k92/sf-helm-registry.git/index.yaml : 404 Not Found
```

## Root Cause

Kustomize `helmCharts` uses `helm pull --repo`, which requires:

- A Helm chart repository (e.g., `https://charts.bitnami.com/bitnami`)
- An `index.yaml` file

Git repositories don't have `index.yaml` files.

## Solutions

### Solution 1: Use ArgoCD Multi-Source (Recommended)

**Remove** `helmCharts` from kustomization and use ArgoCD's multi-source feature:

**Update `deploy/overlays/development/kustomization.yaml`**:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Remove helmCharts section entirely!

# Namespace
namespace: super-fortnight

# ConfigMap
configMapGenerator:
  - name: service-config
    literals:
      - PORT=3000
      - SERVICE_NAME=aggregator-service
      - LOG_LEVEL=debug
      - NODE_ENV=development

# Patches
patches:
  - path: patches/deployment.yaml
```

**Update ApplicationSet** to use multi-source:

```yaml
sources:
  # Source 1: Helm chart from Git
  - repoURL: https://github.com/ashutosh-18k92/sf-helm-registry.git
    targetRevision: v0.1.0
    path: api
    helm:
      releaseName: aggregator
      valueFiles:
        - $values/deploy/base/values.yaml
        - $values/deploy/overlays/{{.env}}/values.yaml

  # Source 2: Values files
  - repoURL: https://github.com/ashutosh-18k92/aggregator-service.git
    targetRevision: "{{.env}}"
    ref: values

  # Source 3: Kustomize patches (optional)
  - repoURL: https://github.com/ashutosh-18k92/aggregator-service.git
    targetRevision: "{{.env}}"
    path: deploy/overlays/{{.env}}
    kustomize: {}
```

### Solution 2: Publish Helm Chart to GitHub Pages

Convert your Git repo into a proper Helm chart repository:

```bash
cd sf-helm-registry

# Package the chart
helm package api

# Create index
helm repo index . --url https://ashutosh-18k92.github.io/sf-helm-registry

# Push to gh-pages branch
git checkout -b gh-pages
git add index.yaml *.tgz
git commit -m "Publish Helm charts"
git push origin gh-pages
```

Enable GitHub Pages for the `gh-pages` branch, then use:

```yaml
helmCharts:
  - name: api
    repo: https://ashutosh-18k92.github.io/sf-helm-registry
    version: v0.1.0
```

### Solution 3: Use OCI Registry

Push charts to GitHub Container Registry:

```bash
helm package api
helm push api-0.1.0.tgz oci://ghcr.io/ashutosh-18k92/sf-helm-registry
```

Then use:

```yaml
helmCharts:
  - name: api
    repo: oci://ghcr.io/ashutosh-18k92/sf-helm-registry
    version: 0.1.0
```

## Recommended Approach

**Use ArgoCD Multi-Source** (Solution 1):

- ✅ No need to publish charts
- ✅ Charts stay in Git
- ✅ Team controls versions via Git tags
- ✅ Kustomize patches still work
- ✅ Simpler than maintaining a chart repository

## Implementation

I've created `aggregator-appset-multisource.yaml` with the correct multi-source configuration.

**Next Steps**:

1. Remove `helmCharts` from overlay kustomizations
2. Apply the multi-source ApplicationSet
3. Verify it works

This approach gives you:

- Helm chart from Git (no chart repo needed)
- Kustomize patches for environment-specific changes
- Team autonomy for chart versions (via Git tags)
