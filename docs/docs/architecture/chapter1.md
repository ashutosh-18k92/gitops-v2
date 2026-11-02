# Chapter 1: Introduction and Problem Statement

### 1.1 The Cloud-Native Deployment Challenge

Organizations adopting microservices architectures on Kubernetes face a fundamental challenge in managing deployments across multiple teams and environments. As platforms grow from a handful of services to dozens or hundreds, the complexity of maintaining consistent deployment patterns while preserving team autonomy becomes increasingly difficult.

Traditional approaches to Kubernetes deployment manifest management fall into two problematic categories. The monolithic repository pattern centralizes all deployment configurations in a single repository. While this provides consistency, it creates bottlenecks as multiple teams compete for access to the same configuration files. Every deployment requires coordination, code reviews span unrelated changes, and the repository becomes a single point of failure for the entire platform.

The opposite extreme, complete team autonomy without standardization, leads to different problems. Teams duplicate deployment configurations, creating hundreds of lines of YAML for each service. Configuration drift occurs as teams implement different patterns for the same requirements. Platform-wide improvements require visiting every service repository individually. Inconsistency in resource limits, health checks, and scaling policies creates operational challenges.

### 1.2 The GitOps Requirement

GitOps has emerged as the industry standard for managing Kubernetes deployments, but its implementation presents unique challenges. GitOps requires that the desired state of the entire system be declaratively defined in Git, making Git the single **source of truth** for infrastructure and applications. This provides powerful benefits including complete audit trails through Git history, rollback capabilities by reverting commits, pull request workflows for reviewing changes, and automated synchronization between Git and cluster state.

However, strict GitOps adherence conflicts with practical team workflows. Teams need to deploy changes rapidly without waiting for platform team reviews. Services require different configurations across development, staging, and production environments. Platform teams must evolve infrastructure templates without forcing synchronous adoption. Security policies, resource limits, and monitoring configurations should be standardized, yet teams need flexibility for service-specific requirements.

### 1.3 Configuration Management Tool Landscape

The Kubernetes ecosystem provides several configuration management approaches, each with distinct strengths and limitations. Understanding these tools and their appropriate use cases is essential for designing an effective deployment architecture.

#### Plain YAML Manifests

Plain Kubernetes YAML manifests represent the simplest approach. They provide complete transparency, with exactly what you write being applied to the cluster. There are no build steps or compilation phases to debug. However, this simplicity comes at a significant cost. Duplication is rampant, as common patterns must be repeated across services. Making changes requires manual edits to multiple files. Environment-specific configurations necessitate maintaining separate complete manifests for each environment. As platforms scale beyond a few services, plain YAML becomes unmaintainable.

#### Helm Charts

Helm introduced templating to Kubernetes configuration management, treating applications as packages. Charts define reusable **templates** with values files for customization. This eliminates duplication through shared templates and provides **semantic versioning** for application releases. Helm's package management model works well for distributing applications, but presents challenges for multi-environment deployments. Handling environment-specific configurations requires multiple values files or complex conditional logic within templates. Teams often struggle with Helm's template language, and debugging template rendering can be opaque. The values override mechanism does not support patching arbitrary fields, limiting flexibility for complex scenarios.

#### Kustomize

Kustomize takes a different approach, using strategic merge patches and overlays rather than templates. It builds on base configurations and applies environment-specific transformations. Kustomize works directly with standard Kubernetes YAML without introducing a new templating language. Its **overlay** system naturally represents environment differences, and the **patching** mechanism can modify any field in any resource. However, Kustomize lacks Helm's package management and versioning capabilities. Sharing base configurations requires Git submodules or directory copying. Complex transformations can require deeply nested patches, and strategic merge behavior is sometimes non-intuitive.

### 1.4 The Hybrid Approach Rationale

The Super Fortnight architecture recognizes that Helm and Kustomize solve different problems, and combining them leverages the strengths of each while mitigating their individual weaknesses. Helm excels at defining reusable templates and distributing versioned packages. Platform teams can maintain base charts with production-ready defaults, and teams can select specific chart versions for selective adoption. Semantic versioning clearly communicates compatibility and changes.

Kustomize excels at environment-specific customization and precise patching. Development, staging, and production overlays apply targeted transformations. Teams can add service-specific configuration without modifying base templates. Patches maintain separation between platform-provided templates and team-specific requirements.

By combining these tools, the architecture achieves the benefits of both. Platform teams publish Helm charts as versioned templates. Team repositories reference specific chart versions in Kustomize configurations. Environment overlays apply patches for environment-specific needs. ArgoCD orchestrates the rendering and deployment of the combined configuration. This hybrid approach addresses the fundamental tension between standardization and flexibility, enabling both platform evolution and team autonomy.

> Platform team maintains the starter charts that are used by feature teams to kick-start their service layers. The feautre team has two options to move forward they can either create their own service specific helm chart by using the `helm create feature-service --starter=path/to/starter-chart` and then the feature team take their own path in mantaining their chart. Alternatively, teams can follow the leader chart approach and refer the base chart as a dependency. The team then refers the base chart as dependency and adds their chart layer and dependencies on top of that; for example if a particular service required a database such as postgres it can be added as dependency. With this approach multiple charts can be combined through dependencies to achieve one common service. This pattern fits well with Domain Drivern Design principles of creating aggregates.
