#!/bin/bash
# Script to start the integration test stack using .env.test configuration
# This spins up local InfluxDB and MQTT services for testing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_INTEGRATION_DIR="$PROJECT_ROOT/test/integration"

echo "🚀 Starting test integration stack..."
echo "   Using configuration from .env.test"
echo ""

# Check if .env.test exists
if [ ! -f "$PROJECT_ROOT/.env.test" ]; then
    echo "⚠️  Warning: .env.test not found"
    echo "   Creating from .env.test.example..."
    if [ -f "$PROJECT_ROOT/.env.test.example" ]; then
        cp "$PROJECT_ROOT/.env.test.example" "$PROJECT_ROOT/.env.test"
        echo "✅ Created .env.test"
    else
        echo "❌ Error: .env.test.example not found"
        exit 1
    fi
fi

# Check if docker-compose.yml exists in test/integration
if [ ! -f "$TEST_INTEGRATION_DIR/docker-compose.yml" ]; then
    echo "❌ Error: test/integration/docker-compose.yml not found"
    echo "   Make sure you're in the project root directory"
    exit 1
fi

# Start the stack
cd "$TEST_INTEGRATION_DIR"
echo "📦 Starting containers..."
docker-compose --env-file "$PROJECT_ROOT/.env.test" up -d

echo ""
echo "✅ Test stack started successfully!"
echo ""
echo "Services:"
echo "  - InfluxDB: http://localhost:8086"
echo "  - MQTT: localhost:1883"
echo ""
echo "To stop the stack:"
echo "  cd $TEST_INTEGRATION_DIR && docker-compose down"
echo ""
echo "To view logs:"
echo "  cd $TEST_INTEGRATION_DIR && docker-compose logs -f"
