# Disaster Recovery Guide

Procedures for recovering the n8n stack from various failure scenarios.

## Overview

This guide covers:
- PostgreSQL database recovery
- Redis queue recovery
- n8n data recovery
- Full stack rebuild from scratch

## Prerequisites

Before starting any recovery procedure:

1. **Verify backups exist**:
   ```bash
   ls -la backups/postgres/
   ls -la backups/redis/
   ls -la backups/n8n/
   ```

2. **Check disk space**:
   ```bash
   df -h
   ```

3. **Stop affected services** (if running):
   ```bash
   docker compose down
   ```

---

## Recovery Scenarios

### Quick Reference

| Scenario | Recovery Time | Data Loss Risk |
|----------|---------------|----------------|
| PostgreSQL corruption | 10-15 minutes | Minimal (last backup) |
| Redis failure | 5 minutes | Queue jobs only |
| n8n container failure | 5 minutes | None |
| Full host failure | 30-45 minutes | Depends on backup age |
| Volume corruption | 15-20 minutes | Minimal (last backup) |

---

## PostgreSQL Recovery

### Scenario: Database Corruption or Data Loss

**Symptoms**:
- n8n shows database connection errors
- Workflows missing or corrupted
- Credentials lost

**Recovery Steps**:

1. **Stop n8n services** (keep postgres running):
   ```bash
   docker compose stop n8n n8n-worker
   ```

2. **List available backups**:
   ```bash
   ls -lt backups/postgres/ | head -10
   ```

3. **Choose backup to restore** (most recent or known-good):
   ```bash
   # Example: latest backup
   BACKUP_FILE=$(ls -t backups/postgres/*.sql.gz | head -1)
   echo "Restoring from: $BACKUP_FILE"
   ```

4. **Run restore script**:
   ```bash
   ./scripts/restore-postgres.sh "$BACKUP_FILE"
   ```

5. **Start n8n services**:
   ```bash
   docker compose up -d n8n n8n-worker
   ```

6. **Verify recovery**:
   ```bash
   # Check n8n health
   curl http://localhost:5678/healthz

   # Check workflows in UI
   # Login and verify workflows are present
   ```

### Scenario: PostgreSQL Container Won't Start

1. **Check container logs**:
   ```bash
   docker compose logs postgres --tail 100
   ```

2. **Common fixes**:
   - Out of disk space: Clean up and restart
   - Corrupt data directory: Restore from volume backup
   - Configuration error: Check postgresql.conf

3. **Last resort - rebuild from backup**:
   ```bash
   # Remove corrupted volume
   docker compose down
   docker volume rm n8n_postgres_data

   # Recreate and restore
   docker compose up -d postgres
   sleep 10  # Wait for postgres to initialize
   ./scripts/restore-postgres.sh backups/postgres/latest.sql.gz
   docker compose up -d
   ```

---

## Redis Recovery

### Scenario: Redis Failure

**Symptoms**:
- Workflows not executing
- Queue status shows errors
- Workers not picking up jobs

**Recovery Steps**:

1. **Check Redis status**:
   ```bash
   docker compose ps redis
   docker exec n8n-redis redis-cli -p 6386 PING
   ```

2. **Restart Redis**:
   ```bash
   docker compose restart redis
   ```

3. **If restart fails, rebuild**:
   ```bash
   docker compose stop redis
   docker volume rm n8n_redis_data
   docker compose up -d redis
   ```

4. **Restart workers to reconnect**:
   ```bash
   docker compose restart n8n n8n-worker
   ```

**Note**: Redis primarily stores the job queue. Losing Redis data means in-flight jobs may be lost, but no workflow definitions or execution history is affected (those are in PostgreSQL).

### Restoring Redis from Backup

If you have a Redis RDB backup:

1. **Stop Redis**:
   ```bash
   docker compose stop redis
   ```

2. **Copy backup to volume**:
   ```bash
   # Find latest backup
   REDIS_BACKUP=$(ls -t backups/redis/*.rdb 2>/dev/null | head -1)

   # Copy to Redis data volume
   docker run --rm -v n8n_redis_data:/data -v "$(pwd)/backups/redis:/backup" \
     alpine cp "/backup/$(basename $REDIS_BACKUP)" /data/dump.rdb
   ```

3. **Start Redis**:
   ```bash
   docker compose up -d redis
   ```

---

## n8n Data Recovery

### Scenario: n8n Container Crash

1. **Check container status and logs**:
   ```bash
   docker compose ps n8n
   docker compose logs n8n --tail 100
   ```

