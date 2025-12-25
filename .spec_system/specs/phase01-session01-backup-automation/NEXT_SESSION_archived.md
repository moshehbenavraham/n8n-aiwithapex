# NEXT_SESSION.md

## Session Recommendation

**Generated**: 2025-12-26
**Project State**: Phase 01 - Operations and Optimization
**Completed Sessions**: 4 (Phase 00 complete)

---

## Recommended Next Session

**Session ID**: `phase01-session01-backup-automation`
**Session Name**: Backup Automation and Data Protection
**Estimated Duration**: 2-4 hours
**Estimated Tasks**: ~20-25

---

## Why This Session Next?

### Prerequisites Met
- [x] Phase 00 completed - all services running
- [x] PostgreSQL container healthy and accessible
- [x] Redis container healthy with RDB persistence
- [x] n8n data directory exists at project path
- [x] Write access to backup destination directory

### Dependencies
- **Builds on**: Phase 00 service deployment (all containers running)
- **Enables**: Disaster recovery, data protection, production readiness

### Project Progression
Backup automation is the **critical first step** for Phase 01. The CONSIDERATIONS.md explicitly flags "[P00] No backup automation: PostgreSQL and Redis data unprotected" as an active concern. Before scaling workers, tuning performance, or hardening production, the existing data must be protected. This session creates the foundational scripts that ensure recoverability and establishes the backup infrastructure other sessions may reference.

---

## Session Overview

### Objective
Create comprehensive backup scripts for PostgreSQL database, Redis data, and n8n configuration, then implement automated scheduling via cron with retention policies to ensure data protection.

### Key Deliverables
1. `scripts/backup-postgres.sh` - PostgreSQL database backup script
2. `scripts/backup-redis.sh` - Redis RDB snapshot backup script
3. `scripts/backup-n8n.sh` - n8n data and config backup script
4. `scripts/backup-all.sh` - Master backup script calling all components
5. `scripts/restore-postgres.sh` - PostgreSQL restore script
6. `scripts/cleanup-backups.sh` - Retention policy enforcement script
7. Cron configuration for automated daily backups (2 AM)
8. Backup verification documentation
9. Tested restore procedure

### Scope Summary
- **In Scope (MVP)**: PostgreSQL pg_dump backups, Redis RDB snapshots, n8n data/encryption key backup, .env backup, 7-day retention, cron scheduling, restore testing
- **Out of Scope**: Off-site/cloud backup, incremental backups, PITR, encryption at rest, monitoring alerts

---

## Technical Considerations

### Technologies/Patterns
- Bash scripting for all backup automation
- Docker exec for container-native pg_dump and redis-cli commands
- gzip compression for backup files
- cron for scheduling (daily at 2 AM)
- Timestamped backup naming (YYYYMMDD_HHMMSS)

### Backup Directory Structure
```
backups/
├── postgres/    # n8n_YYYYMMDD_HHMMSS.sql.gz
├── redis/       # dump_YYYYMMDD_HHMMSS.rdb
├── n8n/         # n8n_data_YYYYMMDD_HHMMSS.tar.gz
└── env/         # env_YYYYMMDD_HHMMSS.backup
```

### Potential Challenges
- Cron job may fail silently without proper logging
- Large PostgreSQL databases may take time to dump
- Redis BGSAVE timing must be handled (wait for completion)
- Retention cleanup must not delete today's backup

### Relevant Considerations
- [P00] **No backup automation**: This is the primary driver for this session - PostgreSQL and Redis data currently unprotected
- [P00] **Named Docker volumes**: Use volume inspection to identify backup sources
- [P00] **Service names as hostnames**: Use `postgres` and `redis` container names for exec commands

---

## Alternative Sessions

If this session is blocked:
1. **phase01-session02-worker-scaling** - Can be done independently if backup is deferred; addresses single worker limitation
2. **phase01-session03-postgresql-tuning** - No dependencies, could optimize DB before backup scripts exist

However, proceeding without backup automation leaves production data at risk. Strongly recommend completing Session 01 first.

---

## Next Steps

Run `/sessionspec` to generate the formal specification.
