# Integration Tests

This directory contains integration tests for the Hydroponic Monitor application that test the complete data pipeline: MQTT → Telegraf → InfluxDB.

## Prerequisites

- Docker and Docker Compose
- Flutter SDK
- Internet connection (for pulling Docker images)

## Test Services

The integration tests spin up the following services using Docker Compose:

### InfluxDB (Port 8086)
- Time-series database for storing sensor data
- Pre-configured with test organization, bucket, and token
- Health check endpoint available

### Mosquitto MQTT Broker (Ports 1883, 9001)
- Message broker for sensor data and device commands
- Anonymous access enabled for testing
- WebSocket support on port 9001

### Telegraf (No exposed ports)
- Data collection agent that subscribes to MQTT and forwards to InfluxDB
- Configured to process hydroponic sensor data format
- Includes system monitoring for observability

## Running Integration Tests

### Automatic (Recommended)
```bash
# From project root
./scripts/run-integration-tests.sh
```

### Manual
```bash
# Start services
cd test/integration
docker compose up -d

# Wait for services to be healthy (check with docker compose ps)
# Services typically take 30-60 seconds to be ready

# Run tests from project root
cd ../..
flutter test test/integration/

# Clean up
cd test/integration
docker compose down
```

## Test Coverage

The integration tests cover:

1. **End-to-end data flow**: MQTT publish → Telegraf processing → InfluxDB storage
2. **Multiple sensor types**: Temperature, humidity, pH, water level, etc.
3. **Device status integration**: Device state changes via MQTT
4. **Data persistence**: Verification that data is actually stored in InfluxDB
5. **Service health**: All services start and remain healthy during tests

## Test Data Format

### Sensor Data (MQTT Topic: `grow/tent/{node}/sensor/{type}/{id}/state`)
```json
{
  "ts": "2024-01-01T12:00:00Z",
  "value": 25.5,
  "unit": "°C",
  "accuracy": 0.1
}
```

Topic example: `grow/tent/rpi/sensor/temperature/01/state`

### Actuator State (MQTT Topic: `grow/tent/{node}/actuator/{type}/{id}/state`)
```json
{
  "ts": "2024-01-01T12:00:00Z",
  "state": 1,
  "level": "high",
  "power_W": 50.0,
  "request_id": "req_001"
}
```

Topic example: `grow/tent/rpi/actuator/pump/01/state`

### Device Commands (MQTT Topic: `grow/tent/{node}/actuator/{type}/{id}/set`)
```json
{
  "command": "turn_on",
  "level": "medium",
  "timestamp": "2024-01-01T12:00:00Z"
}
```

Topic example: `grow/tent/rpi/actuator/pump/01/set`

### Node Status (MQTT Topic: `grow/tent/{node}/status`)
```
ONLINE
```
or
```
OFFLINE
```

Topic example: `grow/tent/rpi/status`

## Configuration

### Service Endpoints
- **InfluxDB**: http://localhost:8086
- **MQTT**: tcp://localhost:1883
- **MQTT WebSocket**: ws://localhost:9001

### Test Credentials
- **InfluxDB Token**: `test-token-for-integration-tests`
- **InfluxDB Org**: `test-org`
- **InfluxDB Bucket**: `test-bucket`
- **MQTT**: Anonymous access (no credentials)

## Troubleshooting

### Services not starting
```bash
# Check service logs
cd test/integration
docker compose logs

# Restart services
docker compose down
docker compose up -d
```

### Port conflicts
If you have local services running on the same ports:
- InfluxDB: 8086
- MQTT: 1883, 9001

Stop the conflicting services or modify the ports in `docker-compose.yml`.

### Tests timing out
Integration tests have a 3-minute timeout per test. If tests are timing out:
1. Check that all services are healthy: `docker compose ps`
2. Verify network connectivity: `docker compose logs telegraf`
3. Check InfluxDB is accepting data: `docker compose logs influxdb`

### Data not appearing in InfluxDB
1. Check Telegraf logs: `docker compose logs telegraf`
2. Verify MQTT messages are being published (check Mosquitto logs)
3. Ensure InfluxDB bucket and token are correct

## CI/CD Integration

The integration tests are designed to run in CI/CD environments. See `.github/workflows/ci.yml` for the complete GitHub Actions setup that:

1. Starts the Docker services
2. Waits for health checks
3. Runs integration tests
4. Collects test results and coverage
5. Cleans up resources

## Development Tips

### Adding new integration tests
1. Follow the existing test patterns in `integration_test.dart`
2. Use the `TestDataGenerator` for realistic test data
3. Include proper cleanup in test teardown
4. Add appropriate timeouts for service operations

### Debugging failed tests
1. Enable verbose logging in service configurations
2. Use `docker compose logs -f` to watch logs in real-time
3. Connect to services manually to verify they're working:
   ```bash
   # Test MQTT
   mosquitto_pub -h localhost -t test/topic -m "test message"
   
   # Test InfluxDB
   curl http://localhost:8086/health
   ```

### Performance considerations
- Integration tests are slower than unit tests
- Services may take 30-60 seconds to start
- Use appropriate timeouts and retries
- Consider running integration tests separately from unit tests in CI