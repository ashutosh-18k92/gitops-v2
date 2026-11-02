# Kustomize Patterns

## Overview

Common Kustomize patterns and best practices for the Super Fortnight platform.

## Strategic Merge Patches

### Basic Patch

```yaml
# patches/custom-env.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: service-api-v1
spec:
  template:
    spec:
      containers:
        - name: api
          env:
            - name: CUSTOM_VAR
              value: "custom-value"
```

### Resource Limits Patch

```yaml
# patches/resources.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: service-api-v1
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
```

### Affinity Patch

```yaml
# patches/affinity.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: service-api-v1
spec:
  template:
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchExpressions:
                    - key: app.kubernetes.io/name
                      operator: In
                      values:
                        - service-api-v1
                topologyKey: kubernetes.io/hostname
```

## ConfigMap Generator

### Literals

```yaml
# kustomization.yaml
configMapGenerator:
  - name: service-config
    literals:
      - LOG_LEVEL=debug
      - ENABLE_FEATURE_X=true
      - MAX_CONNECTIONS=100
```

### From Files

```yaml
# kustomization.yaml
configMapGenerator:
  - name: service-config
    files:
      - config.json
      - application.properties
```

### From Env File

```yaml
# kustomization.yaml
configMapGenerator:
  - name: service-config
    envs:
      - .env.production
```

## Secret Generator

### Basic Secrets

```yaml
# kustomization.yaml
secretGenerator:
  - name: api-secrets
    literals:
      - DATABASE_PASSWORD=changeme
      - API_KEY=secret-key
```

### From Files

```yaml
# kustomization.yaml
secretGenerator:
  - name: tls-secrets
    files:
      - tls.crt
      - tls.key
```

## Namespace Transformation

```yaml
# kustomization.yaml
namespace: super-fortnight-production
```

## Name Prefix/Suffix

```yaml
# kustomization.yaml
namePrefix: prod-
nameSuffix: -v2
```

## Common Labels

```yaml
# kustomization.yaml
commonLabels:
  environment: production
  team: platform
  managed-by: kustomize
```

## Common Annotations

```yaml
# kustomization.yaml
commonAnnotations:
  deployed-by: argocd
  version: "1.0.0"
```

## Images Transformation

```yaml
# kustomization.yaml
images:
  - name: service-name
    newName: ghcr.io/org/service-name
    newTag: v1.2.3
```

## Replicas Transformation

```yaml
# kustomization.yaml
replicas:
  - name: service-api-v1
    count: 5
```

## Complete Example

### Base

```yaml
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

helmCharts:
  - name: api
    repo: https://github.com/ashutosh-18k92/sf-helm-registry.git
    releaseName: myservice
    namespace: super-fortnight
    valuesFile: values.yaml
    version: 0.1.0
    includeCRDs: false
```

### Development Overlay

```yaml
# overlays/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

namespace: super-fortnight-dev

commonLabels:
  environment: development

configMapGenerator:
  - name: service-config
    literals:
      - LOG_LEVEL=debug
      - ENABLE_DEBUG=true

images:
  - name: myservice
    newTag: dev-latest
```

### Production Overlay

```yaml
# overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

namespace: super-fortnight

commonLabels:
  environment: production

patchesStrategicMerge:
  - patches/deployment-affinity.yaml
  - patches/hpa-scaling.yaml
  - patches/production-resources.yaml

configMapGenerator:
  - name: service-config
    literals:
      - LOG_LEVEL=error
      - ENABLE_DEBUG=false

secretGenerator:
  - name: api-secrets
    literals:
      - DATABASE_PASSWORD=${DB_PASSWORD}
      - API_KEY=${API_KEY}

images:
  - name: myservice
    newTag: v1.2.3

replicas:
  - name: myservice-api-v1
    count: 3
```

## Best Practices

### ✅ DO

- Use strategic merge for simple changes
- Keep patches focused and minimal
- Use generators for ConfigMaps and Secrets
- Document complex patches with comments
- Test with `kustomize build` before committing
- Use overlays for environment-specific config

### ❌ DON'T

- Don't create massive patches (indicates base chart issue)
- Don't duplicate logic across overlays
- Don't hardcode sensitive data in patches
- Don't patch templates directly
- Don't use JSON patches unless necessary

## Common Pitfalls

### Resource Name Mismatch

**Problem**: Patch doesn't apply because resource name doesn't match.

**Solution**: Verify resource name with `kustomize build`:

```bash
kustomize build . | grep "name: service-api-v1"
```

### ConfigMap Name Changes

**Problem**: ConfigMap name changes on every build due to hash suffix.

**Solution**: Use `disableNameSuffixHash`:

```yaml
configMapGenerator:
  - name: service-config
    literals:
      - LOG_LEVEL=debug
    options:
      disableNameSuffixHash: true
```

### Patch Order

**Problem**: Patches applied in wrong order.

**Solution**: List patches in desired order in `patchesStrategicMerge`.

## Testing

```bash
# Build and view output
kustomize build overlays/production

# Save for review
kustomize build overlays/production > /tmp/output.yaml

# Validate against cluster
kustomize build overlays/production | kubectl apply --dry-run=client -f -

# Diff against cluster
kustomize build overlays/production | kubectl diff -f -
```

## Related Documentation

- [Feature Team Guide](../guides/feature-team-guide.md)
- [Decentralized Helm Charts Pattern](../guides/service-specific-charts.md)
- [Adding a New Service](../guides/adding-new-service.md)
