# Appendix F: Complete Dependencies Example

### Full Working Order Service Aggregate

This appendix provides a complete, deployable example demonstrating the dependencies pattern with DDD alignment.

**Directory Structure:**
```
order-service/
├── src/
│   └── index.js
├── charts/
│   └── order-service/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── values.dev.yaml
│       ├── values.prod.yaml
│       ├── charts/  # Downloaded dependencies
│       │   ├── postgresql-12.1.9.tgz
│       │   ├── mongodb-13.6.0.tgz
│       │   ├── redis-17.3.7.tgz
│       │   └── kafka-26.4.0.tgz
│       └── templates/
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── migration-job.yaml
│           ├── projection-service.yaml
│           └── saga-coordinator.yaml
└── Dockerfile
```

**Complete Chart.yaml:**
```yaml
apiVersion: v2
name: order-service
description: |
  E-commerce order processing service implementing Event Sourcing and CQRS.
  This chart composes multiple infrastructure components into a cohesive
  domain aggregate following Domain-Driven Design principles.
type: application
version: 2.0.0
appVersion: "2.0.0"

maintainers:
  - name: E-commerce Team
    email: ecommerce@example.com

keywords:
  - orders
  - event-sourcing
  - cqrs
  - saga

dependencies:
  # Event Store (Write Side - Event Sourcing)
  - name: postgresql
    version: "12.1.9"
    repository: "https://charts.bitnami.com/bitnami"
    alias: eventStore
    condition: eventStore.enabled
    tags:
      - persistence
      - write-side
  
  # Read Model (Read Side - CQRS Projections)
  - name: mongodb
    version: "13.6.0"
    repository: "https://charts.bitnami.com/bitnami"
    alias: readModel
    condition: readModel.enabled
    tags:
      - persistence
      - read-side
  
  # Saga State Store (Distributed Transaction Coordination)
  - name: redis
    version: "17.3.7"
    repository: "https://charts.bitnami.com/bitnami"
    alias: sagaStore
    condition: sagaStore.enabled
    tags:
      - coordination
  
  # Event Bus (Domain Events Publication)
  - name: kafka
    version: "26.4.0"
    repository: "https://charts.bitnami.com/bitnami"
    alias: eventBus
    condition: eventBus.enabled
    tags:
      - messaging
```

