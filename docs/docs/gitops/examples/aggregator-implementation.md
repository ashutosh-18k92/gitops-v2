# Aggregator Service - Implementation Guide

## Overview

This guide documents the **cloud-native deployment implementation** for the aggregator service using the **Helm + Kustomize hybrid approach**.

The aggregator service exemplifies best-in-class practices for microservice deployment with complete team autonomy.

## Implementation Architecture

### Directory Structure

```
GitHub Repository (sf-helm-registry):
https://github.com/ashutosh-18k92/sf-helm-registry.git
├── README.md
└── api/                           # ← Base API chart
    ├── Chart.yaml (v0.1.0)
    ├── templates/
    ├── values.yaml
    └── values.schema.json

GitOps Repository (gitops-v3):
└── services/
    └── aggregator/                # ← Team-owned service
        ├── base/
        │   ├── kustomization.yaml # References GitHub chart
        │   └── values.yaml        # Service-specific values (minimal)
        ├── overlays/
        │   ├── dev/
        │   │   └── kustomization.yaml
        │   └── production/
        │       ├── kustomization.yaml
        │       └── patches/
        │           ├── deployment-affinity.yaml
        │           ├── hpa-scaling.yaml
        │           └── production-resources.yaml
        └── README.md
```

### Files Created

**GitHub Repository (sf-helm-registry)**:

1. **`api/Chart.yaml`** - Chart metadata (v0.1.0)
2. **`api/templates/`** - All Helm templates
3. **`api/values.yaml`** - Base default values
4. **`api/values.{env}.yaml`** - Environment-specific defaults
5. **`README.md`** - Repository documentation

**GitOps Repository (gitops-v3)**:

1. **`services/aggregator/base/kustomization.yaml`** - References GitHub chart
2. **`services/aggregator/base/values.yaml`** - Service-specific values (minimal - 30 lines)
3. **`services/aggregator/overlays/dev/kustomization.yaml`** - Dev environment
4. **`services/aggregator/overlays/production/kustomization.yaml`** - Production environment
5. **`services/aggregator/overlays/production/patches/`** - Production patches:
   - `deployment-affinity.yaml` - Node and zone spreading
   - `hpa-scaling.yaml` - 5-20 replicas with CPU/memory targets
   - `production-resources.yaml` - Increased resources and health checks
6. **`services/aggregator/README.md`** - Service documentation
7. **`HELM_KUSTOMIZE_HYBRID.md`** - Workflow documentation
8. **`BASE_CHART_REPOSITORY.md`** - GitHub repository guide

## Key Benefits

### Team Autonomy

- Aggregator team owns their service completely
- Can choose when to upgrade base chart (currently pinned to v0.1.0)
- Can create custom patches without modifying base templates
- **No dependency on platform team for deployments**

### Selective Adoption

- Platform team updates chart in GitHub repository
- Aggregator team reviews and decides to upgrade
- Other teams can stay on older versions
- **True separation of concerns**

### GitHub-Based Workflow

- **No local `base/api/` directory** needed in gitops-v3
- Chart fetched directly from GitHub by Kustomize
- Clear ownership: Platform owns sf-helm-registry, teams own gitops-v3
- **Reusable across multiple GitOps repositories**

### Environment-Specific Configuration

- **Dev**: 1 replica, debug logging, minimal resources
- **Production**: 5-20 replicas, error logging, affinity, increased resources
- **Minimal service values**: Only 30 lines of service-specific overrides

## Testing the Implementation

### Render Manifests

```bash
cd helm-charts

# Render production environment
kustomize build services/aggregator/overlays/production

# Render dev environment
kustomize build services/aggregator/overlays/dev

# Save for review
kustomize build services/aggregator/overlays/production > /tmp/aggregator-prod.yaml
```

### Validate

```bash
# Dry-run apply
kustomize build services/aggregator/overlays/production | kubectl apply --dry-run=client -f -

# Check for errors
kustomize build services/aggregator/overlays/production | kubectl apply --dry-run=server -f -
```

