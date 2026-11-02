# Appendix G: Enabling Helm Support in ArgoCD for Kustomize Builds

## G.1 Overview

The Helm + Kustomize hybrid architecture requires ArgoCD to support Helm chart inflation within Kustomize builds. This appendix provides complete configuration instructions for enabling the `--enable-helm` flag in ArgoCD, which is essential for the reference pattern documented in Chapters 1-8.

## G.2 Problem Statement

When deploying applications using `helmCharts` in `kustomization.yaml`, ArgoCD may fail with the following error:

```
ComparisonError: rpc error: code = Unknown desc = Manifest generation error (cached):
`kustomize build` failed exit status 1:
Error: must specify --enable-helm with 'kustomize build' to enable Helm chart inflation
```

This occurs because ArgoCD's Kustomize integration does not automatically enable Helm chart inflation. The `--enable-helm` flag must be explicitly configured.

### Example Failing Configuration

```yaml
# deploy/overlays/development/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

helmCharts:
  - name: aggregator
    repo: https://ashutosh-18k92.github.io/aggregator-service/
    version: v0.2.4
    releaseName: aggregator
    namespace: super-fortnight-dev
    valuesFile: values.yaml
    includeCRDs: false
```

Without proper ArgoCD configuration, this `kustomization.yaml` will fail during sync.

## G.3 Root Cause Analysis

### Why the Error Occurs

1.  **Kustomize Default Behavior**: By default, Kustomize does not process `helmCharts` entries
2.  **Flag Requirement**: The `--enable-helm` flag must be passed to `kustomize build` command
3.  **ArgoCD Execution**: ArgoCD runs `kustomize build` in the `argocd-repo-server` component
4.  **Global Configuration**: Build options must be configured globally, not per-application

### Common Misconceptions

**❌ Incorrect**: Setting `buildOptions` in ApplicationSet source

```yaml
# This does NOT work
spec:
  template:
    spec:
      source:
        kustomize:
          buildOptions: "--enable-helm" # Ignored by ArgoCD
```

**✅ Correct**: Configuring globally in `argocd-cm` ConfigMap

```yaml
# This works
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  kustomize.buildOptions: "--enable-helm --load-restrictor LoadRestrictionsNone"
```

## G.4 Solution: Global Configuration

### Step 1: Create ConfigMap Patch

Create a file to configure Kustomize build options globally:

**File: `argocd/config/argocd-cm-kustomize-helm.yaml`**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-cm
    app.kubernetes.io/part-of: argocd
data:
  # Enable Helm chart inflation in Kustomize builds
  kustomize.buildOptions: "--enable-helm --load-restrictor LoadRestrictionsNone"

  # Optional: Configure Kustomize version if needed
  # kustomize.version.v5.0.0: /path/to/kustomize-5.0.0

  # Optional: Enable namespace creation if needed
  # application.namespaces: "super-fortnight,super-fortnight-dev,super-fortnight-staging"
```

### Step 2: Apply Configuration

**Option A: Apply ConfigMap File**

```bash
# Apply the ConfigMap
kubectl apply -f argocd/config/argocd-cm-kustomize-helm.yaml

# Verify application
kubectl get configmap argocd-cm -n argocd -o yaml
```

**Option B: Patch Existing ConfigMap**

```bash
# Patch the existing ConfigMap without overwriting other settings
kubectl patch configmap argocd-cm -n argocd --type merge -p '
{
  "data": {
    "kustomize.buildOptions": "--enable-helm --load-restrictor LoadRestrictionsNone"
  }
}'
```

### Step 3: Restart ArgoCD Components

The `argocd-repo-server` component must be restarted for changes to take effect:

```bash
# Restart the repo server
kubectl rollout restart deployment argocd-repo-server -n argocd

# Wait for rollout to complete
kubectl rollout status deployment argocd-repo-server -n argocd

# Verify pods are running
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-repo-server
```

**Expected Output:**

```
deployment "argocd-repo-server" successfully rolled out

NAME                                  READY   STATUS    RESTARTS   AGE
argocd-repo-server-7c5c8f9d6b-xyz12   1/1     Running   0          30s
```

### Step 4: Verify Configuration

```bash
# Check ConfigMap contains the setting
kubectl get configmap argocd-cm -n argocd -o jsonpath='{.data.kustomize\.buildOptions}'

