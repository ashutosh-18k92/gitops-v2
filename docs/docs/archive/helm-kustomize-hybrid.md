# Kustomize with Per-Environment Helm Charts

## Architecture

### What's the one-sentence architecture philosophy?

> _"Centralized templates, decentralized control—platform teams provide the foundation, feature teams own the execution."_

Here's the **working solution** tested on the following benchmarks:

### Team Autonomy

**Q: How do we prevent platform changes from blocking feature team deployments?**

A: By establishing clear separation of concerns—platform teams own the infrastructure templates and operators, while feature teams maintain complete ownership of their service configurations. Each team operates in their own repository with their own deployment cadence.

### Modular Patches

**Q: What happens when the Auth team needs a custom security patch that doesn't apply to Payments?**

A: Feature teams can add environment-specific patches that only affect their services. A patch applied in the Auth team's staging environment has zero impact on Payments' staging or any other team's environments. True modularity without collision.

### Independent Environment Configurations

**Q: Why should production configuration decisions wait for dev and staging consensus?**

A: They shouldn't. Each environment maintains its own configuration—dev can experiment with minimal resources, staging can mirror production topology, and production can enforce strict security policies. No environment is hostage to another's requirements.

### Independent Environment Upgrades

**Q: Should a breaking change in development prevent critical production hotfixes?**

A: Absolutely not. Each environment upgrades on its own schedule. Development can test Kafka 3.8 while production remains stable on 3.6. When production needs an urgent security patch, it doesn't wait for dev's experimental features to stabilize.

### Environment-Based Overlays

**Q: How do we handle the reality that dev needs 256MB RAM while production needs 4GB?**

A: Through environment-specific Kustomize overlays. Each environment applies only the transformations it needs—dev patches down to minimal resources, staging adds moderate scaling, production layers on full HA configuration with HPA. Same base, radically different runtime profiles.

### Embedded Base Values

**Q: Why are we tired of managing separate `values-base.yaml` files alongside Kustomize patches?**

A: Because Kustomize doesn't support multi-file Helm value merging elegantly. We embedded base values directly into the service chart itself. Now feature teams only manage their environment overlays—the chart ships with sensible defaults, and Kustomize patches do what they do best: targeted transformations.

### Approach: Kustomize with Per-Environment helmCharts

Each environment overlay defines its own Helm chart version in its `kustomization.yaml`.

## Repository Structure

```
aggregator-service/
├── charts
│   ├── aggregator                        # Helm chart for the service
│   │   ├── Chart.yaml
│   │   ├── README.md
│   │   ├── templates
│   │   │   ├── deployment.yaml
│   │   │   ├── _helpers.tpl
│   │   │   ├── hpa.yaml
│   │   │   ├── ingress.yaml
│   │   │   ├── NOTES.txt
│   │   │   ├── serviceAccount.yaml
│   │   │   ├── service.yaml
│   │   │   └── tests
│   │   │       └── test-connection.yaml
│   │   ├── values.schema.json              # schema validation for values.yaml
│   │   └── values.yaml
│   └── ct.yaml                             # chart testing
├── deploy
│   ├── environments
│   │   ├── development.yaml
│   │   └── production.yaml
│   └── overlays
│       ├── development
│       │   ├── kustomization.yaml
│       │   ├── patches
│       │   │   ├── configmap.yaml
│       │   │   ├── deployment.yaml
│       │   │   ├── service.yaml
│       │   │   └── virtual-service.yaml
│       │   └── values.yaml
│       └── production
│           ├── kustomization.yaml
│           ├── patches
│           │   ├── deployment-affinity.yaml
│           │   ├── hpa-scaling.yaml
│           │   └── production-resources.yaml
│           └── values.yaml
├── Dockerfile
├── package.json
├── README.md
├── src
│   └── index.ts
└── tsconfig.json
```

## Implementation

### 1. Environment Files (Metadata for ApplicationSet)

**`deploy/environments/dev.yaml`**:

```yaml
env: dev
namespace: super-fortnight-dev
```

**`deploy/environments/production.yaml`**:

```yaml
env: production
namespace: super-fortnight
```

### 2. Overlay Kustomization (Chart Version Control)

**`deploy/overlays/dev/kustomization.yaml`**:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Helm chart inflation - ArgoCD handles this with --enable-helm
helmCharts:
  - name: aggregator
    repo: https://ashutosh-18k92.github.io/aggregator-service/
    version: v0.2.4
    releaseName: aggregator
    namespace: super-fortnight # -dev
    valuesFile: values.yaml
    includeCRDs: false

# ConfigMap for development
configMapGenerator:
  - name: service-config
    namespace: super-fortnight
    files:
      - patches/configmap.yaml
    options:
      disableNameSuffixHash: true
      annotations:
        argocd.argoproj.io/sync-options: Replace=true

# Patches for development
patches:
  - target:
      kind: Deployment
      name: aggregator-api-v1
    path: patches/deployment.yaml
  - target:
      kind: VirtualService
      name: aggregator-api-v1-virtualservice
    path: patches/virtual-service.yaml
```

**`deploy/overlays/production/kustomization.yaml`**:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Helm chart inflation - Production uses v0.2.0
helmCharts:
  - name: aggregator
    repo: https://ashutosh-18k92.github.io/aggregator-service/
    version: v0.2.3 # Production can use different version
    releaseName: aggregator
    namespace: super-fortnight
    valuesFile: values.yaml
    includeCRDs: false

# ConfigMap for production
configMapGenerator:
  - name: service-config
    namespace: super-fortnight
    literals:
      - PORT=3000
      - SERVICE_NAME=aggregator-service
      - LOG_LEVEL=error
      - NODE_ENV=production

# Patches for production
patches:
  - path: patches/deployment-affinity.yaml
  - path: patches/hpa-scaling.yaml
  - path: patches/production-resources.yaml
```

### 3. ApplicationSet (Simple Single Source)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
spec:
  generators:
    - git:
        repoURL: https://github.com/ashutosh-18k92/aggregator-service.git
        files:
          - path: "deploy/environments/*.yaml"

  template:
    spec:
      source:
        repoURL: https://github.com/ashutosh-18k92/aggregator-service.git
        path: deploy/overlays/{{.env}}
        targetRevision: { { .env } }
        kustomize:
          buildOptions: "--enable-helm --load-restrictor LoadRestrictionsNone"
```

## Benefits

✅ **Team Autonomy**: Chart version in overlay kustomization  
✅ **Modular Patches**: Separate patch files  
✅ **Per-Environment Versions**: Dev can use v0.1.0, Prod uses v0.2.0  
✅ **ArgoCD Handles Helm 4.x**: `--enable-helm` flag works in ArgoCD

## Limitations

⚠️ **Local Testing**: `kustomize build --enable-helm` still broken with Helm 4.x  
✅ **ArgoCD Works**: ArgoCD has patched this internally

## Team Workflow

### Upgrade Chart Version

```bash
cd aggregator-service

# Upgrade dev
vim deploy/overlays/dev/kustomization.yaml
# Change: version: v0.1.0 → v0.2.0

git commit -m "Upgrade dev to chart v0.2.0"
git push
```

### Add New Patch

```bash
# Create patch file
cat > deploy/overlays/production/patches/custom-feature.yaml <<EOF
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
            - name: FEATURE_FLAG
              value: "enabled"
EOF

# Add to kustomization
vim deploy/overlays/production/kustomization.yaml
# Add to patches list

git commit -m "Add custom feature patch"
git push
```
