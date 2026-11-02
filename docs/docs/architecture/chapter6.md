# Chapter 6: Team Operations and Best Practices

### 6.1 Platform Team Best Practices

#### Chart Design Principles

Platform charts should encode opinionated defaults while remaining flexible through values. Production-ready defaults ensure that teams starting with minimal configuration still deploy robust services. Health checks should be configured with sensible probe settings. Resource requests and limits should reflect typical service requirements. Security contexts should enforce least privilege and read-only root filesystems. Service mesh integration should be enabled by default with sensible traffic policies.

Values should expose all fields teams commonly customize while avoiding excessive parameterization that creates cognitive load. Common customization points include replica counts and autoscaling parameters, resource requests and limits, image repository and tag, environment variables, ingress and virtual service configuration, and service mesh retry and timeout policies. Rarely modified fields can remain in templates without values exposure.

#### Versioning Discipline

Semantic versioning must be followed strictly. Major version bumps indicate breaking changes requiring manual intervention. Minor versions add features while maintaining backward compatibility. Patch versions fix bugs without interface changes. Breaking changes require migration guides in release notes, documented differences from previous versions, recommended upgrade paths, and example patches for common migration scenarios.

Platform teams should maintain at least two minor versions, supporting security fixes for the previous minor version while developing the next. This provides teams flexibility in upgrade timing without forcing immediate adoption of new features.

#### Testing Requirements

Before releasing chart versions, platform teams should test with representative services. Render charts with common value combinations, verify generated manifests match expectations, test upgrades from previous versions, validate that patches commonly used by teams still apply correctly, and verify behavior in actual cluster environments. Automated testing using helm lint and template validation catches syntax errors, while integration testing with real services uncovers semantic issues.

### 6.2 Feature Team Best Practices

#### Minimal Values

Feature teams should maintain minimal values files, overriding only what differs from chart defaults. Typical value files span about 30 lines, covering application name and labels, image repository and tag, environment-specific configurations, resource requests when defaults are inappropriate, and service-specific feature flags. Avoid duplicating chart defaults in values files, as this creates maintenance burden and obscures what actually differs from defaults.

Example minimal values file:

```yaml
app:
  name: aggregator-service
  component: api
  partOf: superfortnight

environment: production

image:
  repository: aggregator-service
  tag: "v1.2.3"
  pullPolicy: IfNotPresent

env:
  LOG_LEVEL: "error"
  NODE_ENV: "production"

resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "1Gi"
    cpu: "500m"

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

virtualService:
  hosts:
    - aggregator.example.com
```

#### Patch Discipline

Patches should be surgical, modifying only necessary fields. Use explicit targeting to specify which resources to patch. Prefer values-based configuration over patches when charts expose appropriate fields. Document why patches exist, especially for non-obvious customizations. Review patches when adopting new chart versions to ensure continued validity. Patches that modify deeply nested fields may break when chart templates change. Prefer patches that add rather than replace to reduce fragility.

#### Chart Version Pinning

Pin specific chart versions in kustomization files rather than using version ranges or latest tags. Explicit versions ensure reproducible deployments and prevent unexpected changes during sync operations. Upgrade deliberately, testing new versions in development and staging before production. Document version choices in commit messages, explaining why specific versions were selected or why upgrades are being deferred.

### 6.3 Anti-Patterns to Avoid

#### Platform Team Anti-Patterns

Platform teams should avoid forcing teams to upgrade immediately. Breaking changes require major version bumps and migration support, not forced adoption. Service-specific logic does not belong in base charts. If only one team needs a feature, it should be implemented through patches or custom values in that team's repository. Avoid adding unnecessary complexity to templates. Every template conditional adds cognitive load. Keep charts simple and focused on common patterns.

#### Feature Team Anti-Patterns

Feature teams should never use latest for chart versions, as this creates non-reproducible deployments. Avoid duplicating base chart logic through extensive patches that reimplement template logic. This creates maintenance burden and defeats the purpose of base charts. Do not skip testing before deployment. Always validate changes in development and staging before production. Never hardcode values in patches that should be parameterized through values files.

### 6.4 Operational Procedures

#### Incident Response

When incidents occur, the architecture supports rapid rollback. Teams identify the problematic commit in their repository, revert the commit to restore previous configuration, push the revert to trigger ArgoCD sync, and verify that the cluster returns to stable state. Git history provides clear audit trails for understanding what changed and when. Because each team's repository is independent, incidents in one service do not require rolling back unrelated services.

```bash
# Identify problematic commit
git log --oneline

# Revert the commit
git revert abc123

# Push revert
git push

# Verify ArgoCD sync
argocd app get aggregator-service-production

# Check cluster state
kubectl get pods -n super-fortnight -l app=aggregator
```

#### Configuration Auditing

The architecture provides comprehensive auditability. Git commits in tier 1 show platform chart evolution. Git commits in tier 2 show service configuration changes. ArgoCD sync history shows actual cluster deployments. Application events in ArgoCD show successful and failed syncs. This multi-layered audit trail supports compliance requirements and incident investigations. Teams can trace from a cluster resource back through ArgoCD to the exact Git commit that defined it.

#### Disaster Recovery

GitOps enables powerful disaster recovery capabilities. If a cluster is lost, platform teams create a new cluster and install ArgoCD, apply ApplicationSet definitions from the GitOps repository, and ArgoCD automatically recreates all applications. Team repositories contain all service configuration, chart versions specify exact infrastructure versions, and applications sync to restore desired state. The cluster rebuilds itself from Git, potentially in minutes rather than days of manual reconstruction.