2. **Restart the container**:
   ```bash
   docker compose restart n8n
   ```

3. **Wait for health check**:
   ```bash
   docker compose ps
   # Wait until status shows (healthy)
   ```

### Scenario: n8n Volume Data Corruption

1. **Stop n8n services**:
   ```bash
   docker compose stop n8n n8n-worker
   ```

2. **Backup current (potentially corrupt) data**:
   ```bash
   docker run --rm -v n8n_n8n_data:/data -v "$(pwd):/backup" \
     alpine tar czf /backup/n8n-corrupt-$(date +%Y%m%d).tar.gz /data
   ```

3. **Restore from backup**:
   ```bash
   # Find latest n8n backup
   N8N_BACKUP=$(ls -t backups/n8n/*.tar.gz 2>/dev/null | head -1)

   # Clear volume and restore
   docker volume rm n8n_n8n_data
   docker volume create n8n_n8n_data
   docker run --rm -v n8n_n8n_data:/data -v "$(pwd)/backups/n8n:/backup" \
     alpine sh -c "cd /data && tar xzf /backup/$(basename $N8N_BACKUP) --strip-components=1"
   ```

4. **Start services**:
   ```bash
   docker compose up -d
   ```

---

## Full Stack Rebuild

### Scenario: Complete System Recovery from Scratch

Use this when recovering on a new machine or after catastrophic failure.

**Requirements**:
- Docker and Docker Compose installed
- Backup files available
- Access to project repository (or backup of project files)

**Recovery Procedure**:

1. **Clone or copy project files**:
   ```bash
   git clone <repository-url> n8n
   cd n8n
   ```

2. **Restore environment configuration**:
   ```bash
   # Copy .env from backup or recreate from .env.example
   cp /path/to/backup/.env .env
   # Or: cp .env.example .env && nano .env
   ```

3. **Pull Docker images**:
   ```bash
   docker compose pull
   ```

4. **Start database only**:
   ```bash
   docker compose up -d postgres
   sleep 15  # Wait for postgres to fully initialize
   ```

5. **Restore PostgreSQL data**:
   ```bash
   ./scripts/restore-postgres.sh /path/to/backup/postgres/backup.sql.gz
   ```

6. **Start Redis**:
   ```bash
   docker compose up -d redis
   sleep 5
   ```

7. **Optionally restore Redis data** (if backup exists):
   ```bash
   docker compose stop redis
   docker run --rm -v n8n_redis_data:/data -v "/path/to/backup/redis:/backup" \
     alpine cp /backup/dump.rdb /data/
   docker compose up -d redis
   ```

8. **Start n8n and workers**:
   ```bash
   docker compose up -d n8n n8n-worker
   ```

9. **Verify full stack**:
   ```bash
   ./scripts/health-check.sh
   curl http://localhost:5678/healthz
   ```

10. **Test login and workflows**:
    - Access http://localhost:5678
    - Login with existing credentials
    - Verify workflows are present
    - Test execution of a simple workflow

---

## Backup Verification

Periodically verify backups are restorable:

### Verify PostgreSQL Backup Integrity

```bash
# Check backup file
ls -la backups/postgres/
gunzip -t backups/postgres/latest.sql.gz && echo "Backup file OK"

# Optional: Test restore to temporary database
docker exec n8n-postgres psql -U n8n -d postgres -c "CREATE DATABASE test_restore;"
gunzip -c backups/postgres/latest.sql.gz | docker exec -i n8n-postgres psql -U n8n -d test_restore
docker exec n8n-postgres psql -U n8n -d postgres -c "DROP DATABASE test_restore;"
```

### Verify Backup Schedule

```bash
# Check cron is running backups
crontab -l | grep backup

# Check recent backup files
find backups/ -type f -mtime -1 -ls
```

---

## Recovery Checklist

After any recovery procedure:

- [ ] All containers show healthy status
- [ ] n8n UI accessible at http://localhost:5678
- [ ] Can login with existing credentials
- [ ] Workflows are visible
- [ ] Test workflow executes successfully
- [ ] Workers are processing jobs (check queue status)
- [ ] Backup schedule is active

---

## Emergency Contacts

For issues beyond this guide:

- n8n Community Forum: https://community.n8n.io
- n8n Documentation: https://docs.n8n.io
- PostgreSQL Documentation: https://www.postgresql.org/docs/16/

---

## Related Documentation

- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and fixes
- [RUNBOOK.md](RUNBOOK.md) - Day-to-day operations
- [UPGRADE.md](UPGRADE.md) - Version upgrades
- [SECURITY.md](SECURITY.md) - Security configuration
