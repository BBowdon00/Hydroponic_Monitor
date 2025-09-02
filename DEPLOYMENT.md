# Hydroponic Monitor Docker Deployment Guide

This guide shows how to deploy the Hydroponic Monitor infrastructure stack for production use.

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/BBowdon00/Hydroponic_Monitor.git
cd Hydroponic_Monitor

# 2. Configure environment
cp .env.example .env
# Edit .env with your production values

# 3. Generate MQTT passwords
./scripts/generate-mqtt-passwords.sh

# 4. Start the stack
docker compose up -d

# 5. Verify deployment
docker compose ps
curl http://localhost:8086/health  # InfluxDB health check
```

## Architecture

```
IoT Devices → MQTT (Mosquitto) → Telegraf → InfluxDB
                    ↓
              Flutter App
```

## Environment Configuration

Key variables in `.env`:

```bash
# InfluxDB
INFLUX_ADMIN_PASSWORD=your-secure-password
INFLUX_ADMIN_TOKEN=your-secure-token
INFLUX_ORG=your-organization

# MQTT Authentication
MQTT_TELEGRAF_PASSWORD=telegraf-password
MQTT_CONTROLLER_PASSWORD=controller-password
```

## MQTT Topic Structure

### Sensor Data
```
Topic: grow/tent/{node}/sensor/{type}/{id}/state
Payload: {"ts":"2025-01-01T12:00:00Z","value":25.5,"unit":"°C","accuracy":0.1}
```

### Actuator Commands
```
Topic: grow/tent/{node}/actuator/{type}/{id}/set
Payload: {"command":"turn_on","level":"medium","timestamp":"2025-01-01T12:00:00Z"}
```

### Actuator Status
```
Topic: grow/tent/{node}/actuator/{type}/{id}/state
Payload: {"ts":"2025-01-01T12:00:00Z","state":1,"power_W":50.0}
```

### Node Status
```
Topic: grow/tent/{node}/status
Payload: ONLINE | OFFLINE
```

## InfluxDB Buckets

- **grow_raw**: Raw sensor data (default retention)
- **grow_state**: Actuator states and node status (365 days)
- **grow_meta**: Metadata and configuration (infinite retention)
- **grow_1m**: 1-minute aggregated data (730 days)
- **grow_15m**: 15-minute aggregated data (1825 days)

## Security

### MQTT Authentication

The system uses username/password authentication with ACL controls:

- **telegraf**: Read-only access to all telemetry
- **controller**: Can read states and send commands
- **device nodes**: Individual credentials per device (optional)

Generate passwords:
```bash
./scripts/generate-mqtt-passwords.sh
```

Or manually:
```bash
mosquitto_passwd -c config/mosquitto/passwords telegraf
mosquitto_passwd -b config/mosquitto/passwords controller your_password
```

### Firewall Recommendations

```bash
# Allow only necessary ports
ufw allow 1883/tcp   # MQTT
ufw allow 8086/tcp   # InfluxDB
# Block 9001/tcp unless WebSocket access needed
```

## Monitoring

### Health Checks

```bash
# Service status
docker compose ps

# InfluxDB health
curl http://localhost:8086/health

# MQTT connectivity
mosquitto_pub -h localhost -u controller -P your_password -t health -m test

# Check logs
docker compose logs influxdb
docker compose logs mosquitto  
docker compose logs telegraf
```

### Metrics

Telegraf automatically adds tags:
- `environment`: Deployment environment
- `host`: Container hostname
- `project`: hydroponic_monitor

## Backup

### InfluxDB Data
```bash
# Create backup
docker exec -it hydroponic_influxdb influx backup /tmp/backup
docker cp hydroponic_influxdb:/tmp/backup ./influx-backup-$(date +%Y%m%d)

# Restore backup
docker cp ./influx-backup-20250101 hydroponic_influxdb:/tmp/restore
docker exec -it hydroponic_influxdb influx restore /tmp/restore
```

### Configuration
```bash
# Backup config
tar -czf config-backup-$(date +%Y%m%d).tar.gz config/
```

## Scaling

### Multiple Nodes

Add device credentials to `config/mosquitto/passwords`:
```bash
mosquitto_passwd -b config/mosquitto/passwords rpi_node_01 device_password_1
mosquitto_passwd -b config/mosquitto/passwords rpi_node_02 device_password_2
```

Update ACL in `config/mosquitto/aclfile`:
```
user rpi_node_01
topic write grow/tent/rpi_node_01/+/+/+/state
topic write grow/tent/rpi_node_01/status
topic read grow/tent/rpi_node_01/actuator/+/+/set
```

### High Availability

For production HA setup:
1. Use external InfluxDB cluster
2. Setup MQTT broker clustering
3. Run multiple Telegraf instances
4. Use load balancer for InfluxDB

## Troubleshooting

### Common Issues

1. **MQTT Connection Refused**
   - Check credentials in config/mosquitto/passwords
   - Verify ACL permissions in config/mosquitto/aclfile

2. **No Data in InfluxDB**
   - Check Telegraf logs: `docker compose logs telegraf`
   - Verify MQTT topic format matches Telegraf configuration
   - Test manual MQTT publish

3. **Bucket Creation Failed**
   - Check InfluxDB logs during startup
   - Verify admin token is correct
   - Ensure init script has execute permissions

4. **Permission Denied**
   - Check Docker volume permissions
   - Ensure config files are readable by containers

### Debug Mode

Enable Telegraf debug logging:
```bash
# Edit config/telegraf/telegraf.conf
debug = true
quiet = false

# Restart Telegraf
docker compose restart telegraf
```

## Development

For development and testing, use:
```bash
cd test/integration
docker compose up -d
cd ../..
flutter test test/integration/
```

This uses a separate test configuration with:
- Anonymous MQTT access for test compatibility
- Single bucket (`test-bucket`) for all test data  
- Simplified configuration without authentication
- Same telegraf configuration but with test-specific routing

### Directory Structure

The project uses the following configuration structure:

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
        ├── input_sensors.toml  # Sensor data processing
        ├── input_actuators.toml # Actuator state processing
        └── input_status.toml   # Node status processing
```

### Docker Volumes

The system creates persistent volumes for data storage:

- **influxdb_data**: InfluxDB time-series data
- **influxdb_config**: InfluxDB configuration
- **mosquitto_data**: MQTT broker persistence
- **mosquitto_logs**: MQTT broker logs

### Reset Data

To start fresh with clean data:

```bash
docker compose down -v           # Stop and remove volumes
docker compose up -d             # Restart with fresh data
```