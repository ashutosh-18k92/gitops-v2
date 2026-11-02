# ⚠️ Deprecated

## Deprecated Architecture Documentation

This folder contains documentation for **deprecated architectural patterns** that have been replaced by the **Decentralized Helm Charts Pattern**.

## ⚠️ These Approaches Are No Longer Recommended

The documents in this folder describe older approaches to solving the Helm + Kustomize integration challenge. While they may still work, they have been superseded by a better solution.

## Deprecated Patterns

### 1. ArgoCD Multi-Source Helm Pattern

**File**: [`helm-kustomize-hybrid.md`](./helm-kustomize-hybrid.md)

**What it was**: Using ArgoCD's multi-source feature to reference a remote Helm chart repository while keeping values in the service repository.

**Why deprecated**:

- ❌ Teams don't own their charts (dependency on remote chart repo)
- ❌ Limited customization (can only override values, not templates)
- ❌ No Helm dependency management
- ❌ Kustomize still needed for patches
- ❌ Complex multi-source configuration

**Replaced by**: [Decentralized Helm Charts Pattern](../../guides/service-specific-charts.md)

### 2. ApplicationSet + Git Files Generator - Referring Base `api` Chart

**File**: [`applicationset-pattern.md`](./applicationset-pattern.md)

**What it was**: Using ApplicationSet's Git Files Generator to read environment configurations from the service repository.

**Why deprecated**:

- ❌ Still relies on remote chart repository
- ❌ Teams can't modify chart templates
- ❌ Complex ApplicationSet configuration
- ❌ Tight coupling between platform and service repos

**Replaced by**: [Decentralized Helm Charts Pattern](../../guides/service-specific-charts.md) with service-owned charts

## Current Recommended Approach

### ✅ Decentralized Helm Charts Pattern

Each service **owns its own Helm chart** created from a starter template:

```bash
# Create service chart from starter
helm create charts/your-service --starter=sf-charts/api
```

**Benefits**:

- ✅ Full team autonomy (own the chart, not just values)
- ✅ Helm dependency management works
- ✅ Simpler architecture (no multi-source complexity)
- ✅ Standard Helm workflows
- ✅ Independent evolution per service

**Documentation**:

- [Decentralized Helm Charts Pattern Guide](../../guides/service-specific-charts.md)
- [Adding a New Service](../../guides/adding-new-service.md)
- [Publishing Helm Charts](../../guides/publishing-helm-charts.md)

## Migration Path

If you're currently using one of the deprecated patterns:

1. **Create service-specific chart** using `helm create --starter`
2. **Copy your values** from `deploy/overlays/` to chart's `values.yaml`
3. **Set up automated publishing** with GitHub Actions
4. **Update ArgoCD** to use Helm chart from GitHub Pages
5. **Remove** multi-source configuration and environment files

See the [Decentralized Helm Charts Pattern Guide](../../guides/service-specific-charts.md) for detailed migration instructions.

## Why We Changed

The evolution of our architecture:

1. **Phase 1**: Kustomize `helmCharts` (broken with Helm 4.x)
2. **Phase 2**: ArgoCD Multi-Source (complex, limited autonomy) ← **Deprecated**
3. **Phase 3**: Decentralized Helm Charts (current) ← **Recommended**

The Decentralized Helm Charts Pattern provides the best balance of:

- Team autonomy
- Simplicity
- Standard tooling
- Scalability

## Questions?

If you have questions about migrating from these deprecated patterns, please refer to:

- [Decentralized Helm Charts Pattern Guide](../../guides/service-specific-charts.md)
- Platform team documentation
- Your team's migration plan
