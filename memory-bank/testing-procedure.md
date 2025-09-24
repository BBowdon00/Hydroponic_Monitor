# Hydroponic Monitor - Testing Quick Reference

## How to Test (Most Important)

### 1. Run All Tests (Unit + Integration)
```bash
./scripts/test-runner.sh --all
```

### 2. Run Only Unit Tests
```bash
./scripts/test-runner.sh --unit
# Or
flutter test --exclude-tags=integration
```

### 3. Run Only Integration Tests
```bash
./scripts/test-runner.sh --integration
# Or
./scripts/run-integration-tests.sh
```

### 4. Run Widget/UI Tests
```bash
flutter test test/presentation/
```

### 5. Run Real-Time Data Integration Tests
```bash
# MQTT Provider Integration Tests (validates end-to-end real-time data flow)
flutter test test/integration/mqtt_provider_test.dart

# Dashboard Widget Tests (validates UI responsiveness to real-time data)
flutter test test/presentation/pages/dashboard_page_test.dart

# Error Handling Tests (validates system resilience)
flutter test test/data/error_handling_test.dart
```
---

## Prerequisites

- Flutter 3.35+, Dart 3.9+
- Docker & Docker Compose (for integration tests)

```bash
flutter pub get
flutter doctor
chmod +x scripts/test-runner.sh scripts/run-integration-tests.sh
```

---

## Troubleshooting

### Common Issues and Fixes

- **Port in use**:  
    Have it restart the docker container
    ```bash
    docker compose restart
    ```

- **Services not healthy**:  
  Check the logs of each Docker container to identify issues:  
  ```bash
  docker ps  # List running containers
  docker logs <container_id>  # Replace <container_id> with the ID of the container
  ```

- **Docker Compose issues**:  
  Restart the services and ensure they are healthy:  
  ```bash
  docker compose down
  docker compose up -d
  docker compose ps  # Check the status of all services
  ```

### Checking Logs for Integration Tests

To debug integration tests, check the logs of the relevant Docker containers:

1. **List all running containers**:  
   ```bash
   docker ps
   ```

2. **Check logs for specific containers**:
   - **MQTT Broker**:  
     ```bash
     docker logs hydroponic_test_mosquitto
     ```
   - **InfluxDB**:  
     ```bash
     docker logs hydroponic_test_influxdb
     ```
   - **Telegraf**:  
     ```bash
     docker logs hydroponic_test_telegraf
     ```

3. **Follow logs in real-time**:  
   Use the `-f` flag to follow logs as they are generated:  
   ```bash
   docker logs -f <container_id>
   ```

4. **Inspect container health**:  
   Check the health status of a container:  
   ```bash
   docker inspect <container_id> | grep Health
   ```

5. **Restart a specific container**:  
   If a container is unhealthy, restart it:  
   ```bash
   docker restart <container_id>
   ```

---

## Task Completion
TASK IS NOT FINISHED UNTIL ALL TESTS PASS. DO NOT MARK AS COMPLETE.

---

## Related Docs

- [techContext.md](./techContext.md) - Testing infrastructure
- [systemPatterns.md](./systemPatterns.md) - Architecture patterns
- [progress.md](./progress.md) - Testing status

---

*Last Updated: 2025-09-24*