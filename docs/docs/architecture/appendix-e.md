# Appendix E: Glossary

**ApplicationSet:** ArgoCD resource that generates multiple Application instances from templates and generators, enabling dynamic application creation based on Git repository structure or other inputs.

**Chart Version:** Semantic version identifier for Helm charts that indicates compatibility and breaking changes, following the pattern major.minor.patch.

**DRY Principle:** Don't Repeat Yourself principle, emphasizing elimination of configuration duplication through shared templates and inheritance.

**Environment Overlay:** Kustomize configuration layer that applies environment-specific transformations to base resources, such as resource limits or replica counts.

**GitOps:** Operational framework using Git as the single source of truth for declarative infrastructure and application configuration, with automated synchronization to cluster state.

**Helm Chart:** Package of Kubernetes manifest templates with configurable values, providing reusable deployment patterns with semantic versioning.

**Kustomize:** Kubernetes configuration customization tool using overlays and patches to modify base configurations without templating.

**Overlay:** Kustomize configuration layer that applies transformations to base resources through patches and value modifications.

**Patch:** Partial resource definition that modifies specific fields of Kubernetes resources through strategic merge or JSON patch operations.

**Selective Adoption:** Pattern where teams control timing of platform update adoption through explicit version pinning rather than automatic upgrades.

**Semantic Versioning:** Versioning scheme using major.minor.patch format where major indicates breaking changes, minor adds features, and patch fixes bugs.

**Strategic Merge Patch:** Kustomize patching mechanism that intelligently merges configurations based on field types, merging maps and replacing lists by default.

**Sync Wave:** ArgoCD mechanism for controlling deployment order through numeric annotations, ensuring dependencies deploy before dependents.

**Three-Tier Architecture:** Architectural pattern separating platform charts (Tier 1), Feature Team Services (Tier 2), and orchestration (Tier 3) for clear ownership boundaries.

**Values Hierarchy:** Precedence order for Helm values, from chart defaults through environment-specific overrides, determining final configuration.

* * *