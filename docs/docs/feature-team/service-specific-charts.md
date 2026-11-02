# Decentralized Helm Charts Pattern

## Overview

The **Decentralized Helm Charts Pattern** is our architectural approach where **each service owns its own Helm chart**, rather than referencing a shared remote chart. This provides team autonomy, eliminates Kustomize limitations, and enables proper Helm dependency management.

## Architecture

### The Problem We Solved

**Previous Approach** (Kustomize + Remote Helm Chart):

```yaml
# deploy/base/kustomization.yaml
helmCharts:
  - name: api
    repo: https://github.com/platform-team/sf-helm-charts.git
    # ❌ Kustomize has limitations with remote Helm charts
    # ❌ Teams don't control the base configuration
    # ❌ Shared chart creates coupling between services
```

**Current Approach** (Service-Specific Charts):

```
service-repo/
├── charts/
│   └── service-name/        # ✅ Service owns its chart
│       ├── Chart.yaml
│       ├── values.yaml      # ✅ Team controls base config
│       └── templates/
└── deploy/overlays/         # ✅ Environment-specific customization
```

### Key Components

#### 1. Service Chart (`charts/service-name/`)

Each service has its own Helm chart:

```
charts/aggregator/
├── Chart.yaml              # Chart metadata and version
├── values.yaml             # Base configuration (source of truth)
├── values.schema.json      # Values validation
├── README.md               # Chart documentation
└── templates/              # Kubernetes resource templates
    ├── deployment.yaml
    ├── service.yaml
    ├── hpa.yaml
    ├── istioVirtualService.yaml
    └── _helpers.tpl
```

**Ownership**: Feature team (e.g., Aggregator Team)  
**Purpose**: Define the service's base configuration and templates  
**Distribution**: Published via GitHub Pages

#### 2. API Template Chart (`sf-helm-charts/charts/api/`)

The platform team maintains a template chart:

**Purpose**: Kickstart template for new services  
**Usage**: Copy to create a new service chart  
**Ownership**: Platform team  
**NOT**: A shared runtime dependency

#### 3. Environment Overlays (`deploy/overlays/`)

Kustomize overlays for environment-specific configuration:

```
deploy/overlays/
├── development/
│   ├── kustomization.yaml    # References service chart
│   ├── values.yaml           # Dev-specific values
│   └── patches/              # Dev-specific patches
├── staging/
└── production/
```

#### 4. Chart Distribution (GitHub Pages)

Each service publishes its chart to GitHub Pages:

```
https://team-name.github.io/service-name/charts
```

## Benefits

### ✅ Team Autonomy

- Feature teams **own and control** their service's base configuration
- No dependency on platform team for configuration changes
- Independent versioning and evolution

### ✅ No Kustomize Limitations

- Helm charts are first-class citizens in the service repository
- No issues with remote Helm chart references
- Proper Helm + Kustomize integration

### ✅ Separation of Concerns

- **Platform Team**: Maintains the `api` template chart
- **Feature Teams**: Own their service-specific charts
- Clear boundaries and responsibilities

### ✅ Helm Native Features

- Use Helm's dependency system (`Chart.yaml` dependencies)
- "Leader chart" pattern for complex services
- Proper chart versioning and distribution

### ✅ Quick Launchpad

- Copy `api` template to start a new service
- Customize for service-specific needs
- Publish and deploy independently

## Creating a New Service Chart

### Step 1: Create Chart from Starter Template

Use `helm create --starter` to create your service chart (recommended):

```bash
# Navigate to your service repository
cd /path/to/your-service

# Add the sf-charts repository
helm repo add sf-charts https://ashutosh-18k92.github.io/sf-helm-charts

# Create your service chart from the starter
mkdir -p charts
helm create charts/your-service --starter=sf-charts/api
```

**Alternative**: Pull and rename manually:

```bash
helm pull sf-charts/api --untar --untardir ./charts
mv ./charts/api ./charts/your-service
```

**Why `helm create --starter`?**

- ✅ Official Helm workflow for starter charts
- ✅ Single command - no packaging needed
- ✅ Clean and professional approach
- ✅ Consistent with Helm best practices

### Step 2: Customize Chart.yaml

```yaml
apiVersion: v2
name: your-service # Change from "api"
description: Your service description
type: application
version: 0.1.0 # Initial version
appVersion: "v1" # Application version
```

### Step 3: Update Base Values

Edit `charts/your-service/values.yaml`:

```yaml
# Business/Service Identity
app:
  name: your-service # Your service name
  component: api # api | worker | consumer
  partOf: superfortnight # Parent application

# Container configuration
containerPort: 3000 # Your service port

# Image configuration
image:
  repository: "your-org/your-service"
  tag: "latest"

# Environment variables
env:
  SERVICE_NAME: "your-service"
  PORT: "3000"

# Health checks
healthCheck:
  livenessProbe:
    httpGet:
      path: /health
      port: 3000
  readinessProbe:
    httpGet:
      path: /ready
      port: 3000

# Resources
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"
```

### Step 4: Test the Chart

```bash
# Lint the chart
helm lint charts/your-service

# Render templates
helm template your-service charts/your-service

# Validate output
helm template your-service charts/your-service | kubectl apply --dry-run=client -f -
```

### Step 5: Create Environment Overlays

Create `deploy/overlays/development/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

helmCharts:
  - name: your-service
    repo: https://your-org.github.io/your-service
    releaseName: your-service
    namespace: super-fortnight-dev
    valuesFile: values.yaml
    version: 0.1.0
    includeCRDs: false
```

Create `deploy/overlays/development/values.yaml`:

```yaml
app:
  name: your-service
  component: api
  partOf: superfortnight

environment: development

image:
  tag: "dev-latest"
  pullPolicy: Always

env:
  LOG_LEVEL: "debug"

autoscaling:
  enabled: false
```

### Step 6: Set Up Automated Publishing

Instead of manually packaging and publishing charts, use GitHub Actions for automation.

**Quick Setup**:

```bash
# 1. Create gh-pages branch
git checkout -b gh-pages
echo "# Helm Charts" > README.md
git add README.md
git commit -m "Initialize gh-pages"
git push origin gh-pages
git checkout main

# 2. Create workflows directory
mkdir -p .github/workflows

# 3. Copy workflow files from sf-helm-charts
cp /path/to/sf-helm-charts/.github/workflows/release-helm-chart.yml .github/workflows/
cp /path/to/sf-helm-charts/.github/workflows/test-lint-helm-chart .github/workflows/test-lint-helm-chart.yml

# 4. Commit workflows
git add .github/workflows/
git commit -m "Add chart release workflows"
git push origin main
```

**Configure GitHub Pages**:

1. Go to repository **Settings** → **Pages**
2. Set **Source** to "Deploy from a branch"
3. Select **gh-pages** branch and **/ (root)**
4. Save

**How It Works**:

- When you push to `main`, the workflow automatically:
  - Detects chart version changes
  - Packages the chart
  - Creates a GitHub release
  - Publishes to `gh-pages` branch
  - Updates the Helm repository index

**Publishing New Versions**:

```bash
# 1. Bump version in Chart.yaml
vim charts/your-service/Chart.yaml
# Change: version: 0.1.0 → 0.1.1

# 2. Commit and push
git add charts/your-service/Chart.yaml
git commit -m "Bump chart version to 0.1.1"
git push origin main

# 3. GitHub Actions automatically publishes!
```

See the [Publishing Helm Charts Guide](./publishing-helm-charts.md) for detailed setup instructions.

### Step 7: Create ArgoCD Application

Create `gitops-v2/argocd/apps/your-service-appset.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: your-service
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: https://github.com/your-org/your-service.git
        revision: main
        files:
          - path: "deploy/environments/*.yaml"

  template:
    metadata:
      name: "your-service-{{.env}}"
    spec:
      project: default

      source:
        repoURL: https://github.com/your-org/your-service.git
        targetRevision: "{{.env}}"
        path: deploy/overlays/{{.env}}
        kustomize: {} # Uses --enable-helm

      destination:
        server: https://kubernetes.default.svc
        namespace: "{{.namespace}}"

      syncPolicy:
        automated:
          enabled: true
          prune: true
          selfHeal: true
```

## Chart Dependencies (Leader Chart Pattern)

For complex services that depend on other services, use Helm dependencies:

### Example: Aggregator Service with Dependencies

**File**: `charts/aggregator/Chart.yaml`

```yaml
apiVersion: v2
name: aggregator
version: 0.2.0
appVersion: "v1"
description: Aggregator service with dependencies

dependencies:
  - name: rock-service
    version: "0.1.0"
    repository: "https://team-rock.github.io/rock-service/charts"
    condition: rock.enabled

  - name: paper-service
    version: "0.1.0"
    repository: "https://team-paper.github.io/paper-service/charts"
    condition: paper.enabled

  - name: scissor-service
    version: "0.1.0"
    repository: "https://team-scissor.github.io/scissor-service/charts"
    condition: scissor.enabled
```

