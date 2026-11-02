# Platform Team Guide

## Overview

This guide is for **Platform Team** members who manage the base API chart in the `sf-helm-registry` repository.

**Repository**: https://github.com/ashutosh-18k92/sf-helm-registry.git

## Responsibilities

As a platform team member, you:

- ✅ Maintain the base API Helm chart
- ✅ Release new chart versions with semantic versioning
- ✅ Ensure backward compatibility
- ✅ Announce updates to feature teams
- ✅ Provide documentation and migration guides

## Repository Structure

```
sf-helm-registry/
└── api/
    ├── Chart.yaml              # Chart metadata with version
    ├── values.yaml             # Base default values
    ├── values.dev.yaml         # Development environment defaults
    ├── values.stage.yaml       # Staging environment defaults
    ├── values.prod.yaml        # Production environment defaults
    ├── values.schema.json      # JSON schema for values validation
    ├── README.md               # Chart documentation
    ├── CHANGELOG.md            # Version history
    └── templates/
        ├── deployment.yaml
        ├── service.yaml
        ├── hpa.yaml
        ├── istioVirtualService.yaml
        ├── serviceAccount.yaml
        ├── _helpers.tpl
        └── tests/
            └── test-connection.yaml
```

## Workflow

### 1. Making Changes to the Chart

```bash
# Clone the repository
git clone https://github.com/ashutosh-18k92/sf-helm-registry.git
cd sf-helm-registry/api

# Create a feature branch
git checkout -b feature/add-prometheus-annotations

# Make your changes
vim templates/deployment.yaml
vim values.yaml

# Test locally
helm lint .
helm template test . --dry-run

# Test with a real service
helm template aggregator . -f /path/to/aggregator/values.yaml
```

### 2. Versioning

Use **semantic versioning** (MAJOR.MINOR.PATCH):

- **MAJOR**: Breaking changes (e.g., 1.0.0 → 2.0.0)
- **MINOR**: New features, backward compatible (e.g., 0.1.0 → 0.2.0)
- **PATCH**: Bug fixes, backward compatible (e.g., 0.1.0 → 0.1.1)

```bash
# Update version in Chart.yaml
vim Chart.yaml
```

**Example**:

```yaml
apiVersion: v2
name: api
description: Base API Helm chart for microservices
type: application
version: 0.2.0 # ← Bump this
appVersion: "1.0"
```

### 3. Update CHANGELOG

```bash
vim CHANGELOG.md
```

**Example**:

```markdown
# Changelog

## [0.2.0] - 2026-01-30

### Added

- Prometheus monitoring annotations
- Improved health check defaults
- Resource recommendations for production

### Changed

- Updated affinity rules for better HA

### Fixed

- Label selector issue in HPA
```

### 4. Commit and Tag

```bash
# Commit changes
git add .
git commit -m "v0.2.0: Add Prometheus monitoring annotations"

# Tag the release
git tag v0.2.0

# Push to GitHub
git push origin main --tags
```

### 5. Announce to Feature Teams

Post an announcement in your team communication channel:

```markdown
📢 **API Chart v0.2.0 Released**

**New Features**:

- Prometheus monitoring annotations on pods
- Improved health check defaults (initialDelaySeconds: 10)
- Resource recommendations for production workloads

**Breaking Changes**: None

**Upgrade Instructions**:
Update `version: 0.2.0` in your service's `deploy/base/kustomization.yaml`

**Documentation**: https://github.com/ashutosh-18k92/sf-helm-registry/blob/main/CHANGELOG.md

**Questions**: #platform-team
```

## Understanding Version Preservation

### How Teams Access Older Versions

> [!IMPORTANT]
> When you tag a release with `git tag v0.1.0`, that version is **permanently preserved in Git history**. Teams can reference it forever, even after you've released v0.2.0, v0.3.0, or v10.0.0!

**How it works**:

When feature teams specify a version in their `kustomization.yaml`:

```yaml
helmCharts:
  - name: api
    repo: https://github.com/ashutosh-18k92/sf-helm-registry.git
    version: 0.1.0 # This is a Git tag!
```

