# PRD Phase 01: Operations and Optimization

**Status**: In Progress
**Sessions**: 5
**Estimated Duration**: 2-3 days

**Progress**: 2/5 sessions (40%)

---

## Important: WSL2 Ubuntu Only

**All commands and operations run exclusively from WSL2 Ubuntu.** There is NO need for PowerShell, CMD, or Windows Terminal. Windows files are accessed via `/mnt/c/` from Ubuntu when needed.

---

## Overview

This phase establishes production-ready operations for the n8n stack deployed in Phase 00. It covers automated backup procedures, worker scaling for throughput, PostgreSQL performance tuning, monitoring and health management, and production hardening with comprehensive documentation. By the end of this phase, the n8n installation will be fully operational with data protection, optimized performance, and documented recovery procedures.

---

## Progress Tracker

| Session | Name | Status | Est. Tasks | Validated |
|---------|------|--------|------------|-----------|
| 01 | Backup Automation and Data Protection | Complete | 22 | 2025-12-26 |
| 02 | Worker Scaling and Queue Optimization | Complete | 22 | 2025-12-26 |
| 03 | PostgreSQL Performance Tuning | Not Started | ~15-20 | - |
| 04 | Monitoring and Health Management | Not Started | ~20-25 | - |
| 05 | Production Hardening and Documentation | Not Started | ~20-25 | - |

---

## Completed Sessions

### Session 01: Backup Automation and Data Protection

**Completed**: 2025-12-26

Created comprehensive backup infrastructure for the n8n production stack:
- PostgreSQL database backup via pg_dump with gzip compression
- Redis RDB snapshot backup with BGSAVE/LASTSAVE polling
- n8n data volume backup via Docker alpine container
- Environment file backup with secure 600 permissions
- Master orchestrator script with disk space checks and lock file
- PostgreSQL restore script with DROP DATABASE FORCE support
- 7-day retention cleanup script with --dry-run option
- Automated daily backups at 2 AM via cron

**Deliverables**: 6 scripts, 5 directories, .gitignore updates

---

### Session 02: Worker Scaling and Queue Optimization

**Completed**: 2025-12-26

Configured multi-worker architecture for production workloads:
- Docker Compose configured with deploy.replicas: 5 for n8n-worker
- Memory limits applied (512MB per worker)
- OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS enabled
- EXECUTIONS_CONCURRENCY set to 10 per worker (50 total capacity)
- Queue job distribution verified across all workers
- Scaling procedures documented (up/down)
- Memory baseline: ~1.57 GiB total (well under 8 GiB WSL2 limit)

**Deliverables**: docker-compose.yml updates, .env additions, docs/SCALING.md

---

## Upcoming Sessions

- Session 03: PostgreSQL Performance Tuning
- Session 04: Monitoring and Health Management
- Session 05: Production Hardening and Documentation

---

## Objectives

1. Create and schedule automated backup procedures for PostgreSQL, Redis, and n8n data with retention policies
2. Implement worker scaling configuration to support 5+ workers with optimized concurrency
3. Configure PostgreSQL performance tuning for production workloads
4. Establish monitoring, health checks, and resource management procedures
5. Harden the installation for production use and document troubleshooting/recovery procedures

---

## Prerequisites

- Phase 00 completed (all 4 sessions)
- All containers running and healthy (postgres, redis, n8n, n8n-worker)
- n8n accessible at http://localhost:5678
- Queue mode verified functional

---

## Technical Considerations

### Architecture
- Backup scripts using Docker exec for container-native operations
- Cron scheduling for automated backups within WSL2
- Worker scaling via Docker Compose replica configuration
- PostgreSQL tuning via custom configuration file mounted as volume
- Centralized logging and metrics collection via n8n endpoints

### Technologies
- Bash scripting for automation
- Cron for scheduling
- Docker Compose for scaling
- PostgreSQL 16 performance configuration
- Redis 7 optimization

### Risks
- **Backup storage exhaustion**: Unbounded backups fill disk. Mitigation: Implement retention policies with automated cleanup.
- **Worker memory contention**: Too many workers exhaust WSL2 memory. Mitigation: Monitor with docker stats, tune concurrency.
- **PostgreSQL tuning regression**: Incorrect settings degrade performance. Mitigation: Benchmark before/after changes.
- **Cron job failures**: Silent failures leave data unprotected. Mitigation: Implement logging and verification.

### Relevant Considerations
<!-- From CONSIDERATIONS.md -->
- [P00] **No backup automation**: Primary driver for Session 01 - implement comprehensive backup scripts
- [P00] **Single worker instance**: Session 02 addresses scaling to 5+ workers for production throughput
- [P00] **Manual execution offload**: Enable OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS in Session 02
- [P00] **n8n:latest image tag**: Session 05 pins to specific version for stability
- [P00] **Redis vm.overcommit_memory warning**: Document remediation in Session 05 (requires host sysctl)
- [P00] **WSL2 8GB RAM constraint**: Monitor throughout, especially during worker scaling

---

## Success Criteria

Phase complete when:
- [ ] All 5 sessions completed
- [x] Backup scripts created and tested for PostgreSQL, Redis, and n8n data
- [x] Automated backup scheduling via cron functional
- [x] Worker scaling verified (5+ workers operational)
- [ ] PostgreSQL tuning applied and benchmarked
- [ ] Monitoring procedures documented and functional
- [ ] Production hardening checklist completed
- [ ] Troubleshooting and recovery documentation complete

---

## Dependencies

### Depends On
- Phase 00: Foundation and Core Infrastructure (complete)

### Enables
- Production operations and scaling
- Disaster recovery capabilities
- Performance optimization
