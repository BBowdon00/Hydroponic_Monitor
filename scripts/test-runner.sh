#!/bin/bash

# Comprehensive Test Runner for Hydroponic Monitor
# Runs unit tests and optionally integration tests

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default options
RUN_UNIT=true
RUN_INTEGRATION=false
RUN_COVERAGE=false
VERBOSE=false

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -u, --unit              Run unit tests only (default)"
    echo "  -i, --integration       Run integration tests only"
    echo "  -a, --all               Run both unit and integration tests"
    echo "  -c, --coverage          Generate test coverage report"
    echo "  -v, --verbose           Verbose output"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                      # Run unit tests only"
    echo "  $0 -a                   # Run all tests"
    echo "  $0 -i                   # Run integration tests only"
    echo "  $0 -u -c               # Run unit tests with coverage"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--unit)
            RUN_UNIT=true
            RUN_INTEGRATION=false
            shift
            ;;
        -i|--integration)
            RUN_UNIT=false
            RUN_INTEGRATION=true
            shift
            ;;
        -a|--all)
            RUN_UNIT=true
            RUN_INTEGRATION=true
            shift
            ;;
        -c|--coverage)
            RUN_COVERAGE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

print_status $BLUE "🧪 Hydroponic Monitor Test Suite"
echo ""

# Get project root directory
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

# Check Flutter installation
if ! command -v flutter &> /dev/null; then
    print_status $RED "❌ Flutter is not installed or not in PATH"
    exit 1
fi

print_status $BLUE "📦 Getting dependencies..."
if flutter pub get; then
    print_status $GREEN "✅ Dependencies resolved"
else
    print_status $RED "❌ Failed to get dependencies"
    exit 1
fi

# Create test logs directory
mkdir -p test/logs

# Run unit tests
if [ "$RUN_UNIT" = true ]; then
    print_status $BLUE "🔬 Running unit tests..."
    
    unit_test_args="--exclude-tags=integration"
    if [ "$RUN_COVERAGE" = true ]; then
        unit_test_args="$unit_test_args --coverage"
    fi
    if [ "$VERBOSE" = true ]; then
        unit_test_args="$unit_test_args --reporter=expanded"
    fi
    
    if flutter test $unit_test_args; then
        print_status $GREEN "✅ Unit tests passed"
        unit_success=true
    else
        print_status $RED "❌ Unit tests failed"
        unit_success=false
    fi
    
    if [ "$RUN_COVERAGE" = true ] && [ "$unit_success" = true ]; then
        if command -v lcov &> /dev/null; then
            print_status $BLUE "📊 Generating coverage report..."
            lcov --remove coverage/lcov.info \
                'lib/generated/*' \
                'lib/**/*.g.dart' \
                'lib/**/*.freezed.dart' \
                -o coverage/lcov_filtered.info
            genhtml coverage/lcov_filtered.info -o coverage/html
            print_status $GREEN "📊 Coverage report generated in coverage/html/"
        else
            print_status $YELLOW "⚠️  lcov not installed, skipping HTML coverage report"
        fi
    fi
fi

# Run integration tests
if [ "$RUN_INTEGRATION" = true ]; then
    print_status $BLUE "🐳 Running integration tests..."
    
    # Check Docker and Docker Compose
    if ! command -v docker &> /dev/null; then
        print_status $RED "❌ Docker is required for integration tests"
        exit 1
    fi
    
    if ! command -v docker compose &> /dev/null; then
        print_status $RED "❌ Docker Compose is required for integration tests"
        exit 1
    fi
    
    # Start integration test services
    print_status $BLUE "🚀 Starting test services..."
    cd test/integration
    
    if docker compose down --remove-orphans; then
        print_status $GREEN "🧹 Cleaned up existing services"
    fi
    
    if docker compose up -d; then
        print_status $GREEN "🚀 Services started"
    else
        print_status $RED "❌ Failed to start services"
        exit 1
    fi
    
    # Wait for services to be ready
    print_status $BLUE "⏳ Waiting for services to be healthy..."
    timeout=300
    elapsed=0
    interval=10
    
    while [ $elapsed -lt $timeout ]; do
        healthy_services=$(docker compose ps --format "table {{.Service}}\t{{.State}}" | grep -c "running" || echo "0")
        total_services=3
        
        if [ "$healthy_services" -eq "$total_services" ]; then
            print_status $GREEN "✅ All services are running!"
            docker compose ps
            break
        fi
        
        if [ "$VERBOSE" = true ]; then
            print_status $YELLOW "Waiting for services... ($elapsed/$timeout seconds) - $healthy_services/$total_services ready"
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    if [ $elapsed -ge $timeout ]; then
        print_status $RED "❌ Services did not become ready within $timeout seconds"
        print_status $BLUE "🔍 Service status:"
        docker compose ps
        print_status $BLUE "🔍 Service logs:"
        docker compose logs --tail=100
        docker compose down
        exit 1
    fi
    
    # Additional wait for services to fully initialize
    print_status $BLUE "⏳ Waiting additional time for service initialization..."
    sleep 30
    
    # Go back to project root
    cd "$PROJECT_ROOT"
    
    # Run integration tests
    integration_test_args="--tags=integration"
    if [ "$RUN_COVERAGE" = true ]; then
        integration_test_args="$integration_test_args --coverage"
    fi
    if [ "$VERBOSE" = true ]; then
        integration_test_args="$integration_test_args --reporter=expanded"
    fi
    
    if flutter test $integration_test_args --timeout=180s; then
        print_status $GREEN "✅ Integration tests passed"
        integration_success=true
    else
        print_status $RED "❌ Integration tests failed"
        integration_success=false
        
        # Show service logs for debugging
        print_status $BLUE "🔍 Service logs for debugging:"
        cd test/integration
        docker compose logs --tail=50
        cd "$PROJECT_ROOT"
    fi
    
    # Clean up services
    print_status $BLUE "🔽 Stopping test services..."
    cd test/integration
    docker compose down -v
    cd "$PROJECT_ROOT"
    
    if [ "$integration_success" = false ]; then
        exit 1
    fi
fi

# Summary
print_status $BLUE ""
print_status $BLUE "📋 Test Summary:"

if [ "$RUN_UNIT" = true ]; then
    if [ "$unit_success" = true ]; then
        print_status $GREEN "  ✅ Unit tests: PASSED"
    else
        print_status $RED "  ❌ Unit tests: FAILED"
    fi
fi

if [ "$RUN_INTEGRATION" = true ]; then
    if [ "$integration_success" = true ]; then
        print_status $GREEN "  ✅ Integration tests: PASSED"
    else
        print_status $RED "  ❌ Integration tests: FAILED"
    fi
fi

if [ "$RUN_COVERAGE" = true ]; then
    print_status $BLUE "  📊 Coverage reports generated"
fi

print_status $GREEN ""
print_status $GREEN "🎉 Test run completed!"