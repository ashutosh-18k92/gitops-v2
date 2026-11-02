---
sidebar_position: 1
---

# Super Fortnight Documentation

Welcome to the Super Fortnight cloud-native deployment documentation!

This documentation describes our **best-in-class GitOps workflow** using Helm, Kustomize, and ArgoCD for microservice deployments.

## Quick Start

New to the platform? Start here:

1. [Three-Tier Architecture](architecture/three-tier-architecture.md) - Understand the overall structure
2. [Cloud-Native Workflow](architecture/cloud-native-workflow.md) - See how it all works together
3. Choose your role:
   - **Feature Team**: [Feature Team Guide](guides/feature-team-guide.md)
   - **Platform Team**: [Platform Team Guide](guides/platform-team-guide.md)

## Architecture

Understand the platform architecture and design principles:

- **[Three-Tier Architecture](architecture/three-tier-architecture.md)**  
  Platform chart, team repositories, and GitOps orchestration

- **[Cloud-Native Workflow](architecture/cloud-native-workflow.md)**  
  Complete workflow from development to deployment

- **[ArgoCD Multi-Source Helm](architecture/deprecated/helm-kustomize-hybrid.md)**  
  How we use ArgoCD's multi-source pattern for Helm 4.x compatibility and team autonomy

- **[ApplicationSet Pattern](architecture/deprecated/applicationset-pattern.md)**  
  Git Files Generator for team-controlled environments and chart versions

## Guides

Step-by-step guides for common tasks:

### For Feature Teams

- **[Feature Team Guide](guides/feature-team-guide.md)**  
  Complete guide for feature teams: development, deployment, and operations

- **[Adding a New Service](guides/adding-new-service.md)**  
  Step-by-step guide to add a new microservice to the platform

- **[ArgoCD Applications](guides/argocd-applications.md)**  
  Understanding ArgoCD application definitions and deployment

### For Platform Teams

- **[Platform Team Guide](guides/platform-team-guide.md)**  
  Managing the base API chart, releasing versions, and supporting teams

## Reference

Detailed reference documentation:

- **[Helm Chart Reference](reference/helm-chart-reference.md)**  
  Complete reference for the base API chart structure and values

- **[Kustomize Patterns](reference/kustomize-patterns.md)**  
  Common Kustomize patterns and best practices

## Examples

Real-world implementation examples:

- **[Aggregator Service Implementation](examples/aggregator-implementation.md)**  
  Complete example of implementing a service with Helm + Kustomize

- **[Helm Registry Setup](examples/helm-registry-setup.md)**  
  Platform chart repository structure and management

## Key Concepts

### Team Autonomy

Service teams have **complete ownership** of their services:

- ✅ Code and deployment config in same repository
- ✅ Control when to adopt platform updates
- ✅ Independent release cycles
- ✅ No dependencies on platform team for deployments

### DRY Principle

Eliminate duplication through centralized templates:

- ✅ Base chart eliminates 200+ lines of YAML per service
- ✅ Service values: only 30 lines of overrides
- ✅ Shared templates across all services
- ✅ Consistent deployment patterns

### GitOps Excellence

Git as the single source of truth:

- ✅ Declarative configuration
- ✅ Automated sync via ArgoCD
- ✅ Easy rollback capability
- ✅ Complete audit trail

### Selective Adoption

Teams control when to adopt platform updates:

- ✅ Platform releases chart v0.2.0
- ✅ Teams review and test
- ✅ Teams upgrade when ready
- ✅ No forced updates

## Repository Structure

```
Super Fortnight Platform
│
├── sf-helm-registry (GitHub)
│   └── api/                          # Platform-maintained base chart
│
├── aggregator-service (GitHub)
│   ├── src/                          # Application code
│   └── deploy/                       # Deployment config
│       ├── base/
│       └── overlays/
│
├── gitops-v2 (GitHub)
│   └── services/                     # ArgoCD applications
│
└── gitops-v3 (This Repository)
    ├── docs/                         # Documentation (you are here!)
    └── helm-charts/
        ├── base/api/                 # Local copy (optional)
        └── starters/api/             # Starter template
```

## Common Workflows

### Feature Team: Deploy a Feature

```bash
# In service repository
vim src/index.ts                    # Code change
vim deploy/base/values.yaml         # Config change
git commit -m "Add feature"
git push                            # ArgoCD auto-syncs
```

### Feature Team: Adopt Platform Update

```bash
# Platform releases v0.2.0
vim deploy/base/kustomization.yaml  # version: 0.1.0 → 0.2.0
kustomize build deploy/overlays/production  # Test
git commit -m "Adopt API chart v0.2.0"
git push
```

### Platform Team: Release Chart Update

```bash
# In sf-helm-registry
vim api/templates/deployment.yaml
vim api/Chart.yaml                  # Bump version
git tag v0.2.0
git push origin main --tags
# Announce to teams
```

## Support

### For Feature Teams

- **Questions**: #platform-team Slack channel
- **Issues**: GitHub Issues in your service repository
- **Documentation**: [Feature Team Guide](guides/feature-team-guide.md)

### For Platform Team

- **Chart Repository**: https://github.com/ashutosh-18k92/sf-helm-registry
- **GitOps Repository**: gitops-v2 or gitops-v3
- **Documentation**: [Platform Team Guide](guides/platform-team-guide.md)

## Contributing

Found an issue or have a suggestion?

- **Documentation Issues**: Create an issue in gitops-v3
- **Chart Issues**: Create an issue in sf-helm-registry
- **Service Issues**: Create an issue in your service repository

## External Resources

- [Helm Documentation](https://helm.sh/docs/)
- [Kustomize Documentation](https://kustomize.io/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

---

**Last Updated**: 2026-01-30  
**Version**: 1.0
