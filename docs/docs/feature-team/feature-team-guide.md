# Feature Team Guide

## Overview

This guide is for **Feature Teams** who own and deploy microservices using the Helm + Kustomize hybrid approach.

Your team has **complete autonomy** over your service's deployment lifecycle.

## Your Repository Structure

```
your-service/
├── src/                        # Application code
│   └── index.ts
├── deploy/                     # Deployment configuration
│   ├── base/
│   │   ├── kustomization.yaml  # References platform chart
│   │   └── values.yaml         # Service-specific values (30 lines)
│   └── overlays/
│       ├── dev/
│       │   └── kustomization.yaml
│       └── production/
│           ├── kustomization.yaml
│           └── patches/
│               ├── deployment-affinity.yaml
│               ├── hpa-scaling.yaml
│               └── production-resources.yaml
├── package.json
├── Dockerfile
└── README.md
```

## Getting Started

### 1. Base Configuration

**File**: `deploy/base/kustomization.yaml`

```yaml
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

**File**: `deploy/base/values.yaml` (keep it minimal!)

```yaml
# Only service-specific overrides
containerPort: 3000

image:
  repository: "your-service"
  tag: "latest"

env:
  SERVICE_NAME: "your-service"
  LOG_LEVEL: "info"

virtualService:
  hosts:
    - your-service

healthCheck:
  livenessProbe:
    httpGet:
      path: /health
      port: 3000
  readinessProbe:
    httpGet:
      path: /ready
      port: 3000
```

### 2. Environment Overlays

**Development** (`deploy/overlays/dev/kustomization.yaml`):

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

configMapGenerator:
  - name: service-config
    literals:
      - LOG_LEVEL=debug
      - ENABLE_DEBUG=true
```

**Production** (`deploy/overlays/production/kustomization.yaml`):

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

patchesStrategicMerge:
  - patches/deployment-affinity.yaml
  - patches/hpa-scaling.yaml
  - patches/production-resources.yaml

configMapGenerator:
  - name: service-config
    literals:
      - LOG_LEVEL=error
      - ENABLE_DEBUG=false
```

## Common Workflows

### Scenario 1: Application Development

```bash
# Clone your repository
git clone https://github.com/your-org/your-service.git
cd your-service

# Develop feature
vim src/index.ts
npm run dev

# Update deployment config (same PR!)
vim deploy/base/values.yaml
# Update image tag or environment variables

# Commit both code and config
git add src/ deploy/
git commit -m "feat: Add feature X with deployment config"
git push

# ArgoCD automatically syncs to cluster
```

**Benefits**:

- ✅ Code and deployment in single PR
- ✅ Atomic changes
- ✅ Easy rollback
- ✅ Complete ownership

### Scenario 2: Adopting Platform Chart Updates

```bash
# Platform team announces API chart v0.2.0

# Review changes
git clone https://github.com/ashutosh-18k92/sf-helm-registry.git /tmp/helm-registry
cd /tmp/helm-registry
git log v0.1.0..v0.2.0
git diff v0.1.0..v0.2.0

# Test locally
cd your-service/deploy/base
vim kustomization.yaml
# Change: version: 0.1.0 → 0.2.0

# Render and review
kustomize build ../overlays/production

# Test deployment
kustomize build ../overlays/production | kubectl apply --dry-run=client -f -

# Commit when satisfied
git add deploy/base/kustomization.yaml
git commit -m "chore: Upgrade to API chart v0.2.0"
git push
```

**Benefits**:

- ✅ You control timing
- ✅ Test before deploying
- ✅ No forced updates
- ✅ Gradual rollout

> [!NOTE]
> **How version pinning works**: When you specify `version: 0.1.0`, Kustomize checks out that **Git tag** from the chart repository. The platform team's newer releases (v0.2.0, v0.3.0, etc.) don't affect you because Git preserves all tagged versions in history. You can stay on v0.1.0 forever if needed!

### Scenario 3: Adding Custom Configuration

```bash
# Add production-specific feature flag
cd deploy/overlays/production

cat > patches/feature-flag.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: your-service-api-v1
spec:
  template:
    spec:
      containers:
        - name: api
          env:
            - name: ENABLE_CACHING
              value: "true"
            - name: CACHE_TTL
              value: "3600"
EOF

# Add to kustomization
vim kustomization.yaml
# Add under patchesStrategicMerge:
#   - patches/feature-flag.yaml

# Test
kustomize build .

# Commit
git add patches/feature-flag.yaml kustomization.yaml
git commit -m "feat: Enable caching in production"
git push
```

**Benefits**:

- ✅ Environment-specific config
- ✅ No base chart modification
- ✅ Preserved across chart updates
- ✅ Clear separation of concerns

### Scenario 4: Updating Environment Variables

```bash
# Update production config
cd deploy/overlays/production
vim kustomization.yaml

