# Session 03: PostgreSQL Performance Tuning

**Session ID**: `phase01-session03-postgresql-tuning`
**Status**: Not Started
**Estimated Tasks**: ~15-20
**Estimated Duration**: 2-3 hours

---

## Important: WSL2 Ubuntu Only

**All commands and operations run exclusively from WSL2 Ubuntu.** There is NO need for PowerShell, CMD, or Windows Terminal.

---

## Objective

Configure PostgreSQL performance tuning for optimal n8n workflow execution, applying memory, connection, and query optimization settings appropriate for the WSL2 environment.

---

## Scope

### In Scope (MVP)
- Create custom postgresql.conf with tuned settings
- Configure shared_buffers for available memory
- Tune work_mem and maintenance_work_mem
- Optimize max_connections for worker pool
- Configure effective_cache_size
- Apply WAL (Write-Ahead Log) optimizations
- Mount configuration file in Docker Compose
- Benchmark before/after configuration changes
- Verify performance improvement

### Out of Scope
- Connection pooling (PgBouncer)
- Replication configuration
- Vacuum tuning (use defaults)
- Query-level optimization
- Index creation/optimization

---

## Prerequisites

- [ ] PostgreSQL container running and healthy
- [ ] Baseline performance metrics captured
- [ ] Understanding of current workload patterns
- [ ] Backup of PostgreSQL data (Session 01 complete preferred)

---

## Deliverables

1. `config/postgresql.conf` - Custom PostgreSQL configuration
2. Updated `docker-compose.yml` with config volume mount
3. Before/after benchmark results
4. Performance tuning documentation
5. Rollback procedure if issues arise

---

## Technical Details

### Memory Allocation (for 8GB WSL2)
```ini
# postgresql.conf tuning for n8n workloads

# Memory Settings (conservative for 8GB WSL2)
shared_buffers = 512MB          # 25% of available, but conservative
effective_cache_size = 2GB       # 50% of available
work_mem = 32MB                  # Per-operation memory
maintenance_work_mem = 128MB     # For VACUUM, CREATE INDEX

# Connection Settings
max_connections = 100            # Support 5 workers + overhead

# WAL Settings
wal_buffers = 16MB
checkpoint_completion_target = 0.9

# Query Planner
random_page_cost = 1.1           # SSD-appropriate
effective_io_concurrency = 200   # SSD-appropriate
```

### Docker Compose Volume Mount
```yaml
postgres:
  volumes:
    - postgres_data:/var/lib/postgresql/data
    - ./config/postgresql.conf:/etc/postgresql/postgresql.conf:ro
  command: postgres -c config_file=/etc/postgresql/postgresql.conf
```

### Benchmark Approach
```bash
# Before tuning
docker exec postgres pgbench -U n8n -i -s 10 n8n
docker exec postgres pgbench -U n8n -c 10 -j 2 -T 60 n8n

# After tuning (same commands, compare TPS)
```

---

## Success Criteria

- [ ] Custom postgresql.conf created with tuned settings
- [ ] Configuration mounted and active in container
- [ ] PostgreSQL starts successfully with new config
- [ ] Benchmark shows measurable improvement (target: 20%+ TPS)
- [ ] No errors in PostgreSQL logs after tuning
- [ ] Rollback procedure documented
