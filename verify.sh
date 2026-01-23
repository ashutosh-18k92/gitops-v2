#!/bin/bash
# Jaeger V2 Stack Verification Script
# This script verifies each component of the Jaeger V2 stack
# Run after each deployment step to ensure dependencies are met

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warning() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }

# Check if a command exists
check_command() {
    if command -v "$1" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Wait for deployment to be ready
wait_for_deployment() {
    local deployment=$1
    local namespace=$2
    local timeout=${3:-300}
    
    info "Waiting for deployment $deployment in namespace $namespace..."
    if kubectl wait --for=condition=available --timeout="${timeout}s" \
        deployment/"$deployment" -n "$namespace" 2>/dev/null; then
        success "Deployment $deployment is ready"
        return 0
    else
        error "Deployment $deployment failed to become ready within ${timeout}s"
        return 1
    fi
}

# Check if CRD exists
check_crd() {
    local crd=$1
    if kubectl get crd "$crd" &>/dev/null; then
        success "CRD $crd exists"
        return 0
    else
        error "CRD $crd not found"
        return 1
    fi
}

# Banner
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║           Jaeger V2 Stack Verification Script                  ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Parse arguments
STEP=${1:-all}

verify_prerequisites() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Step 0: Verifying Prerequisites"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check kubectl
    if check_command kubectl; then
        success "kubectl is available"
    else
        error "kubectl is not installed"
        exit 1
    fi
    
    # Check cluster connectivity
    if kubectl cluster-info &>/dev/null; then
        success "Kubernetes cluster is accessible"
    else
        error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Check cert-manager
    info "Checking cert-manager..."
    if kubectl get deployment cert-manager -n cert-manager &>/dev/null; then
        if kubectl wait --for=condition=available --timeout=10s \
            deployment/cert-manager -n cert-manager &>/dev/null; then
            success "cert-manager is running"
        else
            warning "cert-manager exists but may not be ready"
        fi
    else
        error "cert-manager is not installed (required for operators)"
        exit 1
    fi
    
    # Check Istio (optional for tracing integration)
    info "Checking Istio..."
    if kubectl get deployment istiod -n istio-system &>/dev/null; then
        success "Istio is installed"
    else
        warning "Istio is not installed (required for mesh tracing)"
    fi
    
    success "Prerequisites verified"
}

verify_eck_operator() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Step 1: Verifying ECK Operator"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check namespace
    if kubectl get namespace elastic-system &>/dev/null; then
        success "Namespace elastic-system exists"
    else
        error "Namespace elastic-system does not exist"
        return 1
    fi
    
    # Check CRDs
    check_crd "elasticsearches.elasticsearch.k8s.elastic.co" || return 1
    
    # Check operator deployment
    wait_for_deployment "elastic-operator" "elastic-system" || return 1
    
    # Check operator logs for errors
    info "Checking operator logs for errors..."
    ERROR_COUNT=$(kubectl logs -n elastic-system -l control-plane=elastic-operator --tail=100 2>/dev/null | grep -c "error" || true)
    if [ "$ERROR_COUNT" -gt 5 ]; then
        warning "Found $ERROR_COUNT error messages in operator logs"
        info "Check logs: kubectl logs -n elastic-system -l control-plane=elastic-operator"
    else
        success "Operator logs look healthy"
    fi
    
    success "ECK Operator verified"
}

verify_otel_operator() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Step 2: Verifying OpenTelemetry Operator"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check namespace
    if kubectl get namespace opentelemetry-operator-system &>/dev/null; then
        success "Namespace opentelemetry-operator-system exists"
    else
        error "Namespace opentelemetry-operator-system does not exist"
        return 1
    fi
    
    # Check CRDs
    check_crd "opentelemetrycollectors.opentelemetry.io" || return 1
    
    # Check operator deployment
    OTEL_DEPLOY=$(kubectl get deployment -n opentelemetry-operator-system -o name 2>/dev/null | head -1 | cut -d'/' -f2)
    if [ -n "$OTEL_DEPLOY" ]; then
        wait_for_deployment "$OTEL_DEPLOY" "opentelemetry-operator-system" || return 1
    else
        error "OpenTelemetry Operator deployment not found"
        return 1
    fi
    
    success "OpenTelemetry Operator verified"
}

