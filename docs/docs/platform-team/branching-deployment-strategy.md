# Branching Strategy

## Overview

This strategy combines **environment-based branches** for isolation with **tags** for deployment targeting:

- **Branches**: Provide complete isolation between dev, staging, and prod environments
- **Tags**: Mark specific deployment targets within each branch

## Architecture

```
aggregator-service/
├── main                    # Source of truth, environment configs
├── dev                     # Development environment
│   └── tags: dev-v1.0.0, dev-v1.1.0, dev-latest
├── staging                 # Staging environment
│   └── tags: staging-v1.0.0, staging-latest
└── prod                    # Production environment
    └── tags: prod-v1.0.0, prod-v1.1.0, prod-latest
```

## How It Works

### 1. Branches for Environment Isolation

Each environment has its own branch for complete isolation:

```yaml
# ApplicationSet uses branch per environment
source:
  repoURL: https://github.com/ashutosh-18k92/aggregator-service.git
  targetRevision: "{{.env}}" # dev, staging, or prod branch
  path: "deploy/overlays/{{.env}}"
```

### 2. Tags for Deployment Targets

Within each branch, tags mark specific deployment states:

**Tag Naming Convention**:

- `{env}-v{semver}` - Specific version (e.g., `dev-v1.2.3`, `prod-v2.0.1`)
- `{env}-latest` - Latest stable deployment for that environment
- `{env}-rc{number}` - Release candidate (e.g., `staging-rc1`)

## Benefits

✅ **Complete Environment Isolation**: Branches prevent cross-environment contamination  
✅ **Precise Deployment Control**: Tags enable targeting specific versions  
✅ **Easy Rollback**: Point to any previous tag within the branch  
✅ **Clear Audit Trail**: Branch history + tag markers  
✅ **Flexible Promotion**: Cherry-pick or merge between branches, tag when ready  
✅ **Hotfix Support**: Apply fixes to specific branches and tag immediately

## Team Workflow

### 1. Develop in Dev Branch

```bash
# Switch to dev branch
git checkout dev

# Make changes
vim deploy/overlays/dev/values.yaml
# Update chart version, add features, etc.

# Commit changes
git add .
git commit -m "feat: Add new feature"
git push origin dev

# Tag the deployment
git tag dev-v1.2.0
git push origin dev-v1.2.0

# Update latest tag
git tag -f dev-latest
git push -f origin dev-latest
```

### 2. Test in Dev

```bash
# ArgoCD syncs to dev-latest tag
kubectl get pods -n super-fortnight-dev

# Test the feature
curl https://aggregator-dev.example.com/health
```

### 3. Promote to Staging

```bash
# Switch to staging branch
git checkout staging

# Merge from dev (or cherry-pick specific commits)
git merge dev

# Or cherry-pick specific features
git cherry-pick <commit-sha>

# Tag for staging deployment
git tag staging-v1.2.0
git push origin staging-v1.2.0

# Update staging-latest
git tag -f staging-latest
git push -f origin staging-latest
```

### 4. Deploy to Production

```bash
# Switch to prod branch
git checkout prod

# Merge from staging (recommended) or dev
git merge staging

# Tag production release
git tag prod-v1.2.0
git push origin prod-v1.2.0

# Update prod-latest
git tag -f prod-latest
git push -f origin prod-latest
```

### 5. Rollback in Production

```bash
# Point to previous tag
git checkout prod
git reset --hard prod-v1.1.0

# Update prod-latest to previous version
git tag -f prod-latest prod-v1.1.0
git push -f origin prod-latest

# Or use ArgoCD to point to specific tag
argocd app set aggregator-service-production --revision prod-v1.1.0
```

### 6. Hotfix Production

```bash
# Work directly on prod branch
git checkout prod

# Make urgent fix
vim deploy/overlays/production/patches/security-fix.yaml

# Commit and tag immediately
git commit -m "hotfix: Critical security patch"
git tag prod-v1.2.1
git push origin prod
git push origin prod-v1.2.1

# Update prod-latest
git tag -f prod-latest
git push -f origin prod-latest

# Backport to other environments
git checkout staging
git cherry-pick <hotfix-commit-sha>
git tag staging-v1.2.1
git push origin staging staging-v1.2.1

git checkout dev
git cherry-pick <hotfix-commit-sha>
git tag dev-v1.2.1
git push origin dev dev-v1.2.1
```