# Expected output:
# --enable-helm --load-restrictor LoadRestrictionsNone
```

### Step 5: Test ApplicationSet

```bash
# Apply your ApplicationSet
kubectl apply -f gitops-v2/argocd/apps/aggregator-appset.yaml

# List generated applications
argocd app list | grep aggregator-service

# View manifests for one application (should work without error)
argocd app manifests aggregator-service-development

# Check application status
argocd app get aggregator-service-development
```

**Expected Behavior:**

- ✅ Application syncs successfully
- ✅ Helm charts are inflated by Kustomize
- ✅ Patches apply correctly
- ✅ Resources deploy to cluster

## G.5 Configuration Options Explained

### Flag: `--enable-helm`

**Purpose**: Enables Kustomize to process `helmCharts` entries in `kustomization.yaml`

**Behavior**:

- Kustomize fetches charts from specified repositories
- Renders charts with provided values files
- Includes rendered manifests in Kustomize build output

**Without this flag**: `helmCharts` entries are silently ignored

### Flag: `--load-restrictor LoadRestrictionsNone`

**Purpose**: Allows Kustomize to load files outside the kustomization root

**Behavior**:

- Permits loading Helm charts from external repositories
- Allows patches to reference files in parent directories
- Enables flexible repository structures

**Default behavior**: `LoadRestrictionsRootOnly` prevents loading external files

**Security Note**: Only use `LoadRestrictionsNone` if you trust the Git repositories ArgoCD monitors. For stricter security, omit this flag and structure repositories accordingly.

## G.6 ApplicationSet Configuration

With global configuration in place, ApplicationSets should **not** specify `buildOptions`:

### Correct ApplicationSet

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: aggregator-service
  namespace: argocd
spec:
  goTemplate: true
  generators:
    - git:
        repoURL: https://github.com/ashutosh-18k92/aggregator-service.git
        revision: main
        files:
          - path: "deploy/environments/*.yaml"

  template:
    metadata:
      name: "aggregator-service-{{.env}}"
      namespace: argocd

    spec:
      project: default

      source:
        repoURL: https://github.com/ashutosh-18k92/aggregator-service.git
        targetRevision: "{{.targetRevision}}"
        path: deploy/overlays/{{.env}}
        kustomize: {} # Empty - uses global buildOptions

      destination:
        server: https://kubernetes.default.svc
        namespace: "{{.namespace}}"

      syncPolicy:
        automated:
          enabled: true
          prune: true
          selfHeal: true
```

### Incorrect ApplicationSet (Don't Use)

```yaml
# ❌ This approach does not work in ArgoCD
spec:
  template:
    spec:
      source:
        kustomize:
          buildOptions: "--enable-helm" # Ignored!
```

## G.7 Alternative: Config Management Plugin

For scenarios requiring application-specific build commands or additional tooling, use a custom Config Management Plugin.

### Step 1: Define Plugin in argocd-cm

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  # Define custom plugin
  configManagementPlugins: |
    - name: kustomize-with-helm
      generate:
        command: ["sh", "-c"]
        args:
          - |
            kustomize build --enable-helm --load-restrictor LoadRestrictionsNone .
```

### Step 2: Mount Plugin in argocd-repo-server

If the plugin requires additional tools, modify the `argocd-repo-server` deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-repo-server
  namespace: argocd
spec:
  template:
    spec:
      containers:
        - name: argocd-repo-server
          volumeMounts:
            - name: custom-tools
              mountPath: /usr/local/bin/kustomize
              subPath: kustomize
      volumes:
        - name: custom-tools
          emptyDir: {}
      initContainers:
        - name: install-kustomize
          image: alpine:3.18
          command: ["/bin/sh", "-c"]
          args:
            - |
              wget -O /custom-tools/kustomize https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v5.0.0/kustomize_v5.0.0_linux_amd64.tar.gz
              chmod +x /custom-tools/kustomize
          volumeMounts:
            - name: custom-tools
              mountPath: /custom-tools
```

### Step 3: Use Plugin in Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: aggregator-service-dev
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/ashutosh-18k92/aggregator-service.git
    path: deploy/overlays/development
    plugin:
      name: kustomize-with-helm
  destination:
    server: https://kubernetes.default.svc
    namespace: super-fortnight-dev
