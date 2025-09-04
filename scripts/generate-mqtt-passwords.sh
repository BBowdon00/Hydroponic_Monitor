#!/bin/bash

# Script to generate MQTT password file for production use
# Usage: ./generate-mqtt-passwords.sh

echo "Generating MQTT password file..."

# Create temporary password file
TEMP_PASSWD_FILE=$(mktemp)

# Default passwords (change these in production!)
TELEGRAF_PASSWORD="${MQTT_TELEGRAF_PASSWORD:-telegraf123}"
CONTROLLER_PASSWORD="${MQTT_CONTROLLER_PASSWORD:-controller123}"

# Generate password hashes using mosquitto_passwd
echo "Creating hash for telegraf user..."
mosquitto_passwd -c "$TEMP_PASSWD_FILE" telegraf <<< "$TELEGRAF_PASSWORD"

echo "Creating hash for controller user..."
mosquitto_passwd -b "$TEMP_PASSWD_FILE" controller "$CONTROLLER_PASSWORD"

# Move to final location
mv "$TEMP_PASSWD_FILE" config/mosquitto/passwords

echo "Password file generated at config/mosquitto/passwords"
echo "WARNING: Change default passwords before production use!"

# Set restrictive permissions
chmod 600 config/mosquitto/passwords

echo "File permissions set to 600 for security"