## ApplicationSet Configuration

### Option A: Use Latest Tags (Recommended)

```yaml
source:
  repoURL: https://github.com/ashutosh-18k92/aggregator-service.git
  targetRevision: "{{.env}}-latest" # dev-latest, staging-latest, prod-latest
  path: "deploy/overlays/{{.env}}"
```

**Benefits**: Automatic deployment when you update the `-latest` tag

### Option B: Use Specific Version Tags

```yaml
source:
  repoURL: https://github.com/ashutosh-18k92/aggregator-service.git
  targetRevision: "{{.chartVersion}}" # From environment config
  path: "deploy/overlays/{{.env}}"
```

**Environment config** (`deploy/environments/production.yaml`):

```yaml
env: production
namespace: super-fortnight
chartVersion: prod-v1.2.0 # Specific tag
```

**Benefits**: Explicit version control, no automatic updates

## Tag Management

### Creating Tags

```bash
# Semantic versioning within environment
git tag {env}-v{major}.{minor}.{patch}

# Examples
git tag dev-v1.0.0
git tag staging-v1.0.0
git tag prod-v1.0.0

# Push tags
git push origin --tags
```

### Moving Latest Tags

```bash
# Update latest tag to current commit
git tag -f dev-latest
git push -f origin dev-latest

# Update latest tag to specific version
git tag -f prod-latest prod-v1.2.0
git push -f origin prod-latest
```

### Listing Tags

```bash
# List all tags for an environment
git tag -l "prod-v*"

# Show tag details
git show prod-v1.2.0
```

## Branch Protection

### Main Branch

- ✅ Require pull request reviews
- ✅ Require status checks
- ✅ Only platform team can merge

### Prod Branch

- ✅ Require pull request reviews (2 approvals)
- ✅ Require status checks to pass
- ✅ No direct pushes (except hotfixes)
- ✅ Protected tags: `prod-v*`

### Staging Branch

- ✅ Require pull request review (1 approval)
- ✅ Require status checks
- ⚠️ Allow hotfixes with approval

### Dev Branch

- ⚠️ Fewer restrictions
- ✅ Feature team has write access
- ✅ Can push directly for rapid iteration

## Comparison with Other Strategies

| Aspect                    | Hybrid (Branches + Tags) | Pure Branching  | Pure Tagging |
| ------------------------- | ------------------------ | --------------- | ------------ |
| **Environment Isolation** | ✅ Complete              | ✅ Complete     | ⚠️ Partial   |
| **Version Control**       | ✅ Precise               | ⚠️ Commit-based | ✅ Precise   |
| **Rollback**              | ✅ Easy (tag)            | ⚠️ Revert       | ✅ Easy      |
| **Complexity**            | ⚠️ Moderate              | ⚠️ High         | ✅ Low       |
| **Audit Trail**           | ✅ Excellent             | ✅ Good         | ⚠️ Mixed     |
| **Hotfixes**              | ✅ Easy                  | ✅ Easy         | ⚠️ Complex   |
| **Promotion Flow**        | ✅ Clear                 | ✅ Clear        | ⚠️ Manual    |

## Recommendation

Use **hybrid branching + tagging** for:

- ✅ Production systems requiring strict isolation AND precise versioning
- ✅ Teams needing independent workflows with deployment control
- ✅ Compliance requirements for change tracking and rollback capability
- ✅ Multi-environment setups (dev → staging → prod)
- ✅ Systems requiring frequent hotfixes

## Repository Setup

### Create Environment Branches

```bash
cd aggregator-service

# Create dev branch from main
git checkout -b dev
git push -u origin dev

# Create prod branch from main
git checkout -b prod
git push -u origin prod

# Back to main
git checkout main
```

### Sync Initial State

```bash
# Ensure all branches have the same initial state
git checkout dev
git merge main
git push

git checkout prod
git merge main
git push

git checkout main
```

Now each environment can evolve independently!
