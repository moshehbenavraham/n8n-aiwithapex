# Version Upgrade Guide

Procedures for upgrading n8n, PostgreSQL, and Redis versions safely.

## Overview

This guide covers:
- Pre-upgrade preparation
- Version upgrade procedures
- Rollback procedures
- Post-upgrade verification

## Current Pinned Versions

| Component | Image Tag | Version |
|-----------|-----------|---------|
| n8n | n8nio/n8n:2.1.4 | 2.1.4 |
| PostgreSQL | postgres:16.11-alpine | 16.11 |
| Redis | redis:7.4.7-alpine | 7.4.7 |

---

## Pre-Upgrade Checklist

Before any upgrade:

- [ ] **Create full backup**
  ```bash
  ./scripts/backup-all.sh
  ```

- [ ] **Verify backup integrity**
  ```bash
  gunzip -t backups/postgres/$(ls -t backups/postgres/ | head -1)
  ```

- [ ] **Check current health**
  ```bash
  ./scripts/health-check.sh
  ./scripts/system-status.sh
  ```

- [ ] **Review release notes**
  - n8n: https://github.com/n8n-io/n8n/releases
  - Check for breaking changes
  - Note any migration steps required

- [ ] **Check disk space**
  ```bash
  df -h
  # Need space for new images (~1-2GB per major component)
  ```

- [ ] **Plan maintenance window**
  - Upgrades cause brief downtime
  - Notify stakeholders if needed

---

## n8n Upgrade Procedure

### Step 1: Check Available Versions

```bash
# Current version
docker exec n8n-main n8n --version

# List recent tags from Docker Hub
# Visit: https://hub.docker.com/r/n8nio/n8n/tags
```

### Step 2: Pull New Image

```bash
# Replace X.Y.Z with target version
docker pull n8nio/n8n:X.Y.Z
```

### Step 3: Update docker-compose.yml

Edit docker-compose.yml and update both n8n and n8n-worker image tags:

```yaml
services:
  n8n:
    image: n8nio/n8n:X.Y.Z  # Update this
    # ...

  n8n-worker:
    image: n8nio/n8n:X.Y.Z  # Must match n8n version
    # ...
```

**Important**: n8n main and workers MUST use the same version.

### Step 4: Stop Services

```bash
# Graceful stop - wait for queue to drain
docker compose stop n8n-worker
./scripts/system-status.sh  # Verify queue is empty

docker compose down
```

### Step 5: Start with New Version

```bash
docker compose up -d
```

### Step 6: Verify Upgrade

```bash
# Check version
docker exec n8n-main n8n --version

# Check health
./scripts/health-check.sh

# Check logs for migration messages
docker compose logs n8n --tail 100
```

### Step 7: Test Functionality

- [ ] Login to n8n UI
- [ ] Verify workflows are present
- [ ] Execute a test workflow
- [ ] Check execution history

---

## PostgreSQL Upgrade Procedure

### Minor Version Upgrade (e.g., 16.11 to 16.12)

Minor PostgreSQL upgrades are typically safe and don't require data migration.

```bash
# 1. Backup
./scripts/backup-postgres.sh

# 2. Update image tag in docker-compose.yml
# Change: postgres:16.11-alpine
# To:     postgres:16.12-alpine

# 3. Pull new image
docker pull postgres:16.12-alpine

# 4. Restart postgres
docker compose down
docker compose up -d postgres
docker compose up -d

# 5. Verify
docker exec n8n-postgres postgres --version
./scripts/health-check.sh
```

### Major Version Upgrade (e.g., 16.x to 17.x)

Major PostgreSQL upgrades require data migration. This is an advanced procedure.

**Warning**: Major upgrades require pg_dump/pg_restore and should be tested thoroughly first.

