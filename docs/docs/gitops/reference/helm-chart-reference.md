# Helm Chart Reference

## Overview

Complete reference for the base API Helm chart in `sf-helm-charts`.

**Repository**: https://github.com/ashutosh-18k92/sf-helm-charts.git

## Chart Structure

```
api/
├── Chart.yaml              # Chart metadata
├── values.yaml             # Default values
├── values.dev.yaml         # Development defaults
├── values.stage.yaml       # Staging defaults
├── values.prod.yaml        # Production defaults
├── values.schema.json      # Values validation
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

## Identity System

The chart uses a clear separation between **business service identity** and **Kubernetes deployment identity**.

### Business Identity (`app.*`)

Defines what the service IS:

```yaml
app:
  name: aggregator-service # Business service name
  component: api # Component type: api | worker | consumer
  partOf: superfortnight # Optional: parent application/system
```

### Deployment Identity

- **Resource names**: Use `.Release.Name` (e.g., `aggregator-dev`, `aggregator-prod`)
- **Instance label**: `app.kubernetes.io/instance: {{ .Release.Name }}`

### Label Structure

**Common Labels** (metadata only):

```yaml
helm.sh/chart: api-0.1.7
app.kubernetes.io/name: aggregator-service # Business identity
app.kubernetes.io/component: api # Component type
app.kubernetes.io/instance: aggregator-dev # Deployment identity
app.kubernetes.io/version: v1 # Version for canary
app.kubernetes.io/managed-by: Helm
app.kubernetes.io/part-of: superfortnight # Optional
```

**Selector Labels** (for pod selection - stable and minimal):

```yaml
app.kubernetes.io/name: aggregator-service
app.kubernetes.io/component: api
app.kubernetes.io/instance: aggregator-dev
app.kubernetes.io/version: v1
```

## Values Reference

### Business Identity

```yaml
app:
  name: api # MUST be overridden in overlay values
  component: api # api | worker | consumer
  partOf: "" # Optional: parent application
```

### Image Configuration

```yaml
image:
  repository: "service-name" # Container image repository
  tag: "latest" # Image tag
  pullPolicy: IfNotPresent # Pull policy
```

### Container Configuration

```yaml
containerPort: 3000 # Container port
replicaCount: 1 # Number of replicas (overridden by HPA)
```

### Environment Variables

```yaml
env:
  SERVICE_NAME: "service-name"
  LOG_LEVEL: "info"
  # Add custom environment variables
```

### Health Checks

```yaml
healthCheck:
  livenessProbe:
    httpGet:
      path: /health
      port: 3000
    initialDelaySeconds: 30
    periodSeconds: 10
  readinessProbe:
    httpGet:
      path: /ready
      port: 3000
    initialDelaySeconds: 10
    periodSeconds: 5
```

### Resources

```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"
```

### Horizontal Pod Autoscaler

```yaml
autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80
```

### Istio VirtualService

```yaml
virtualService:
  enabled: true
  namespace: istio-system
  hosts:
    - aggregator
  domain: "api.local"
  gateways:
    - super-fortnight-gateway
  routes:
    - /api
  attempts: 3
  perTryTimeoutSeconds: 2
  retryOn:
    - 5xx
    - reset
    - connect-failure
```

### Service Account

```yaml
serviceAccount:
  create: true
  annotations: {}
  name: "" # Defaults to release name
```

### Affinity Rules

```yaml
# Node affinity (spreads pods across nodes)
nodeAffinityEnabled: false
nodeAffinityOverride: false
nodeAffinity: {}

# Zone affinity (spreads pods across availability zones)
zoneAffinityEnabled: false
zoneAffinityOverride: false
zoneAffinity: {}

