# Adding a New Service

## Overview

This guide walks you through adding a new microservice to the Super Fortnight platform using the **service-specific Helm chart** approach.

## Prerequisites

- Access to create GitHub repositories
- `helm` installed locally
- `kustomize` installed locally
- `kubectl` configured for your cluster
- ArgoCD CLI installed (optional)

## Architecture Overview

Each service uses a **service-specific Helm chart** approach:

1. **Service Chart** (`charts/service-name/`): Your team owns the Helm chart
2. **Environment Overlays** (`deploy/overlays/`): Kustomize overlays for each environment
3. **Chart Distribution**: Published via GitHub Pages
4. **ArgoCD Integration**: ApplicationSets reference your service chart

## Step-by-Step Guide

### Step 1: Create Service Repository

Create a new GitHub repository for your service:

```bash
# Create repository on GitHub
# Example: https://github.com/your-org/new-service.git

# Clone locally
git clone https://github.com/your-org/new-service.git
cd new-service
```

### Step 2: Set Up Application Code

Create your application structure:

```bash
# Create directories
mkdir -p src

# Initialize package.json (for Node.js services)
npm init -y

# Create basic application
cat > src/index.ts <<EOF
import express from 'express';

const app = express();
const PORT = process.env.PORT || 3000;

app.get('/health', (req, res) => {
  res.json({ status: 'healthy' });
});

app.get('/ready', (req, res) => {
  res.json({ status: 'ready' });
});

app.listen(PORT, () => {
  console.log(\`Service listening on port \${PORT}\`);
});
EOF

# Create Dockerfile
cat > Dockerfile <<EOF
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
CMD ["node", "src/index.ts"]
EOF
```

### Step 3: Create Chart from Starter Template

Use `helm create --starter` to create your service chart (recommended):

```bash
# Add the sf-charts repository
helm repo add sf-charts https://ashutosh-18k92.github.io/sf-helm-charts

# Create your service chart from the starter
mkdir -p charts
helm create charts/new-service --starter=sf-charts/api
```

**Alternative**: Pull and rename manually:

```bash
mkdir -p charts
helm pull sf-charts/api --untar --untardir ./charts
mv ./charts/api ./charts/new-service
```

**Why use `helm create --starter`?**

- Official Helm workflow for starter charts
- Single command - simple and clean
- Automatically creates proper chart structure

### Step 4: Customize Chart.yaml

Edit `charts/new-service/Chart.yaml`:

```yaml
apiVersion: v2
name: new-service # Change from "api"
description: A Helm chart for new-service
type: application
version: 0.1.0 # Initial version
appVersion: "v1" # Application version
```

### Step 5: Configure Base Values

Edit `charts/new-service/values.yaml`:

```yaml
# Business/Service Identity
app:
  name: new-service
  component: api # api | worker | consumer
  partOf: superfortnight

# Container configuration
containerPort: 3000
replicaCount: 1

# Image configuration
image:
  repository: "your-org/new-service"
  tag: "latest"
  pullPolicy: IfNotPresent

# Environment variables
env:
  SERVICE_NAME: "new-service"
  PORT: "3000"
  LOG_LEVEL: "info"

# Istio VirtualService
virtualService:
  enabled: true
  namespace: istio-system
  hosts:
    - new-service
  domain: "" # Auto-constructs as {environment}.local
  gateways:
    - super-fortnight-gateway
  routes:
    - /api

# Health checks
healthCheck:
  livenessProbe:
    httpGet:
      path: /health
      port: 3000
    initialDelaySeconds: 30
    periodSeconds: 10
  readinessProbe:
    httpGet:
      path: /ready
      port: 3000
    initialDelaySeconds: 10
    periodSeconds: 5

# Resources
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"

# Autoscaling
autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80
```

### Step 6: Test the Chart

```bash
# Return to repository root
cd ../..

# Lint the chart
helm lint charts/new-service

# Render templates
helm template new-service charts/new-service

# Validate output
helm template new-service charts/new-service | kubectl apply --dry-run=client -f -
```

### Step 7: Create Environment Overlays

Create directory structure:

```bash
mkdir -p deploy/overlays/development
mkdir -p deploy/overlays/production/patches
```

**File**: `deploy/overlays/development/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

helmCharts:
  - name: new-service
    repo: https://your-org.github.io/new-service/charts
    releaseName: new-service
    namespace: super-fortnight-dev
    valuesFile: values.yaml
    version: 0.1.0
    includeCRDs: false
```

**File**: `deploy/overlays/development/values.yaml`

```yaml
app:
  name: new-service
  component: api
  partOf: superfortnight

environment: development

image:
  tag: "dev-latest"
  pullPolicy: Always

env:
  LOG_LEVEL: "debug"
  NODE_ENV: "development"

autoscaling:
  enabled: false

resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
```

**File**: `deploy/overlays/production/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

helmCharts:
  - name: new-service
    repo: https://your-org.github.io/new-service/charts
    releaseName: new-service
    namespace: super-fortnight
    valuesFile: values.yaml
    version: 0.1.0
    includeCRDs: false

patchesStrategicMerge:
  - patches/production-resources.yaml
  - patches/high-availability.yaml
```

**File**: `deploy/overlays/production/values.yaml`

```yaml
app:
  name: new-service
  component: api
  partOf: superfortnight

environment: production

image:
  tag: "latest"
  pullPolicy: IfNotPresent

env:
  LOG_LEVEL: "error"
  NODE_ENV: "production"

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20

resources:
  requests:
    memory: "256Mi"
    cpu: "200m"
  limits:
    memory: "512Mi"
    cpu: "500m"

# Enable high availability
nodeAffinityEnabled: true
zoneAffinityEnabled: true
```

### Step 8: Test Kustomize Build

```bash
# Test development overlay
kustomize build --enable-helm deploy/overlays/development

# Test production overlay
kustomize build --enable-helm deploy/overlays/production

# Save for review
kustomize build --enable-helm deploy/overlays/production > /tmp/new-service-prod.yaml
less /tmp/new-service-prod.yaml
```

### Step 9: Set Up Automated Chart Publishing

Configure GitHub Actions to automatically publish your chart:

```bash
# 1. Create gh-pages branch
git checkout -b gh-pages
echo "# New Service Helm Charts" > README.md
git add README.md
git commit -m "Initialize gh-pages branch"
git push origin gh-pages
git checkout main

# 2. Create workflows directory
mkdir -p .github/workflows

# 3. Create release workflow
cat > .github/workflows/release-helm-chart.yml <<EOF
name: Release Charts

on:
  push:
    branches:
      - main

jobs:
  release:
    permissions:
      contents: write
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Configure Git
        run: |
          git config user.name "\$GITHUB_ACTOR"
          git config user.email "\$GITHUB_ACTOR@users.noreply.github.com"

      - name: Run chart-releaser
        uses: helm/chart-releaser-action@v1.6.0
        env:
          CR_TOKEN: "\${{ secrets.GITHUB_TOKEN }}"
EOF

# 4. Create testing workflow
cat > .github/workflows/test-lint-helm-chart.yml <<EOF
name: Lint and Test Charts

on: pull_request

permissions: {}

jobs:
  lint-test:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Set up Helm
        uses: azure/setup-helm@v4

      - uses: actions/setup-python@v5
        with:
          python-version: '3.x'
          check-latest: true

      - name: Set up chart-testing
        uses: helm/chart-testing-action@v2.8.0

      - name: Run chart-testing (list-changed)
        id: list-changed
        run: |
          changed=\$(ct list-changed --target-branch \${{ github.event.repository.default_branch }})
          if [[ -n "\$changed" ]]; then
            echo "changed=true" >> "\$GITHUB_OUTPUT"
          fi

      - name: Run chart-testing (lint)
        if: steps.list-changed.outputs.changed == 'true'
        run: ct lint --target-branch \${{ github.event.repository.default_branch }}

      - name: Create kind cluster
        if: steps.list-changed.outputs.changed == 'true'
        uses: helm/kind-action@v1.12.0

      - name: Run chart-testing (install)
        if: steps.list-changed.outputs.changed == 'true'
        run: ct install --target-branch \${{ github.event.repository.default_branch }}
EOF

# 5. Commit workflows
git add .github/workflows/
git commit -m "Add chart release and testing workflows"
git push origin main
```