**File**: `charts/aggregator/values.yaml`

```yaml
# Aggregator configuration
app:
  name: aggregator-service
  component: api

# Dependency configuration
rock:
  enabled: true
  # Override rock-service values
  replicaCount: 2

paper:
  enabled: true
  # Override paper-service values
  replicaCount: 2

scissor:
  enabled: true
  # Override scissor-service values
  replicaCount: 2
```

**Update dependencies**:

```bash
# Download dependencies
helm dependency update charts/aggregator

# This creates charts/aggregator/charts/ with dependency charts
```

## Updating a Service Chart

### Update Chart Version

```bash
# Edit Chart.yaml
vim charts/your-service/Chart.yaml

# Bump version
# version: 0.1.0 → 0.1.1

# Update appVersion if application changed
# appVersion: "v1" → "v2"
```

### Update Values

```bash
# Edit base values
vim charts/your-service/values.yaml

# Test changes
helm lint charts/your-service
helm template your-service charts/your-service
```

### Publish New Version

With GitHub Actions, publishing is automatic:

```bash
# 1. Update chart version
vim charts/your-service/Chart.yaml
# Bump version: 0.1.0 → 0.1.1

# 2. Update appVersion if application changed
# appVersion: "v1" → "v2"

# 3. Test changes locally
helm lint charts/your-service
helm template your-service charts/your-service

# 4. Commit and push to main
git add charts/your-service/
git commit -m "Release chart v0.1.1"
git push origin main

# 5. GitHub Actions automatically:
#    - Packages the chart
#    - Creates GitHub release
#    - Publishes to gh-pages
#    - Updates Helm repo index
```

**Verify Release**:

```bash
# Check GitHub Actions tab for workflow status
# Check Releases tab for new release

# Test the published chart
helm repo update
helm search repo your-service --versions
```

### Update Environment Overlays

```bash
# Update overlay to use new chart version
vim deploy/overlays/production/kustomization.yaml

# Change version: 0.1.0 → 0.1.1

# Commit and push
git add deploy/
git commit -m "Update production to chart v0.1.1"
git push

# ArgoCD auto-syncs
```

## Team Responsibilities

### Platform Team

- **Maintain**: `api` template chart in `sf-helm-charts`
- **Provide**: Best practices and guidelines
- **Support**: Feature teams with chart issues
- **Update**: Template when platform-wide changes needed

### Feature Teams

- **Own**: Service-specific chart in `charts/service-name/`
- **Maintain**: Base configuration in `values.yaml`
- **Publish**: Chart versions to GitHub Pages
- **Update**: Environment overlays for deployments
- **Monitor**: Service health and performance

## Best Practices

### 1. Chart Versioning

- Use semantic versioning for chart versions
- Bump `version` when chart changes
- Bump `appVersion` when application changes
- Document changes in chart README

### 2. Base Values

- Keep `charts/service-name/values.yaml` minimal
- Only include common configuration
- Use environment overlays for environment-specific values
- Document all values in chart README

### 3. Chart Publishing

- Publish to GitHub Pages for distribution
- Maintain a chart repository index
- Tag releases in Git
- Keep old versions available

### 4. Testing

- Always lint charts before publishing
- Test rendering with different value files
- Validate generated manifests
- Test in development before production

### 5. Documentation

- Maintain chart README with usage examples
- Document all values and their defaults
- Include troubleshooting section
- Link to related documentation

## Troubleshooting

### Chart Not Found

```bash
# Verify chart is published
curl https://your-org.github.io/your-service/charts/index.yaml

# Check chart version exists
helm search repo your-service --versions
```

### Kustomize Build Fails

```bash
# Enable Helm in Kustomize
kustomize build --enable-helm deploy/overlays/development

# Check chart reference
cat deploy/overlays/development/kustomization.yaml
```

### ArgoCD Sync Issues

```bash
# Check if --enable-helm is set in ArgoCD ConfigMap
kubectl get cm argocd-cm -n argocd -o yaml | grep enable-helm

# Manual sync with Helm enabled
argocd app sync your-service --force
```

## Related Documentation

- [Helm Chart Reference](../reference/helm-chart-reference.md)
- [Adding a New Service](./adding-new-service.md)
- [Feature Team Guide](./feature-team-guide.md)
- [Platform Team Guide](./platform-team-guide.md)
- [ArgoCD Applications](./argocd-applications.md)
