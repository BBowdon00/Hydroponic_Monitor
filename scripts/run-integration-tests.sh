#!/bin/bash

# Integration Test Runner for Hydroponic Monitor
# This script sets up the test environment and runs integration tests

set -e

# Parse command line arguments
KEEP_SERVICES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --keep-services|--no-cleanup)
            KEEP_SERVICES=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --keep-services, --no-cleanup    Keep Docker services running after tests"
            echo "  --help, -h                       Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "🧪 Starting Hydroponic Monitor Integration Tests"

# Check if docker compose is available
if ! command -v docker compose &> /dev/null; then
    echo "❌ docker compose is required but not installed."
    echo "Please install docker compose to run integration tests."
    exit 1
fi

# Navigate to integration test directory
cd "$(dirname "$0")/../test/integration"

echo "🐳 Starting test services with Docker Compose..."
docker compose down --remove-orphans
docker compose up -d
docker compose logs -f telegraf > ../logs/telegraf.log 2>&1 &
docker compose logs -f mosquitto > ../logs/mosquitto.log 2>&1 &
docker compose logs -f influxdb > ../logs/influxdb.log 2>&1 &

echo "⏳ Waiting for services to be healthy..."
timeout=300  # 5 minutes timeout
elapsed=0
interval=10

while [ $elapsed -lt $timeout ]; do
    if docker compose ps | grep -q "healthy"; then
        echo "✅ Services are healthy!"
        break
    fi
    
    echo "Waiting for services... ($elapsed/$timeout seconds)"
    sleep $interval
    elapsed=$((elapsed + interval))
done

if [ $elapsed -ge $timeout ]; then
    echo "❌ Services did not become healthy within $timeout seconds"
    echo "🔍 Service status:"
    docker compose ps
    echo "🔍 Service logs:"
    docker compose logs
    docker compose down
    exit 1
fi

echo "🔍 Service status:"
docker compose ps

# Go back to project root
cd ../..

echo "🧪 Running integration tests..."
if flutter test test/integration/ --reporter=expanded; then
    echo "✅ Integration tests passed!"
    test_result=0
else
    echo "❌ Integration tests failed!"
    test_result=1
fi

if [ "$KEEP_SERVICES" = true ]; then
    echo "🔧 Keeping test services running (--keep-services flag detected)"
    echo "💡 To stop services manually, run: cd test/integration && docker compose down"
else
    echo "🔽 Stopping test services..."
    cd test/integration
    docker compose down

    echo "🧹 Cleaning up..."
    docker system prune -f > /dev/null 2>&1 || true
fi

if [ $test_result -eq 0 ]; then
    echo "🎉 All integration tests completed successfully!"
else
    echo "💥 Integration tests failed. Check the logs above for details."
fi

exit $test_result
