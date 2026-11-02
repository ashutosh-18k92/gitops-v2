# API Starter Helm Chart

A production-ready Helm chart template for deploying API microservices on Kubernetes with Istio service mesh integration.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Getting Started](#getting-started)
- [Architecture & Design Decisions](#architecture--design-decisions)
- [Configuration](#configuration)
- [Usage Examples](#usage-examples)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Overview

This Helm chart provides a standardized, production-ready template for deploying API microservices with:

- Kubernetes Deployment, Service, and HPA resources
- Istio VirtualService for traffic management
- Environment-specific configuration overrides
- Schema validation for values
- Comprehensive health checks
- Kubernetes standard labels for proper resource grouping

## Features

- ✅ **Istio Integration**: Built-in VirtualService with retry policies and timeouts
- ✅ **Auto-scaling**: Horizontal Pod Autoscaler with CPU/memory targets
- ✅ **Health Checks**: Configurable liveness and readiness probes
- ✅ **Environment Overrides**: Separate values files for dev/stage/prod
- ✅ **Schema Validation**: JSON schema for values validation
- ✅ **Port Configuration**: Centralized port management with fallback pattern
- ✅ **Resource Management**: Configurable CPU/memory limits and requests
- ✅ **Standard Labels**: Kubernetes `app.kubernetes.io/*` labels with canary deployment support
- ✅ **Explicit Naming**: Resource-specific naming helpers for clarity
- ✅ **Flexible Affinity**: Default node and zone affinity templates with override capability

## Getting Started

### Prerequisites

- Helm 3.x
- Kubernetes cluster
- Istio installed (if using VirtualService)

### Creating a New Service

```bash
# Create from starter template
helm create my-new-service --starter api-0.1.0.tgz

# Or copy the chart
cp -r api my-new-service
```

### Customizing Values

Edit `values.yaml` in your new service:

```yaml
# Required: Update these for your service
containerPort: 3000

image:
  repository: "my-service"
  tag: "v1.0.0"

env:
  SERVICE_NAME: "my-service"

virtualService:
  hosts:
    - my-service
```

### Installing the Chart

**Note**: Helm automatically loads `values.yaml` from the chart directory. You only need to specify environment-specific override files.

```bash
# Development (values.yaml is automatically loaded)
helm install my-service . -f values.dev.yaml -n my-namespace

# Production (values.yaml is automatically loaded)
helm install my-service . -f values.prod.yaml -n my-namespace

# Base only (just uses values.yaml automatically)
helm install my-service . -n my-namespace
```

**Value Precedence** (lowest to highest):

1. `values.yaml` (automatic, always loaded first)
2. Additional `-f` files (left to right)
3. `--set` flags (highest priority)

## Architecture & Design Decisions

### 1. Resource Naming Conventions

**Approach**: Explicit, resource-specific naming helpers using `{Release.Name}-{Chart.Name}` pattern.

**Rationale**:

- Clear resource identification in `kubectl get` output
- Prevents naming conflicts
- Follows Kubernetes community conventions
- Declarative and self-documenting
- Chart name "api" avoids confusion (e.g., "api-service" vs "service-service")

**Implementation**:

```go-template
{{/* Base fullname: Release.Name-Chart.Name */}}
{{- define "api.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Deployment name - uses fullname with no suffix */}}
{{- define "api.deployment.name" -}}
{{- include "api.fullname" . | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Service name - uses fullname with -service suffix */}}
{{- define "api.service.name" -}}
{{- printf "%s-service" (include "api.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
```

**Naming Pattern**:

| Resource       | Helper                    | Pattern                            | Example (release=payment, chart=api) |
| -------------- | ------------------------- | ---------------------------------- | ------------------------------------ |
| Deployment     | `api.deployment.name`     | `{release}-{chart}`                | `payment-api`                        |
| Service        | `api.service.name`        | `{release}-{chart}-service`        | `payment-api-service`                |
| ServiceAccount | `api.serviceaccount.name` | `{release}-{chart}-serviceaccount` | `payment-api-serviceaccount`         |
| HPA            | `api.hpa.name`            | `{release}-{chart}-hpa`            | `payment-api-hpa`                    |
| VirtualService | `api.virtualservice.name` | `{release}-{chart}-virtualservice` | `payment-api-virtualservice`         |

### 2. Labels and Selectors

**Approach**: Kubernetes standard `app.kubernetes.io/*` labels with minimal selectors for proper resource grouping and canary deployment support.

**Rationale**:

- **Standards Compliant**: Uses recommended Kubernetes labels
- **Tool Compatible**: Works with Helm, ArgoCD, kubectl, Kustomize, Istio
- **Minimal Selectors**: Only 3 labels for pod selection (best practice)
- **Canary Ready**: Version label enables traffic splitting between versions
- **Clear Separation**: Common labels (metadata) vs selector labels (pod selection)

**Implementation**:

```go-template
{{/* Common labels - for metadata only */}}
{{- define "api.labels" -}}
helm.sh/chart: {{ include "api.chart" . }}
app.kubernetes.io/name: {{ include "api.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Selector labels - for pod selection and canary deployments */}}
{{- define "api.selectorLabels" -}}
app.kubernetes.io/name: {{ include "api.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end }}
```

**Label Types**:

**Common Labels** (metadata only - NOT for selection):

- `helm.sh/chart`: Chart name and version
- `app.kubernetes.io/name`: Application name (from `api.fullname`)
- `app.kubernetes.io/instance`: Release name
- `app.kubernetes.io/version`: App version (from Chart.AppVersion)
- `app.kubernetes.io/managed-by`: Helm

**Selector Labels** (for pod selection - minimal and immutable):

- `app.kubernetes.io/name`: Application name (from `api.fullname`)
- `app.kubernetes.io/instance`: Release name
- `app.kubernetes.io/version`: Version (from `Chart.AppVersion`) - **Required for canary deployments**

**Resource Discovery**:

| Resource      | How it finds/uses other resources                                                                    |
| ------------- | ---------------------------------------------------------------------------------------------------- |
| Service       | Finds pods via `app.kubernetes.io/name` + `app.kubernetes.io/instance` + `app.kubernetes.io/version` |
| HPA           | Scales Deployment via `spec.scaleTargetRef.name`                                                     |
| Deployment    | Uses ServiceAccount via `spec.template.spec.serviceAccountName`                                      |
| All Resources | Share common metadata labels for grouping and filtering                                              |

**Canary Deployment Support**:

The `app.kubernetes.io/version` label in selectors enables canary deployment strategies:

```yaml
# Chart.yaml (v1)
appVersion: "v1"

# Chart.yaml (v2)
appVersion: "v2"

# Deploy v1
helm install payment-v1 ./chart-v1

# Deploy v2 alongside v1
helm install payment-v2 ./chart-v2

# Service routes to both versions based on selector
# Istio VirtualService can split traffic between v1 and v2
```

**Benefits**:

- Deploy multiple versions simultaneously
- Service can route to specific versions using label selectors
- Istio VirtualService can split traffic between versions
- Gradual rollout by adjusting replica counts per version

### 3. Environment-Specific Values Pattern

**Approach**: Base `values.yaml` contains sensible defaults; environment-specific files (`values.dev.yaml`, `values.stage.yaml`, `values.prod.yaml`) only override necessary attributes.

**Rationale**:

- Reduces duplication (~40% reduction in file size)
- Single source of truth for common configuration
- Clear visibility of environment differences
- Leverages Helm's native value merging

**Usage**:

```bash
# Development
helm install my-service . -f values.dev.yaml

# Production
helm install my-service . -f values.prod.yaml
```

### 4. ContainerPort Fallback Pattern

**Approach**: Introduced top-level `containerPort` field that serves as a fallback when specific port properties are not defined.

**Rationale**:

- Provides flexibility: each section can override its port if needed
- Sensible default: `containerPort` used when specific ports are unset
- Single override point: change `containerPort` to affect all unset ports
- Explicit control: specific ports (e.g., `service.targetPort`) take precedence

**Implementation**:

```yaml
# values.yaml
containerPort: 3000

service:
  # containerPort override - falls back to containerPort if not specified
  targetPort: 3000

healthCheck:
  livenessProbe:
    httpGet:
      # containerPort override - falls back to containerPort if not specified
      port: 3000
```

**Template Logic**:

```yaml
# Uses targetPort if set, otherwise falls back to containerPort
targetPort: { { default .Values.containerPort .Values.service.targetPort } }
```

### 5. Environment-Based Domain Configuration

**Approach**: Explicit `environment` field with automatic domain construction and `domainOverride` for local testing.

**Rationale**:

- Automatic domain construction: Domain is auto-constructed as `{environment}.local`
- Single source of truth: `environment` field drives domain construction
- Quick local testing: `domainOverride` allows developers to bypass environment-based construction
- Flexible: Can still explicitly set `domain` when needed

**Implementation**:

```yaml
# values.yaml
environment: dev # Identifies deployment environment

virtualService:
  domain: "" # Empty = auto-construct as {environment}.local
  domainOverride: "" # Quick override for local testing
```

**Precedence** (highest to lowest):

1. `domainOverride` - Quick override for local testing
2. `domain` - Explicit domain setting
3. Auto-construction - `{environment}.local`

**Usage Examples**:

```bash
# Auto-construction (uses dev.local)
helm install my-service . -f values.dev.yaml

# Local testing override
helm install my-service . --set virtualService.domainOverride=api.local

# Explicit domain
helm install my-service . --set virtualService.domain=api.example.com
```

### 6. Schema Validation

**Approach**: `values.schema.json` validates required fields and value ranges.

**Rationale**:

- Catches configuration errors early (before deployment)
- Documents expected value types and constraints
- Ensures `containerPort` is always defined and valid (1-65535)

### 6. Flexible Affinity System

**Approach**: Default affinity templates with enable/override flags for production-ready pod spreading across nodes and availability zones.

**Rationale**:

- **High Availability**: Protects against hardware failures (node spreading) and datacenter outages (zone spreading)
- **Production-Ready Defaults**: Pre-configured affinity rules following Kubernetes best practices
- **Flexibility**: Enable/disable node and zone affinity independently with override capability
- **Zero Configuration**: Works out-of-the-box for production with sensible defaults
- **Dynamic Label Matching**: Automatically matches pods based on release, chart, and version

**Implementation**:

#### Default Affinity Templates

Two helper templates provide production-ready affinity rules:

```go-template
{{/* Node Affinity - spreads pods across nodes (weight 100) */}}
{{- define "api.nodeAffinity" -}}
- weight: 100
  podAffinityTerm:
    labelSelector:
      matchExpressions:
        - key: app.kubernetes.io/name
          operator: In
          values:
            - {{ include "api.fullname" . }}
    topologyKey: kubernetes.io/hostname
{{- end }}

{{/* Zone Affinity - spreads pods across zones (weight 50) */}}
{{- define "api.zoneAffinity" -}}
- weight: 50
  podAffinityTerm:
    labelSelector:
      matchExpressions:
        - key: app.kubernetes.io/name
          operator: In
          values:
            - {{ include "api.fullname" . }}
    topologyKey: topology.kubernetes.io/zone
{{- end }}
```

#### Configuration Flags

```yaml
# Node affinity configuration
nodeAffinityEnabled: false # Enable node spreading
nodeAffinityOverride: false # Use custom nodeAffinity instead of default
nodeAffinity: {} # Custom node affinity rules

# Zone affinity configuration
zoneAffinityEnabled: false # Enable zone spreading
zoneAffinityOverride: false # Use custom zoneAffinity instead of default
zoneAffinity: {} # Custom zone affinity rules

# Legacy affinity block (used when flags are disabled)
affinity: {}
```

#### Deployment Logic

The deployment template uses conditional logic to merge affinity rules:

```yaml
{{- if or .Values.nodeAffinityEnabled .Values.zoneAffinityEnabled }}
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    {{- if .Values.nodeAffinityEnabled }}
      {{- if .Values.nodeAffinityOverride }}
      {{- toYaml .Values.nodeAffinity.podAntiAffinity.preferredDuringScheduling... }}
      {{- else }}
      {{- include "api.nodeAffinity" . }}
      {{- end }}
    {{- end }}
    {{- if .Values.zoneAffinityEnabled }}
      {{- if .Values.zoneAffinityOverride }}
      {{- toYaml .Values.zoneAffinity.podAntiAffinity.preferredDuringScheduling... }}
      {{- else }}
      {{- include "api.zoneAffinity" . }}
      {{- end }}
    {{- end }}
{{- else }}
{{- with .Values.affinity }}
affinity:
  {{- toYaml . }}
{{- end }}
{{- end }}
```

**Behavior**:

| Scenario             | nodeAffinityEnabled | zoneAffinityEnabled | Result                                  |
| -------------------- | ------------------- | ------------------- | --------------------------------------- |
| Development          | `false`             | `false`             | No affinity rules (single node OK)      |
| Node spreading only  | `true`              | `false`             | Pods spread across nodes                |
| Zone spreading only  | `false`             | `true`              | Pods spread across zones                |
| Full HA (production) | `true`              | `true`              | Pods spread across both nodes AND zones |

**Weight Priority**:

- **Node weight: 100** (higher priority) - Node failures are more common
- **Zone weight: 50** (lower priority) - Zone failures are rare but catastrophic

This ensures the scheduler prioritizes node spreading for day-to-day resilience while still benefiting from zone spreading when possible.

**Soft vs Hard Rules**:

Default templates use `preferredDuringScheduling...` (soft rules):

- **Advantage**: Pods can still schedule when ideal spreading isn't possible
- **Use case**: Limited nodes, development environments, resource constraints
- **Override**: Use `requiredDuringScheduling...` in custom affinity for strict guarantees

**Production Example** (values.prod.yaml):

```yaml
# Enable both node and zone affinity with custom overrides
nodeAffinityEnabled: true
nodeAffinityOverride: true
nodeAffinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app.kubernetes.io/name
                operator: In
                values:
                  - payment-api-v1
          topologyKey: kubernetes.io/hostname

zoneAffinityEnabled: true
zoneAffinityOverride: false # Use default template
```

**Result**: Pods spread across nodes (custom rule) AND zones (default template).

**Benefits**:

1. **Hardware Resilience**: Node spreading protects against server failures
2. **Datacenter Resilience**: Zone spreading protects against entire AZ outages
3. **Automatic Merging**: Both rules combine into single affinity block
4. **Canary Support**: Version label ensures affinity only affects same version
5. **Zero Config**: Production defaults work out-of-the-box

## Configuration

### Key Configuration Sections

#### Container Port

```yaml
# Centralized port configuration
containerPort: 3000
```

#### Image Configuration

```yaml
image:
  repository: "service-name"
  pullPolicy: IfNotPresent
  tag: "latest"
```

#### Environment Variables

```yaml
env:
  PORT: "3000"
  SERVICE_NAME: "service-name"
  NODE_ENV: "development"
  LOG_LEVEL: "info"
```

#### Resources

```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"
```

#### Health Checks

```yaml
healthCheck:
  livenessProbe:
    httpGet:
      path: /health
      port: 3000
    initialDelaySeconds: 10
    periodSeconds: 10
  readinessProbe:
    httpGet:
      path: /ready
      port: 3000
    initialDelaySeconds: 5
    periodSeconds: 5
```

#### Autoscaling

```yaml
autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 3
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80
```

#### Affinity (High Availability)

```yaml
# Use default templates (recommended for production)
nodeAffinityEnabled: true
nodeAffinityOverride: false  # Use default template

zoneAffinityEnabled: true
zoneAffinityOverride: false  # Use default template

# Or use custom affinity rules
nodeAffinityEnabled: true
nodeAffinityOverride: true
nodeAffinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app.kubernetes.io/name
                operator: In
                values:
                  - my-api-v1
          topologyKey: kubernetes.io/hostname
```

## Usage Examples

### Override Port Configuration

```bash
# Override containerPort (affects all unset ports)
helm install my-service . --set containerPort=8080

# Override specific port (takes precedence over containerPort)
helm install my-service . --set service.targetPort=9000
```

### Domain Configuration

```bash
# Auto-construction based on environment (default behavior)
helm install my-service . -f values.dev.yaml  # Uses dev.local
helm install my-service . -f values.prod.yaml  # Uses prod.local

# Quick local testing with domainOverride
helm install my-service . \
  -f values.dev.yaml \
  --set virtualService.domainOverride=api.local

# Explicit domain override
helm install my-service . --set virtualService.domain=api.example.com
```

### Canary Deployment

For canary deployments, you need to maintain separate chart directories with different `appVersion` values:

```bash
# Create chart directories for each version
cp -r . ../payment-v1
cp -r . ../payment-v2

# Update Chart.yaml in each directory
# payment-v1/Chart.yaml: appVersion: "v1"
# payment-v2/Chart.yaml: appVersion: "v2"

# Deploy v1
helm install payment-v1 ../payment-v1 --set image.tag=1.0.0

# Deploy v2 alongside v1
helm install payment-v2 ../payment-v2 --set image.tag=2.0.0

# Both versions run simultaneously with different app.kubernetes.io/version labels
# Configure Istio VirtualService to split traffic between v1 and v2
```

### High Availability with Affinity

#### Use Default Templates (Recommended)

```bash
# Production with both node and zone spreading
helm install my-service . -f values.prod.yaml \
  --set nodeAffinityEnabled=true \
  --set nodeAffinityOverride=false \
  --set zoneAffinityEnabled=true \
  --set zoneAffinityOverride=false

# Node spreading only (single-zone cluster)
helm install my-service . \
  --set nodeAffinityEnabled=true \
  --set zoneAffinityEnabled=false
```

#### Custom Affinity with Hard Requirements

```bash
# Strict node spreading (pods MUST be on different nodes)
helm install my-service . \
  --set nodeAffinityEnabled=true \
  --set nodeAffinityOverride=true \
  --set-json 'nodeAffinity={"podAntiAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":[{"labelSelector":{"matchExpressions":[{"key":"app.kubernetes.io/name","operator":"In","values":["my-api-v1"]}]},"topologyKey":"kubernetes.io/hostname"}]}}'
```

#### Mixed: Custom Node + Default Zone

```yaml
# values.prod.yaml
nodeAffinityEnabled: true
nodeAffinityOverride: true
nodeAffinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution: # Hard requirement
      - labelSelector:
          matchExpressions:
            - key: app.kubernetes.io/name
              operator: In
              values:
                - payment-api-v1
        topologyKey: kubernetes.io/hostname

zoneAffinityEnabled: true
zoneAffinityOverride: false # Use default template
```

```bash
helm install payment . -f values.prod.yaml
```

### Environment-Specific Deployment

```yaml
# values.dev.yaml
replicaCount: 1
image:
  tag: "dev-latest"
  pullPolicy: Always
env:
  LOG_LEVEL: "debug"
autoscaling:
  enabled: false
```

```bash
helm install my-service . -f values.dev.yaml
```

### Multiple Value Overrides

```bash
helm install my-service . \
  --set image.tag=v2.0.0 \
  --set replicaCount=5 \
  --set env.LOG_LEVEL=error
```

### Dry Run and Template Preview

```bash
# Dry run to see what would be deployed
helm install my-service . --dry-run --debug

# Render templates to files
helm template my-service . --output-dir ./rendered

# Render with specific environment
helm template my-service . -f values.prod.yaml --output-dir ./rendered
```

### Linting

```bash
# Lint the chart
helm lint .

# Lint with specific values
helm lint . -f values.prod.yaml
```

### Upgrading

```bash
# Upgrade existing release
helm upgrade my-service . -f values.prod.yaml

# Upgrade with new image tag
helm upgrade my-service . --set image.tag=v2.1.0
```

### Packaging

```bash
# Package the chart
helm package . --version 1.0.0 --app-version 1.0.0

# Package and update dependencies
helm package . -u --version 1.0.0
```

## Best Practices

### 1. Port Configuration

- **Use `containerPort` as default**: Set `containerPort` to your service's default port
- **Override when needed**: Use `service.targetPort` for service-specific ports
- **Keep in sync**: Ensure `env.PORT` matches your actual container port

### 2. Version Management

- **Use Chart.AppVersion**: Set `appVersion` in `Chart.yaml` (e.g., `v1`, `v2`, `v1.0.0`)
- **Canary deployments**: Maintain separate chart directories with different `appVersion` values
- **Traffic splitting**: Use Istio VirtualService to gradually shift traffic between versions
- **Immutable versions**: Once deployed, don't change `appVersion` for a running release

### 3. Environment Variables

- **Minimize overrides**: Only override `LOG_LEVEL` and `NODE_ENV` in env-specific files
- **Keep common values in base**: `PORT` and `SERVICE_NAME` should stay in `values.yaml`

### 4. Resource Limits

- **Start conservative**: Use base values for dev, increase for prod
- **Monitor and adjust**: Use metrics to tune resource requests/limits
- **Set both requests and limits**: Ensures predictable scheduling and prevents resource starvation

### 5. Health Checks

- **Use appropriate delays**: Give services time to start before first probe
- **Separate endpoints**: Use `/health` for liveness, `/ready` for readiness
- **Conservative in prod**: Longer delays and more retries in production

### 6. Autoscaling

- **Disable in dev/stage**: Use fixed replicas for testing environments
- **Enable in prod**: Use HPA for production workloads
- **Set appropriate thresholds**: 70-80% CPU/memory utilization is typical

### 7. Values File Organization

```
my-service/
├── values.yaml           # Base configuration
├── values.dev.yaml       # Dev overrides only
├── values.stage.yaml     # Stage overrides only
└── values.prod.yaml      # Prod overrides only
```

### 8. Naming Conventions

- **Release names**: Use descriptive names (e.g., `payment`, `user-auth`)
- **Chart name**: Keep as `api` for consistency
- **Result**: Resources named `{release}-api-{suffix}` (e.g., `payment-api-service`)

### 9. Affinity Configuration

- **Use defaults in production**: Enable both node and zone affinity with `nodeAffinityOverride=false` and `zoneAffinityOverride=false`
- **Disable in development**: Set `nodeAffinityEnabled=false` and `zoneAffinityEnabled=false` for single-node environments
- **Soft rules for flexibility**: Default templates use `preferredDuringScheduling...` to allow scheduling when spreading isn't possible
- **Hard rules for guarantees**: Override with `requiredDuringScheduling...` when strict spreading is mandatory
- **Weight priority**: Node spreading (weight 100) takes priority over zone spreading (weight 50)
- **Label matching**: Default templates use `app.kubernetes.io/name` which includes release, chart, and version
- **Test before production**: Verify affinity rules with `helm template` before deploying
- **Multi-zone clusters**: Enable zone affinity only if your cluster spans multiple availability zones

## Troubleshooting

### Schema Validation Errors

```bash
# Error: containerPort is required
# Solution: Ensure containerPort is set in values.yaml or via --set
helm install my-service . --set containerPort=3000
```

### Port Mismatch Issues

```bash
# Check rendered port values
helm template my-service . | grep -E "port:|targetPort:|containerPort:"
```

### Label Selector Issues

```bash
# Check labels and selectors
helm template my-service . | grep -A5 "selector:"
helm template my-service . | grep -A10 "labels:"
```

### Template Rendering Issues

```bash
# Debug template rendering
helm install my-service . --dry-run --debug

# Check specific template
helm template my-service . -s templates/deployment.yaml
```

### Values Not Applying

```bash
# Verify value precedence (rightmost wins)
helm install my-service . \
  -f values.yaml \
  -f values.prod.yaml \
  --set image.tag=override
```

### Canary Deployment Issues

```bash
# Check version labels
helm template my-service . --set version=v1 | grep "app.kubernetes.io/version"

# Verify both versions are running
kubectl get pods -l app.kubernetes.io/name=payment-api --show-labels
```

### Affinity Issues

```bash
# Check if affinity is applied
helm template my-service . -f values.prod.yaml | grep -A30 "affinity:"

# Verify pods are spread across nodes
kubectl get pods -o wide -l app.kubernetes.io/name=payment-api

# Check node labels for zone information
kubectl get nodes --show-labels | grep topology.kubernetes.io/zone

# Debug pod scheduling
kubectl describe pod <pod-name> | grep -A10 "Events:"

# Check if pods are pending due to affinity constraints
kubectl get pods | grep Pending
kubectl describe pod <pending-pod> | grep -A5 "Warning"
```

**Common Issues**:

1. **Pods stuck in Pending**: Affinity rules too strict (use `preferredDuringScheduling...` instead of `required...`)
2. **All pods on same node**: Zone labels missing or affinity disabled
3. **Affinity not applied**: Check `nodeAffinityEnabled` and `zoneAffinityEnabled` flags
4. **Wrong label matching**: Verify `app.kubernetes.io/name` matches `api.fullname` output

## Contributing

When modifying this chart:

1. Update `values.schema.json` for new required fields
2. Add comments explaining fallback behavior for port-related fields
3. Test with all environment files (`dev`, `stage`, `prod`)
4. Run `helm lint` before committing
5. Update this README with new features or changes
6. Ensure all helper names use `api.*` prefix
7. Follow Kubernetes labeling best practices
8. Test affinity rules with `helm template` and verify pod distribution

## References

- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [Kubernetes Recommended Labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/)
- [Kubernetes Pod Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity)
- [Istio VirtualService](https://istio.io/latest/docs/reference/config/networking/virtual-service/)
