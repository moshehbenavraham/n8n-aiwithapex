# Troubleshooting Guide

Decision tree and common fixes for n8n stack issues.

## Quick Diagnosis

Run the system status dashboard first:

```bash
./scripts/system-status.sh
```

This provides an overview of:
- Container health
- Resource usage
- Queue status
- Endpoint availability

## Decision Tree

### Container Not Running

```
Container not running?
|
+-> Check docker compose status
|   $ docker compose ps
|
+-> Is container exited?
|   |
|   +-> Yes: Check exit code and logs
|   |   $ docker compose logs <service> --tail 50
|   |
|   +-> No: Container may be restarting
|       $ docker compose logs <service> -f
|
+-> Restart the service
    $ docker compose restart <service>
```

### Container Unhealthy

```
Container shows (unhealthy)?
|
+-> Check health check logs
|   $ docker inspect <container> --format='{{json .State.Health}}'
|
+-> Service-specific checks:
|   |
|   +-> postgres: Check connections
|   |   $ docker exec n8n-postgres pg_isready -U n8n
|   |
|   +-> redis: Check ping
|   |   $ docker exec n8n-redis redis-cli -p 6386 PING
|   |
|   +-> n8n/worker: Check healthz endpoint
|       $ curl http://localhost:5678/healthz
|
+-> Restart if needed
    $ docker compose restart <service>
```

### High Memory Usage

```
Memory above 80%?
|
+-> Identify consumer
|   $ docker stats --no-stream | sort -k4 -h
|
+-> Is it a specific container?
|   |
|   +-> Worker: May have memory leak
|   |   $ docker compose restart n8n-worker
|   |
|   +-> n8n main: Check for large workflows
|   |   Review active executions in UI
|   |
|   +-> postgres: Check for long queries
|       $ docker exec n8n-postgres psql -U n8n -c "SELECT * FROM pg_stat_activity WHERE state = 'active';"
|
+-> System-wide high memory?
    Consider reducing worker replicas
    Edit docker-compose.yml: replicas: 3
```

### Workflows Not Executing

```
Workflows stuck or not running?
|
+-> Check queue status
|   $ ./scripts/system-status.sh
|
+-> High waiting count?
|   |
|   +-> Workers may be stuck
|       $ ./scripts/view-logs.sh -s worker -n 100
|       $ docker compose restart n8n-worker
|
+-> Failed jobs in queue?
|   |
|   +-> Check worker logs for errors
|   |   $ ./scripts/view-logs.sh -s worker -f
|   |
|   +-> Retry from n8n UI or clear failed jobs
|
+-> Check n8n main is healthy
    $ curl http://localhost:5678/healthz
```

### Endpoint Not Responding

```
HTTP endpoint not responding?
|
+-> Check container is running
|   $ docker compose ps
|
+-> Check port binding
|   $ docker port n8n-main 5678
|
+-> Test from inside container
|   $ docker exec n8n-main curl -s http://localhost:5678/healthz
|
+-> Check for port conflicts
    $ netstat -tlnp | grep 5678
```

## Common Issues and Fixes

### 1. Redis vm.overcommit_memory Warning

**Symptom**: Redis logs show warning about vm.overcommit_memory

**Cause**: WSL2 kernel setting not optimal for Redis

**Temporary Fix** (resets on WSL restart):
```bash
sudo sysctl vm.overcommit_memory=1
```

**Permanent Fix** (persists across restarts):

1. Create sysctl configuration file:
   ```bash
   sudo tee /etc/sysctl.d/99-redis.conf << 'EOF'
   # Redis optimization for WSL2
   # Prevents Redis background save failures under memory pressure
   vm.overcommit_memory = 1
   EOF
   ```

2. Apply the setting immediately:
   ```bash
   sudo sysctl -p /etc/sysctl.d/99-redis.conf
   ```

3. Verify the setting:
   ```bash
   sysctl vm.overcommit_memory
   # Should output: vm.overcommit_memory = 1
   ```

4. Restart Redis to clear warning from logs:
   ```bash
   docker compose restart redis
   ```

**Note**: This fix requires sudo access. The sysctl.d configuration will persist across WSL restarts.

**Verification**: After applying, check Redis logs for the warning:
```bash
docker compose logs redis --tail 50 | grep -i overcommit
# Should return no results (warning cleared)
```

### 2. PostgreSQL Connection Refused

**Symptom**: n8n cannot connect to PostgreSQL

**Checks**:
```bash
# Is postgres running?
docker compose ps postgres

# Check postgres logs
./scripts/view-logs.sh -s postgres -n 50

# Test connection
docker exec n8n-postgres pg_isready -U n8n
```

**Fixes**:
- Restart postgres: `docker compose restart postgres`
- Check disk space: `df -h`
- Check postgres data volume: `docker volume ls`

### 3. Workers Not Processing Jobs

**Symptom**: Jobs pile up in queue, workers not processing