Kustomize:

1. Clones the Git repository
2. **Checks out the specific tag** `v0.1.0`
3. Uses the chart files **as they existed at that point in Git history**
4. The current state of `main` branch doesn't matter!

### Example Timeline

```bash
# You release v0.1.0
vim Chart.yaml  # version: 0.1.0
git commit -m "v0.1.0: Initial release"
git tag v0.1.0
git push origin main --tags

# Later, you release v0.2.0
vim Chart.yaml  # version: 0.2.0
vim templates/deployment.yaml  # Add features
git commit -m "v0.2.0: Add Prometheus"
git tag v0.2.0
git push origin main --tags

# Even later, you release v0.3.0
vim Chart.yaml  # version: 0.3.0
git commit -m "v0.3.0: Breaking changes"
git tag v0.3.0
git push origin main --tags
```

**Now the repository has**:

- Current `main` branch: v0.3.0
- Git tag `v0.1.0`: Points to old commit (still accessible!)
- Git tag `v0.2.0`: Points to middle commit (still accessible!)
- Git tag `v0.3.0`: Points to current commit

### Team Scenarios

**Team A (still on v0.1.0)**:

```yaml
version: 0.1.0 # Git checks out tag v0.1.0
```

✅ Works perfectly! Gets chart as it was at v0.1.0

**Team B (upgraded to v0.2.0)**:

```yaml
version: 0.2.0 # Git checks out tag v0.2.0
```

✅ Works perfectly! Gets chart as it was at v0.2.0

**Team C (on latest v0.3.0)**:

```yaml
version: 0.3.0 # Git checks out tag v0.3.0
```

✅ Works perfectly! Gets latest chart

### Verification

You can verify this yourself:

```bash
# Check all available versions
git ls-remote --tags https://github.com/ashutosh-18k92/sf-helm-registry.git

# Checkout old version
git clone https://github.com/ashutosh-18k92/sf-helm-registry.git /tmp/test
cd /tmp/test
git checkout v0.1.0
cat api/Chart.yaml  # Shows version: 0.1.0

# Checkout newer version
git checkout v0.2.0
cat api/Chart.yaml  # Shows version: 0.2.0
```

### Critical Rule: Never Delete Tags!

> [!CAUTION]
> **NEVER delete Git tags!** If you delete a tag, teams referencing that version will break.

❌ **DON'T DO THIS**:

```bash
git tag -d v0.1.0  # Delete tag locally
git push origin :refs/tags/v0.1.0  # Delete from remote
# This breaks all teams using version: 0.1.0!
```

✅ **DO THIS INSTEAD**:

- Keep all tags forever
- If a version has critical bugs, release a new PATCH version
- Document deprecated versions in CHANGELOG
- Let teams upgrade at their own pace

### Alternative: Using Commit SHAs

Teams can also reference specific commits:

```yaml
helmCharts:
  - name: api
    version: abc123def456 # Commit SHA instead of tag
```

This works but is less readable than semantic versions.

### Summary

**The "older versions" are preserved in Git history via tags**, not as separate files or directories.

Benefits:

- ✅ No need for multiple chart directories
- ✅ No need for backup files
- ✅ Clean repository structure
- ✅ Teams can reference any historical version
- ✅ Platform team just needs to tag releases

**Key takeaway**: Git tags are permanent version bookmarks that teams can always reference!

### ✅ DO

**Versioning**:

- Use semantic versioning strictly
- Tag every release in Git
- Document changes in CHANGELOG.md

**Compatibility**:

- Maintain backward compatibility for MINOR and PATCH versions
- Only break compatibility in MAJOR versions
- Provide migration guides for breaking changes

**Testing**:

- Test with `helm lint` before releasing
- Validate with real service values
- Test in development environment first

**Communication**:

- Announce all releases to feature teams
- Provide clear upgrade instructions
- Document breaking changes prominently

**Documentation**:

- Keep README.md up to date
- Document all values in values.yaml
- Provide examples for common use cases

### ❌ DON'T

**Versioning**:

- Don't skip versions (e.g., 0.1.0 → 0.3.0)
- Don't reuse version numbers
- Don't use `latest` as a version

**Compatibility**:

- Don't break compatibility in MINOR/PATCH releases
- Don't remove values without deprecation period
- Don't change default behavior without major version bump

**Releases**:

- Don't release untested changes
- Don't force teams to upgrade
- Don't add service-specific logic to base chart

## Common Tasks

### Adding a New Template

```bash
cd sf-helm-registry/api

# Create new template
cat > templates/configmap.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "microservice.name" . }}-config
  labels:
    {{- include "microservice.labels" . | nindent 4 }}
data:
  {{- range \$key, \$value := .Values.configMap }}
  {{ \$key }}: {{ \$value | quote }}
  {{- end }}
EOF

# Add values
vim values.yaml
# Add:
# configMap: {}

# Test
helm lint .
helm template test .

# Commit
git add templates/configmap.yaml values.yaml
git commit -m "Add ConfigMap template"
```

### Updating Helper Functions

```bash
vim templates/_helpers.tpl
```

**Example**: Add a new label helper

```go-template
{{/*
Prometheus scrape annotations
*/}}
{{- define "microservice.prometheus.annotations" -}}
prometheus.io/scrape: "true"
prometheus.io/port: {{ .Values.containerPort | quote }}
prometheus.io/path: "/metrics"
{{- end }}
```

### Adding Environment-Specific Defaults

```bash
vim values.prod.yaml
```

**Example**:

```yaml
# Production defaults
replicaCount: 3

resources:
  requests:
    memory: "256Mi"
    cpu: "200m"
  limits:
    memory: "512Mi"
    cpu: "500m"

hpa:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
```

## Testing

### Local Testing

```bash
# Lint the chart
helm lint .

# Dry-run template rendering
helm template test . --dry-run

# Render with specific values
helm template test . -f values.prod.yaml

# Validate against Kubernetes
helm template test . | kubectl apply --dry-run=client -f -
```

### Testing with Service Values

```bash
# Get service values from a team repository
git clone https://github.com/ashutosh-18k92/aggregator-service.git /tmp/aggregator
cd /tmp/aggregator

# Build with Kustomize (uses your chart)
kustomize build deploy/overlays/production

# Or test directly with Helm
cd /path/to/sf-helm-registry/api
helm template aggregator . -f /tmp/aggregator/deploy/base/values.yaml
```

## Troubleshooting

### Chart Fails Lint

```bash
helm lint .
# Review errors and fix templates
```

### Feature Team Reports Issue

```bash
# Reproduce with their values
helm template test . -f /path/to/their/values.yaml

# Debug template rendering
helm template test . --debug
```

### Version Conflict

```bash
# Check existing tags
git tag -l

# If tag already exists, increment version
vim Chart.yaml  # Bump version
git tag v0.2.1  # Use next version
```

## Release Checklist

Before releasing a new version:

- [ ] All changes tested locally with `helm lint`
- [ ] Tested with at least one real service's values
- [ ] Version bumped in `Chart.yaml`
- [ ] CHANGELOG.md updated
- [ ] README.md updated (if needed)
- [ ] Breaking changes documented
- [ ] Migration guide created (if breaking changes)
- [ ] Committed and tagged
- [ ] Pushed to GitHub
- [ ] Announcement posted to team channel

## Support

### For Feature Teams

- **Questions**: #platform-team Slack channel
- **Issues**: GitHub Issues in sf-helm-registry
- **Documentation**: This guide + chart README.md

### For Platform Team

- **Chart Repository**: https://github.com/ashutosh-18k92/sf-helm-registry
- **GitOps Repository**: gitops-v2 or gitops-v3
- **Helm Documentation**: https://helm.sh/docs/

## Related Documentation

- [Three-Tier Architecture](../architecture/three-tier-architecture.md)
- [Decentralized Helm Charts Pattern](service-specific-charts.md)
- [Feature Team Guide](feature-team-guide.md)
- [Adding a New Service](adding-new-service.md)
