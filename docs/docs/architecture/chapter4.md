# Chapter 4: Helm + Kustomize Hybrid Implementation

### 4.1 Implementation Overview

The Helm plus Kustomize hybrid implementation combines the strengths of both tools through careful integration. This chapter details the technical implementation, covering how Kustomize invokes Helm, how values and patches compose, and how ArgoCD orchestrates the rendering pipeline.

### 4.2 Kustomize HelmCharts Integration

Kustomize supports Helm chart inflation through the helmCharts field in kustomization.yaml files. This integration enables Kustomize to fetch Helm charts, render them with specified values, and include the resulting manifests in the Kustomize build. The helmCharts configuration specifies the chart name, repository URL, version, release name, target namespace, values file path, and whether to include Custom Resource Definitions.

For example, a development environment overlay might specify the aggregator chart from the platform repository at version 0.2.4, with a release name of aggregator in the super-fortnight-dev namespace, using values from a local values.yaml file. ArgoCD handles this inflation automatically when the enable-helm build option is configured, eliminating the need for manual helm template commands.

```yaml
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

### 4.3 Values Hierarchy

Understanding the values hierarchy is critical for predicting configuration outcomes. Helm chart default values reside in the chart's values.yaml file in Tier 1. Environment-specific values are provided by the overlay's values.yaml file referenced in the helmCharts section. These overlay values override chart defaults through deep merging, where specified fields replace defaults while unspecified fields retain their default values.

For instance, if the chart default specifies two replicas and 512 megabytes of memory, and the development overlay specifies one replica but says nothing about memory, the result combines one replica from the overlay with 512 megabytes from the chart default. This deep merge behavior allows overlays to be minimal, specifying only what differs from defaults.

### 4.4 Patch Application

After Helm renders templates with merged values, Kustomize applies **strategic merge** patches and JSON patches. Patches enable modifications that values alone cannot express, such as adding environment variables not templated in the chart, modifying probe configurations with complex logic, adding volume mounts for environment-specific requirements, or configuring service mesh features like traffic splitting.

Patches target specific resources using `kind`, `name`, and optionally `namespace`. A patch file contains partial Kubernetes resource definitions. Kustomize merges these definitions with rendered resources using strategic merge semantics where maps merge and lists replace by default, though behavior can be customized through merge directives.

Production patches commonly include pod anti-affinity rules to spread replicas across nodes and zones, horizontal pod autoscaler configuration for dynamic scaling, increased resource limits appropriate for production load, and custom annotations for monitoring or networking policies. These patches apply after Helm rendering, allowing surgical modifications without editing chart templates.

Example production patch for affinity:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aggregator-api-v1
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
                    - key: app
                      operator: In
                      values:
                        - aggregator
                topologyKey: kubernetes.io/hostname
```

### 4.5 ConfigMap Generation

Kustomize's configMapGenerator feature enables environment-specific configuration without manual ConfigMap definitions. Overlays specify ConfigMap generators that create ConfigMaps from literal values or files. Development might define log level as debug and environment as development. Production would specify log level as error and environment as production. The generator creates ConfigMaps with appropriate labels and names, and Kustomize automatically updates referencing pods when ConfigMap content changes.

```yaml
configMapGenerator:
  - name: service-config
    namespace: super-fortnight
    literals:
      - PORT=3000
      - SERVICE_NAME=aggregator-service
      - LOG_LEVEL=error
      - NODE_ENV=production
```

### 4.6 ArgoCD Build Options

ArgoCD must be configured to enable Helm support within Kustomize builds. The enable-helm option in ArgoCD's configuration map activates this integration. Applications specify kustomize build options in their source configuration or rely on global defaults. ArgoCD renders configuration during sync, fetching Helm charts from configured repositories, applying Kustomize transformations, and deploying resulting manifests to the cluster.

This integration means teams do not need local Helm installations for deployment. ArgoCD handles all chart rendering and manifest generation. Teams only interact with Git, committing changes to their repositories and trusting ArgoCD to render and deploy correctly.

### 4.7 Development Workflow

While ArgoCD handles production rendering, developers need to validate configurations locally before committing. The `kustomize build --enable-helm` command works in ArgoCD but may encounter issues with Helm version 4.x in local environments. Teams can test using ArgoCD's diff feature, which previews what will be deployed without actually applying changes. For local validation, teams might maintain Helm installed alongside Kustomize, render charts manually with helm template, then apply Kustomize patches to rendered output for verification.

The recommended workflow involves making changes in the team repository, committing to a development branch, using ArgoCD diff to preview rendered manifests, validating that patches apply correctly and values override as expected, merging to the main branch, and allowing ArgoCD to sync automatically. This workflow ensures validation while avoiding local tool version conflicts.

**Dry-run without Helm inflation (for local testing)**

If you need to test locally, you can temporarily replace the `helmCharts` with actual manifests:

```bash
# 1. Manually render Helm chart
helm template aggregator \
  https://github.com/ashutosh-18k92/sf-helm-registry.git \
  -f deploy/base/values.yaml \
  > /tmp/rendered-chart.yaml

# 2. Temporarily modify base/kustomization.yaml
# Replace helmCharts with:
resources:
  - /tmp/rendered-chart.yaml

# 3. Run kustomize
kustomize build deploy/overlays/dev

# 4. Revert changes
git checkout deploy/base/kustomization.yaml
```
