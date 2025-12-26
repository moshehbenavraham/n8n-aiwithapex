# Session 01: Backup Automation and Data Protection

**Session ID**: `phase01-session01-backup-automation`
**Status**: Not Started
**Estimated Tasks**: ~20-25
**Estimated Duration**: 2-4 hours

---

## Important: WSL2 Ubuntu Only

**All commands and operations run exclusively from WSL2 Ubuntu.** There is NO need for PowerShell, CMD, or Windows Terminal.

---

## Objective

Create comprehensive backup scripts for PostgreSQL database, Redis data, and n8n configuration, then implement automated scheduling via cron with retention policies to ensure data protection.

---

## Scope

### In Scope (MVP)
- PostgreSQL database backup script using pg_dump via Docker exec
- Redis RDB snapshot backup script
- n8n data directory backup (workflows, credentials encryption key)
- Environment file (.env) backup
- Retention policy implementation (7-day default)
- Cron job configuration for automated daily backups
- Backup verification and integrity checking
- Backup restoration testing
- Backup log and status reporting

### Out of Scope
- Off-site/cloud backup destinations
- Incremental or differential backups
- Point-in-time recovery (PITR)
- Backup encryption at rest
- Backup monitoring alerts (covered in Session 04)

---

## Prerequisites

- [ ] Phase 00 completed - all services running
- [ ] PostgreSQL container healthy and accessible
- [ ] Redis container healthy with RDB persistence
- [ ] n8n data directory exists at project path
- [ ] Write access to backup destination directory

---

## Deliverables

1. `scripts/backup-postgres.sh` - PostgreSQL database backup script
2. `scripts/backup-redis.sh` - Redis RDB snapshot backup script
3. `scripts/backup-n8n.sh` - n8n data and config backup script
4. `scripts/backup-all.sh` - Master backup script calling all components
5. `scripts/restore-postgres.sh` - PostgreSQL restore script
6. `scripts/cleanup-backups.sh` - Retention policy enforcement script
7. Cron configuration for automated scheduling
8. Backup verification documentation
9. Tested restore procedure

---

## Technical Details

### Backup Directory Structure
```
backups/
├── postgres/
│   └── n8n_YYYYMMDD_HHMMSS.sql.gz
├── redis/
│   └── dump_YYYYMMDD_HHMMSS.rdb
├── n8n/
│   └── n8n_data_YYYYMMDD_HHMMSS.tar.gz
└── env/
    └── env_YYYYMMDD_HHMMSS.backup
```

### PostgreSQL Backup Command
```bash
docker exec postgres pg_dump -U n8n -d n8n | gzip > backup.sql.gz
```

### Redis Backup Command
```bash
docker exec redis redis-cli BGSAVE
docker cp redis:/data/dump.rdb ./backup.rdb
```

### Cron Schedule (Daily at 2 AM)
```bash
0 2 * * * /home/aiwithapex/n8n/scripts/backup-all.sh >> /home/aiwithapex/n8n/logs/backup.log 2>&1
```

---

## Success Criteria

- [ ] PostgreSQL backup script creates valid, restorable dumps
- [ ] Redis backup script captures RDB snapshot
- [ ] n8n data backup includes workflows and encryption key
- [ ] Retention policy deletes backups older than 7 days
- [ ] Cron job scheduled and verified running
- [ ] Restore procedure tested and documented
- [ ] Backup logs capture success/failure status