```bash
# 1. Full backup (critical!)
./scripts/backup-all.sh

# 2. Export database
docker exec n8n-postgres pg_dump -U n8n -d n8n > upgrade_backup.sql

# 3. Stop all services
docker compose down

# 4. Remove old volume (data will be lost!)
# docker volume rm n8n_postgres_data

# 5. Update docker-compose.yml to new major version

# 6. Start postgres only
docker compose up -d postgres
sleep 15

# 7. Restore database
cat upgrade_backup.sql | docker exec -i n8n-postgres psql -U n8n -d n8n

# 8. Start remaining services
docker compose up -d

# 9. Verify thoroughly
```

**Recommendation**: For major PostgreSQL upgrades, consider a staged migration with a test environment first.

---

## Redis Upgrade Procedure

Redis minor version upgrades are typically straightforward.

```bash
# 1. Backup (optional - queue data is transient)
./scripts/backup-redis.sh

# 2. Update image tag in docker-compose.yml
# Change: redis:7.4.7-alpine
# To:     redis:7.4.8-alpine

# 3. Pull new image
docker pull redis:7.4.8-alpine

# 4. Restart redis
docker compose down
docker compose up -d redis
docker compose up -d

# 5. Verify
docker exec n8n-redis redis-server --version
./scripts/health-check.sh
```

---

## Rollback Procedures

### n8n Rollback

If the upgrade causes issues:

```bash
# 1. Stop services
docker compose down

# 2. Revert docker-compose.yml to previous version tag
# Change image tags back to previous versions

# 3. Start with old version
docker compose up -d

# 4. If database migration occurred, restore backup
./scripts/restore-postgres.sh backups/postgres/pre-upgrade-backup.sql.gz
```

### PostgreSQL Rollback (Minor Version)

```bash
# 1. Stop services
docker compose down

# 2. Revert docker-compose.yml to previous version

# 3. Restart
docker compose up -d
```

### PostgreSQL Rollback (Major Version)

Major version rollback requires restoring from backup:

```bash
# 1. Stop services
docker compose down

# 2. Revert docker-compose.yml to previous version

# 3. Remove new version's data
docker volume rm n8n_postgres_data

# 4. Start postgres
docker compose up -d postgres
sleep 15

# 5. Restore from pre-upgrade backup
./scripts/restore-postgres.sh backups/postgres/pre-upgrade-backup.sql.gz

# 6. Start remaining services
docker compose up -d
```

---

## Post-Upgrade Verification

After any upgrade:

### Immediate Checks

```bash
# Container health
docker compose ps

# Version confirmation
docker exec n8n-main n8n --version
docker exec n8n-postgres postgres --version
docker exec n8n-redis redis-server --version

# Health endpoints
./scripts/health-check.sh
```

### Functional Tests

- [ ] n8n UI loads correctly
- [ ] Can login with existing credentials
- [ ] All workflows visible
- [ ] Execute test workflow successfully
- [ ] Webhook receives test request
- [ ] Workers process jobs (check queue)

### Performance Checks

```bash
# Resource usage
./scripts/monitor-resources.sh

# Database performance
./scripts/postgres-benchmark.sh
```

---

## Upgrade Schedule Recommendations

| Component | Frequency | When to Upgrade |
|-----------|-----------|-----------------|
| n8n | Quarterly | After testing in dev, security fixes immediately |
| PostgreSQL | Semi-annually | Minor versions; major requires planning |
| Redis | Annually | Unless security issues |

### Staying Informed

- n8n releases: https://github.com/n8n-io/n8n/releases
- n8n blog: https://blog.n8n.io
- PostgreSQL: https://www.postgresql.org/support/versioning/
- Redis: https://github.com/redis/redis/releases

---

## Version History

Track previous versions here for reference:

| Date | Component | From | To | Notes |
|------|-----------|------|-----|-------|
| 2025-12-26 | All | floating | pinned | Initial version pinning |

---

## Related Documentation

- [RECOVERY.md](RECOVERY.md) - Disaster recovery procedures
- [RUNBOOK.md](RUNBOOK.md) - Day-to-day operations
- [SECURITY.md](SECURITY.md) - Security configuration
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Problem diagnosis
