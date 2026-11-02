# ArgoCD Multi-Source Helm Pattern

## Overview

This document describes the **ArgoCD Multi-Source** approach for managing Helm charts in a multi-team environment, replacing the deprecated Kustomize `helmCharts` feature.

## Why This Approach?

### The Problem: Kustomize helmCharts + Helm 4.x

Kustomize's `helmCharts` feature is **incompatible with Helm 4.x**:

```yaml
# BROKEN with Helm 4.x ❌
helmCharts:
  - name: api
    repo: https://github.com/team/helm-registry.git
    version: 0.1.0
```

**Error**: `unknown shorthand flag: 'c' in -c`

Kustomize tries to run `helm version -c --short`, but Helm 4.x removed the `-c` flag. This affects **all Kustomize versions**.

### The Solution: ArgoCD Multi-Source

ArgoCD's native multi-source support provides:

- ✅ **Helm 4.x compatibility**: Direct Helm chart rendering
- ✅ **Team autonomy**: Teams control chart versions
- ✅ **Clean separation**: Helm charts vs. service configuration
- ✅ **No Kustomize dependency**: Pure Helm + values files

## Architecture

```
Base Chart Repository:
https://github.com/ashutosh-18k92/sf-helm-registry.git
  └── api/                          # Reference chart (platform team maintains)
      ├── templates/
      ├── values.yaml
      └── Chart.yaml

Service Repository:
aggregator-service/
├── deploy/
│   ├── environments/               # Team controls chart versions
│   │   ├── dev.yaml               # env: dev, chartVersion: "0.1.0"
│   │   └── production.yaml        # env: production, chartVersion: "0.2.0"
│   ├── base/
│   │   └── values.yaml            # Base Helm values
│   └── overlays/
│       ├── dev/
│       │   └── values.yaml        # Dev-specific values
│       └── production/
│           └── values.yaml        # Prod-specific values

GitOps Repository:
gitops-v2/
└── argocd/
    └── apps/
        └── aggregator-appset.yaml  # ApplicationSet with Git Files Generator
```

## How It Works

### 1. Base Chart (Platform Team)

Platform team maintains the reference API chart:

```
sf-helm-registry/
└── api/
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
        ├── deployment.yaml
        ├── service.yaml
        └── virtualservice.yaml
```

### 2. Environment Configuration (Team-Owned)

Teams define environments and chart versions in their repo:

**`deploy/environments/dev.yaml`**:

```yaml
env: dev
namespace: super-fortnight-dev

# Team controls chart version
chartRepo: https://github.com/ashutosh-18k92/sf-helm-registry.git
chartVersion: "0.1.0" # Pin specific version
chartPath: api
```

**`deploy/environments/production.yaml`**:

```yaml
env: production
namespace: super-fortnight

# Can use different version than dev
chartRepo: https://github.com/ashutosh-18k92/sf-helm-registry.git
chartVersion: "0.2.0" # Upgraded independently
chartPath: api
```

### 3. Helm Values (Team-Owned)

Teams provide base and environment-specific values:

**`deploy/base/values.yaml`**:

```yaml
# Common configuration
containerPort: 3000

image:
  repository: "aggregator-service"

env:
  PORT: "3000"
  SERVICE_NAME: "aggregator-service"
```

**`deploy/overlays/production/values.yaml`**:

```yaml
# Production overrides
env:
  LOG_LEVEL: "error"
  NODE_ENV: "production"

resources:
  requests:
    memory: "256Mi"
    cpu: "200m"
  limits:
    memory: "512Mi"
    cpu: "500m"

replicaCount: 3

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
```

### 4. ApplicationSet (Platform Team)

Platform team creates ApplicationSet with Git Files Generator:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: aggregator-service
spec:
  goTemplate: true
  generators:
    - git:
        repoURL: https://github.com/ashutosh-18k92/aggregator-service.git
        files:
          - path: "deploy/environments/*.yaml"

  template:
    spec:
      sources:
        # Source 1: Helm chart with team-controlled version
        - repoURL: "{{.chartRepo}}"
          targetRevision: "{{.chartVersion}}"
          path: "{{.chartPath}}"
          helm:
            releaseName: aggregator
            valueFiles:
              - $values/deploy/base/values.yaml
              - $values/deploy/overlays/{{.env}}/values.yaml

        # Source 2: Values from team repo
        - repoURL: https://github.com/ashutosh-18k92/aggregator-service.git
          targetRevision: main
          ref: values
```

## Team Workflows

### Adopting Base Chart Updates

```bash
cd aggregator-service

# Platform releases new chart version (e.g., v0.3.0)
# Team reviews changelog and decides to upgrade

# Update dev first
vim deploy/environments/dev.yaml
# Change: chartVersion: "0.1.0" → "0.3.0"

git commit -m "Upgrade dev to API chart v0.3.0"
git push

