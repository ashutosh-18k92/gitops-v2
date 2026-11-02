# Cloud-Native GitOps Architecture

**Production-Grade Microservices Deployment Platform**

A Comprehensive Guide to Three-Tier Architecture with Helm + Kustomize Hybrid Approach

**Super Fortnight Platform**

January 2026

---

## Table of Contents

- [Executive Summary](#executive-summary)
- [Chapter 1: Introduction and Problem Statement](chapter1.md)
- [Chapter 2: Architectural Philosophy and Design Principles](chapter2.md)
- [Chapter 3: Three-Tier Architecture Overview](chapter3.md)
- [Chapter 4: Helm + Kustomize Hybrid Implementation](chapter4.md)
- [Chapter 5: Repository Structures and Workflows](chapter5.md)
- [Chapter 6: Team Operations and Best Practices](chapter6.md)
- [Chapter 7: Deployment Patterns and ArgoCD Integration](chapter7.md)
- [Chapter 8: Helm Chart Ownership Models](chapter8.md)
- [Chapter 9: Conclusion and Future Directions](chapter9.md)
- [Appendix A: Quick Reference Tables](appendix-a.md)
- [Appendix B: Command Reference](appendix-b.md)
- [Appendix C: Troubleshooting Guide](appendix-c.md)
- [Appendix D: Configuration Examples](appendix-d.md)
- [Appendix E: Glossary](appendix-e.md)
- [Appendix F: Complete Dependencies Example](appendix-f.md)
- [Appendix G: Enabling Helm Support in ArgoCD for Kustomize Builds](appendix-g.md)

---

## Executive Summary

This document presents a comprehensive architectural framework for deploying microservices in production Kubernetes environments using GitOps principles. The architecture addresses the fundamental challenge of balancing security, team autonomy, and operational efficiency in distributed systems where multiple teams develop and deploy services independently.

### The Challenge

Modern cloud-native platforms face a critical tension. GitOps mandates that all configuration reside in Git as the single source of truth, enabling declarative infrastructure management and automated deployments. However, this creates several operational challenges. Teams require autonomy to deploy services without dependencies on platform teams or other feature teams. Configuration duplication across services leads to inconsistency and maintenance burden. Different environments demand different configurations, yet maintaining consistency in deployment patterns remains essential. Platform teams must evolve infrastructure templates without forcing immediate adoption across all services.

### The Solution

The Super Fortnight platform implements a three-tier architecture that provides clear separation of concerns between platform infrastructure, team-owned services, and GitOps orchestration. This architecture combines the templating power of Helm with the patching flexibility of Kustomize, enabling teams to work independently while maintaining consistency.

The architecture consists of three distinct tiers. Tier 1 represents the Platform Chart Repository, where centralized Helm chart templates are maintained by the platform team with semantic versioning. Tier 2 encompasses Feature Team Service Repositories, where feature teams own complete repositories containing both application code and deployment configuration. Tier 3 comprises the GitOps Repository, containing ArgoCD application definitions that orchestrate deployments across environments.

### Key Architectural Principles

Team autonomy forms the foundation of this architecture. Feature teams maintain complete ownership of their services, working exclusively within their own repositories. Teams control when to adopt platform updates through selective version pinning, eliminating forced upgrades and deployment dependencies on other teams. This autonomy extends to independent release cycles, where each team operates on its own schedule without blocking others.

The DRY principle eliminates configuration duplication through centralized base charts. Service-specific configuration files are reduced from hundreds of lines to approximately thirty lines of essential values. Shared templates ensure consistent patterns across all services, while avoiding the pitfalls of copy-paste configuration management.

GitOps excellence is achieved through Git as the single source of truth for all three tiers. Declarative configuration enables automated synchronization via ArgoCD, while Git history provides complete audit trails for all changes. The architecture supports easy rollback capabilities when issues arise.

Environment management leverages Kustomize overlays to handle environment-specific configurations. Base values provide defaults applicable across all environments, while overlays apply targeted transformations for development, staging, and production. Production patches implement high availability configurations, scaling policies, and resource allocations without modifying base templates.

### The One-Sentence Philosophy

**"Centralized templates, decentralized control—platform teams provide the foundation, feature teams own the execution."**

This philosophy manifests in six critical architectural decisions, each answering a fundamental question about distributed system deployment.

**How do we prevent platform changes from blocking feature team deployments?** By establishing clear separation of concerns where platform teams own infrastructure templates and operators, while feature teams maintain complete ownership of their service configurations. Each team operates in their own repository with their own deployment cadence.

**What happens when the Auth team needs a custom security patch that doesn't apply to Payments?** Feature teams can add environment-specific patches that only affect their services. A patch applied in the Auth team's staging environment has zero impact on Payments' staging or any other team's environments. True modularity without collision.

**Why should production configuration decisions wait for dev and staging consensus?** They should not. Each environment maintains its own configuration. Development can experiment with minimal resources, staging can mirror production topology, and production can enforce strict security policies. No environment is hostage to another's requirements.

**Should a breaking change in development prevent critical production hotfixes?** Absolutely not. Each environment upgrades on its own schedule. Development can test Kafka version 3.8 while production remains stable on version 3.6. When production needs an urgent security patch, it does not wait for development's experimental features to stabilize.

**How do we handle the reality that dev needs 256MB RAM while production needs 4GB?** Through environment-specific Kustomize overlays. Each environment applies only the transformations it needs. Development patches down to minimal resources, staging adds moderate scaling, production layers on full high availability configuration with horizontal pod autoscaling. Same base, radically different runtime profiles.

**Why are we tired of managing separate values-base files alongside Kustomize patches?** Because Kustomize does not support multi-file Helm value merging elegantly. We embedded base values directly into the service chart itself. Now feature teams only manage their environment overlays. The chart ships with sensible defaults, and Kustomize patches do what they do best: targeted transformations.

### Business Value

This architecture delivers measurable business value across multiple dimensions. Development velocity increases as teams work independently without cross-team coordination overhead. The reduced blast radius of changes means issues affect only the services being modified, not the entire platform. **Operational overhead decreases through standardized deployment patterns and automated GitOps workflows.** The architecture scales naturally as new teams and services join the platform, with proven patterns ready for adoption.

### Implementation Scope

The Super Fortnight platform currently implements this architecture across multiple microservices including game result aggregation, individual game services, and event streaming infrastructure. The platform leverages ArgoCD for GitOps orchestration, Istio service mesh for traffic management and observability, Kubernetes with production-grade configurations for container orchestration, and Helm combined with Kustomize for configuration management.

### Document Structure

This guide provides comprehensive coverage of the architecture, from foundational concepts through detailed implementation patterns. Readers will understand the problem space and architectural philosophy, learn the three-tier architecture structure and interactions, master the Helm plus Kustomize hybrid implementation approach, explore repository structures and team workflows, review deployment patterns and ArgoCD integration, and access reference materials and best practices. Whether you are a platform team member designing infrastructure, a feature team developer deploying services, or an architect evaluating deployment strategies, this guide provides the knowledge needed to implement and operate production-grade cloud-native systems.