**Checks**:
```bash
# Check worker health
docker compose ps n8n-worker

# Check worker logs
./scripts/view-logs.sh -s worker -f

# Check queue status
./scripts/system-status.sh
```

**Fixes**:
- Restart workers: `docker compose restart n8n-worker`
- Check Redis connectivity from worker container
- Verify QUEUE_BULL_REDIS_HOST environment variable

### 4. Disk Space Running Low

**Symptom**: Containers failing, logs not writing

**Checks**:
```bash
# System disk
df -h

# Docker disk usage
docker system df

# Backup directory
du -sh backups/
```

**Fixes**:
```bash
# Clean old backups
./scripts/cleanup-backups.sh

# Prune Docker
docker system prune -f

# Remove old images
docker image prune -a
```

### 5. Container Keeps Restarting

**Symptom**: Container in restart loop

**Checks**:
```bash
# Check restart count
docker inspect <container> --format='{{.RestartCount}}'

# Check last exit code
docker inspect <container> --format='{{.State.ExitCode}}'

# Check logs
docker compose logs <service> --tail 100
```

**Common Exit Codes**:
| Code | Meaning |
|------|---------|
| 0 | Normal exit |
| 1 | Application error |
| 137 | OOM killed (SIGKILL) |
| 139 | Segmentation fault |
| 143 | Graceful termination (SIGTERM) |

### 6. n8n Web UI Not Loading

**Symptom**: Browser shows error or timeout

**Checks**:
```bash
# Check n8n container
docker compose ps n8n

# Check healthz
curl -v http://localhost:5678/healthz

# Check n8n logs
./scripts/view-logs.sh -s n8n -n 100
```

**Fixes**:
- Restart n8n: `docker compose restart n8n`
- Check for JavaScript errors in browser console
- Clear browser cache

### 7. Database Connections Exhausted

**Symptom**: "too many connections" errors in logs

**Checks**:
```bash
# Check active connections
docker exec n8n-postgres psql -U n8n -c "SELECT count(*) FROM pg_stat_activity;"

# Check max connections
docker exec n8n-postgres psql -U n8n -c "SHOW max_connections;"
```

**Fixes**:
- Restart n8n and workers to release connections
- Increase max_connections in postgresql.conf
- Check for connection leaks in workflows

### 8. Slow Workflow Execution

**Symptom**: Workflows taking longer than expected

**Checks**:
```bash
# Check resource usage
./scripts/monitor-resources.sh

# Check queue status
./scripts/system-status.sh

# Check for high CPU containers
docker stats --no-stream
```

**Fixes**:
- Scale workers if CPU is bottleneck
- Check for inefficient workflow logic
- Review external API timeouts

## Tunnel Issues

### 9. Tunnel Not Connecting

**Symptom**: ngrok container running but tunnel not connected, or container restarting

**Checks**:
```bash
# Check tunnel status
./scripts/tunnel-manage.sh status

# Check ngrok logs for errors
./scripts/view-logs.sh -s ngrok -n 50

# Verify authtoken is set
grep NGROK_AUTHTOKEN .env
```

**Common Error Codes**:
| Error | Meaning | Fix |
|-------|---------|-----|
| ERR_NGROK_105 | Invalid authtoken | Update NGROK_AUTHTOKEN in .env |
| ERR_NGROK_108 | Tunnel session limit | Check ngrok dashboard for active sessions |
| ERR_NGROK_120 | Domain not authorized | Verify domain in ngrok dashboard |

**Fixes**:
- Verify authtoken: Ensure NGROK_AUTHTOKEN is correct in .env
- Check domain: Verify custom domain is configured in ngrok dashboard
- Restart tunnel: `./scripts/tunnel-manage.sh restart`

### 10. Webhooks Not Received

**Symptom**: External services report webhook delivery failures

**Checks**:
```bash
# Verify tunnel is connected
./scripts/tunnel-manage.sh status

# Check ngrok web inspector for incoming requests
# Open http://localhost:4040 in browser

# Check n8n is receiving requests
./scripts/view-logs.sh -s n8n -n 100 | grep webhook
```

**Fixes**:
- Tunnel down: `./scripts/tunnel-manage.sh start`
- n8n not responding: `docker compose restart n8n`
- Wrong webhook URL: Verify URL includes /webhook/ prefix

### 11. OAuth Login Failing

**Symptom**: Google OAuth loop or access denied at ngrok

**Checks**:
```bash
# Check traffic policy in ngrok.yml
cat config/ngrok.yml | grep -A 10 oauth

# Verify allowed domains
cat config/ngrok.yml | grep endsWith
```

**Fixes**:
- Email domain not allowed: Add domain to traffic policy
- OAuth provider issue: Check Google Cloud Console for OAuth app status
- Cookie issue: Clear browser cookies and try again

### 12. Tunnel API Unreachable

**Symptom**: tunnel-manage.sh shows API unreachable

**Checks**:
```bash
# Verify container is running
docker ps | grep ngrok

# Check port binding
docker port n8n-ngrok 4040

# Test API directly
curl -s http://localhost:4040/api/tunnels
```

