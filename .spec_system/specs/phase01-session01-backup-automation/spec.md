# Session Specification

**Session ID**: `phase01-session01-backup-automation`
**Phase**: 01 - Operations and Optimization
**Status**: Not Started
**Created**: 2025-12-26

---

## 1. Session Overview

This session establishes comprehensive data protection for the n8n production stack by creating automated backup scripts for PostgreSQL, Redis, and n8n configuration data. The backup infrastructure forms the foundation for disaster recovery and is a critical prerequisite before scaling workers or tuning performance.

The implementation uses Docker exec commands to access container-native backup utilities (pg_dump for PostgreSQL, redis-cli for Redis) and standard Unix tools (tar, gzip, cron) for compression and scheduling. All scripts follow a consistent pattern with timestamped filenames, logging, error handling, and exit codes for monitoring integration.

By the end of this session, the n8n stack will have automated daily backups at 2 AM with 7-day retention, tested restore procedures, and comprehensive logging. This directly addresses the Phase 00 active concern: "No backup automation: PostgreSQL and Redis data unprotected."

---

## 2. Objectives

1. Create individual backup scripts for PostgreSQL database, Redis RDB snapshots, and n8n data/configuration
2. Implement a master backup script that orchestrates all backup components with proper sequencing and error handling
3. Create PostgreSQL restore script with tested recovery procedure
4. Implement 7-day retention policy with automated cleanup
5. Configure cron job for automated daily backups at 2 AM with logging

---

## 3. Prerequisites

### Required Sessions
- [x] `phase00-session01-wsl2-environment-optimization` - WSL2 configured with systemd for cron
- [x] `phase00-session02-docker-engine-installation` - Docker Engine available
- [x] `phase00-session03-project-structure-and-configuration` - Project structure with .env and docker-compose.yml
- [x] `phase00-session04-service-deployment-and-verification` - All containers running and healthy

### Required Tools/Knowledge
- Bash scripting fundamentals
- Docker exec command usage
- PostgreSQL pg_dump/pg_restore utilities
- Redis redis-cli commands
- cron scheduling syntax

### Environment Requirements
- All containers running: postgres, redis, n8n, n8n-worker
- Write access to `/home/aiwithapex/n8n/backups/` directory
- Write access to `/home/aiwithapex/n8n/logs/` directory
- cron daemon running via systemd

---

## 4. Scope

### In Scope (MVP)
- PostgreSQL database backup via pg_dump with gzip compression
- Redis RDB snapshot backup via BGSAVE and docker cp
- n8n data directory backup (workflows, credentials, encryption key)
- Environment file (.env) backup with secure permissions
- Timestamp-based backup naming (YYYYMMDD_HHMMSS)
- 7-day retention policy with automated cleanup
- PostgreSQL restore script with validation
- Cron job for daily 2 AM execution
- Backup logging with success/failure status
- Exit codes for each script (0=success, non-zero=failure)

### Out of Scope (Deferred)
- Off-site/cloud backup destinations - *Reason: Requires external service integration*
- Incremental or differential backups - *Reason: Complexity exceeds MVP needs*
- Point-in-time recovery (PITR) - *Reason: Requires PostgreSQL WAL archiving*
- Backup encryption at rest - *Reason: Phase 01 Session 05 (Production Hardening)*
- Backup monitoring alerts - *Reason: Phase 01 Session 04 (Monitoring)*
- Redis restore script - *Reason: RDB file copy is sufficient for restore*

---

## 5. Technical Approach

### Architecture

```
scripts/
|-- backup-postgres.sh    # PostgreSQL pg_dump -> gzip
|-- backup-redis.sh       # Redis BGSAVE -> docker cp
|-- backup-n8n.sh         # n8n data directory tar -> gzip
|-- backup-all.sh         # Master orchestrator
|-- restore-postgres.sh   # pg_restore from backup
|-- cleanup-backups.sh    # Retention policy enforcement

backups/
|-- postgres/             # n8n_YYYYMMDD_HHMMSS.sql.gz
|-- redis/                # dump_YYYYMMDD_HHMMSS.rdb
|-- n8n/                  # n8n_data_YYYYMMDD_HHMMSS.tar.gz
|-- env/                  # env_YYYYMMDD_HHMMSS.backup

logs/
|-- backup.log            # Consolidated backup logs
```

