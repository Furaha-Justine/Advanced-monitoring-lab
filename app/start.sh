#!/bin/bash

# ============================================
# Advanced Monitoring Stack Startup Script
# ============================================

set -e

echo "🚀 Starting Advanced Monitoring Stack..."
echo ""

# Check prerequisites
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Create .env if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env from .env.example..."
    cp .env.example .env
    echo "✅ .env created. You can customize it if needed."
fi

# Start services
echo ""
echo "📦 Starting Docker Compose services..."
docker compose up -d

# Wait for services to be healthy
echo ""
echo "⏳ Waiting for services to start (15 seconds)..."
sleep 15

# Check service health
echo ""
echo "🔍 Checking service status..."
docker compose ps

# Print access instructions
echo ""
echo "================================"
echo "✅ Stack is ready!"
echo "================================"
echo ""
echo "📊 Access Services:"
echo "  - App:           http://localhost:5000"
echo "  - Grafana:       http://localhost:3000 (admin/admin)"
echo "  - Prometheus:    http://localhost:9090"
echo "  - Jaeger:        http://localhost:16686"
echo "  - Loki:          http://localhost:3100"
echo "  - Alloy:         http://localhost:12345"
echo "  - Alertmanager:  http://localhost:9093"
echo ""
echo "🧪 Test Endpoints:"
echo "  - Health:  curl http://localhost:5000/"
echo "  - Users:   curl http://localhost:5000/users"
echo "  - Slow:    curl http://localhost:5000/slow"
echo "  - Error:   curl http://localhost:5000/error"
echo "  - Metrics: curl http://localhost:5000/metrics"
echo ""
echo "📖 For more info, see OBSERVABILITY.md"
echo ""
