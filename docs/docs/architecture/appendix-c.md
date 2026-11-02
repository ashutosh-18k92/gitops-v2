# Appendix C: Troubleshooting Guide

### C.1 Common Issues

#### ArgoCD Shows 'Out of Sync'

**Symptoms:** Application status shows OutOfSync, manifests differ between Git and cluster.

**Diagnosis:**

```bash
# View differences
argocd app diff aggregator-service-production

# Check for manual changes
kubectl get deployment aggregator-api-v1 -n super-fortnight -o yaml
```

**Resolution:** Check if cluster state differs from Git. Manual changes to cluster resources cause drift. Review the diff to identify discrepancies. If changes are intentional, commit them to Git. If changes are unwanted, sync the application to restore Git state. Enable auto-sync with self-heal to prevent manual drift.

#### Patches Not Applying

**Symptoms:** Expected changes from patches not appearing in deployed resources.

**Diagnosis:**

```bash
# Build locally to see if patch applies
kustomize build deploy/overlays/production

# Check ArgoCD application events
argocd app get aggregator-service-production
```

**Resolution:** Verify patch targets match resource names exactly. Check that patches reference correct API versions and kinds. Ensure strategic merge directives are correct for list fields. Review ArgoCD application events for detailed error messages. Test patches locally with kustomize build to isolate issues. Ensure patch file is listed in kustomization.yaml patches section.

#### Values Not Overriding Chart Defaults

**Symptoms:** Deployed resources use chart defaults instead of overlay values.

**Diagnosis:**

```bash
# Render chart with values to verify merge
helm template aggregator ./charts/aggregator -f deploy/overlays/production/values.yaml

# Check rendered manifests in ArgoCD
argocd app manifests aggregator-service-production
```

**Resolution:** Confirm values file path is correct in kustomization.yaml helmCharts section. Verify values file syntax is valid YAML with proper indentation. Check that value paths match chart template expectations. Review rendered manifests to see actual applied values. Consult chart values.yaml and templates to understand supported value paths.

#### Sync Wave Timing Issues

**Symptoms:** Applications fail because dependencies not yet ready, resources deploy out of order.

**Diagnosis:**

```bash
# Check sync wave annotations
kubectl get <resource> -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/sync-wave}'

# Review ArgoCD sync operation
argocd app get <app-name> --show-operation
```

**Resolution:** Verify sync wave annotations are numeric strings not integers. Ensure health checks are configured for custom resources so ArgoCD knows when wave is complete. Check that lower waves complete before higher waves start. Review ArgoCD logs for health check failures. Consider adding explicit health check configurations for problematic resources in ArgoCD ConfigMap.

#### Chart Version Not Found

**Symptoms:** ArgoCD cannot fetch specified chart version.

**Diagnosis:**

```bash
# Check if chart version exists
helm search repo <chart-name> --versions

# Verify chart repository URL
helm repo list
```

**Resolution:** Verify chart repository URL is accessible. Confirm chart version exists in repository. Check if version string format is correct (v0.2.0 vs 0.2.0). Ensure ArgoCD has network access to chart repository. Update Helm repository cache if using Helm repository.

### C.2 Debugging Workflow

When encountering deployment issues, follow this systematic approach:

1.  **Check ArgoCD application status** for high-level health and sync state
2.  **Review application events** in ArgoCD UI or CLI for specific errors
3.  **Examine rendered manifests** to verify configuration is as expected
4.  **Check cluster resources** for actual deployed state and pod events
5.  **Review ArgoCD sync logs** for detailed operation information
6.  **Validate configurations locally** with kustomize build and helm template
7.  **Test incrementally** by starting with minimal configuration and adding complexity
8.  **Compare with working examples** from other services or environments

### C.3 Performance Issues

#### Slow ArgoCD Sync

**Symptoms:** Applications take excessive time to sync, ArgoCD UI sluggish.

**Resolution:** Check ArgoCD resource limits and scale if needed. Review number of applications being managed. Consider splitting large applications into smaller components. Optimize Kustomize builds by reducing patch complexity. Enable ArgoCD application sharding for very large deployments.

#### High Resource Usage in Kustomize Builds

**Symptoms:** Kustomize build operations consume excessive memory or CPU.

**Resolution:** Simplify patch structures and reduce nesting. Minimize number of patches per overlay. Consider breaking large applications into smaller components. Review chart templates for optimization opportunities. Use ArgoCD's build cache effectively.

---
