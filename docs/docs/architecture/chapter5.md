# Chapter 5: Repository Structures and Workflows

### 5.1 Platform Chart Repository Workflow

Platform teams maintain the chart repository following established release management practices. When adding features or fixing bugs, platform engineers clone the repository, create feature branches, modify templates and default values, update documentation, and test changes with real services. Chart versioning follows semantic versioning strictly. Breaking changes increment the major version, new features increment the minor version, and bug fixes increment the patch version.

The release process involves updating Chart.yaml with the new version, documenting changes in CHANGELOG.md, testing with lint and template commands, creating a git tag matching the version, pushing commits and tags to the repository, and announcing the release to feature teams. Announcements include new features, breaking changes if any, upgrade instructions, and links to documentation. This process ensures teams have clear information for evaluating and adopting updates.

Example release workflow:

```bash
# Clone platform chart repository
git clone https://github.com/ashutosh-18k92/sf-helm-registry.git
cd sf-helm-registry/charts/api

# Add new feature to templates
vim templates/deployment.yaml
# Add Prometheus monitoring annotations

# Update chart version
vim Chart.yaml
# version: 0.1.0 → 0.2.0

# Test changes
helm lint .
helm template test . --dry-run

# Document changes
vim ../../CHANGELOG.md

# Commit and tag
git add .
git commit -m "v0.2.0: Add Prometheus monitoring annotations"
git tag v0.2.0
git push origin main --tags
```

### 5.2 Feature Team Service Repository Workflow

#### Application Development

Feature teams work in their service repositories following standard development practices. The workflow co-locates code and configuration changes. When implementing a feature, developers modify application source code, update deployment values if the feature requires configuration changes, adjust resource requests if performance characteristics change, and commit both code and configuration in the same pull request. This co-location provides atomic changes where code and deployment requirements remain synchronized.

For example, when adding a caching layer that requires Redis connection configuration, the developer implements the caching logic in source code, adds Redis connection parameters to the overlay values file, updates the deployment to include Redis client initialization, and commits everything together. Reviewers see both the code change and its deployment implications in one review, and rollback reverts both simultaneously if issues arise.

```bash
# Clone Feature Team Service repository
git clone https://github.com/ashutosh-18k92/aggregator-service.git
cd aggregator-service

# Develop feature
vim src/index.ts
npm run dev

# Update deployment config in same PR
vim deploy/overlays/development/values.yaml
# Add caching configuration

# Commit both code and config
git add src/ deploy/
git commit -m "Add Redis caching with deployment config"
git push

# ArgoCD auto-syncs
```

#### Adopting Platform Updates

When platform teams release new chart versions, feature teams control adoption timing. The team reviews the changelog and release notes, tests the new version in development by updating the chart version in the development overlay kustomization file, validates behavior and confirms no regressions, updates staging overlay to the new version for further validation, and finally updates production overlay after successful staging validation. Teams might skip versions, jumping from 0.1.0 directly to 0.3.0 if intermediate versions provide no needed features.

```bash
cd aggregator-service

# Update development to new chart version
vim deploy/overlays/development/kustomization.yaml
# Change: version: v0.2.3 → v0.2.4

git commit -m "Upgrade dev to chart v0.2.4"
git push

# After validation in dev, update staging
vim deploy/overlays/staging/kustomization.yaml
# Change: version: v0.2.3 → v0.2.4

git commit -m "Upgrade staging to chart v0.2.4"
git push

# After staging validation, update production
vim deploy/overlays/production/kustomization.yaml
# Change: version: v0.2.3 → v0.2.4

git commit -m "Upgrade production to chart v0.2.4"
git push
```

#### Adding Environment-Specific Patches

When teams need configurations that values alone cannot express, they add Kustomize patches. The process involves creating a patch file in the environment's patches directory, adding a patch reference to the kustomization file with appropriate targeting, testing with ArgoCD diff to preview the result, and committing the change. Patches should target narrowly, modifying only the specific resource and fields required.

For instance, enabling a feature flag in production might involve creating a deployment patch that adds an environment variable, specifying the target deployment by kind and name, adding the patch to the production kustomization file's patches list, and validating that the patch applies without conflicts. This surgical approach minimizes the risk of unintended modifications and makes patches easier to understand and maintain.

```bash
cd aggregator-service/deploy/overlays/production

# Create patch file
cat > patches/feature-flag.yaml <<EOF
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
            - name: ENABLE_CACHING
              value: "true"
EOF

# Add to kustomization
vim kustomization.yaml
# Add to patches list:
# patches:
#   - target:
#       kind: Deployment
#       name: aggregator-api-v1
#     path: patches/feature-flag.yaml

git add patches/feature-flag.yaml kustomization.yaml
git commit -m "Enable caching in production"
git push
```

### 5.3 GitOps Repository Workflow

#### Onboarding New Services

When a new service joins the platform, the platform team adds an ApplicationSet definition to the GitOps repository. This involves creating a new ApplicationSet YAML file in the services directory, configuring the Git generator to point to the team repository's environments directory, setting the source path template to reference overlays, specifying the destination cluster and namespace, configuring sync policies for automated or manual deployment, and applying the ApplicationSet to the cluster. Once configured, ArgoCD automatically creates Application instances for each environment file in the team repository.

```bash
cd gitops-v2/services

# Create ApplicationSet for new service
cat > new-service-appset.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: new-service
  namespace: argocd
spec:
  goTemplate: true
  generators:
    - git:
        repoURL: https://github.com/org/new-service.git
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
      source:
        repoURL: https://github.com/org/new-service.git
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
EOF

# Apply to cluster
kubectl apply -f new-service-appset.yaml
```

#### Platform-Wide Policy Changes

Occasionally, platform teams need to modify deployment policies affecting all services. This might include changing sync policies from manual to automatic, adding health checks for custom resource types, configuring resource tracking for specific API groups, or implementing progressive sync for safer rollouts. These changes occur in the GitOps repository but affect all services. Platform teams must communicate changes to feature teams, test with a subset of services first, roll out gradually, and monitor for unexpected behaviors.

### 5.4 Cross-Tier Communication

Effective operation requires clear communication between platform and feature teams. Platform teams announce chart releases through designated channels like Slack or email. Release announcements include version number, new features and improvements, breaking changes with migration guides, upgrade instructions, and recommended testing approaches. Feature teams provide feedback on charts, reporting issues, requesting features, suggesting improvements, and sharing usage patterns that inform future development.

This bidirectional communication ensures that platform charts evolve based on real usage patterns while feature teams benefit from platform improvements. Regular synchronization meetings or asynchronous discussion channels maintain alignment without creating bottlenecks in day-to-day operations.

Example release announcement:

```markdown
📢 **API Chart v0.2.0 Released**

**New Features**:

- Prometheus monitoring annotations for automatic scraping
- Improved health check defaults with configurable timeouts
- Updated resource recommendations based on production metrics

**Breaking Changes**: None

**Upgrade Instructions**:
Update `version: v0.2.0` in your `deploy/overlays/*/kustomization.yaml`

**Testing Recommendations**:

- Verify Prometheus metrics are being collected
- Review new resource recommendations for your workload
- Test health check behavior in development first

**Documentation**: See CHANGELOG.md for full details
```