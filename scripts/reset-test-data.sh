#!/bin/bash

# Test Data Reset Script for Hydroponic Monitor
# Cleanly resets all test containers and volumes for consistent test runs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Get project root directory
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

print_status $BLUE "🧹 Resetting Test Environment"
echo ""

# Check if we're in the right directory
if [ ! -f "test/integration/docker-compose.yml" ]; then
    print_status $RED "❌ Integration test docker-compose.yml not found"
    print_status $RED "   Make sure you're running from the project root"
    exit 1
fi

# Navigate to integration test directory
cd test/integration

print_status $BLUE "🛑 Stopping all test services..."
if docker compose down --remove-orphans; then
    print_status $GREEN "✅ Services stopped"
else
    print_status $YELLOW "⚠️  Some services may not have been running"
fi

print_status $BLUE "🗑️  Removing test volumes..."
if docker compose down -v; then
    print_status $GREEN "✅ Volumes removed"
else
    print_status $YELLOW "⚠️  No volumes to remove"
fi

print_status $BLUE "🧽 Pruning unused volumes..."
if docker volume prune -f; then
    print_status $GREEN "✅ Unused volumes pruned"
else
    print_status $YELLOW "⚠️  No volumes to prune"
fi

# Remove any dangling containers with our test prefix
print_status $BLUE "🔍 Cleaning up test containers..."
test_containers=$(docker ps -aq --filter "name=hydroponic_test_" 2>/dev/null || echo "")
if [ -n "$test_containers" ]; then
    docker rm -f $test_containers
    print_status $GREEN "✅ Test containers cleaned up"
else
    print_status $GREEN "✅ No test containers to clean up"
fi

print_status $BLUE "🚀 Starting fresh test services..."
if docker compose up -d --wait; then
    print_status $GREEN "✅ Fresh test environment ready"
else
    print_status $RED "❌ Failed to start fresh test environment"
    exit 1
fi

# Wait a moment for services to fully initialize
print_status $BLUE "⏳ Allowing services to initialize..."
sleep 10

print_status $BLUE "🔍 Verifying service health..."
healthy_services=0
total_services=4  # influxdb, mosquitto, telegraf, nginx

# Check InfluxDB
if curl -f -s http://localhost:8086/health > /dev/null 2>&1; then
    print_status $GREEN "  ✅ InfluxDB: Healthy"
    healthy_services=$((healthy_services + 1))
else
    print_status $RED "  ❌ InfluxDB: Not responding"
fi

# Check Mosquitto
if mosquitto_pub -h localhost -p 1883 -t test/health -m "check" > /dev/null 2>&1; then
    print_status $GREEN "  ✅ Mosquitto: Healthy"
    healthy_services=$((healthy_services + 1))
else
    print_status $RED "  ❌ Mosquitto: Not responding"
fi

# Check Telegraf (indirectly via container status)
if docker compose ps telegraf --format "{{.State}}" | grep -q "running"; then
    print_status $GREEN "  ✅ Telegraf: Running"
    healthy_services=$((healthy_services + 1))
else
    print_status $RED "  ❌ Telegraf: Not running"
fi

# Check Nginx
if curl -f -s http://localhost:8081/ > /dev/null 2>&1; then
    print_status $GREEN "  ✅ Nginx: Healthy"
    healthy_services=$((healthy_services + 1))
else
    print_status $RED "  ❌ Nginx: Not responding"
fi

echo ""
if [ $healthy_services -eq $total_services ]; then
    print_status $GREEN "🎉 All services healthy! Test environment ready."
    print_status $BLUE "📋 Service Status:"
    docker compose ps
    echo ""
    print_status $BLUE "🔗 Available endpoints:"
    print_status $BLUE "   InfluxDB: http://localhost:8086"
    print_status $BLUE "   MQTT: mqtt://localhost:1883"
    print_status $BLUE "   MQTT WS: ws://localhost:9001"
    print_status $BLUE "   Nginx Proxy: http://localhost:8081"
else
    print_status $YELLOW "⚠️  Warning: Only $healthy_services/$total_services services are healthy"
    print_status $BLUE "📋 Current Status:"
    docker compose ps
    print_status $BLUE "🔍 Check logs with: docker compose logs <service_name>"
    exit 1
fi

# Go back to project root
cd "$PROJECT_ROOT"
print_status $GREEN ""
print_status $GREEN "✨ Test environment reset complete!"