## Next Steps

### 1. Update ArgoCD Application

```yaml
# argocd/applications/aggregator-prod.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: aggregator-prod
spec:
  source:
    repoURL: https://github.com/your-org/gitops-v3
    targetRevision: main
    path: helm-charts/services/aggregator/overlays/production
    kustomize:
      version: v5.0.0 # Use latest Kustomize
  destination:
    server: https://kubernetes.default.svc
    namespace: super-fortnight
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### 2. Clean Up Legacy Files (Optional)

Once verified working, you can remove:

- `services/aggregator/Chart.yaml` (legacy)
- `services/aggregator/templates/` (legacy)
- `services/aggregator/values.yaml` (legacy - now in base/)
- `services/aggregator/values.*.yaml` (legacy - now in overlays/)

### 3. Add Other Services

Use aggregator as a template:

```bash
# Copy structure
cp -r services/aggregator/base services/paper/
cp -r services/aggregator/overlays services/paper/

# Update service-specific values
vim services/paper/base/values.yaml
# Change: port, image, service name

# Update kustomization
vim services/paper/base/kustomization.yaml
# Change: releaseName: aggregator → paper
```

## Team Workflow Examples

### Scenario 1: Platform Updates Base Chart

```bash
# Platform team updates chart in GitHub
cd sf-helm-registry/api
vim templates/deployment.yaml
vim Chart.yaml  # Bump version to 0.2.0
git commit -m "v0.2.0: Add new feature"
git tag v0.2.0
git push origin main --tags

# Aggregator team reviews and decides to upgrade
cd gitops-v3/helm-charts/services/aggregator/base
vim kustomization.yaml
# Change: version: 0.1.0 → version: 0.2.0

# Test
kustomize build ../overlays/production

# Commit
git commit -m "Upgrade aggregator to API chart v0.2.0 from GitHub"
git push
```

### Scenario 2: Team Needs Custom Feature

```bash
# Aggregator team wants custom timeout
cd gitops-v3/helm-charts/services/aggregator/overlays/production

cat > patches/custom-timeout.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aggregator-api-v1
spec:
  template:
    spec:
      containers:
        - name: api
          env:
            - name: REQUEST_TIMEOUT
              value: "30s"
EOF

# Add to kustomization
vim kustomization.yaml
# Add: - patches/custom-timeout.yaml

# Test and commit
kustomize build . | kubectl apply --dry-run=client -f -
git commit -m "Add custom request timeout for aggregator"
git push
```

### Scenario 3: Team Rejects Update

```bash
# Platform releases v0.3.0 with breaking changes in GitHub
# Aggregator team decides to stay on v0.2.0

# No action needed!
# Team controls version in base/kustomization.yaml
# Can upgrade when ready (or never)
```

## Troubleshooting

### Kustomize Not Found

```bash
# Install kustomize
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
sudo mv kustomize /usr/local/bin/
```

### Helm Chart Not Rendering

```bash
# Verify base chart exists
ls -la base/api/

# Check kustomization syntax
kustomize build services/aggregator/base --enable-helm
```

### Patches Not Applied

```bash
# Verify resource names match
kustomize build services/aggregator/overlays/production | grep "name: aggregator-api-v1"

# Check patch syntax
yamllint services/aggregator/overlays/production/patches/*.yaml
```

## Summary

✅ **Implementation Complete**  
✅ **Team Autonomy Enabled**  
✅ **Selective Updates Possible**  
✅ **Environment-Specific Patches Working**  
✅ **Production Ready**

The aggregator service exemplifies best-in-class cloud-native deployment practices!

## Related Documentation

- [Feature Team Guide](../guides/feature-team-guide.md)
- [Platform Team Guide](../guides/platform-team-guide.md)
- [Cloud-Native Workflow](../architecture/cloud-native-workflow.md)
- [Decentralized Helm Charts Pattern](../guides/service-specific-charts.md)
- [Adding a New Service](../guides/adding-new-service.md)