```

**When to Use Plugins:**

- Per-application build customization needed
- Additional preprocessing required
- Custom tooling integration
- Multiple Kustomize versions needed

**Trade-offs:**

- ✅ Application-specific control
- ✅ Custom tooling support
- ❌ More complex configuration
- ❌ Harder to maintain
- ❌ Slower initial sync (plugin execution)

## G.8 Troubleshooting

### Issue: ConfigMap Changes Not Taking Effect

**Symptoms:**

- ConfigMap updated successfully
- Error persists in ArgoCD

**Diagnosis:**

```bash
# Check if repo-server restarted
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-repo-server

# Check pod age (should be recent)
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-repo-server -o jsonpath='{.items[0].metadata.creationTimestamp}'
```

**Solution:**

```bash
# Force restart repo-server
kubectl rollout restart deployment argocd-repo-server -n argocd

# Delete pods if rollout doesn't work
kubectl delete pods -n argocd -l app.kubernetes.io/name=argocd-repo-server

# Wait for new pods
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-repo-server -n argocd --timeout=120s
```

### Issue: Helm Chart Not Found

**Symptoms:**

```
Error: chart "aggregator" not found in https://example.com/charts
```

**Diagnosis:**

```bash
# Test chart repository accessibility from cluster
kubectl run -it --rm debug --image=alpine --restart=Never -- sh

# Inside pod:
apk add curl
curl -L https://ashutosh-18k92.github.io/aggregator-service/index.yaml

# Check if chart version exists
curl -L https://ashutosh-18k92.github.io/aggregator-service/aggregator-0.2.4.tgz
```

**Solutions:**

1.  Verify chart repository URL is correct
2.  Ensure chart version exists: `helm search repo aggregator --versions`
3.  Check network policies allow egress to chart repository
4.  Verify ArgoCD service account has network access

### Issue: Values File Not Found

**Symptoms:**

```
Error: values file "values.yaml" not found
```

**Diagnosis:**

```bash
# Check file exists in repository
ls -la deploy/overlays/development/values.yaml

# Verify path in kustomization.yaml
cat deploy/overlays/development/kustomization.yaml | grep valuesFile
```

**Solution:**

- Ensure `valuesFile` path is relative to `kustomization.yaml` location
- Use correct path: `valuesFile: values.yaml` (not `valuesFile: ./values.yaml`)

### Issue: Load Restrictions Error

**Symptoms:**

```
Error: security; file '/path' is not in or below '/workspace'
```

**Diagnosis:**

```bash
# Check current load restrictor setting
kubectl get configmap argocd-cm -n argocd -o jsonpath='{.data.kustomize\.buildOptions}'
```

**Solution:**  
Add `--load-restrictor LoadRestrictionsNone` to build options:

```bash
kubectl patch configmap argocd-cm -n argocd --type merge -p '
{
  "data": {
    "kustomize.buildOptions": "--enable-helm --load-restrictor LoadRestrictionsNone"
  }
}'

kubectl rollout restart deployment argocd-repo-server -n argocd
```

### Issue: Kustomize Version Incompatibility

**Symptoms:**

```
Error: unknown flag: --enable-helm
```

**Diagnosis:**

```bash
# Check Kustomize version in ArgoCD
kubectl exec -it deployment/argocd-repo-server -n argocd -- kustomize version
```

**Requirement:**

- Kustomize v4.5.0+ required for `--enable-helm` flag
- ArgoCD v2.5.0+ bundles compatible Kustomize version

**Solution:**  
Update ArgoCD to v2.5.0 or later:

```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

## G.9 Verification Checklist

After configuration, verify the complete workflow:

```bash
# 1. ConfigMap contains correct settings
kubectl get configmap argocd-cm -n argocd -o jsonpath='{.data.kustomize\.buildOptions}'
# Expected: --enable-helm --load-restrictor LoadRestrictionsNone

# 2. Repo server restarted recently
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-repo-server -o jsonpath='{.items[0].metadata.creationTimestamp}'
# Should show recent timestamp

# 3. ApplicationSet exists and is healthy
kubectl get applicationset -n argocd
argocd appset get aggregator-service

# 4. Applications generated successfully
argocd app list | grep aggregator-service
# Should show: aggregator-service-development, aggregator-service-staging, etc.

# 5. Application is synced
argocd app get aggregator-service-development
# Status should be: Synced, Healthy

# 6. Manifests render correctly
argocd app manifests aggregator-service-development | head -50
# Should show rendered Kubernetes resources

# 7. Resources deployed to cluster
kubectl get all -n super-fortnight-dev -l app=aggregator
# Should show Deployment, Service, HPA, etc.

# 8. Helm chart was actually used
kubectl get deployment aggregator-api-v1 -n super-fortnight-dev -o yaml | grep -A 5 labels
# Should show labels from Helm chart template
```