verify_elasticsearch() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Step 3: Verifying Elasticsearch Cluster"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check namespace
    if kubectl get namespace observability &>/dev/null; then
        success "Namespace observability exists"
    else
        error "Namespace observability does not exist"
        return 1
    fi
    
    # Check Elasticsearch CR
    info "Checking Elasticsearch CR..."
    if kubectl get elasticsearch jaeger-es -n observability &>/dev/null; then
        success "Elasticsearch CR jaeger-es exists"
    else
        error "Elasticsearch CR jaeger-es not found"
        return 1
    fi
    
    # Check Elasticsearch health
    info "Checking Elasticsearch health (this may take a few minutes)..."
    local attempts=0
    local max_attempts=60
    while [ $attempts -lt $max_attempts ]; do
        HEALTH=$(kubectl get elasticsearch jaeger-es -n observability -o jsonpath='{.status.health}' 2>/dev/null || echo "unknown")
        PHASE=$(kubectl get elasticsearch jaeger-es -n observability -o jsonpath='{.status.phase}' 2>/dev/null || echo "unknown")
        
        if [ "$HEALTH" = "green" ]; then
            success "Elasticsearch health is GREEN"
            break
        elif [ "$HEALTH" = "yellow" ]; then
            warning "Elasticsearch health is YELLOW (acceptable for single-node)"
            break
        else
            info "Elasticsearch phase: $PHASE, health: $HEALTH (attempt $((attempts+1))/$max_attempts)"
            sleep 10
            ((attempts++))
        fi
    done
    
    if [ $attempts -eq $max_attempts ]; then
        error "Elasticsearch failed to become healthy"
        kubectl get elasticsearch jaeger-es -n observability -o yaml
        return 1
    fi
    
    # Check Elasticsearch pods
    info "Checking Elasticsearch pods..."
    ES_READY=$(kubectl get pods -n observability -l elasticsearch.k8s.elastic.co/cluster-name=jaeger-es \
        -o jsonpath='{.items[*].status.containerStatuses[0].ready}' 2>/dev/null | grep -c "true" || echo "0")
    ES_TOTAL=$(kubectl get pods -n observability -l elasticsearch.k8s.elastic.co/cluster-name=jaeger-es \
        --no-headers 2>/dev/null | wc -l)
    
    if [ "$ES_READY" -eq "$ES_TOTAL" ] && [ "$ES_TOTAL" -gt 0 ]; then
        success "All $ES_TOTAL Elasticsearch pods are ready"
    else
        warning "$ES_READY/$ES_TOTAL Elasticsearch pods are ready"
    fi
    
    # Check Elasticsearch secret
    if kubectl get secret jaeger-es-es-elastic-user -n observability &>/dev/null; then
        success "Elasticsearch credentials secret exists"
    else
        error "Elasticsearch credentials secret not found"
        return 1
    fi
    
    success "Elasticsearch verified"
}

verify_jaeger() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Step 4: Verifying Jaeger V2 (OpenTelemetryCollector)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check OpenTelemetryCollector CR
    info "Checking OpenTelemetryCollector CR..."
    if kubectl get opentelemetrycollector jaeger-collector -n observability &>/dev/null; then
        success "OpenTelemetryCollector CR jaeger-collector exists"
    else
        error "OpenTelemetryCollector CR jaeger-collector not found"
        return 1
    fi
    
    # Check collector status
    COLLECTOR_STATUS=$(kubectl get opentelemetrycollector jaeger-collector -n observability \
        -o jsonpath='{.status.replicas}' 2>/dev/null || echo "0")
    if [ "$COLLECTOR_STATUS" -gt 0 ]; then
        success "Jaeger collector has $COLLECTOR_STATUS replica(s)"
    else
        warning "Jaeger collector replicas: $COLLECTOR_STATUS"
    fi
    
    # Check collector pods
    info "Checking Jaeger collector pods..."
    local attempts=0
    local max_attempts=30
    while [ $attempts -lt $max_attempts ]; do
        READY_PODS=$(kubectl get pods -n observability \
            -l app.kubernetes.io/name=jaeger-collector-collector \
            -o jsonpath='{.items[*].status.containerStatuses[0].ready}' 2>/dev/null | grep -c "true" || echo "0")
        
        if [ "$READY_PODS" -gt 0 ]; then
            success "Jaeger collector pod is ready"
            break
        else
            info "Waiting for Jaeger collector pod... (attempt $((attempts+1))/$max_attempts)"
            sleep 10
            ((attempts++))
        fi
    done
    
    if [ $attempts -eq $max_attempts ]; then
        error "Jaeger collector pod failed to become ready"
        kubectl logs -n observability -l app.kubernetes.io/name=jaeger-collector-collector --tail=50
        return 1
    fi
    
    # Check services
    info "Checking Jaeger services..."
    if kubectl get svc -n observability | grep -q "jaeger-collector"; then
        success "Jaeger collector services exist"
        kubectl get svc -n observability -l app.kubernetes.io/name=jaeger-collector-collector
    else
        warning "Jaeger collector services not found"
    fi
    
    # Check Jaeger credentials secret
    if kubectl get secret jaeger-es-credentials -n observability &>/dev/null; then
        success "Jaeger ES credentials secret exists"
    else
        warning "Jaeger ES credentials secret not found (may still be creating)"
    fi
    
    # Check collector logs for ES connectivity
    info "Checking collector logs for Elasticsearch connectivity..."
    ES_CONNECTED=$(kubectl logs -n observability \
        -l app.kubernetes.io/name=jaeger-collector-collector --tail=50 2>/dev/null | \
        grep -c "elasticsearch" || echo "0")
    if [ "$ES_CONNECTED" -gt 0 ]; then
        success "Collector logs mention Elasticsearch connection"
    else
        warning "No Elasticsearch connection messages in recent logs"
    fi
    
    success "Jaeger V2 verified"
}

