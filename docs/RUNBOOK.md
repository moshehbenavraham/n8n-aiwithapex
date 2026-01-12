# Operations Runbook

Day-to-day operations reference for the n8n stack.

---

## Deployment Context

This runbook covers operations for **both deployment forms**:

| Deployment | Status | Primary Operations |
|------------|--------|-------------------|
| **WSL2 (Local)** | Operational | This document |
| **Coolify (Cloud)** | Planning | [Coolify Operations](#coolify-operations) |

See [Deployment Comparison](deployment-comparison.md) for detailed differences.

---

## Quick Reference

### Essential Commands

| Task | Command |
|------|---------|
| Check status | `./scripts/system-status.sh` |
| View logs | `./scripts/view-logs.sh -f` |
| Health check | `./scripts/health-check.sh` |
| Start stack | `docker compose up -d` |
| Stop stack | `docker compose down` |
| Restart stack | `docker compose down && docker compose up -d` |
| Resource usage | `./scripts/monitor-resources.sh` |

### Service-Specific Commands

| Service | Start | Stop | Restart | Logs |
|---------|-------|------|---------|------|
| All | `docker compose up -d` | `docker compose down` | `docker compose restart` | `./scripts/view-logs.sh -f` |
| n8n | `docker compose up -d n8n` | `docker compose stop n8n` | `docker compose restart n8n` | `./scripts/view-logs.sh -s n8n` |
| Workers | `docker compose up -d n8n-worker` | `docker compose stop n8n-worker` | `docker compose restart n8n-worker` | `./scripts/view-logs.sh -s worker` |
| PostgreSQL | `docker compose up -d postgres` | `docker compose stop postgres` | `docker compose restart postgres` | `./scripts/view-logs.sh -s postgres` |
| Redis | `docker compose up -d redis` | `docker compose stop redis` | `docker compose restart redis` | `./scripts/view-logs.sh -s redis` |
| ngrok | `./scripts/tunnel-manage.sh start` | `./scripts/tunnel-manage.sh stop` | `./scripts/tunnel-manage.sh restart` | `./scripts/view-logs.sh -s ngrok` |

### Backup Commands

| Task | Command |
|------|---------|
| Full backup | `./scripts/backup-all.sh` |
| PostgreSQL only | `./scripts/backup-postgres.sh` |
| Redis only | `./scripts/backup-redis.sh` |
| n8n data only | `./scripts/backup-n8n.sh` |
| Cleanup old backups | `./scripts/cleanup-backups.sh` |

---

## Daily Operations

### Morning Checklist

Run these checks at the start of each day:

```bash
# 1. Quick health check
./scripts/health-check.sh

# 2. View system status dashboard
./scripts/system-status.sh

# 3. Check for any errors in logs (last 1 hour)
./scripts/view-logs.sh -n 100 | grep -i "error\|warn"
```

**What to look for**:
- All containers showing "healthy"
- No unusual memory/CPU usage
- No error patterns in logs
- Queue processing (waiting count near 0)

### Ongoing Monitoring

Check periodically throughout the day:

```bash
# Quick container status
docker compose ps

# Resource usage
docker stats --no-stream

# Queue status (via system status)
./scripts/system-status.sh
```

### End of Day

```bash
# Verify backups ran
ls -lt backups/postgres/ | head -3

# Check disk space
df -h

# Review any accumulated warnings
./scripts/view-logs.sh -n 500 | grep -i warn | sort | uniq -c | sort -rn | head -10
```

---

## Weekly Maintenance

### Weekly Checklist

Perform these tasks weekly (suggested: Monday morning):

- [ ] **Verify backup integrity**
  ```bash
  # Check latest backup is valid
  gunzip -t backups/postgres/$(ls -t backups/postgres/ | head -1)
  echo "Backup integrity: OK"
  ```

- [ ] **Clean up old backups**
  ```bash
  ./scripts/cleanup-backups.sh
  ```

- [ ] **Check disk usage**
  ```bash
  df -h
  docker system df
  ```

- [ ] **Review execution statistics**
  - Login to n8n UI
  - Check Executions tab
  - Note any failed workflows

- [ ] **Prune Docker resources** (if disk is low)
  ```bash
  docker system prune -f
  ```

### PostgreSQL Maintenance

```bash
# Check database size
docker exec n8n-postgres psql -U n8n -c "\l+"

# Check table sizes
docker exec n8n-postgres psql -U n8n -c "
  SELECT schemaname, tablename,
         pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename)) as size
  FROM pg_tables
  WHERE schemaname = 'public'
  ORDER BY pg_total_relation_size(schemaname || '.' || tablename) DESC
  LIMIT 10;"
```

---

## Monthly Maintenance

### Monthly Checklist

Perform these tasks monthly (suggested: first Monday):

- [ ] **Full system review**
  ```bash
  ./scripts/system-status.sh
  ./scripts/monitor-resources.sh
  ```

- [ ] **PostgreSQL vacuum** (if not auto-vacuum)
  ```bash
  docker exec n8n-postgres psql -U n8n -c "VACUUM ANALYZE;"
  ```

- [ ] **Security review**
  - Review n8n user accounts
  - Check for unused workflows with credentials
  - Verify .env not in git: `git status | grep .env`

- [ ] **Check for version updates**
  ```bash
  # Check current versions
  docker exec n8n-main n8n --version
  docker exec n8n-postgres postgres --version
  docker exec n8n-redis redis-server --version
  ```
  - Review n8n releases: https://github.com/n8n-io/n8n/releases
  - Plan upgrades if needed

- [ ] **Backup retention review**
  ```bash
  # Count backups by type
  echo "PostgreSQL: $(ls backups/postgres/*.sql.gz 2>/dev/null | wc -l) backups"
  echo "Redis: $(ls backups/redis/*.rdb 2>/dev/null | wc -l) backups"
  echo "n8n: $(ls backups/n8n/*.tar.gz 2>/dev/null | wc -l) backups"
  ```

- [ ] **Log rotation check**
  ```bash
  du -sh logs/
  ```

---

## Common Operations

### Scaling Workers

To adjust worker count temporarily:

```bash
# Scale to 3 workers
docker compose up -d --scale n8n-worker=3

# Scale back to 5 workers (default)
docker compose up -d --scale n8n-worker=5
```

For permanent change, edit docker-compose.yml:
```yaml
n8n-worker:
  deploy:
    replicas: 5  # Change this number
```

### Viewing Logs

```bash
# All services, follow mode
./scripts/view-logs.sh -f

# Specific service
./scripts/view-logs.sh -s n8n -n 100

# Filter for errors
./scripts/view-logs.sh -n 500 | grep -i error

# Specific time range (via docker)
docker compose logs --since 1h
docker compose logs --since "2025-01-01T10:00:00"
```

### Manual Backup

```bash
# Full backup with timestamp
./scripts/backup-all.sh

# Just PostgreSQL
./scripts/backup-postgres.sh

# Verify backup created
ls -lt backups/*/
```

### Graceful Restart

To restart without losing in-flight jobs:

```bash
# 1. Stop accepting new jobs (pause workers)
docker compose stop n8n-worker

# 2. Wait for current jobs to complete (check queue)
./scripts/system-status.sh  # Wait until queue is empty

# 3. Restart everything
docker compose down
docker compose up -d
```

### Emergency Stop

If something is broken and needs immediate stop:

```bash
# Stop all containers immediately
docker compose down

# If containers won't stop
docker compose kill
docker compose down

# Nuclear option (removes containers)
docker compose down --remove-orphans
```

---

## Tunnel Operations

The ngrok tunnel provides external access for webhooks and authenticated UI access.

### Quick Status Check

```bash
# Check tunnel is connected
./scripts/tunnel-manage.sh status

# Detailed status with metrics
./scripts/tunnel-status.sh
```

### Starting/Stopping Tunnel

```bash
# Start tunnel
./scripts/tunnel-manage.sh start

# Stop tunnel (webhooks will fail while stopped)
./scripts/tunnel-manage.sh stop

# Restart tunnel (clears connections)
./scripts/tunnel-manage.sh restart
```

### Viewing Tunnel Logs

```bash
# Recent logs
./scripts/view-logs.sh -s ngrok -n 50

# Follow logs in real-time
./scripts/view-logs.sh -s ngrok -f
```

### Web Inspector

Access the ngrok web inspector for request debugging:
- URL: http://localhost:4040
- Shows all requests through the tunnel
- Useful for debugging webhook deliveries

### Common Tunnel Tasks

| Task | Command |
|------|---------|
| Check status | `./scripts/tunnel-manage.sh status` |
| Restart tunnel | `./scripts/tunnel-manage.sh restart` |
| View logs | `./scripts/view-logs.sh -s ngrok` |
| Debug requests | Open http://localhost:4040 |

### Tunnel Health in Morning Checklist

Add to your morning checks:

```bash
# Include tunnel status
./scripts/tunnel-manage.sh status
```

**What to look for**:
- Tunnel connected and healthy
- Active tunnels count = 1 (or more if multi-service)
- No repeated reconnection in logs

---

## Troubleshooting Quick Links

| Issue | Solution |
|-------|----------|
| Container not starting | Check logs: `docker compose logs <service>` |
| High memory | See [TROUBLESHOOTING.md](TROUBLESHOOTING.md#high-memory-usage) |
| Workflows not running | Check queue: `./scripts/system-status.sh` |
| Database issues | See [RECOVERY.md](RECOVERY.md#postgresql-recovery) |
| Slow performance | Run: `./scripts/monitor-resources.sh` |
| Tunnel not connecting | See [TROUBLESHOOTING.md](TROUBLESHOOTING.md#tunnel-issues) |
| Webhooks not working | Check: `./scripts/tunnel-manage.sh status` |

---

## Key Paths

| Resource | Path |
|----------|------|
| Project root | `/home/aiwithapex/n8n` |
| Docker Compose | `docker-compose.yml` |
| Environment | `.env` |
| Scripts | `scripts/` |
| Backups | `backups/` |
| Logs | `logs/` |
| n8n Data (volume) | `n8n_n8n_data` |
| PostgreSQL Data (volume) | `n8n_postgres_data` |
| Redis Data (volume) | `n8n_redis_data` |

---

---

## Coolify Operations

Operations for the Coolify cloud deployment differ from WSL2. This section covers Coolify-specific operations.

> **Note**: The Coolify deployment is currently in PLANNING status. These operations will be applicable once deployed.

### Dashboard Access

- **Coolify Dashboard**: https://coolify.aiwithapex.com
- **n8n Production**: https://n8n.aiwithapex.com (planned)

### Essential Operations (Coolify)

| Task | Method |
|------|--------|
| Check status | Coolify Dashboard → Application → Status |
| View logs | Coolify Dashboard → Application → Logs |
| Deploy | Coolify Dashboard → Application → Deploy |
| Restart | Coolify Dashboard → Application → Restart |
| Stop | Coolify Dashboard → Application → Stop |

### Coolify API Commands

```bash
# Set environment
export COOLIFY_API_TOKEN="<your-token>"
export COOLIFY_API_URL="https://coolify.aiwithapex.com/api/v1"

# Check application status
curl -s "${COOLIFY_API_URL}/applications/<uuid>" \
  -H "Authorization: Bearer ${COOLIFY_API_TOKEN}" | jq '.status'

# Deploy application
curl -X POST "${COOLIFY_API_URL}/applications/<uuid>/deploy" \
  -H "Authorization: Bearer ${COOLIFY_API_TOKEN}"

# Stop application
curl -X POST "${COOLIFY_API_URL}/applications/<uuid>/stop" \
  -H "Authorization: Bearer ${COOLIFY_API_TOKEN}"

# Start application
curl -X POST "${COOLIFY_API_URL}/applications/<uuid>/start" \
  -H "Authorization: Bearer ${COOLIFY_API_TOKEN}"
```

### Health Checks (Coolify)

```bash
# n8n health endpoint
curl -s "https://n8n.aiwithapex.com/healthz"

# Prometheus metrics
curl -s "https://n8n.aiwithapex.com/metrics" | head -20
```

### Log Access (Coolify)

Logs are accessed via the Coolify dashboard:

1. Navigate to Coolify Dashboard
2. Select the n8n application
3. Click **Logs** tab
4. Select specific service (n8n, worker, postgres, redis)

Or via Docker on the Coolify server:

```bash
# SSH to Coolify server, then:
docker logs n8n-<uuid> --tail 100
docker logs n8n-worker-1-<uuid> --tail 100
```

### Scaling Workers (Coolify)

To adjust worker count in Coolify:

1. Edit `docker-compose.coolify.yml`
2. Add/remove `n8n-worker-N` service definitions
3. Commit and push to GitHub
4. Redeploy via Coolify dashboard

### Backup (Coolify)

```bash
# Export via n8n API
curl -X GET "https://n8n.aiwithapex.com/api/v1/workflows" \
  -H "X-N8N-API-KEY: <api-key>" > workflows-backup.json

# Database dump (via Coolify server SSH)
docker exec postgres-<uuid> pg_dump -U n8n n8n > backup.sql
```

### Key UUIDs (Coolify)

| Resource | UUID |
|----------|------|
| Server | `rcgk0og40w0kwogock4k44s0` |
| Project | `m4cck40w0go4k88gwcg4k400` |
| Environment | `sko8scc0c0ok8gcwo0gscw8o` |
| Current n8n | `g8wow80sgg8oo0csg4sgkws0` |

### Coolify-Specific Documentation

- [Deploy to Coolify](ongoing-roadmap/deploy-to-coolify.md) - Full deployment guide
- [Coolify API Reference](https://coolify.io/docs/api-reference) - Official API docs

---

## Related Documentation

- [Deployment Comparison](deployment-comparison.md) - WSL2 vs Coolify
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Problem diagnosis and fixes
- [TUNNELS.md](TUNNELS.md) - Tunnel configuration (WSL2)
- [RECOVERY.md](RECOVERY.md) - Disaster recovery procedures
- [UPGRADE.md](UPGRADE.md) - Version upgrade procedures
- [SECURITY.md](SECURITY.md) - Security configuration
- [MONITORING.md](MONITORING.md) - Monitoring details
- [SCALING.md](SCALING.md) - Worker scaling configuration