**Fixes**:
- Port conflict: Check if port 4040 is in use by another process
- Container issue: `./scripts/tunnel-manage.sh restart`
- Firewall: Ensure localhost:4040 is not blocked

### 13. Tunnel Disconnecting Frequently

**Symptom**: Tunnel drops and reconnects repeatedly

**Checks**:
```bash
# Check ngrok logs for patterns
./scripts/view-logs.sh -s ngrok -n 200 | grep -i "reconnect\|disconnect\|error"

# Check network stability
ping -c 5 google.com
```

**Fixes**:
- Network issues: Check internet connection stability
- Auth issues: Verify authtoken is still valid
- Rate limits: Check ngrok dashboard for rate limit warnings

### Tunnel Decision Tree

```
Tunnel not working?
|
+-> Is container running?
|   $ docker ps | grep ngrok
|   |
|   +-> No: Start tunnel
|   |   $ ./scripts/tunnel-manage.sh start
|   |
|   +-> Yes: Check API
|       $ ./scripts/tunnel-manage.sh status
|
+-> API reachable?
|   |
|   +-> No: Container issue
|   |   $ ./scripts/tunnel-manage.sh restart
|   |
|   +-> Yes: Check tunnel connection
|       $ curl http://localhost:4040/api/tunnels
|
+-> Tunnel connected?
|   |
|   +-> No: Check ngrok logs for errors
|   |   $ ./scripts/view-logs.sh -s ngrok -n 50
|   |
|   +-> Yes: Issue is elsewhere
|       Check n8n, network, or external service
```

---

## Log Management Issues

### 14. Disk Space Exhausted by Logs

**Symptom**: Disk full errors, containers failing to start, log writes failing

**Checks**:
```bash
# Check disk space
df -h

# Check container log sizes
./scripts/cleanup-logs.sh

# Find large log files
sudo find /var/lib/docker/containers -name "*-json.log" -size +100M
```

**Fixes**:
```bash
# Truncate container logs (requires sudo)
sudo ./scripts/cleanup-logs.sh --force

# Verify daemon.json is deployed
cat /etc/docker/daemon.json

# If not deployed, copy and restart Docker
sudo cp config/daemon.json /etc/docker/daemon.json
sudo systemctl restart docker
```

### 15. Logs Not Rotating

**Symptom**: Container log files growing beyond 100MB

**Checks**:
```bash
# Verify daemon.json exists
ls -la /etc/docker/daemon.json

# Check Docker logging driver config
docker info | grep -A 5 "Logging Driver"

# Verify compose logging config
docker compose config | grep -A 3 "logging:"
```

**Fixes**:
- Deploy daemon.json if missing
- Restart Docker after deploying daemon.json
- Note: Existing logs only rotate when they exceed max-size after restart

### 16. Cannot View Specific Service Logs

**Symptom**: view-logs.sh returns empty or shows wrong service

**Checks**:
```bash
# Verify container name
docker compose ps --format "{{.Names}}"

# Check view-logs.sh service mapping
./scripts/view-logs.sh --help
```

**Fixes**:
- Use correct service name: postgres, redis, n8n, worker, ngrok, all
- For worker logs specifically: `./scripts/view-logs.sh -s worker`

### Log Management Decision Tree

```
Disk filling up with logs?
|
+-> Check container log sizes
|   $ ./scripts/cleanup-logs.sh
|
+-> Is daemon.json deployed?
|   $ cat /etc/docker/daemon.json
|   |
|   +-> No: Deploy it
|   |   $ sudo cp config/daemon.json /etc/docker/daemon.json
|   |   $ sudo systemctl restart docker
|   |
|   +-> Yes: Check if rotation is working
|       $ sudo ls -la /var/lib/docker/containers/*/
|       Look for rotated files: *-json.log.1, *-json.log.2, etc.
|
+-> Need immediate space?
    $ sudo ./scripts/cleanup-logs.sh --force
```

---

## Emergency Procedures

### Full Stack Restart

When everything seems broken:

```bash
# Stop all containers
docker compose down

# Wait a moment
sleep 5

# Start fresh
docker compose up -d

# Watch logs
./scripts/view-logs.sh -f
```

### Data Recovery

If data corruption suspected:

```bash
# Stop services
docker compose down

# Restore from latest backup
./scripts/restore-postgres.sh backups/postgres/latest.sql.gz

# Start services
docker compose up -d
```

## Getting Help

1. Check logs first: `./scripts/view-logs.sh -s <service> -n 200`
2. Run full status: `./scripts/system-status.sh`
3. Check this troubleshooting guide
4. Review n8n documentation: https://docs.n8n.io

## Related Documentation

- [MONITORING.md](MONITORING.md) - Monitoring runbook
- [SCALING.md](SCALING.md) - Worker scaling configuration
- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture overview
- [TUNNELS.md](TUNNELS.md) - Tunnel configuration and multi-service architecture
- [log-management.md](log-management.md) - Log rotation and cleanup guide
