# Appendix B: Command Reference

### B.1 Platform Team Commands

**Testing and validating charts:**

```bash
# Lint chart for errors
helm lint ./charts/api

# Render chart with default values
helm template test ./charts/api

# Render with specific values file
helm template test ./charts/api -f test-values.yaml

# Validate schema if values.schema.json exists
helm lint ./charts/api --strict

# Package chart for distribution
helm package ./charts/api
```

**Releasing new chart versions:**

```bash
# Update Chart.yaml version
vim charts/api/Chart.yaml

# Create git tag
git tag v0.2.0
git push origin main --tags

# Package and publish (if using chart repository)
helm package charts/api
helm repo index .
```

### B.2 Feature Team Commands

**Validating configurations:**

```bash
# Build kustomize overlay locally (if Helm 3.x)
kustomize build deploy/overlays/development

# Preview what ArgoCD will deploy
argocd app diff aggregator-service-dev

# View rendered manifests without applying
argocd app manifests aggregator-service-dev

# Validate kustomization syntax
kustomize build deploy/overlays/development --dry-run
```

**Checking deployment status:**

```bash
# Get application status
argocd app get aggregator-service-production

# View sync history
argocd app history aggregator-service-production

# Verify cluster resources
kubectl get all -n super-fortnight -l app=aggregator

# Check pod logs
kubectl logs -n super-fortnight -l app=aggregator --tail=100

# Describe deployment for events
kubectl describe deployment aggregator-api-v1 -n super-fortnight
```

**Managing chart versions:**

```bash
# Upgrade development to new chart version
cd deploy/overlays/development
vim kustomization.yaml  # Update version
git commit -m "Upgrade dev to chart v0.2.4"
git push

# Sync specific application manually
argocd app sync aggregator-service-dev

# Rollback to previous sync
argocd app rollback aggregator-service-production
```

### B.3 ArgoCD Administration Commands

**Managing applications:**

```bash
# List all applications
argocd app list

# Get application details
argocd app get <app-name>

# Manually sync application
argocd app sync <app-name>

# Delete application
argocd app delete <app-name>

# Set sync policy
argocd app set <app-name> --sync-policy automated
```

**Troubleshooting:**

```bash
# View application events
argocd app get <app-name> --show-operation

# View sync logs
argocd app logs <app-name> --follow

# Compare Git vs cluster state
argocd app diff <app-name>

# Refresh application (check for changes)
argocd app refresh <app-name>
```

---