**Success Criteria:**

- ✅ All commands execute without errors
- ✅ Applications show "Synced" status
- ✅ Resources exist in target namespaces
- ✅ Helm-generated labels present on resources
- ✅ No manifest generation errors in ArgoCD UI

## G.10 Best Practices

### Security Considerations

1.  **Load Restrictor**: Use `LoadRestrictionsNone` only if you trust all Git repositories
2.  **RBAC**: Restrict who can modify `argocd-cm` ConfigMap
3.  **Repository Access**: Use private repositories with authentication for sensitive charts
4.  **Chart Verification**: Consider enabling chart signature verification

### Operational Practices

1.  **Infrastructure as Code**: Store ArgoCD configuration in Git alongside applications
2.  **Change Management**: Document ConfigMap changes in Git commit messages
3.  **Monitoring**: Alert on `argocd-repo-server` deployment changes
4.  **Backup**: Include `argocd-cm` in cluster backup procedures

### Testing Strategy

1.  **Development First**: Test Helm chart changes in development environment overlays
2.  **Dry Run**: Use `argocd app diff` before syncing to production
3.  **Rollback Plan**: Document rollback procedures for chart version changes
4.  **Validation**: Implement pre-sync hooks for critical validation

## G.11 Integration with CI/CD

### GitHub Actions Example

```yaml
name: Validate Kustomize + Helm

on:
  pull_request:
    paths:
      - "deploy/overlays/**"

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install Kustomize
        run: |
          curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
          sudo mv kustomize /usr/local/bin/

      - name: Validate Development Overlay
        run: |
          cd deploy/overlays/development
          kustomize build --enable-helm --load-restrictor LoadRestrictionsNone .

      - name: Validate Production Overlay
        run: |
          cd deploy/overlays/production
          kustomize build --enable-helm --load-restrictor LoadRestrictionsNone .
```

### GitLab CI Example

```yaml
validate-kustomize:
  image:
    name: k8s.gcr.io/kustomize/kustomize:v5.0.0
    entrypoint: [""]
  script:
    - cd deploy/overlays/development
    - kustomize build --enable-helm --load-restrictor LoadRestrictionsNone .
    - cd ../production
    - kustomize build --enable-helm --load-restrictor LoadRestrictionsNone .
  only:
    changes:
      - deploy/overlays/**
```

## G.12 Summary

### Key Takeaways

1.  **Global Configuration Required**: `--enable-helm` must be configured in `argocd-cm` ConfigMap
2.  **Repo Server Restart**: Configuration changes require restarting `argocd-repo-server`
3.  **No Application-Level Override**: ApplicationSets cannot override global build options
4.  **Load Restrictor**: May need `LoadRestrictionsNone` for external chart repositories
5.  **Version Requirements**: Requires ArgoCD v2.5.0+ with Kustomize v4.5.0+

### Configuration Summary

**Minimal Working Configuration:**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  kustomize.buildOptions: "--enable-helm --load-restrictor LoadRestrictionsNone"
```

**Restart Command:**

```bash
kubectl rollout restart deployment argocd-repo-server -n argocd
```

**Verification Command:**

```bash
argocd app manifests <app-name>
```

### Next Steps

After enabling Helm support in ArgoCD:

1.  **Chapter 4**: Review Helm + Kustomize hybrid implementation details
2.  **Chapter 5**: Understand repository structures and workflows
3.  **Appendix B**: Reference command guide for day-to-day operations
4.  **Appendix C**: Consult troubleshooting guide for issues

---

**This configuration enables the core architecture pattern documented in Chapters 1-8, where teams reference platform charts through Kustomize while ArgoCD orchestrates the rendering and deployment process.**

**This architecture guide represents the culmination of production experience and continuous refinement.**

**May your deployments be swift, your rollbacks rare, and your teams autonomous.**

_— The Super Fortnight Platform Team_