**Configure GitHub Pages**:

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Pages**
3. Under **Build and deployment**:
   - **Source**: "Deploy from a branch"
   - **Branch**: `gh-pages` and `/ (root)`
4. Click **Save**

**How It Works**:

- Push to `main` triggers automatic chart release
- Chart is packaged and published to `gh-pages`
- GitHub release is created
- Helm repository index is updated

See [Publishing Helm Charts Guide](../guides/publishing-helm-charts.md) for details.

### Step 10: Commit Application Code

```bash
# Add all files
git add .

# Commit
git commit -m "Initial service setup with service-specific chart"

# Push to GitHub
git push origin main
```

### Step 11: Create Environment Configuration Files

Create environment configuration files for ArgoCD ApplicationSet:

**File**: `deploy/environments/development.yaml`

```yaml
env: development
namespace: super-fortnight-dev
```

**File**: `deploy/environments/production.yaml`

```yaml
env: production
namespace: super-fortnight
```

### Step 12: Create ArgoCD ApplicationSet

In the `gitops-v2` (or `gitops-v3`) repository:

```bash
cd /path/to/gitops-v2/argocd/apps

cat > new-service-appset.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: new-service
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "100"
spec:
  goTemplate: true
  generators:
    - git:
        repoURL: https://github.com/your-org/new-service.git
        revision: main
        files:
          - path: "deploy/environments/*.yaml"

  template:
    metadata:
      name: "new-service-{{.env}}"
      namespace: argocd
      finalizers:
        - resources-finalizer.argocd.argoproj.io

    spec:
      project: default

      # Single source: Kustomize overlay (includes Helm chart + patches)
      source:
        repoURL: https://github.com/your-org/new-service.git
        targetRevision: "{{.env}}"
        path: deploy/overlays/{{.env}}
        kustomize: {} # Uses global --enable-helm from argocd-cm

      destination:
        server: https://kubernetes.default.svc
        namespace: "{{.namespace}}"

      syncPolicy:
        automated:
          enabled: true
          prune: true
          selfHeal: true

      ignoreDifferences:
        - group: apps
          kind: Deployment
          jsonPointers:
            - /spec/replicas
EOF
```

### Step 13: Apply ArgoCD ApplicationSet

```bash
# Apply to cluster
kubectl apply -f new-service-appset.yaml

# Verify
kubectl get applicationset -n argocd | grep new-service
kubectl get applications -n argocd | grep new-service
```

### Step 14: Verify Deployment

```bash
# Check ArgoCD sync status
argocd app get new-service-development
argocd app get new-service-production

# Check pods
kubectl get pods -n super-fortnight-dev -l app.kubernetes.io/name=new-service
kubectl get pods -n super-fortnight -l app.kubernetes.io/name=new-service

# Check service
kubectl get svc -n super-fortnight -l app.kubernetes.io/name=new-service

# Check logs
kubectl logs -n super-fortnight -l app.kubernetes.io/name=new-service --tail=50
```

## Directory Structure Summary

Your final repository structure:

