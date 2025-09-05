# Integration Tests

This directory contains integration tests for the Hydroponic Monitor application that test the complete data pipeline: MQTT → Telegraf → InfluxDB.

## Prerequisites

- Docker and Docker Compose
- Flutter SDK
- Internet connection (for pulling Docker images)

## Test Services

The integration tests use the same production Telegraf configuration with test-specific routing to ensure configuration consistency across environments.

### InfluxDB (Port 8086)
- Time-series database for storing sensor data
- Pre-configured with test organization, bucket, and token
- Health check endpoint available

### Mosquitto MQTT Broker (Ports 1883, 9001)
- Message broker for sensor data and device commands
- Anonymous access enabled for testing compatibility
- WebSocket support on port 9001

### Telegraf (No exposed ports)
- Uses production configuration from `../../config/telegraf/`
- Automatically routes test data to `test-bucket` when `TELEGRAF_ENV=integration_test`
- Supports both authenticated (production) and anonymous (test) MQTT access
- Modular configuration with separate input files for different data types

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

The integration tests comprehensively cover:

### 1. **End-to-end data flow**
- MQTT publish → Telegraf processing → InfluxDB storage
- Verifies data persistence and integrity

### 2. **Comprehensive sensor types**
- All sensor types: temperature, humidity, pH, water level, EC, light intensity, air quality
- Realistic data generation with time-based variations
- Batch processing of multiple sensor readings

### 3. **Device and actuator control**
- **Actuator state reporting**: Devices publish their current state
- **Device commands via /set topics**: Control commands sent to devices
- Multiple device types: pumps, lights, fans, valves
- Power monitoring and level control

### 4. **Node status monitoring**
- Node online/offline status reporting
- Status change tracking over time

### 5. **Data persistence verification**
- Direct InfluxDB queries to verify data storage
- Bucket-specific data routing (test vs. production)
- Data format validation

### 7. **Provider Framework Integration**
- **MQTT Provider Tests** (`mqtt_provider_test.dart`): Tests that MQTT messages are properly received and processed through the Riverpod provider framework
- Real-time sensor data streaming through providers
- Device status updates via provider streams
- Connection status monitoring
- Error handling for malformed messages

## Test Data Formats

### Sensor Data (MQTT Topic: `grow/tent/{node}/sensor/{type}/{id}/state`)
```json
{
  "ts": "2025-01-01T12:00:00Z",
  "value": 25.5,
  "unit": "°C",
  "accuracy": 0.1
}
```

Topic example: `grow/tent/rpi/sensor/temperature/01/state`

### Actuator State (MQTT Topic: `grow/tent/{node}/actuator/{type}/{id}/state`)
```json
{
  "ts": "2025-01-01T12:00:00Z",
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
  "command": "set_brightness",
  "deviceId": "light_001",
  "timestamp": "2025-01-01T12:00:00Z",
  "brightness": 75,
  "duration": 3600
}
```

Topic example: `grow/tent/rpi/actuator/light/01/set`

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

### Shared Configuration
Tests now use the same Telegraf configuration as production (`../../config/telegraf/`) with environment-specific routing:
- **Production**: Data routed to `grow_raw`, `grow_state` buckets
- **Test**: All data routed to `test-bucket` when `TELEGRAF_ENV=integration_test`

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

### Configuration issues
Since tests now use production Telegraf config:
1. Verify `../../config/telegraf/` directory exists
2. Check that `TELEGRAF_ENV=integration_test` is set in docker-compose.yml

### Tests failing after configuration changes
1. Check Telegraf logs for configuration errors: `docker compose logs telegraf`
2. Verify MQTT topic format matches telegraf input patterns
3. Test manual MQTT publish to verify connectivity

### Data not appearing in InfluxDB
1. Check Telegraf logs: `docker compose logs telegraf`
2. Verify data is routed to correct bucket based on environment tag
3. Use InfluxDB query to check data:
   ```bash
   curl -XPOST 'http://localhost:8086/api/v2/query?org=test-org' \
     -H 'Authorization: Token test-token-for-integration-tests' \
     -H 'Content-Type: application/vnd.flux' \
     -d 'from(bucket:"test-bucket") |> range(start: -1h) |> limit(n:10)'
   ```

## Development Tips

### Adding new integration tests
1. Follow patterns in `integration_test.dart`
2. Use `TestDataGenerator` for realistic test data
3. Test both command sending (/set) and state reporting (/state)
4. Include verification that data reaches InfluxDB
5. Use appropriate timeouts (comprehensive tests may need 5+ minutes)

### Testing new sensor/device types
1. Add to `TestDataGenerator` in `../test_utils.dart`
2. Create test cases for both unit validation and integration flow
3. Verify data format matches Telegraf input expectations

### Debugging configuration
1. Compare test and production telegraf configurations
2. Use `telegraf --test` to validate configuration syntax
3. Check environment variable substitution in Docker logs