**Complete values.yaml with DDD annotations:**
```yaml
# Global configuration (accessible to all dependencies)
global:
  namespace: ecommerce
  environment: production
  domain: orders  # Bounded context identifier

# ============================================================
# AGGREGATE ROOT: Order Service Application
# ============================================================
application:
  name: order-service
  
  image:
    repository: order-service
    tag: "v2.0.0"
    pullPolicy: IfNotPresent
  
  replicas: 3
  
  # ---- Domain Configuration ----
  # These values express domain concepts and business rules
  domain:
    # Aggregate boundaries
    aggregateTimeout: "30m"  # How long an order aggregate stays in memory
    
    # Business rules
    orderExpirationMinutes: 60  # Orders expire after 1 hour without payment
    inventoryReservationMinutes: 15  # How long inventory is held
    
    # Sagas (distributed transactions)
    sagas:
      payment:
        timeout: "5m"
        retries: 3
      inventory:
        timeout: "10m"
        retries: 2
      shipping:
        timeout: "15m"
        retries: 1
    
    # Event Sourcing configuration
    eventSourcing:
      snapshotFrequency: 100  # Create snapshot every 100 events
      replayBatchSize: 1000
    
    # CQRS configuration
    cqrs:
      projectionDelay: "1s"  # Eventual consistency window
      projections:
        - order-list
        - order-details
        - order-analytics
  
  # ---- Technical Translation ----
  # Domain concepts translated to infrastructure connections
  env:
    # Application identity
    SERVICE_NAME: "order-service"
    BOUNDED_CONTEXT: "orders"
    
    # Event Store connection (Write Side)
    EVENT_STORE_URL: "postgresql://{{ .Release.Name }}-eventStore:5432/events"
    EVENT_STORE_USER: "order_writer"
    EVENT_STORE_PASSWORD: "{{ .Values.eventStore.auth.password }}"
    
    # Read Model connection (Read Side)
    READ_MODEL_URL: "mongodb://{{ .Release.Name }}-readModel:27017/orders"
    READ_MODEL_USER: "order_reader"
    
    # Saga Store connection (Coordination)
    SAGA_STORE_URL: "redis://{{ .Release.Name }}-sagaStore-master:6379/0"
    
    # Event Bus connection (Domain Events)
    EVENT_BUS_BROKERS: "{{ .Release.Name }}-eventBus:9092"
    EVENT_BUS_TOPIC: "domain.orders"
    
    # Domain configuration as environment variables
    ORDER_TIMEOUT: "{{ .Values.application.domain.aggregateTimeout }}"
    SNAPSHOT_FREQUENCY: "{{ .Values.application.domain.eventSourcing.snapshotFrequency }}"
    PROJECTION_DELAY: "{{ .Values.application.domain.cqrs.projectionDelay }}"
  
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

# ============================================================
# BOUNDED CONTEXT: Event Store (Write Side)
# ============================================================
# PostgreSQL configured for Event Sourcing patterns
eventStore:
  enabled: true
  
  # Database authentication
  auth:
    username: order_writer
    password: "changeme-event-store"  # Use secrets management
    database: events
  
  # Primary instance configuration
  primary:
    # Event streams are append-only, need significant storage
    persistence:
      enabled: true
      storageClass: "fast-ssd"  # Low latency critical for writes
      size: 100Gi  # Size based on event volume
    
    # Resource allocation
    resources:
      requests:
        memory: "2Gi"
        cpu: "1000m"
      limits:
        memory: "4Gi"
        cpu: "2000m"
    
    # PostgreSQL tuning for event sourcing
    extraEnvVars:
      - name: POSTGRESQL_SHARED_BUFFERS
        value: "1GB"
      - name: POSTGRESQL_EFFECTIVE_CACHE_SIZE
        value: "3GB"
      - name: POSTGRESQL_MAINTENANCE_WORK_MEM
        value: "256MB"
      - name: POSTGRESQL_WAL_BUFFERS
        value: "16MB"
  
  # Backup configuration for event store
  backup:
    enabled: true
    schedule: "0 2 * * *"  # Daily at 2 AM
    retention: 30  # Keep 30 days

# ============================================================
# BOUNDED CONTEXT: Read Model (Read Side)
# ============================================================
# MongoDB configured for CQRS projections
readModel:
  enabled: true
  
  # Authentication
  auth:
    enabled: true
    rootPassword: "changeme-read-model"
    usernames:
      - order_reader
    passwords:
      - "changeme-reader"
    databases:
      - orders
  
  # Architecture
  architecture: replicaset
  replicaCount: 3  # Read replicas for query scaling
  
  # Persistence for projections
  persistence:
    enabled: true
    storageClass: "standard"  # Reads tolerate higher latency
    size: 50Gi
  
  # Resource allocation
  resources:
    requests:
      memory: "1Gi"
      cpu: "500m"
    limits:
      memory: "2Gi"
      cpu: "1000m"
  
  # MongoDB configuration for read-heavy workload
  configuration: |
    storage:
      wiredTiger:
        engineConfig:
          cacheSizeGB: 1
        collectionConfig:
          blockCompressor: snappy
    operationProfiling:
      mode: slowOp
      slowOpThresholdMs: 100

# ============================================================
# BOUNDED CONTEXT: Saga Store (Coordination)
# ============================================================
# Redis configured for saga state management
sagaStore:
  enabled: true
  
  # Architecture
  architecture: standalone  # Can upgrade to replication for HA
  
  # Authentication
  auth:
    enabled: true
    password: "changeme-saga-store"
  
  # Saga state must survive restarts
  master:
    persistence:
      enabled: true
      storageClass: "fast-ssd"
      size: 10Gi  # Saga state is compact
    
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
      limits:
        memory: "512Mi"
        cpu: "200m"
    
    # Redis configuration for saga coordination
    configuration: |
      maxmemory-policy allkeys-lru
      save 900 1
      save 300 10
      save 60 10000

# ============================================================
# BOUNDED CONTEXT: Event Bus (Domain Events)
# ============================================================
# Kafka configured for domain event publication
eventBus:
  enabled: true
  
  # Cluster configuration
  replicaCount: 3  # High availability
  
  # Persistence for event log
  persistence:
    enabled: true
    storageClass: "fast-ssd"
    size: 200Gi  # Event log retention
  
  # Resource allocation
  resources:
    requests:
      memory: "2Gi"
      cpu: "1000m"
    limits:
      memory: "4Gi"
      cpu: "2000m"
  
  # Kafka broker configuration
  config: |
    log.retention.hours=168
    log.segment.bytes=1073741824
    log.retention.check.interval.ms=300000
    num.partitions=10
    default.replication.factor=3
    min.insync.replicas=2
    compression.type=snappy
  
  # Zookeeper (required for Kafka)
  zookeeper:
    enabled: true
    replicaCount: 3
    persistence:
      enabled: true
      size: 10Gi

# ============================================================
# SERVICE-SPECIFIC RESOURCES
# ============================================================
# These are managed in the service chart templates, not dependencies

# Projection Service (reads events, updates read model)
projectionService:
  enabled: true
  replicas: 2
  resources:
    requests:
      memory: "256Mi"
      cpu: "100m"

# Saga Coordinator (manages distributed transactions)
sagaCoordinator:
  enabled: true
  replicas: 2
  resources:
    requests:
      memory: "256Mi"
      cpu: "100m"

# Monitoring
monitoring:
  enabled: true
  serviceMonitor:
    enabled: true
    interval: 30s

# Migrations
migrations:
  enabled: true
  hookWeight: "-5"  # Run before main deployment
```

