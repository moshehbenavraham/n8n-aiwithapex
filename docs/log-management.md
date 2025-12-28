# Log Management

Comprehensive guide to Docker container log management for the n8n stack.

## Overview

The n8n stack generates logs from multiple services:
- **postgres**: Database server logs
- **redis**: Cache server logs
- **n8n**: Main application logs
- **n8n-worker**: Worker process logs (5 replicas)
- **ngrok**: Tunnel connector logs

Without log rotation, these logs can grow unbounded and exhaust disk space.

## Log Rotation Configuration

### Docker Daemon Level (Recommended)

The daemon-level configuration applies to all containers by default.

**Configuration file**: `config/daemon.json`

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "5",
    "compress": "true"
  }
}
```

**Settings**:
| Option | Value | Description |
|--------|-------|-------------|
| log-driver | json-file | Docker's default logging driver |
| max-size | 100m | Rotate when log reaches 100MB |
| max-file | 5 | Keep at most 5 rotated log files |
| compress | true | Compress rotated logs with gzip |

**Deployment** (requires sudo):

```bash
# Copy configuration to Docker daemon directory
sudo cp config/daemon.json /etc/docker/daemon.json

# Restart Docker to apply changes
sudo systemctl restart docker

# Verify daemon is running
docker info
```

**Note**: Restarting Docker will temporarily stop all containers. Plan for brief downtime when applying this change.

### Container Level

Each service in `docker-compose.yml` has explicit logging configuration:

```yaml
logging:
  driver: json-file
  options:
    max-size: "100m"
    max-file: "5"
```

This provides defense-in-depth: containers get rotation even if daemon.json is not deployed.

## n8n Application Logs

### Log Level Configuration

The n8n application log level is controlled via environment variables in `.env`:

```bash
# Log levels: error, warn, info, debug
N8N_LOG_LEVEL=info

# Output destination: console, file
N8N_LOG_OUTPUT=console
```

**Log Levels**:
| Level | Description |
|-------|-------------|
| error | Only critical errors |
| warn | Errors and warnings |
| info | Normal operational messages (default) |
| debug | Detailed debugging information |

**Changing Log Level**:

```bash
# Edit .env file
N8N_LOG_LEVEL=debug

# Restart services to apply
docker compose restart n8n n8n-worker
```

## Viewing Logs

### Using view-logs.sh

The `scripts/view-logs.sh` script provides filtered log viewing:

```bash
# Show last 100 lines from all services
./scripts/view-logs.sh

# Filter by service
./scripts/view-logs.sh -s n8n          # Main app
./scripts/view-logs.sh -s worker       # All workers
./scripts/view-logs.sh -s postgres     # Database
./scripts/view-logs.sh -s redis        # Cache
./scripts/view-logs.sh -s ngrok        # Tunnel

# Customize line count
./scripts/view-logs.sh -s n8n -n 200   # Last 200 lines

# Follow logs in real-time
./scripts/view-logs.sh -s worker -f
```

### Direct Docker Commands

```bash
# View specific container logs
docker compose logs n8n --tail 100

# Follow logs
docker compose logs n8n -f

# View all logs with timestamps
docker compose logs --timestamps

# View logs since a specific time
docker compose logs --since 1h
```

## Cleaning Up Logs

### Using cleanup-logs.sh

The `scripts/cleanup-logs.sh` script reports and optionally truncates logs:

```bash
# Report log sizes (dry-run, safe)
./scripts/cleanup-logs.sh

# Actually truncate logs (requires sudo)
sudo ./scripts/cleanup-logs.sh --force
```

**Sample Output**:

```
CONTAINER                                           SIZE LOG PATH
================================================================================
n8n-main                                           45.2M /var/lib/docker/containers/.../...-json.log
n8n-n8n-worker-1                                   12.3M /var/lib/docker/containers/.../...-json.log
n8n-postgres                                        8.1M /var/lib/docker/containers/.../...-json.log
================================================================================
TOTAL (9 containers)                               87.5M
```

### Manual Log Truncation

If you need to truncate a specific container's log:

```bash
# Find container ID
docker ps --format "{{.ID}} {{.Names}}"

# Truncate log file (requires sudo)
sudo truncate -s 0 /var/lib/docker/containers/<container-id>/<container-id>-json.log
```

## Automated Cleanup (Optional)

You can schedule log cleanup via cron:

```bash
# Edit crontab
crontab -e

# Add weekly log size check (every Sunday at 3 AM)
0 3 * * 0 /home/aiwithapex/n8n/scripts/cleanup-logs.sh >> /home/aiwithapex/n8n/logs/cleanup-logs.log 2>&1
```

**Note**: The cleanup script defaults to dry-run mode, so the cron job will only report sizes. For automatic truncation, you would need sudo access in cron (not recommended for security reasons).

## Log Locations

### Container Logs

Docker stores container logs at:
```
/var/lib/docker/containers/<container-id>/<container-id>-json.log
```

### Script Logs

Operational scripts write to:
```
logs/cleanup-logs.log
logs/health-check.log
logs/autoscale.log
```

## Best Practices

1. **Deploy daemon.json** for system-wide protection
2. **Keep container-level config** as backup protection
3. **Monitor disk space** regularly with `df -h`
4. **Use info log level** for production; debug only for troubleshooting
5. **Archive important logs** before truncation if needed for auditing

## Troubleshooting

### Logs Not Rotating

1. Verify daemon.json is deployed:
   ```bash
   cat /etc/docker/daemon.json
   ```

2. Restart Docker if recently deployed:
   ```bash
   sudo systemctl restart docker
   ```

3. Note: Existing logs don't rotate until they grow past max-size threshold

### Large Pre-existing Logs

For containers that ran before log rotation was configured:

```bash
# Check current log sizes
./scripts/cleanup-logs.sh

# Truncate if needed
sudo ./scripts/cleanup-logs.sh --force

# Restart containers to start fresh
docker compose restart
```

### Permission Denied Errors

Log files are owned by root. Truncation requires sudo:

```bash
sudo ./scripts/cleanup-logs.sh --force
```

## Related Documentation

- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - General troubleshooting
- [MONITORING.md](MONITORING.md) - System monitoring
- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture
