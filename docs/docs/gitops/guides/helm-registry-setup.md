# Helm Registry Repository

## Overview

The `sf-helm-registry` repository hosts the **platform-maintained base API chart** used by all microservices in the Super Fortnight platform.

**Repository**: https://github.com/ashutosh-18k92/sf-helm-registry.git

## Purpose

This repository serves as the **single source of truth** for Helm chart templates, enabling:

- ✅ **Centralized Management** - Platform team maintains one set of templates
- ✅ **Version Control** - Semantic versioning with Git tags
- ✅ **Team Autonomy** - Service teams choose when to adopt updates
- ✅ **Reusability** - Chart can be used across multiple GitOps repositories

## Repository Structure

```
sf-helm-registry/
├── README.md               # Repository documentation
├── CHANGELOG.md            # Version history
└── charts/
    └── api/                    # Base API Helm chart
        ├── Chart.yaml          # Chart metadata (version: 0.1.0)
        ├── values.yaml         # Base default values
        ├── values.dev.yaml     # Development environment defaults
        ├── values.stage.yaml   # Staging environment defaults
        ├── values.prod.yaml    # Production environment defaults
        ├── values.schema.json  # Values validation schema
        └── templates/
            ├── deployment.yaml
            ├── service.yaml
            ├── hpa.yaml
            ├── istioVirtualService.yaml
            ├── serviceAccount.yaml
            ├── _helpers.tpl
            └── tests/
                └── test-connection.yaml
```

## Chart Features

The base API chart includes production-ready templates:

- **Deployment** - With affinity rules for high availability
- **Service** - ClusterIP service for internal communication
- **HPA** - Horizontal Pod Autoscaler with CPU/memory targets
- **Istio VirtualService** - Service mesh integration
- **ServiceAccount** - RBAC support
- **Standardized Labels** - Consistent labeling across all services

## How It's Used

Service teams reference this chart via Kustomize:

```yaml
# In service repository: deploy/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

helmCharts:
  - name: api
    repo: https://github.com/ashutosh-18k92/sf-helm-registry.git
    releaseName: your-service
    namespace: super-fortnight
    valuesFile: values.yaml
    version: 0.1.0 # Pin specific version
    includeCRDs: false
```

## Management Workflow

### Platform Team Releases New Version

```bash
# Clone repository
git clone https://github.com/ashutosh-18k92/sf-helm-registry.git
cd sf-helm-registry/api

# Make changes
vim templates/deployment.yaml
vim values.yaml

# Update version
vim Chart.yaml  # version: 0.1.0 → 0.2.0

# Test
helm lint .
helm template test . --dry-run

# Commit and tag
git add .
git commit -m "v0.2.0: Add Prometheus annotations"
git tag v0.2.0
git push origin main --tags
```

### Feature Teams Adopt Updates

```bash
# In service repository
cd deploy/base
vim kustomization.yaml
# Change: version: 0.1.0 → 0.2.0

# Test
kustomize build ../overlays/production

# Commit
git commit -m "Adopt API chart v0.2.0"
git push
```

## Versioning Strategy

The chart follows **semantic versioning**:

- **MAJOR** (1.0.0 → 2.0.0): Breaking changes
- **MINOR** (0.1.0 → 0.2.0): New features, backward compatible
- **PATCH** (0.1.0 → 0.1.1): Bug fixes, backward compatible

Each version is tagged in Git:

```bash
git tag -l
# v0.1.0
# v0.2.0
# v0.3.0
```

## Benefits

### For Platform Team

- ✅ Single place to maintain templates
- ✅ Clear versioning and release process
- ✅ Easy to test and validate changes
- ✅ Independent from service repositories

### For Feature Teams

- ✅ Always have access to latest templates
- ✅ Control when to adopt updates
- ✅ Can pin to specific versions
- ✅ No local chart copies to maintain

### For the Organization

- ✅ Consistent deployment patterns
- ✅ Best practices enforced at platform level
- ✅ Reduced duplication across services
- ✅ Clear separation of concerns

## Related Documentation

- [Platform Team Guide](../guides/platform-team-guide.md) - How to manage this repository
- [Feature Team Guide](../guides/feature-team-guide.md) - How to use this chart
- [Three-Tier Architecture](../architecture/three-tier-architecture.md) - Where this fits
- [Cloud-Native Workflow](../architecture/cloud-native-workflow.md) - Complete workflow