```
new-service/
├── src/
│   └── index.ts
├── charts/
│   └── new-service/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── values.schema.json
│       ├── README.md
│       └── templates/
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── hpa.yaml
│           ├── istioVirtualService.yaml
│           ├── serviceAccount.yaml
│           └── _helpers.tpl
├── deploy/
│   ├── environments/
│   │   ├── development.yaml
│   │   └── production.yaml
│   └── overlays/
│       ├── development/
│       │   ├── kustomization.yaml
│       │   └── values.yaml
│       └── production/
│           ├── kustomization.yaml
│           ├── values.yaml
│           └── patches/
│               ├── production-resources.yaml
│               └── high-availability.yaml
├── package.json
├── Dockerfile
└── README.md
```

## Checklist

Before considering your service complete:

- [ ] Application code committed and pushed
- [ ] Service chart created in `charts/service-name/`
- [ ] Chart.yaml customized with service name and version
- [ ] Base values configured in `charts/service-name/values.yaml`
- [ ] Chart tested with `helm lint` and `helm template`
- [ ] Chart packaged and published to GitHub Pages
- [ ] Environment overlays created (`deploy/overlays/`)
- [ ] Environment configuration files created (`deploy/environments/`)
- [ ] Tested locally with `kustomize build --enable-helm`
- [ ] ArgoCD ApplicationSet created
- [ ] ApplicationSet applied to cluster
- [ ] Verified sync status in ArgoCD
- [ ] Verified pods are running
- [ ] Verified service is accessible
- [ ] Documentation updated (README.md)

## Updating Your Service

### Update Application Code

```bash
# Make changes
vim src/index.ts

# Build and test
npm run build
npm test

# Commit
git commit -am "Add new feature"
git push
```

### Update Chart

```bash
# Update chart version
vim charts/new-service/Chart.yaml
# Bump version: 0.1.0 → 0.1.1

# Update values if needed
vim charts/new-service/values.yaml

# Test
helm lint charts/new-service

# Publish new version
helm package charts/new-service
git checkout gh-pages
mv new-service-*.tgz charts/
helm repo index charts/ --url https://your-org.github.io/new-service/charts
git add charts/
git commit -m "Release chart v0.1.1"
git push origin gh-pages
git checkout main
```

### Update Environment

```bash
# Update overlay to use new chart version
vim deploy/overlays/production/kustomization.yaml
# Change version: 0.1.0 → 0.1.1

# Commit and push
git commit -am "Update to chart v0.1.1"
git push

# ArgoCD auto-syncs
```

## Troubleshooting

### Chart Not Found

```bash
# Verify chart is published
curl https://your-org.github.io/new-service/charts/index.yaml

# Check ArgoCD can access
argocd app get new-service-development
```

### Kustomize Build Fails

```bash
# Enable Helm explicitly
kustomize build --enable-helm deploy/overlays/development

# Check chart reference in kustomization.yaml
cat deploy/overlays/development/kustomization.yaml
```

### ArgoCD Sync Fails

```bash
# Check application status
argocd app get new-service-development

# View detailed errors
kubectl describe application new-service-development -n argocd

# Manual sync
argocd app sync new-service-development --force
```

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n super-fortnight-dev -l app.kubernetes.io/name=new-service

# Check events
kubectl get events -n super-fortnight-dev --sort-by='.lastTimestamp'

# Check logs
kubectl logs -n super-fortnight-dev -l app.kubernetes.io/name=new-service
```

## Next Steps

After your service is deployed:

1. **Monitor**: Set up monitoring and alerting
2. **Scale**: Adjust HPA settings based on load
3. **Optimize**: Fine-tune resource requests/limits
4. **Document**: Update README with service-specific information
5. **Iterate**: Continue development with confidence!

## Related Documentation

- [Decentralized Helm Charts Pattern](service-specific-charts.md)
- [Helm Chart Reference](../reference/helm-chart-reference.md)
- [Feature Team Guide](feature-team-guide.md)
- [Platform Team Guide](platform-team-guide.md)
- [ArgoCD Applications](argocd-applications.md)
