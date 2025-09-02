# Hydroponic Monitor Docker Compose Setup

This directory contains Docker Compose configurations for running the Hydroponic Monitor infrastructure stack, including InfluxDB, MQTT broker (Mosquitto), and Telegraf data collector.

## Production Deployment

### Prerequisites

1. Docker and Docker Compose installed
2. Copy `.env.example` to `.env` and configure your environment variables
3. Generate MQTT password hashes (see Authentication section below)

### Quick Start

```bash
# 1. Copy and configure environment
cp .env.example .env
# Edit .env with your production values

# 2. Generate MQTT passwords (optional, uses defaults if skipped)
./scripts/generate-mqtt-passwords.sh

# 3. Start services
docker compose up -d

# 4. Check service health
docker compose ps
docker compose logs
```

### Authentication

The production setup uses MQTT authentication with user-based access control:

- **telegraf**: Read-only access to all telemetry data
- **controller**: Can read device states and send commands

To generate password hashes:

```bash
# Automatic (uses environment variables)
./scripts/generate-mqtt-passwords.sh

# Manual
mosquitto_passwd -c config/mosquitto/passwords telegraf
mosquitto_passwd -b config/mosquitto/passwords controller your_password
```

### MQTT Topic Structure

The system uses a hierarchical topic structure:

```
grow/tent/
├── {node}/
│   ├── sensor/{type}/{id}/state     # Sensor readings
│   ├── actuator/{type}/{id}/state   # Actuator status
│   ├── actuator/{type}/{id}/set     # Actuator commands
│   └── status                       # Node online/offline
```

**Examples:**
- `grow/tent/rpi/sensor/temperature/01/state` - Temperature sensor data
- `grow/tent/rpi/actuator/pump/01/set` - Pump control commands
- `grow/tent/rpi/status` - Raspberry Pi node status

### InfluxDB Buckets

The system automatically creates the following buckets:

- **grow_raw**: Raw sensor data (default retention)
- **grow_state**: Actuator states and node status (365 days)
- **grow_meta**: Metadata and configuration (no retention limit)
- **grow_1m**: 1-minute aggregated data (730 days)
- **grow_15m**: 15-minute aggregated data (1825 days)

### Data Flow

```
IoT Devices → MQTT → Telegraf → InfluxDB
             ↑
        Flutter App
```

1. IoT devices publish sensor data and actuator states to MQTT
2. Telegraf subscribes to MQTT topics and forwards data to InfluxDB
3. Flutter app subscribes to MQTT for real-time updates and queries InfluxDB for historical data

## Testing

For integration testing, use the configuration in `test/integration/`:

```bash
cd test/integration
docker compose up -d
# Run integration tests
cd ../..
flutter test test/integration/
```

The test configuration uses anonymous MQTT access and test credentials for compatibility with existing tests.

## Configuration Files

### Directory Structure

```
config/
├── influxdb/
│   └── init-buckets.sh         # InfluxDB bucket initialization
├── mosquitto/
│   ├── mosquitto.conf          # MQTT broker configuration
│   ├── passwords               # User password hashes
│   └── aclfile                 # Access control rules
└── telegraf/
    ├── telegraf.conf           # Main Telegraf configuration
    └── telegraf.d/             # Input plugin configurations
        ├── input_sensors.toml
        ├── input_actuators.toml
        └── input_status.toml
```

### Volumes

- **influxdb_data**: InfluxDB time-series data
- **influxdb_config**: InfluxDB configuration
- **mosquitto_data**: MQTT broker persistence
- **mosquitto_logs**: MQTT broker logs

## Troubleshooting

### Check Service Health

```bash
docker compose ps                    # Service status
docker compose logs influxdb        # InfluxDB logs
docker compose logs mosquitto       # MQTT broker logs
docker compose logs telegraf        # Telegraf logs
```

### Common Issues

1. **Permission denied on config files**: Ensure Docker has read access to config directory
2. **MQTT authentication failures**: Verify password file is correctly generated
3. **InfluxDB bucket creation fails**: Check init script permissions and InfluxDB logs
4. **Telegraf connection issues**: Verify MQTT credentials and topic permissions

### Reset Data

```bash
docker compose down -v           # Stop and remove volumes
docker compose up -d             # Restart with fresh data
```

## Security Notes

1. Change default passwords in `.env` file
2. Use strong passwords for production
3. Consider using certificates for MQTT TLS
4. Restrict network access to services
5. Regular backup of InfluxDB data
6. Monitor access logs for unauthorized attempts