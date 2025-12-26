# Session Specification

**Session ID**: `phase01-session03-postgresql-tuning`
**Phase**: 01 - Operations and Optimization
**Status**: Not Started
**Created**: 2025-12-26

---

## 1. Session Overview

This session configures PostgreSQL for optimal n8n workflow execution within the WSL2 environment's 8GB RAM constraint. The default PostgreSQL configuration is designed for broad compatibility, not performance. By tuning memory allocation, connection handling, and write-ahead logging, we can achieve significant throughput improvements for n8n's database-intensive operations.

The timing is strategic: backup automation (Session 01) provides a safety net for configuration changes, and worker scaling (Session 02) means the database now serves 5 concurrent workers plus the main instance. Tuning ensures the database can handle this increased load efficiently before we establish monitoring baselines in Session 04.

All configuration changes are non-destructive and easily reversible. We'll benchmark before and after to quantify improvements, with a documented rollback procedure if issues arise.

---

## 2. Objectives

1. Create a production-tuned postgresql.conf optimized for n8n workloads within 8GB WSL2 memory constraints
2. Integrate the custom configuration into the Docker Compose deployment with proper volume mounting
3. Validate performance improvement through before/after benchmarking (target: 20%+ TPS improvement)
4. Document rollback procedure to restore default configuration if needed

---

## 3. Prerequisites

### Required Sessions
- [x] `phase00-session04-service-deployment-and-verification` - PostgreSQL container running and healthy
- [x] `phase01-session01-backup-automation` - Data protection before configuration changes
- [x] `phase01-session02-worker-scaling` - Worker pool configured (5 workers + main = 6 connections baseline)

### Required Tools/Knowledge
- PostgreSQL configuration parameters and their effects
- Docker Compose volume mounting for configuration files
- pgbench for PostgreSQL benchmarking

### Environment Requirements
- PostgreSQL container running and healthy
- Sufficient disk space for benchmark data (~100MB temporary)
- No active n8n workflow executions during restart

---

## 4. Scope

### In Scope (MVP)
- Create `config/postgresql.conf` with tuned memory, connection, and WAL settings
- Update `docker-compose.yml` to mount configuration and override startup command
- Capture baseline benchmark metrics before tuning
- Apply configuration and restart PostgreSQL cleanly
- Capture post-tuning benchmark metrics and compare
- Document rollback procedure in `docs/POSTGRESQL_TUNING.md`

### Out of Scope (Deferred)
- Connection pooling (PgBouncer) - *Reason: Adds complexity; evaluate if connection limits become an issue*
- Replication configuration - *Reason: Single-instance deployment, no HA requirement*
- Vacuum tuning - *Reason: Default autovacuum settings adequate for current workload*
- Query-level optimization - *Reason: n8n generates queries; no control over query patterns*
- Index creation/optimization - *Reason: n8n manages its own schema and indexes*

---

## 5. Technical Approach

### Architecture
The custom postgresql.conf file is mounted read-only into the container, and PostgreSQL is started with an explicit `-c config_file=` argument to load it. This approach:
- Preserves the original configuration inside the container image
- Allows version-controlled configuration changes
- Enables easy rollback by removing the mount and command override

### Design Patterns
- **Configuration as Code**: postgresql.conf in version control with the project
- **Conservative Memory Allocation**: Stay well under 8GB WSL2 limit to leave room for other services
- **Immutable Config Mount**: Read-only mount prevents accidental modification

### Technology Stack
- PostgreSQL 16-alpine (current container image)
- pgbench (built into PostgreSQL, used for benchmarking)
- Docker Compose volume mounts for configuration injection

---

## 6. Deliverables

### Files to Create
| File | Purpose | Est. Lines |
|------|---------|------------|
| `config/postgresql.conf` | Custom PostgreSQL configuration with tuned settings | ~50 |
| `docs/POSTGRESQL_TUNING.md` | Tuning documentation with parameters explained and rollback procedure | ~100 |
| `scripts/postgres-benchmark.sh` | Benchmark script for before/after comparison | ~60 |

### Files to Modify
| File | Changes | Est. Lines Changed |
|------|---------|-------------------|
| `docker-compose.yml` | Add config volume mount and command override to postgres service | ~5 |

---

## 7. Success Criteria

### Functional Requirements
- [ ] Custom postgresql.conf created with all specified tuning parameters
- [ ] Configuration successfully mounted in container at expected path
- [ ] PostgreSQL starts cleanly with new configuration (no startup errors)
- [ ] Configuration verified active via `SHOW` commands
- [ ] Benchmark shows measurable TPS improvement (target: 20%+)
- [ ] No errors in PostgreSQL logs after tuning

