# Service Deployments - ArgoCD Applications

## Overview

This directory contains **ArgoCD Application manifests** that deploy microservices from their team-owned repositories.

This pattern implements cloud-native best practices where:

- **Platform team** manages ArgoCD application definitions (this repository)
- **Service teams** manage code and deployment config (team repositories)
- **ArgoCD** automatically syncs from team repositories to Kubernetes

## Architecture

```
┌─────────────────────────────────────────┐
│  Team Repository                        │
│  github.com/org/aggregator-service      │
│                                         │
│  ├── src/                               │
│  └── deploy/                            │
│      ├── base/                          │
│      └── overlays/                      │
│          ├── dev/                       │
│          └── production/                │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│  GitOps Repository (this repo)          │
│                                         │
│  services/                              │
│  └── aggregator-service.yaml           │
│      (ArgoCD Application)               │
│      source:                            │
│        repoURL: team-repo               │
│        path: deploy/overlays/production │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│  ArgoCD                                 │
│  - Monitors team repository             │
│  - Syncs to Kubernetes cluster          │
└─────────────────────────────────────────┘
```

## Directory Structure

```
services/
├── aggregator-service.yaml       # Production deployment
├── aggregator-service-dev.yaml   # Dev deployment
├── paper-service.yaml            # (To be implemented)
├── rock-service.yaml             # (To be implemented)
├── scissor-service.yaml          # (To be implemented)
└── README.md                     # This file
```

## Service Applications

### Aggregator Service

**Production** (`aggregator-service.yaml`):

- Source: `github.com/ashutosh-18k92/aggregator-service`
- Path: `deploy/overlays/production`
- Namespace: `super-fortnight`
- Auto-sync: Enabled

**Development** (`aggregator-service-dev.yaml`):

- Source: `github.com/ashutosh-18k92/aggregator-service`
- Path: `deploy/overlays/dev`
- Namespace: `super-fortnight-dev`
- Auto-sync: Enabled

### Other Services

Paper, Rock, and Scissor services follow the same pattern and will be implemented using the aggregator service as a reference.

## Deployment

### Apply ArgoCD Applications

```bash
# Apply all service applications
kubectl apply -f services/

# Or apply individual services
kubectl apply -f services/aggregator-service.yaml
kubectl apply -f services/aggregator-service-dev.yaml
```

### Verify Deployment

```bash
# Check ArgoCD applications
kubectl get applications -n argocd

# Check specific application
argocd app get aggregator-service

# View sync status
argocd app list

# Check deployed resources
kubectl get all -n super-fortnight -l app.kubernetes.io/name=aggregator-api-v1
```

## Team Workflow

### How It Works

1. **Service team** makes changes in their repository:

   ```bash
   cd aggregator-service
   vim src/index.ts                    # Code change
   vim deploy/base/values.yaml         # Deployment change
   git commit -m "Update feature"
   git push
   ```

2. **ArgoCD** automatically detects changes:
   - Monitors team repository
   - Compares desired state (Git) vs actual state (cluster)
   - Syncs automatically if auto-sync enabled

3. **Kubernetes** applies changes:
   - Rolling update for deployments
   - Zero-downtime deployment
   - Automatic rollback on failure

### No Changes Needed Here!

The beauty of this pattern: **feature teams never need to touch this repository**.

- Teams work in their own repositories
- ArgoCD monitors team repositories directly
- This repository only changes when adding/removing services

## Adding a New Service

To add a new service (e.g., `new-service`):

1. **Create team repository** with deployment config:

   ```
   new-service/
   ├── src/
   └── deploy/
       ├── base/
       └── overlays/
   ```

2. **Create ArgoCD application** in this repository:

   ```bash
   cat > services/new-service.yaml <<EOF
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: new-service
     namespace: argocd
   spec:
     source:
       repoURL: https://github.com/your-org/new-service.git
       path: deploy/overlays/production
       kustomize:
         version: v5.0.0
     destination:
       namespace: super-fortnight
     syncPolicy:
       automated:
         prune: true
         selfHeal: true
   EOF
   ```

3. **Apply to cluster**:
   ```bash
   kubectl apply -f services/new-service.yaml
   ```

## Benefits

### Team Autonomy

✅ Teams own their deployment configuration  
✅ No dependency on central GitOps repository  
✅ Changes deploy automatically via ArgoCD

### Clear Separation

✅ Platform team: Manages ArgoCD applications  
✅ Service teams: Manage code and deployment  
✅ ArgoCD: Handles synchronization

### GitOps Excellence

✅ Git as single source of truth  
✅ Declarative configuration  
✅ Automated sync and rollback  
✅ Audit trail via Git history

## Troubleshooting

### Application Not Syncing

```bash
# Check application status
argocd app get aggregator-service

# Manual sync
argocd app sync aggregator-service

# Check sync errors
argocd app get aggregator-service --show-operation
```

### Deployment Issues

```bash
# Check application events
kubectl describe application aggregator-service -n argocd

# Check deployed resources
kubectl get all -n super-fortnight

# View logs
kubectl logs -n super-fortnight -l app.kubernetes.io/name=aggregator-api-v1
```

### Repository Access Issues

```bash
# Verify repository credentials
argocd repo list

# Add repository if needed
argocd repo add https://github.com/your-org/aggregator-service.git
```

## Related Documentation

- [Cloud-Native Workflow](../architecture/cloud-native-workflow.md)
- [Feature Team Guide](feature-team-guide.md)
- [Decentralized Helm Charts Pattern](../guides/service-specific-charts.md)
- [Adding a New Service](adding-new-service.md)

## Support

- **Platform Team**: #platform-team
- **ArgoCD Issues**: #argocd-support
- **Documentation**: [Documentation Index](../README.md)