### Design Patterns
- **Exit code propagation**: All scripts return 0 on success, non-zero on failure
- **Logging pattern**: Timestamped log entries with script name, action, and result
- **Atomic operations**: Use temp files and mv for atomic backup creation
- **Dependency injection**: Read configuration from .env via source command
- **Fail-fast**: Exit immediately on critical errors (set -e where appropriate)

### Technology Stack
- Bash 5.x (WSL2 Ubuntu)
- Docker CLI for container exec
- PostgreSQL 16 pg_dump/pg_restore utilities (in container)
- Redis 7 redis-cli (in container)
- GNU tar and gzip for compression
- cron for scheduling
- find for retention cleanup

---

## 6. Deliverables

### Files to Create

| File | Purpose | Est. Lines |
|------|---------|------------|
| `scripts/backup-postgres.sh` | PostgreSQL database backup with pg_dump | ~60 |
| `scripts/backup-redis.sh` | Redis RDB snapshot backup | ~50 |
| `scripts/backup-n8n.sh` | n8n data and config backup | ~55 |
| `scripts/backup-all.sh` | Master backup orchestrator | ~80 |
| `scripts/restore-postgres.sh` | PostgreSQL restore from backup | ~70 |
| `scripts/cleanup-backups.sh` | Retention policy enforcement | ~50 |
| `logs/.gitkeep` | Ensure logs directory in git | 0 |

### Directories to Create

| Directory | Purpose |
|-----------|---------|
| `backups/postgres/` | PostgreSQL backup storage |
| `backups/redis/` | Redis backup storage |
| `backups/n8n/` | n8n data backup storage |
| `backups/env/` | Environment file backup storage |
| `logs/` | Backup log storage |

### Files to Modify

| File | Changes | Est. Lines |
|------|---------|------------|
| `.gitignore` | Add backup file patterns, keep directory structure | ~5 |

### Cron Configuration

| Schedule | Command | Log |
|----------|---------|-----|
| `0 2 * * *` | `/home/aiwithapex/n8n/scripts/backup-all.sh` | `>> logs/backup.log 2>&1` |

---

## 7. Success Criteria

### Functional Requirements
- [ ] `backup-postgres.sh` creates valid gzip-compressed SQL dump
- [ ] `backup-redis.sh` captures RDB snapshot from Redis container
- [ ] `backup-n8n.sh` archives n8n data directory with encryption key preserved
- [ ] `backup-all.sh` executes all backup scripts in sequence with logging
- [ ] `restore-postgres.sh` successfully restores database from backup file
- [ ] `cleanup-backups.sh` removes backups older than 7 days
- [ ] All scripts return appropriate exit codes (0=success)
- [ ] Backup files follow naming convention: `*_YYYYMMDD_HHMMSS.*`

### Testing Requirements
- [ ] Manual execution of each backup script succeeds
- [ ] Restore procedure tested: backup -> drop table -> restore -> verify
- [ ] Cleanup removes test files older than threshold
- [ ] Cron job installed and verified in crontab

### Quality Gates
- [ ] All scripts have executable permissions (chmod +x)
- [ ] All scripts use ASCII-only characters (0-127)
- [ ] Unix LF line endings (no CRLF)
- [ ] ShellCheck passes with no errors
- [ ] Scripts source .env correctly for credentials

---

## 8. Implementation Notes

### Key Considerations

**PostgreSQL Backup Command:**
```bash
docker exec postgres pg_dump -U n8n -d n8n | gzip > "$BACKUP_FILE"
```

**Redis Backup Sequence:**
```bash
docker exec redis redis-cli BGSAVE
# Wait for BGSAVE to complete
while [ "$(docker exec redis redis-cli LASTSAVE)" == "$LAST_SAVE" ]; do
  sleep 1
done
docker cp redis:/data/dump.rdb "$BACKUP_FILE"
```

**n8n Data Backup:**
```bash
# Backup from Docker volume, not bind mount
docker run --rm -v n8n_data:/data -v $(pwd)/backups/n8n:/backup \
  alpine tar czf /backup/n8n_data_${TIMESTAMP}.tar.gz -C /data .
```