# ArgoCD syncs dev environment
# Team tests in dev

# If successful, upgrade production
vim deploy/environments/production.yaml
# Change: chartVersion: "0.2.0" → "0.3.0"

git commit -m "Upgrade production to API chart v0.3.0"
git push
```

### Testing Locally

```bash
# Clone both repos
git clone https://github.com/ashutosh-18k92/sf-helm-registry.git
git clone https://github.com/ashutosh-18k92/aggregator-service.git

# Render for dev
helm template aggregator sf-helm-registry/api \
  -f aggregator-service/deploy/base/values.yaml \
  -f aggregator-service/deploy/overlays/dev/values.yaml \
  --namespace super-fortnight-dev

# Render for production
helm template aggregator sf-helm-registry/api \
  -f aggregator-service/deploy/base/values.yaml \
  -f aggregator-service/deploy/overlays/production/values.yaml \
  --namespace super-fortnight
```

### Staying on Older Version

```bash
# Team decides not to upgrade yet
# No action needed - version stays at current
# Team can upgrade when ready

# Example: Dev on v0.3.0, Production stays on v0.2.0
# This is perfectly fine!
```

### Adding New Environment

```bash
cd aggregator-service

# Create staging environment
cat > deploy/environments/staging.yaml <<EOF
env: staging
namespace: super-fortnight-staging
chartRepo: https://github.com/ashutosh-18k92/sf-helm-registry.git
chartVersion: "0.2.0"
chartPath: api
EOF

# Create staging values
cat > deploy/overlays/staging/values.yaml <<EOF
env:
  LOG_LEVEL: "info"
  NODE_ENV: "staging"

replicaCount: 2
EOF

git add deploy/environments/staging.yaml deploy/overlays/staging/
git commit -m "Add staging environment"
git push

# ArgoCD automatically creates aggregator-service-staging!
```

## Best Practices

### ✅ DO

- **Pin specific chart versions**: Use `"0.1.0"`, not `"main"`
- **Test in dev first**: Upgrade dev, verify, then promote
- **Document changes**: Clear commit messages for version upgrades
- **Use semantic versioning**: Follow semver for chart versions
- **Keep values minimal**: Only override what's necessary

### ❌ DON'T

- **Don't use `latest` or `main`**: Always pin specific versions
- **Don't skip testing**: Always test upgrades in dev first
- **Don't duplicate values**: Use base values for common config
- **Don't modify chart directly**: Use values to customize

## Comparison with Kustomize helmCharts

| Aspect                    | Kustomize helmCharts        | ArgoCD Multi-Source |
| ------------------------- | --------------------------- | ------------------- |
| **Helm 4.x Compatible**   | ❌ Broken                   | ✅ Works            |
| **Team Controls Version** | ⚠️ In kustomization         | ✅ In env config    |
| **Local Testing**         | ❌ Broken                   | ✅ `helm template`  |
| **ArgoCD Integration**    | ⚠️ Requires `--enable-helm` | ✅ Native           |
| **Complexity**            | ⚠️ Moderate                 | ✅ Simple           |
| **Maintenance**           | ❌ Deprecated               | ✅ Supported        |

## Migration from Kustomize helmCharts

If migrating from the old Kustomize `helmCharts` approach:

### Before (Broken)

```yaml
# deploy/base/kustomization.yaml
helmCharts:
  - name: api
    repo: https://github.com/team/helm-registry.git
    version: 0.1.0
    valuesFile: values.yaml
```

### After (Working)

1. **Create environment configs**:

   ```bash
   mkdir -p deploy/environments
   # Create dev.yaml, production.yaml with chart versions
   ```

2. **Move values to overlays**:

   ```bash
   # Keep deploy/base/values.yaml
   # Create deploy/overlays/{env}/values.yaml for env-specific
   ```

3. **Remove helmCharts from kustomization**:

   ```bash
   # Delete helmCharts section from base/kustomization.yaml
   ```

4. **Update ApplicationSet**:
   ```bash
   # Change from single source to multi-source
   # Add Git Files Generator
   ```

> [!NOTE]
> This pattern is deprecated. See [Decentralized Helm Charts Pattern](../../guides/service-specific-charts.md) for the current recommended approach.

## Benefits

1. **Team Autonomy**: Teams control chart versions and environments
2. **Helm 4.x Compatible**: No Kustomize helmCharts dependency
3. **Git-Based**: All configuration in version control
4. **Self-Service**: No platform team bottleneck
5. **Gradual Rollout**: Test new versions in dev before production
6. **Clean Separation**: Helm charts vs. service configuration
7. **Local Testing**: Standard `helm template` works

## Resources

- [ArgoCD Multi-Source Applications](https://argo-cd.readthedocs.io/en/stable/user-guide/multiple_sources/)
- [ArgoCD ApplicationSet Git Files Generator](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Git/)
- [Helm Documentation](https://helm.sh/docs/)
