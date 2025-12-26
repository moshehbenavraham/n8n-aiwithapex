# PostgreSQL Tuning Guide

This document describes the PostgreSQL configuration tuning applied to the n8n deployment for optimal performance in the WSL2 environment.

## Overview

The default PostgreSQL configuration is designed for broad compatibility, not performance. This tuning optimizes:

- **Memory allocation** for database caching
- **Connection handling** for multi-worker n8n deployment
- **WAL settings** for write performance
- **Query planner** for SSD storage characteristics

## Configuration File

**Location**: `config/postgresql.conf`

The configuration is mounted read-only into the container at `/etc/postgresql/postgresql.conf`.

## Tuned Parameters

### Memory Settings

| Parameter | Default | Tuned | Purpose |
|-----------|---------|-------|---------|
| shared_buffers | 128MB | 512MB | Main database cache |
| effective_cache_size | 4GB | 2GB | Query planner hint (not allocation) |
| work_mem | 4MB | 32MB | Per-operation memory for sorts/hashes |
| maintenance_work_mem | 64MB | 128MB | VACUUM, CREATE INDEX operations |

### Connection Settings

| Parameter | Default | Tuned | Purpose |
|-----------|---------|-------|---------|
| listen_addresses | localhost | * | Allow container networking |
| max_connections | 100 | 100 | No change needed |

### WAL (Write-Ahead Log) Settings

| Parameter | Default | Tuned | Purpose |
|-----------|---------|-------|---------|
| wal_buffers | 4MB | 16MB | WAL buffer size |
| checkpoint_completion_target | 0.9 | 0.9 | No change needed |

### Query Planner (SSD Optimization)

| Parameter | Default | Tuned | Purpose |
|-----------|---------|-------|---------|
| random_page_cost | 4.0 | 1.1 | SSD has low random I/O cost |
| effective_io_concurrency | 1 | 200 | SSD supports high parallelism |

## Memory Budget

Total WSL2 memory: **8GB**

Allocation strategy:
- PostgreSQL shared_buffers: 512MB
- PostgreSQL work_mem: 32MB per operation
- n8n main: ~256MB
- n8n workers (5x): ~512MB each = 2.5GB
- Redis: ~100MB
- WSL2 overhead: ~1GB
- OS cache: remaining

This leaves adequate headroom for the operating system and temporary spikes.

## Benchmark Results

Benchmarks run with pgbench (scale factor 10, 5 clients, 30s duration):

| Configuration | TPS | Improvement |
|---------------|-----|-------------|
| Default | 2519.20 | - |
| Tuned | 2640.06 | +4.8% |

**Note**: The modest pgbench improvement is expected because:
1. WSL2's virtualized disk I/O is the bottleneck
2. The test dataset fits in memory with both configurations
3. Real n8n workflows with complex queries benefit more from increased work_mem

## Rollback Procedure

If issues arise, rollback to default PostgreSQL settings:

### Step 1: Edit docker-compose.yml

Remove the `command` and config volume mount from the postgres service:

```yaml
# REMOVE these lines:
command: postgres -c config_file=/etc/postgresql/postgresql.conf
# And from volumes:
- ./config/postgresql.conf:/etc/postgresql/postgresql.conf:ro
```

The postgres service should look like:

```yaml
postgres:
  image: postgres:16-alpine
  container_name: n8n-postgres
  restart: unless-stopped
  environment:
    POSTGRES_USER: ${POSTGRES_USER}
    POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    POSTGRES_DB: ${POSTGRES_DB}
  volumes:
    - postgres_data:/var/lib/postgresql/data
    - ./config/postgres-init.sql:/docker-entrypoint-initdb.d/init.sql:ro
  # ... healthcheck and networks unchanged
```

### Step 2: Restart PostgreSQL

```bash
docker compose up -d postgres
```

### Step 3: Verify Default Settings

```bash
docker compose exec postgres psql -U n8n -d n8n -c "SHOW shared_buffers;"
# Should show: 128MB (default)
```

### Step 4: Restart Dependent Services

```bash
docker compose restart n8n n8n-worker
```

## Verification Commands

Check current configuration:

```bash
# Show all tuned parameters
docker compose exec postgres psql -U n8n -d n8n -c "
SELECT name, setting, unit
FROM pg_settings
WHERE name IN (
  'shared_buffers', 'effective_cache_size', 'work_mem',
  'maintenance_work_mem', 'max_connections', 'wal_buffers',
  'checkpoint_completion_target', 'random_page_cost',
  'effective_io_concurrency', 'listen_addresses'
)
ORDER BY name;
"
```

Check PostgreSQL logs:

```bash
docker compose logs postgres --tail 50
```

## Troubleshooting

### Container fails to start

**Symptom**: PostgreSQL container restarts repeatedly

**Cause**: Configuration file permission or syntax error

**Solution**:
1. Check logs: `docker compose logs postgres`
2. Verify file permissions: `chmod 644 config/postgresql.conf`
3. Validate syntax: ensure no special characters or Windows line endings

### Services cannot connect

**Symptom**: n8n shows database connection errors

**Cause**: `listen_addresses` not set to `*`

**Solution**: Ensure `listen_addresses = '*'` is in postgresql.conf

### Out of Memory

**Symptom**: PostgreSQL or other services killed by OOM

**Cause**: Memory overallocation

**Solution**: Reduce shared_buffers or work_mem values

## Files Reference

| File | Purpose |
|------|---------|
| `config/postgresql.conf` | Tuned PostgreSQL configuration |
| `scripts/postgres-benchmark.sh` | Benchmark script for testing |
| `data/benchmark/baseline.txt` | Pre-tuning benchmark results |
| `data/benchmark/tuned.txt` | Post-tuning benchmark results |

## Session Information

- **Session**: phase01-session03-postgresql-tuning
- **Applied**: 2025-12-26
- **Environment**: WSL2, 8GB RAM, SSD storage