verify_istio_tracing() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Step 5: Verifying Istio Tracing Configuration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check Istio is available
    if ! kubectl get deployment istiod -n istio-system &>/dev/null; then
        warning "Istio is not installed - skipping tracing verification"
        return 0
    fi
    
    # Check Telemetry CRD
    if kubectl get crd telemetries.telemetry.istio.io &>/dev/null; then
        success "Telemetry CRD exists"
    else
        error "Telemetry CRD not found"
        return 1
    fi
    
    # Check Telemetry CR
    info "Checking Telemetry CR..."
    if kubectl get telemetry mesh-default -n istio-system &>/dev/null; then
        success "Telemetry CR mesh-default exists"
    else
        warning "Telemetry CR mesh-default not found"
    fi
    
    # Check mesh config for extension providers
    info "Checking Istio mesh config for tracing provider..."
    MESH_CONFIG=$(kubectl get cm istio -n istio-system -o jsonpath='{.data.mesh}' 2>/dev/null || echo "")
    if echo "$MESH_CONFIG" | grep -q "extensionProviders"; then
        success "extensionProviders configured in mesh config"
    else
        warning "extensionProviders not found in mesh config"
        info "You may need to update your Istio configuration"
    fi
    
    success "Istio tracing configuration verified"
}

show_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Summary: Access Information"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    echo ""
    info "Jaeger UI Access:"
    echo "  kubectl port-forward svc/jaeger-collector-collector -n observability 16686:16686"
    echo "  Open: http://localhost:16686"
    
    echo ""
    info "Elasticsearch Access:"
    echo "  kubectl port-forward svc/jaeger-es-es-http -n observability 9200:9200"
    echo "  Password: kubectl get secret jaeger-es-es-elastic-user -n observability -o jsonpath='{.data.elastic}' | base64 -d"
    
    echo ""
    info "OTLP Endpoints (for sending traces):"
    echo "  gRPC: jaeger-collector-collector.observability.svc.cluster.local:4317"
    echo "  HTTP: jaeger-collector-collector.observability.svc.cluster.local:4318"
    
    echo ""
    info "Generate test traffic and check Jaeger UI for traces!"
}

# Main execution
case "$STEP" in
    prereq|0)
        verify_prerequisites
        ;;
    eck|1)
        verify_eck_operator
        ;;
    otel|2)
        verify_otel_operator
        ;;
    es|elasticsearch|3)
        verify_elasticsearch
        ;;
    jaeger|4)
        verify_jaeger
        ;;
    istio|5)
        verify_istio_tracing
        ;;
    all)
        verify_prerequisites
        verify_eck_operator
        verify_otel_operator
        verify_elasticsearch
        verify_jaeger
        verify_istio_tracing
        show_summary
        ;;
    *)
        echo "Usage: $0 [prereq|eck|otel|es|jaeger|istio|all]"
        echo ""
        echo "Steps:"
        echo "  prereq, 0  - Verify prerequisites (kubectl, cert-manager)"
        echo "  eck, 1     - Verify ECK Operator"
        echo "  otel, 2    - Verify OpenTelemetry Operator"
        echo "  es, 3      - Verify Elasticsearch cluster"
        echo "  jaeger, 4  - Verify Jaeger V2 collector"
        echo "  istio, 5   - Verify Istio tracing configuration"
        echo "  all        - Run all verification steps"
        exit 1
        ;;
esac

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Verification Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"