**Cron Entry:**
```bash
0 2 * * * /home/aiwithapex/n8n/scripts/backup-all.sh >> /home/aiwithapex/n8n/logs/backup.log 2>&1
```

### Potential Challenges

| Challenge | Mitigation |
|-----------|------------|
| Redis BGSAVE timing | Poll LASTSAVE until value changes |
| Large database dumps | Use compression, consider --jobs for parallel dump |
| Cron silent failures | Redirect stderr to log, check exit codes |
| Disk space exhaustion | Retention cleanup runs before new backup |
| Container not running | Check container status before exec |

### Relevant Considerations

- [P00] **No backup automation**: This session directly addresses this concern by creating comprehensive backup scripts
- [P00] **Named Docker volumes**: Use `docker volume inspect` to identify volume mount points; use `docker run` with volume mounts for n8n data backup
- [P00] **Service names as hostnames**: Use container names `postgres` and `redis` for docker exec commands
- [P00] **Non-standard ports for conflicts**: Redis on port 6386 - use this in any connectivity checks
- [P00] **Environment variable externalization**: Source .env file for database credentials in scripts

### ASCII Reminder

All output files must use ASCII-only characters (0-127). Avoid Unicode characters in scripts, comments, and log messages.

---

## 9. Testing Strategy

### Unit Tests

For each script, verify:
- Script is executable
- Script runs without syntax errors (bash -n)
- Script passes ShellCheck validation
- Exit code is 0 on success
- Exit code is non-zero on failure (test with missing container)

### Integration Tests

| Test | Steps | Expected Result |
|------|-------|-----------------|
| Full backup cycle | Run backup-all.sh | All backup files created, log updated |
| PostgreSQL restore | Backup -> Delete test data -> Restore -> Verify | Data recovered correctly |
| Retention cleanup | Create old test file -> Run cleanup -> Verify deleted | Old files removed |
| Cron execution | Install cron job -> Check next scheduled run | Job appears in crontab |

### Manual Testing

1. **PostgreSQL backup verification:**
   ```bash
   ./scripts/backup-postgres.sh
   gunzip -c backups/postgres/n8n_*.sql.gz | head -50
   ```

2. **Redis backup verification:**
   ```bash
   ./scripts/backup-redis.sh
   ls -la backups/redis/
   ```

3. **Restore procedure:**
   ```bash
   # Create test workflow in n8n UI
   # Run backup
   ./scripts/backup-postgres.sh
   # Delete the workflow in n8n UI
   # Restore
   ./scripts/restore-postgres.sh backups/postgres/n8n_YYYYMMDD_HHMMSS.sql.gz
   # Verify workflow restored
   ```

### Edge Cases

| Edge Case | Handling |
|-----------|----------|
| Container not running | Check docker ps, exit with error code |
| No disk space | Check df before backup, warn if < 1GB |
| Backup directory missing | Create directory if not exists |
| .env file missing | Exit with clear error message |
| Previous backup in progress | Use lock file to prevent concurrent runs |

---

## 10. Dependencies

### External Libraries
- None (uses only system tools)

### System Tools
- docker (Docker CLI)
- bash 5.x
- tar, gzip, gunzip
- find (GNU findutils)
- cron (systemd-cron)
- date (GNU coreutils)

### Other Sessions
- **Depends on**: phase00-session04-service-deployment-and-verification (containers must be running)
- **Depended by**: phase01-session04-monitoring-health (may add backup monitoring), phase01-session05-production-hardening (may add backup encryption)

---

## Configuration Reference

From `.env`:
```bash
POSTGRES_USER=n8n
POSTGRES_PASSWORD=<redacted>
POSTGRES_DB=n8n
POSTGRES_HOST=postgres
REDIS_HOST=redis
REDIS_PORT=6386
```

Container names (from docker-compose.yml):
- `postgres` - PostgreSQL database
- `redis` - Redis message broker
- `n8n` - n8n main instance
- `n8n-worker` - n8n worker(s)

Volume names:
- `postgres_data` - PostgreSQL data
- `redis_data` - Redis data
- `n8n_data` - n8n user data

---

## Next Steps

Run `/tasks` to generate the implementation task checklist.