# Modify configMapGenerator
configMapGenerator:
  - name: service-config
    literals:
      - LOG_LEVEL=error
      - ENABLE_DEBUG=false
      - NEW_FEATURE_FLAG=true  # ← Add this

# Commit
git commit -am "config: Enable new feature in production"
git push
```

### Scenario 5: Scaling Configuration

```bash
# Update HPA for production
cd deploy/overlays/production/patches
vim hpa-scaling.yaml
```

**Example**:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: your-service-api-v1-hpa
spec:
  minReplicas: 5 # ← Increase from 3
  maxReplicas: 30 # ← Increase from 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70 # ← Lower threshold
```

```bash
git commit -am "scale: Increase production capacity"
git push
```

## Testing

### Local Testing

```bash
# Render manifests
kustomize build deploy/overlays/production

# Save for review
kustomize build deploy/overlays/production > /tmp/manifests.yaml
less /tmp/manifests.yaml

# Validate syntax
kustomize build deploy/overlays/production | kubectl apply --dry-run=client -f -

# Test against cluster
kustomize build deploy/overlays/production | kubectl diff -f -
```

### Verify Deployment

```bash
# Check ArgoCD sync status
argocd app get your-service

# Check pods
kubectl get pods -n super-fortnight -l app.kubernetes.io/name=your-service-api-v1

# Check logs
kubectl logs -n super-fortnight -l app.kubernetes.io/name=your-service-api-v1 --tail=50

# Check service
kubectl get svc -n super-fortnight -l app.kubernetes.io/name=your-service-api-v1
```

## Best Practices

### ✅ DO

**Version Control**:

- Pin specific chart versions (e.g., `version: 0.1.0`)
- Review platform updates before adopting
- Test locally with `kustomize build` before pushing

**Configuration**:

- Keep `deploy/base/values.yaml` minimal (30-50 lines)
- Use overlays for environment-specific config
- Use patches for targeted modifications

**Deployment**:

- Commit code and deployment config together
- Use semantic commit messages
- Test in dev environment first

**Collaboration**:

- Document custom patches
- Share learnings with other teams
- Ask platform team for help when needed

### ❌ DON'T

**Version Control**:

- Don't use `latest` for chart version
- Don't skip testing before deployment
- Don't commit untested changes

**Configuration**:

- Don't duplicate base chart logic
- Don't hardcode values in patches
- Don't create massive patches (indicates base chart issue)

**Deployment**:

- Don't modify base chart templates
- Don't bypass ArgoCD for deployments
- Don't ignore sync errors

## Common Patterns

### Adding a Secret

```bash
cd deploy/overlays/production
vim kustomization.yaml
```

Add:

```yaml
secretGenerator:
  - name: api-secrets
    literals:
      - DATABASE_PASSWORD=changeme
      - API_KEY=secret
```

### Adding Resource Limits

```bash
cd deploy/overlays/production/patches
cat > resources.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: your-service-api-v1
spec:
  template:
    spec:
      containers:
        - name: api
          resources:
            requests:
              memory: "256Mi"
              cpu: "200m"
            limits:
              memory: "512Mi"
              cpu: "500m"
EOF
```

### Adding Node Affinity

```bash
cd deploy/overlays/production/patches
cat > node-affinity.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: your-service-api-v1
spec:
  template:
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: workload-type
                    operator: In
                    values:
                      - compute-optimized
EOF
```

## Troubleshooting

### Kustomize Build Fails

```bash
# Check syntax
kustomize build deploy/overlays/production

# Enable verbose output
kustomize build deploy/overlays/production --enable-alpha-plugins

# Validate YAML
yamllint deploy/overlays/production/patches/*.yaml
```

### ArgoCD Sync Fails

```bash
# Check application status
argocd app get your-service

# View sync errors
argocd app get your-service --show-operation

# Manual sync
argocd app sync your-service

# Refresh
argocd app refresh your-service
```

### Patches Not Applied

```bash
# Verify resource names match
kustomize build deploy/overlays/production | grep "name: your-service-api-v1"

# Check patch syntax
cat deploy/overlays/production/patches/your-patch.yaml

# Test patch individually
kustomize build deploy/overlays/production | grep -A 20 "kind: Deployment"
```

## Support

### Resources

- **Platform Team**: #platform-team Slack channel
- **Chart Repository**: https://github.com/ashutosh-18k92/sf-helm-registry
- **Documentation**: [Platform Team Guide](platform-team-guide.md)

### Getting Help

1. Check this guide first
2. Review [Decentralized Helm Charts Pattern](service-specific-charts.md) documentation
3. Ask in #platform-team Slack channel
4. Create GitHub issue in sf-helm-registry

## Related Documentation

- [Three-Tier Architecture](../architecture/three-tier-architecture.md)
- [Cloud-Native Workflow](../architecture/cloud-native-workflow.md)
- [Platform Team Guide](platform-team-guide.md)
- [ArgoCD Applications](argocd-applications.md)
- [Adding a New Service](adding-new-service.md)
