# Disaster Recovery Runbook

This document provides step-by-step procedures for recovering the n8n stack from various failure scenarios.

## Table of Contents

1. [Quick Reference](#quick-reference)
2. [Prerequisites](#prerequisites)
3. [PostgreSQL Recovery](#postgresql-recovery)
4. [Redis Recovery](#redis-recovery)
5. [n8n Data Volume Recovery](#n8n-data-volume-recovery)
6. [Full System Recovery](#full-system-recovery)
7. [Backup Verification](#backup-verification)
8. [Troubleshooting](#troubleshooting)

---

## Quick Reference

| Scenario | Recovery Time | Commands |
|----------|---------------|----------|
| PostgreSQL database corruption | 10-15 min | `./scripts/restore-postgres.sh <backup>` |
| Redis data loss | 5-10 min | `./scripts/restore-redis.sh <backup>` |
| n8n data volume corruption | 10-15 min | `./scripts/restore-n8n.sh <backup>` |
| Full system recovery | 30-45 min | See [Full System Recovery](#full-system-recovery) |

---

## Prerequisites

### Required Tools

- Docker and Docker Compose
- GPG (for encrypted backups)
- Access to backup storage

### Environment Setup

Ensure these environment variables are set in `.env`:

```bash
# Database credentials
POSTGRES_USER=n8n
POSTGRES_DB=n8n

# For encrypted backups
BACKUP_GPG_PASSPHRASE=your-secure-passphrase
```

### Verify Backups Exist

```bash
# List available backups
./scripts/test-recovery.sh --list

# Check backup directory structure
ls -la backups/
```

---

## PostgreSQL Recovery

### When to Use

- Database corruption detected
- Accidental data deletion
- Failed migration rollback needed

### Procedure

#### Step 1: Identify Available Backups

```bash
# List PostgreSQL backups
ls -la backups/postgres/

# Show most recent backup
ls -t backups/postgres/*.sql.gz* | head -5
```

#### Step 2: Stop n8n Services (Recommended)

```bash
# Stop n8n to prevent database writes during restore
docker compose stop n8n n8n-worker
```

#### Step 3: Restore Database

For unencrypted backup:
```bash
./scripts/restore-postgres.sh backups/postgres/n8n_YYYYMMDD_HHMMSS.sql.gz
```

For encrypted backup:
```bash
# Ensure BACKUP_GPG_PASSPHRASE is set in .env
./scripts/restore-postgres.sh backups/postgres/n8n_YYYYMMDD_HHMMSS.sql.gz.gpg
```

#### Step 4: Restart Services

```bash
docker compose up -d n8n n8n-worker
```

#### Step 5: Verify Recovery

```bash
# Check service health
./scripts/health-check.sh

# Verify database tables
docker exec n8n-postgres psql -U n8n -d n8n -c "\dt"
```

---

## Redis Recovery

### When to Use

- Redis data corruption
- Queue data loss
- Failed Redis upgrade

### Procedure

#### Step 1: Identify Available Backups

```bash
# List Redis backups
ls -la backups/redis/

# Show most recent backup
ls -t backups/redis/*.rdb* | head -5
```

#### Step 2: Restore Redis Data

For unencrypted backup:
```bash
./scripts/restore-redis.sh backups/redis/dump_YYYYMMDD_HHMMSS.rdb
```

For encrypted backup:
```bash
# Ensure BACKUP_GPG_PASSPHRASE is set in .env
./scripts/restore-redis.sh backups/redis/dump_YYYYMMDD_HHMMSS.rdb.gpg
```

**Note**: Redis restore requires container restart. The script handles this automatically.

#### Step 3: Verify Recovery

```bash
# Check Redis connectivity
docker exec n8n-redis redis-cli PING

# Check database size
docker exec n8n-redis redis-cli DBSIZE
```

---

## n8n Data Volume Recovery

### When to Use

- n8n configuration corruption
- Lost custom nodes or credentials
- Failed n8n upgrade

### Procedure

#### Step 1: Identify Available Backups

```bash
# List n8n data backups
ls -la backups/n8n/

# Show most recent backup
ls -t backups/n8n/*.tar.gz* | head -5
```

#### Step 2: Stop n8n Services

```bash
# Required for safe volume restore
docker compose stop n8n n8n-worker
```

#### Step 3: Restore Data Volume

For unencrypted backup:
```bash
./scripts/restore-n8n.sh backups/n8n/n8n_data_YYYYMMDD_HHMMSS.tar.gz
```

For encrypted backup:
```bash
# Ensure BACKUP_GPG_PASSPHRASE is set in .env
./scripts/restore-n8n.sh backups/n8n/n8n_data_YYYYMMDD_HHMMSS.tar.gz.gpg
```

#### Step 4: Restart Services

```bash
docker compose up -d n8n n8n-worker
```

#### Step 5: Verify Recovery

```bash
# Check service health
./scripts/health-check.sh

# Access n8n web interface
curl -s http://localhost:5678/healthz
```

---

## Full System Recovery

### When to Use

- Complete system failure
- Migration to new host
- Disaster recovery drill

### Procedure

#### Step 1: Prepare New Environment

```bash
# Clone project
git clone <repository-url> n8n
cd n8n

# Copy environment file
cp .env.example .env
# Edit .env with correct values
```

#### Step 2: Start Infrastructure Services

```bash
# Start PostgreSQL and Redis first
docker compose up -d postgres redis

# Wait for healthy status
sleep 30
docker compose ps
```

#### Step 3: Restore PostgreSQL Database

```bash
./scripts/restore-postgres.sh backups/postgres/<latest-backup>.sql.gz
```

#### Step 4: Restore Redis Data

```bash
./scripts/restore-redis.sh backups/redis/<latest-backup>.rdb
```

#### Step 5: Restore n8n Data Volume

```bash
./scripts/restore-n8n.sh backups/n8n/<latest-backup>.tar.gz
```

#### Step 6: Start n8n Services

```bash
docker compose up -d n8n n8n-worker
```

#### Step 7: Start Supporting Services

```bash
# Start ngrok tunnel
docker compose up -d ngrok

# Verify all services
./scripts/health-check.sh
```

#### Step 8: Verify Full Recovery

```bash
# Check all containers
docker compose ps

# Verify health endpoint
curl -s http://localhost:5678/healthz

# Check tunnel status
./scripts/tunnel-status.sh
```

---

## Backup Verification

### Regular Verification

Run recovery tests periodically to ensure backups are valid:

```bash
# Test all recovery procedures (non-destructive)
./scripts/test-recovery.sh --full

# Test specific service
./scripts/test-recovery.sh --postgres
./scripts/test-recovery.sh --redis
./scripts/test-recovery.sh --n8n
```

### Encrypted Backup Verification

```bash
# List encrypted backups
find backups/ -name "*.gpg" -type f

# Test decryption (requires BACKUP_GPG_PASSPHRASE)
./scripts/test-recovery.sh --full
```

---

## Troubleshooting

### Common Issues

#### GPG Decryption Failed

**Symptom**: "Failed to decrypt backup file - check passphrase"

**Solution**:
1. Verify BACKUP_GPG_PASSPHRASE is set in .env
2. Confirm passphrase matches the one used during backup creation
3. Check GPG is installed: `gpg --version`

#### PostgreSQL Restore Failed - Active Connections

**Symptom**: "Failed to drop database - active connections may be preventing drop"

**Solution**:
```bash
# Stop all n8n services
docker compose stop n8n n8n-worker

# Retry restore
./scripts/restore-postgres.sh <backup>
```

#### Redis Container Not Restarting

**Symptom**: "Redis did not restart within 30 seconds"

**Solution**:
```bash
# Manually restart Redis
docker compose restart redis

# If that fails, recreate container
docker compose up -d --force-recreate redis
```

#### Backup File Corrupted

**Symptom**: "Backup file is corrupted or not a valid gzip file"

**Solution**:
1. Try an older backup
2. Check backup storage for corruption
3. Verify network issues during backup transfer

### Getting Help

- Check logs: `./scripts/view-logs.sh`
- Run health check: `./scripts/health-check.sh`
- See TROUBLESHOOTING.md for additional guidance

---

## Recovery Testing Schedule

| Test Type | Frequency | Last Tested |
|-----------|-----------|-------------|
| PostgreSQL recovery | Monthly | - |
| Redis recovery | Monthly | - |
| n8n volume recovery | Monthly | - |
| Full system recovery | Quarterly | - |
| Encrypted backup test | Monthly | - |

---

*Document Version: 1.0*
*Last Updated: 2025-12-28*
