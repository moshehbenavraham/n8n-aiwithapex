# Monitoring Runbook

This document provides operational guidance for monitoring the n8n stack on WSL2.

## Quick Reference

### Monitoring Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `health-check.sh` | Validate container and endpoint health | `./scripts/health-check.sh` |
| `monitor-resources.sh` | Check resource usage against thresholds | `./scripts/monitor-resources.sh` |
| `view-logs.sh` | View container logs with filtering | `./scripts/view-logs.sh -s n8n -n 100` |
| `system-status.sh` | Dashboard-style status overview | `./scripts/system-status.sh` |

### Thresholds (WSL2 8GB Environment)

| Resource | Threshold | Rationale |
|----------|-----------|-----------|
| Memory | 80% (6.4GB) | Leave headroom for WSL2 overhead |
| CPU | 90% | Per-container, sustained usage |
| Disk | 85% | Allow space for logs and backups |

## Daily Operations

### Morning Health Check

Run the system status dashboard to verify all systems are healthy:

```bash
./scripts/system-status.sh
```

Expected output should show:
- All 8 containers running and healthy
- Memory below 80%
- All endpoints responding OK
- Queue with no failed jobs

### Monitoring Resources

Check resource consumption:

```bash
./scripts/monitor-resources.sh
```

If thresholds are exceeded:
1. Identify the highest-consuming container
2. Check for stuck workflows or runaway processes
3. Restart affected container if needed

### Viewing Logs

View logs for specific services:

```bash
# All services (last 100 lines)
./scripts/view-logs.sh

# Specific service
./scripts/view-logs.sh -s n8n -n 50

# Follow logs in real-time
./scripts/view-logs.sh -s worker -f

# PostgreSQL logs
./scripts/view-logs.sh -s postgres -n 200
```

## Alert Thresholds

### Memory Alert (80%)

**Trigger**: System memory exceeds 80% (6.4GB of 8GB)

**Impact**: WSL2 may become unresponsive, containers may be OOM killed

**Response**:
1. Run `./scripts/system-status.sh` to identify memory consumers
2. Check for stuck workflows in n8n
3. Restart workers if memory leak suspected: `docker compose restart n8n-worker`
4. Consider reducing worker replicas if persistent

### CPU Alert (90%)

**Trigger**: Any container exceeds 90% CPU for sustained period

**Impact**: Workflow execution slowdown, queue backlog

**Response**:
1. Identify high-CPU container
2. Check for infinite loops in workflows
3. Review recent workflow changes
4. Scale workers if legitimate load

### Disk Alert (85%)

**Trigger**: Disk usage exceeds 85%

**Impact**: Container logs may fail, backups may fail

**Response**:
1. Run backup cleanup: `./scripts/cleanup-backups.sh`
2. Check Docker logs: `docker system df`
3. Prune unused Docker resources: `docker system prune`

## Queue Monitoring

The system uses Redis with Bull queue for job processing.

### Healthy Queue State
- Waiting: 0-10 (transient)
- Active: 0-5 (workers processing)
- Failed: 0 (no failures)

### Queue Issues

**High Waiting Count**:
- Workers may be stuck or slow
- Check worker logs: `./scripts/view-logs.sh -s worker -f`
- Restart workers: `docker compose restart n8n-worker`

**Failed Jobs**:
- Check worker logs for errors
- Review workflow configurations
- Failed jobs can be retried from n8n UI

## Docker Log Rotation

### Configuration (T023)

Docker logs can grow unbounded without rotation. Configure log rotation:

1. Create or edit `/etc/docker/daemon.json` (requires sudo):

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

2. Apply the configuration:

```bash
sudo systemctl restart docker
```

**Note**: This affects new containers. Existing containers retain their log settings until recreated.

### Verifying Log Rotation

Check current log sizes:

```bash
docker inspect --format='{{.LogPath}}' n8n-main
ls -lh /var/lib/docker/containers/*/

# Or use docker system df
docker system df -v
```

## Endpoint Monitoring

### Health Endpoints

| Endpoint | URL | Expected Response |
|----------|-----|-------------------|
| Health Check | http://localhost:5678/healthz | HTTP 200 |
| Web UI | http://localhost:5678 | HTTP 200/302 |
| Metrics | http://localhost:5678/metrics | HTTP 200 (Prometheus format) |

### Database Connections

| Service | Check Command |
|---------|---------------|
| PostgreSQL | `docker exec n8n-postgres pg_isready -U n8n` |
| Redis | `docker exec n8n-redis redis-cli -p 6386 PING` |

## Scheduled Monitoring

### Cron Setup (Optional)

Add monitoring to crontab for regular checks:

```bash
# Edit crontab
crontab -e

# Add entries
# Health check every 5 minutes (log only)
*/5 * * * * /path/to/n8n/scripts/health-check.sh >> /path/to/n8n/logs/health-check.log 2>&1

# Full status every hour
0 * * * * /path/to/n8n/scripts/system-status.sh >> /path/to/n8n/logs/hourly-status.log 2>&1
```

## Exit Codes

All monitoring scripts follow consistent exit codes:

| Code | Meaning |
|------|---------|
| 0 | All checks passed / healthy |
| 1 | Critical failure / unhealthy |
| 2 | Warning / partial health |

Use exit codes for automation:

```bash
if ./scripts/health-check.sh; then
    echo "System healthy"
else
    echo "System needs attention"
fi
```

## Related Documentation

- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and solutions
- [SCALING.md](SCALING.md) - Worker scaling configuration
- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture overview
