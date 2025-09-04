#!/usr/bin/env bash
set -euo pipefail

# Wait until InfluxDB is up
until curl -sf http://localhost:9999/health >/dev/null; do
  echo "Waiting for InfluxDB..."
  sleep 2
done

# Env come from container
ORG="${DOCKER_INFLUXDB_INIT_ORG}"
TOKEN="${DOCKER_INFLUXDB_INIT_ADMIN_TOKEN}"

# Create additional buckets with retention
influx bucket create --org "$ORG" --token "$TOKEN" --name grow_data --retention 365d

echo "Buckets created."