**Deploy and verify:**
```bash
# Update dependencies
cd charts/order-service
helm dependency update

# Verify dependencies downloaded
ls charts/
# postgresql-12.1.9.tgz
# mongodb-13.6.0.tgz  
# redis-17.3.7.tgz
# kafka-26.4.0.tgz

# Deploy development environment
helm install order-dev . -f values.dev.yaml \
  --namespace ecommerce-dev \
  --create-namespace

# Verify all components of the aggregate
kubectl get all -n ecommerce-dev

# Expected output:
# - deployment/order-service (aggregate root)
# - statefulset/order-dev-eventStore (event sourcing)
# - statefulset/order-dev-readModel (CQRS projections)
# - deployment/order-dev-sagaStore (saga coordination)
# - statefulset/order-dev-eventBus (domain events)
# - All corresponding services

# Test aggregate connectivity
kubectl run -it debug --rm --image=busybox -n ecommerce-dev -- sh
# nslookup order-dev-eventStore
# nslookup order-dev-readModel
# nslookup order-dev-sagaStore-master
# nslookup order-dev-eventBus

# Deploy production with HA configuration
helm install order-prod . -f values.prod.yaml \
  --namespace ecommerce \
  --create-namespace

# Upgrade just the application component (aggregate root)
helm upgrade order-prod . \
  --set application.image.tag=v2.1.0 \
  --reuse-values

# Upgrade infrastructure component (bounded context evolution)
vim Chart.yaml  # Change postgresql version: 12.1.9 → 13.0.0
helm dependency update
helm upgrade order-prod .
```

This complete example demonstrates:
1. **DDD Aggregate Pattern**: Service composed of multiple bounded contexts
2. **Event Sourcing**: PostgreSQL configured as event store
3. **CQRS**: Separate write (PostgreSQL) and read (MongoDB) models
4. **Saga Pattern**: Redis coordinating distributed transactions
5. **Domain Events**: Kafka for event-driven architecture
6. **Values Hierarchy**: Domain concepts translated to technical configuration
7. **Independent Evolution**: Each component upgradeable separately
8. **Production-Ready**: HA configuration, resource limits, persistence

* * *