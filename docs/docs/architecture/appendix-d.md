# Appendix D: Configuration Examples

### D.1 Complete Environment Overlay Example

**Development overlay structure:**

```
deploy/overlays/development/
├── kustomization.yaml
├── values.yaml
└── patches/
    ├── deployment.yaml
    ├── configmap.yaml
    └── virtualservice.yaml
```

**kustomization.yaml:**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

helmCharts:
  - name: aggregator
    repo: https://ashutosh-18k92.github.io/aggregator-service/
    version: v0.2.4
    releaseName: aggregator
    namespace: super-fortnight-dev
    valuesFile: values.yaml
    includeCRDs: false

configMapGenerator:
  - name: service-config
    namespace: super-fortnight-dev
    literals:
      - PORT=3000
      - SERVICE_NAME=aggregator-service
      - LOG_LEVEL=debug
      - NODE_ENV=development
    options:
      disableNameSuffixHash: true

patches:
  - target:
      kind: Deployment
      name: aggregator-api-v1
    path: patches/deployment.yaml
  - target:
      kind: VirtualService
      name: aggregator-api-v1-virtualservice
    path: patches/virtualservice.yaml
```

**values.yaml:**

```yaml
app:
  name: aggregator-service
  component: api
  partOf: superfortnight

environment: development

image:
  repository: aggregator-service
  tag: "dev-latest"
  pullPolicy: Always

resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"

autoscaling:
  enabled: false

replicas: 1

virtualService:
  hosts:
    - aggregator-dev.local
```

**patches/deployment.yaml:**

```yaml
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
            - name: DEBUG
              value: "true"
            - name: ENABLE_HOT_RELOAD
              value: "true"
```

### D.2 Production Overlay Example

**Production overlay structure:**

```
deploy/overlays/production/
├── kustomization.yaml
├── values.yaml
└── patches/
    ├── deployment-affinity.yaml
    ├── hpa-scaling.yaml
    └── production-resources.yaml
```

**kustomization.yaml:**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

helmCharts:
  - name: aggregator
    repo: https://ashutosh-18k92.github.io/aggregator-service/
    version: v0.2.3
    releaseName: aggregator
    namespace: super-fortnight
    valuesFile: values.yaml
    includeCRDs: false

configMapGenerator:
  - name: service-config
    namespace: super-fortnight
    literals:
      - PORT=3000
      - SERVICE_NAME=aggregator-service
      - LOG_LEVEL=error
      - NODE_ENV=production

patches:
  - path: patches/deployment-affinity.yaml
  - path: patches/hpa-scaling.yaml
  - path: patches/production-resources.yaml
```

**values.yaml:**

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
  targetMemoryUtilizationPercentage: 80

virtualService:
  hosts:
    - aggregator.example.com
  retries:
    attempts: 3
    perTryTimeout: 2s
```

**patches/deployment-affinity.yaml:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aggregator-api-v1
spec:
  template:
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchExpressions:
                    - key: app
                      operator: In
                      values:
                        - aggregator
                topologyKey: kubernetes.io/hostname
            - weight: 50
              podAffinityTerm:
                labelSelector:
                  matchExpressions:
                    - key: app
                      operator: In
                      values:
                        - aggregator
                topologyKey: topology.kubernetes.io/zone
```

**patches/hpa-scaling.yaml:**

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: aggregator-api-v1-hpa
spec:
  minReplicas: 3
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 50
          periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
        - type: Percent
          value: 100
          periodSeconds: 30
```

### D.3 Environment Metadata Files

**deploy/environments/development.yaml:**

```yaml
env: development
namespace: super-fortnight-dev
targetRevision: main
```

**deploy/environments/staging.yaml:**

```yaml
env: staging
namespace: super-fortnight-staging
targetRevision: main
```

**deploy/environments/production.yaml:**

```yaml
env: production
namespace: super-fortnight
targetRevision: main
```

