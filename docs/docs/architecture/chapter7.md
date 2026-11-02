# Chapter 7: Deployment Patterns and ArgoCD Integration

### 7.1 ApplicationSet Patterns

ArgoCD ApplicationSets enable dynamic application generation from Git repositories. The architecture uses Git file generators to iterate over environment definition files in team repositories. Each environment file contains metadata like environment name and target namespace. The ApplicationSet template uses this metadata to generate Application resources with environment-specific configurations.

This pattern provides several benefits. Teams add environments by adding files to their repository without platform team intervention. Environment metadata is co-located with service configuration. Application resources generate automatically, reducing duplication in the GitOps repository. The generator pattern scales naturally as services add environments for regional deployments, feature branches, or temporary testing.

Example ApplicationSet with Git generator:

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
      finalizers:
        - resources-finalizer.argocd.argoproj.io

    spec:
      project: default

      source:
        repoURL: https://github.com/ashutosh-18k92/aggregator-service.git
        targetRevision: "{{.targetRevision}}"
        path: deploy/overlays/{{.env}}
        kustomize: {}

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
```

### 7.2 Sync Wave Orchestration

Complex platforms often require ordered deployment of resources. Infrastructure components must deploy before applications that depend on them. The architecture uses ArgoCD sync waves to control deployment ordering. Annotations on resources specify wave numbers, and ArgoCD deploys resources in wave order, waiting for health checks before proceeding to the next wave.

For the Super Fortnight platform, wave zero deploys namespaces and foundational resources. Wave one deploys operators like Elastic Cloud on Kubernetes or Strimzi. Wave two deploys infrastructure custom resources like Elasticsearch clusters or Kafka brokers. Wave three deploys configuration resources like ConfigMaps and Secrets. Wave one hundred deploys application services that consume infrastructure. This ordering ensures that infrastructure exists before applications attempt to use it.

Example sync wave annotation:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: observability
  annotations:
    argocd.argoproj.io/sync-wave: "0"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: elastic-operator
  namespace: elastic-system
  annotations:
    argocd.argoproj.io/sync-wave: "1"
---
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: jaeger-es
  namespace: observability
  annotations:
    argocd.argoproj.io/sync-wave: "2"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aggregator-service
  namespace: super-fortnight
  annotations:
    argocd.argoproj.io/sync-wave: "100"
```

### 7.3 Health Assessment

ArgoCD determines application health by checking resource status. For standard resources like Deployments, StatefulSets, and Services, built-in health checks verify conditions and ready replicas. For custom resources, teams configure health checks using Lua scripts that interpret resource status. Proper health assessment prevents ArgoCD from reporting success before resources actually achieve ready state.

Platform teams should configure health checks for platform custom resources like Istio VirtualServices, Elasticsearch clusters, and Kafka topics. These health assessments integrate into the sync wave progression, ensuring that subsequent waves wait for complete health before proceeding. Without proper health checks, sync waves may progress before dependencies are truly ready, causing cascading failures.

### 7.4 Sync Policies

Sync policies control how ArgoCD applies changes from Git to clusters. Automated sync with prune and self-heal provides fully automated GitOps, where changes commit and deploy without intervention. Manual sync requires explicit approval before deployment, appropriate for production environments requiring change control. Automated sync with manual prune deploys new resources automatically but requires approval for deletions.

The architecture typically configures development environments with full automation for rapid iteration. Staging environments might use automated sync to mirror production behavior while allowing faster deployment. Production environments might require manual sync for critical services or use automated sync with additional approval gates through ArgoCD notifications and workflows.

### 7.5 Resource Tracking

ArgoCD must track which resources belong to which applications. The architecture uses label-based tracking where ArgoCD adds labels to resources it creates. Teams should avoid modifying these labels, as they ensure ArgoCD can identify and manage resources. For resources created outside ArgoCD, teams can add tracking labels manually to bring them under ArgoCD management.

Resource tracking enables ArgoCD to detect drift when cluster state diverges from Git. Manual changes to cluster resources trigger out-of-sync status. Self-heal sync policy automatically corrects drift by reapplying Git state. This ensures that Git remains the source of truth, and manual cluster changes do not persist.

### 7.6 Progressive Delivery

While ArgoCD handles deployment, progressive delivery strategies require additional tooling. The architecture can integrate with Argo Rollouts for advanced deployment strategies. Canary deployments gradually shift traffic to new versions. Blue-green deployments maintain old and new versions simultaneously, switching traffic instantly. Progressive delivery reduces risk for critical services by validating new versions with subset of traffic before full rollout.

Teams implementing progressive delivery add Rollout resources to their repositories instead of Deployment resources. ArgoCD deploys Rollout resources like any other manifest. Argo Rollouts controller manages the progressive deployment based on Rollout specification. This integration maintains GitOps principles while adding sophisticated deployment capabilities.