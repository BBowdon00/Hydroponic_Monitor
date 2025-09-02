#!/usr/bin/env bash
set -euo pipefail

# Wait until InfluxDB is up
until curl -sf http://localhost:8086/health >/dev/null; do
  echo "Waiting for InfluxDB..."
  sleep 2
done

# Env come from container
ORG="${DOCKER_INFLUXDB_INIT_ORG}"
TOKEN="${DOCKER_INFLUXDB_INIT_ADMIN_TOKEN}"

# Create additional buckets with retention
influx bucket create --org "$ORG" --token "$TOKEN" --name grow_state --retention 365d
influx bucket create --org "$ORG" --token "$TOKEN" --name grow_meta  --retention 0
influx bucket create --org "$ORG" --token "$TOKEN" --name grow_1m    --retention 730d
influx bucket create --org "$ORG" --token "$TOKEN" --name grow_15m   --retention 1825d

echo "Buckets created."