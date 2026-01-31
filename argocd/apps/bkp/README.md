# Backup ApplicationSet Files

This directory contains experimental and backup versions of the ApplicationSet configurations.

## Files

### `aggregator-appset-list-backup.yaml`

- **Type**: Backup of original List Generator approach
- **Status**: Deprecated
- **Reason**: Replaced by Git Files Generator for team autonomy

### `aggregator-appset-hybrid.yaml`

- **Type**: Experimental multi-source Helm + Kustomize
- **Status**: Not used
- **Reason**: ArgoCD multi-source doesn't support mixing Helm and Kustomize sources directly

### `aggregator-appset-kustomize-helm.yaml`

- **Type**: Experimental Kustomize with --enable-helm
- **Status**: Merged into production version
- **Reason**: Functionality incorporated into `../aggregator-appset.yaml`

## Production File

The **production-ready** ApplicationSet is:

- **Location**: `../aggregator-appset.yaml`
- **Approach**: Kustomize with `--enable-helm` flag
- **Features**:
  - Git Files Generator for environment discovery
  - Environment-based branching (`{{.env}}`)
  - Helm chart inflation via Kustomize
  - Modular patches support
  - Team autonomy for chart versions

## Cleanup

These backup files can be safely deleted after confirming the production ApplicationSet works correctly.
