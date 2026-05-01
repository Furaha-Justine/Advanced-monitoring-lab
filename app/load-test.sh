#!/bin/bash

# ============================================
# Load Testing Script for Observability Demo
# ============================================

BASE_URL="${1:-http://localhost:5000}"
ENDPOINT="${2:-/}"
REQUESTS="${3:-100}"
CONCURRENCY="${4:-10}"

echo "🔥 Load Testing: $BASE_URL$ENDPOINT"
echo "📊 Total Requests: $REQUESTS"
echo "⚡ Concurrency: $CONCURRENCY"
echo ""

# Function to make requests
make_request() {
    local endpoint=$1
    curl -s "$BASE_URL$endpoint" > /dev/null 2>&1
}

# Test normal endpoint
test_normal() {
    echo "📍 Testing: $BASE_URL/"
    for i in $(seq 1 "$REQUESTS"); do
        make_request "/" &
        
        # Limit concurrency
        if [ $((i % CONCURRENCY)) -eq 0 ]; then
            wait
        fi
    done
    wait
    echo "✅ Normal endpoint test completed"
}

# Test slow endpoint
test_slow() {
    echo "📍 Testing: $BASE_URL/slow"
    for i in $(seq 1 "$REQUESTS"); do
        make_request "/slow" &
        
        if [ $((i % CONCURRENCY)) -eq 0 ]; then
            wait
        fi
    done
    wait
    echo "✅ Slow endpoint test completed"
}

# Test error endpoint
test_error() {
    echo "📍 Testing: $BASE_URL/error"
    for i in $(seq 1 "$REQUESTS"); do
        make_request "/error" &
        
        if [ $((i % CONCURRENCY)) -eq 0 ]; then
            wait
        fi
    done
    wait
    echo "✅ Error endpoint test completed"
}

# Parse arguments
case "$ENDPOINT" in
    "/")
        test_normal
        ;;
    "/slow")
        test_slow
        ;;
    "/error")
        test_error
        ;;
    "/all")
        echo "🚀 Running all tests..."
        test_normal
        sleep 2
        test_slow
        sleep 2
        test_error
        ;;
    *)
        echo "Usage: $0 [BASE_URL] [ENDPOINT] [REQUESTS] [CONCURRENCY]"
        echo ""
        echo "Examples:"
        echo "  $0 http://localhost:5000 / 100 10          # Test normal endpoint"
        echo "  $0 http://localhost:5000 /slow 50 5        # Test slow endpoint"
        echo "  $0 http://localhost:5000 /error 50 5       # Test error endpoint"
        echo "  $0 http://localhost:5000 /all 100 10       # Test all endpoints"
        exit 1
        ;;
esac

echo ""
echo "📊 Check Grafana dashboard at http://localhost:3000"
echo "🔍 View traces in Jaeger at http://localhost:16686"
echo "📋 Check logs in Loki (via Grafana)"
echo ""