# Legacy affinity block
affinity: {}
```

## Template Helpers

### api.name

Returns the release name for resource naming.

```go-template
{{- define "api.name" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
```

### api.fullname

Returns the release name (same as `api.name`).

```go-template
{{- define "api.fullname" -}}
{{- include "api.name" . }}
{{- end }}
```

### api.labels

Standard labels for all resources (metadata only).

```go-template
{{- define "api.labels" -}}
helm.sh/chart: {{ include "api.chart" . }}
app.kubernetes.io/name: {{ .Values.app.name }}
app.kubernetes.io/component: {{ .Values.app.component }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Values.app.partOf }}
app.kubernetes.io/part-of: {{ .Values.app.partOf }}
{{- end }}
{{- end }}
```

### api.selectorLabels

Stable selector labels for pod selection.

```go-template
{{- define "api.selectorLabels" -}}
app.kubernetes.io/name: {{ .Values.app.name }}
app.kubernetes.io/component: {{ .Values.app.component }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end }}
```

## Environment-Specific Values

### Development (values.dev.yaml)

```yaml
app:
  name: aggregator-service
  component: api
  partOf: superfortnight

environment: development
replicaCount: 1

image:
  tag: "dev-latest"
  pullPolicy: Always

env:
  LOG_LEVEL: "debug"

resources:
  requests:
    memory: "64Mi"
    cpu: "50m"

autoscaling:
  enabled: false
```

### Staging (values.stage.yaml)

```yaml
app:
  name: aggregator-service
  component: api
  partOf: superfortnight

environment: staging
replicaCount: 2

image:
  tag: "staging-latest"

env:
  LOG_LEVEL: "info"

resources:
  requests:
    memory: "128Mi"
    cpu: "100m"

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
```

### Production (values.prod.yaml)

```yaml
app:
  name: aggregator-service
  component: api
  partOf: superfortnight

environment: production
replicaCount: 3

image:
  tag: "latest"

env:
  LOG_LEVEL: "error"

resources:
  requests:
    memory: "256Mi"
    cpu: "200m"

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20

# Enable high availability
nodeAffinityEnabled: true
zoneAffinityEnabled: true
```

## Usage Examples

### Minimal Service Values

```yaml
app:
  name: my-service
  component: api

containerPort: 3000

image:
  repository: "my-service"

env:
  SERVICE_NAME: "my-service"

virtualService:
  hosts:
    - my-service

healthCheck:
  livenessProbe:
    httpGet:
      port: 3000
  readinessProbe:
    httpGet:
      port: 3000
```

### Deploying Multiple Instances

```bash
# Deploy development instance
helm install my-service-dev ./charts/api \
  -f my-service/deploy/overlays/development/values.yaml

# Deploy staging instance of same service
helm install my-service-staging ./charts/api \
  -f my-service/deploy/overlays/staging/values.yaml

# Both deployments:
# - Have SAME app.name: "my-service" (business identity)
# - Have DIFFERENT instance: "my-service-dev" vs "my-service-staging"
# - Can coexist in same or different namespaces
```

### With Custom Resources

```yaml
app:
  name: my-service
  component: api

containerPort: 8080

image:
  repository: "my-service"

resources:
  requests:
    memory: "512Mi"
    cpu: "500m"
  limits:
    memory: "1Gi"
    cpu: "1000m"
```

### With Custom HPA

```yaml
app:
  name: my-service
  component: api

containerPort: 3000

image:
  repository: "my-service"

autoscaling:
  enabled: true
  minReplicas: 5
  maxReplicas: 50
  targetCPUUtilizationPercentage: 70
```

### High Availability Setup

```yaml
app:
  name: my-service
  component: api

# Enable pod spreading across nodes and zones
nodeAffinityEnabled: true
zoneAffinityEnabled: true

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
```

## Benefits of the Identity System

✅ **Stable Selectors**: Labels based on `app.name` and `app.component` don't change accidentally  
✅ **Clear Separation**: Business identity (`app.*`) vs deployment identity (`.Release.Name`)  
✅ **Multiple Releases**: Can deploy same service with different release names  
✅ **ArgoCD Friendly**: Application name = release name  
✅ **Chart Independent**: Not tied to `.Chart.Name`  
✅ **Semantic**: `app.name` = what it is, `.Release.Name` = this specific deployment

## Related Documentation

- [Platform Team Guide](../guides/platform-team-guide.md)
- [Feature Team Guide](../guides/feature-team-guide.md)
- [Adding New Service](../guides/adding-new-service.md)
- [Kustomize Patterns](./kustomize-patterns.md)
