# Operations Runbook

Day-to-day operations reference for the n8n stack.

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

## Troubleshooting Quick Links

| Issue | Solution |
|-------|----------|
| Container not starting | Check logs: `docker compose logs <service>` |
| High memory | See [TROUBLESHOOTING.md](TROUBLESHOOTING.md#high-memory-usage) |
| Workflows not running | Check queue: `./scripts/system-status.sh` |
| Database issues | See [RECOVERY.md](RECOVERY.md#postgresql-recovery) |
| Slow performance | Run: `./scripts/monitor-resources.sh` |

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

## Related Documentation

- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Problem diagnosis and fixes
- [RECOVERY.md](RECOVERY.md) - Disaster recovery procedures
- [UPGRADE.md](UPGRADE.md) - Version upgrade procedures
- [SECURITY.md](SECURITY.md) - Security configuration
- [MONITORING.md](MONITORING.md) - Monitoring details
- [SCALING.md](SCALING.md) - Worker scaling configuration