### Testing Requirements
- [ ] Baseline benchmark captured before any changes
- [ ] PostgreSQL restart completes successfully with new config
- [ ] Post-tuning benchmark shows improvement
- [ ] Configuration values verified via psql SHOW commands

### Quality Gates
- [ ] All files ASCII-encoded (no special characters)
- [ ] Unix LF line endings
- [ ] postgresql.conf follows standard INI format with comments
- [ ] Rollback procedure tested and documented

---

## 8. Implementation Notes

### Key Considerations
- **Memory Budget**: With 8GB WSL2 total, allocate conservatively:
  - shared_buffers: 512MB (PostgreSQL)
  - effective_cache_size: 2GB (informs query planner, not allocation)
  - Remaining: Redis, n8n main, 5 workers, OS overhead
- **Connection Math**: 5 workers + 1 main + overhead = max_connections: 100 (conservative)
- **SSD Optimization**: WSL2 uses virtual disk on SSD; tune random_page_cost and effective_io_concurrency accordingly

### Potential Challenges
- **Container restart required**: Must coordinate with any running workflows; advise user to pause
- **Benchmark variability**: WSL2 I/O can be variable; run multiple iterations and average
- **Configuration syntax errors**: Validate config before applying; PostgreSQL won't start with invalid config

### Relevant Considerations
- [P00] **WSL2 8GB RAM constraint**: Memory settings (shared_buffers=512MB, work_mem=32MB) chosen conservatively to leave headroom for Redis, n8n services, and WSL2 overhead
- [P00] **Named Docker volumes**: Using existing `postgres_data` volume; adding bind mount only for config file (not replacing data volume)
- [P00] **PostgreSQL init scripts only run on first start**: This session doesn't modify init scripts; config changes apply on restart regardless of data volume state
- [P00] **docker compose (space)**: Use `docker compose` not `docker-compose` in all commands and scripts

### ASCII Reminder
All output files must use ASCII-only characters (0-127). No special quotes, em-dashes, or non-ASCII symbols.

---

## 9. Testing Strategy

### Unit Tests
- Validate postgresql.conf syntax (PostgreSQL will refuse to start if invalid)
- Verify all required parameters are present and uncommented

### Integration Tests
- PostgreSQL container starts successfully with mounted config
- All services (redis, n8n, workers) reconnect after postgres restart
- n8n UI accessible and functional after restart

### Manual Testing
- Run pgbench with identical parameters before and after
- Execute SHOW commands to verify configuration values
- Check PostgreSQL logs for warnings or errors
- Run a test workflow in n8n to verify database operations work

### Edge Cases
- Configuration file with Windows line endings (must use LF)
- Typos in parameter names (PostgreSQL will fail to start)
- Memory overallocation causing OOM (conservative settings prevent this)

---

## 10. Dependencies

### External Libraries
- None (using built-in PostgreSQL tools)

### Other Sessions
- **Depends on**:
  - phase00-session04-service-deployment-and-verification (PostgreSQL running)
  - phase01-session01-backup-automation (data protection)
  - phase01-session02-worker-scaling (connection requirements known)
- **Depended by**:
  - phase01-session04-monitoring-health (tuned database for accurate baselines)
  - phase01-session05-production-hardening (tuning documentation feeds into hardening)

---

## PostgreSQL Configuration Parameters

### Memory Settings
| Parameter | Value | Rationale |
|-----------|-------|-----------|
| shared_buffers | 512MB | ~25% of available memory, conservative for 8GB WSL2 |
| effective_cache_size | 2GB | Hint to planner; OS cache estimate, not allocation |
| work_mem | 32MB | Per-operation memory for sorts/hashes |
| maintenance_work_mem | 128MB | For VACUUM, CREATE INDEX operations |

### Connection Settings
| Parameter | Value | Rationale |
|-----------|-------|-----------|
| max_connections | 100 | 5 workers + main + overhead; room for growth |

### WAL Settings
| Parameter | Value | Rationale |
|-----------|-------|-----------|
| wal_buffers | 16MB | Adequate for shared_buffers size |
| checkpoint_completion_target | 0.9 | Spread checkpoint I/O over time |

### Query Planner (SSD)
| Parameter | Value | Rationale |
|-----------|-------|-----------|
| random_page_cost | 1.1 | SSD has low random I/O penalty |
| effective_io_concurrency | 200 | SSD supports high parallel I/O |

---

## Next Steps

Run `/tasks` to generate the implementation task checklist.
