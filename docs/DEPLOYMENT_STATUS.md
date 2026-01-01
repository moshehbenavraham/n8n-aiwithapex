# n8n Deployment Status

**Last Updated**: 2025-12-28

---

## Deployment Forms

This project supports two deployment forms. See [Deployment Comparison](deployment-comparison.md) for details.

| Deployment | Status | URL | Documentation |
|------------|--------|-----|---------------|
| **WSL2 (Local)** | OPERATIONAL | https://your.ngrok.domain | [Installation Plan](n8n-installation-plan.md) |
| **Coolify (Cloud)** | PLANNING | https://n8n-apex.aiwithapex.com | [Deploy to Coolify](ongoing-roadmap/deploy-to-coolify.md) |

---

## WSL2 Local Deployment

**Deployment Date**: 2025-12-25
**Status**: OPERATIONAL
**Session**: phase00-session04-service-deployment-and-verification

### System Overview

This section documents the state of the WSL2 local deployment completed in Phase 00, Session 04.

### Architecture

```
+-------------------+     +------------------+     +------------------+
|    PostgreSQL     |     |      Redis       |     |   n8n-worker     |
|   (n8n-postgres)  |     |   (n8n-redis)    |     |  (queue jobs)    |
|  Port: 5432 int   |     | Port: 6386 int   |     |  Concurrency: 10 |
+--------+----------+     +--------+---------+     +--------+---------+
         |                         |                        |
         |                         |                        |
         +------------+------------+------------------------+
                      |
                      v
         +------------+------------+
         |         n8n-main        |
         |   (UI, webhooks, API)   |
         |   Port: 5678 -> host    |
         +-------------------------+
                      |
                      v
              http://localhost:5678
```

---

## Container Status

| Container | Image | Version | Status | Health |
|-----------|-------|---------|--------|--------|
| n8n-postgres | postgres:16-alpine | 16.11 | Running | Healthy |
| n8n-redis | redis:7-alpine | 7.4.7 | Running | Healthy |
| n8n-main | n8nio/n8n:latest | 2.1.4 | Running | Healthy |
| n8n-worker | n8nio/n8n:latest | 2.1.4 | Running | Healthy |

---

## Service Endpoints

| Service | Internal Endpoint | External Endpoint | Status |
|---------|-------------------|-------------------|--------|
| n8n UI | n8n:5678 | http://localhost:5678 | Accessible |
| Health Check | n8n:5678/healthz | http://localhost:5678/healthz | HTTP 200 OK |
| Metrics | n8n:5678/metrics | http://localhost:5678/metrics | Prometheus format |
| PostgreSQL | postgres:5432 | Not exposed | Internal only |
| Redis | redis:6386 | Not exposed | Internal only |

---

## Volume Configuration

| Volume Name | Purpose | Driver |
|-------------|---------|--------|
| n8n_postgres_data | PostgreSQL database files | local |
| n8n_redis_data | Redis persistence | local |
| n8n_n8n_data | n8n application data | local |

---

## Network Configuration

- **Network Name**: n8n_n8n-network
- **Driver**: bridge
- **Containers Connected**: 4 (postgres, redis, n8n, n8n-worker)

---

## Queue Mode Configuration

- **Execution Mode**: queue
- **Redis Host**: redis
- **Redis Port**: 6386
- **Worker Concurrency**: 10
- **Health Check Active**: true

---

## Verification Results

### Pre-Flight Checks
- [x] Docker daemon running (v29.1.3)
- [x] Docker Compose available (v5.0.0)
- [x] Port 5678 available
- [x] Configuration files present

### Container Health
- [x] PostgreSQL: pg_isready passes
- [x] Redis: PING returns PONG
- [x] n8n: /healthz returns 200 OK
- [x] n8n-worker: Process running, registered with task broker

### Endpoint Tests
- [x] /healthz: {"status":"ok"} (HTTP 200)
- [x] /metrics: Prometheus-format metrics returned (~10KB)

### Functional Tests
- [x] Owner account created via UI
- [x] Test workflow created and executed
- [x] Worker ready with JS Task Runner registered

---

## Environment Summary

| Component | Value |
|-----------|-------|
| Platform | WSL2 (Linux 6.6.87.2-microsoft-standard-WSL2) |
| Docker | v29.1.3 |
| Docker Compose | v5.0.0 |
| Project Directory | /home/aiwithapex/n8n |

---

## Operational Commands

```bash
# Start all services
docker compose up -d

# Stop all services
docker compose down

# View logs
docker compose logs -f

# View specific service logs
docker compose logs n8n --tail=100
docker compose logs n8n-worker --tail=100

# Check container health
docker compose ps

# Restart a service
docker compose restart n8n

# Scale workers (Phase 01)
docker compose up -d --scale n8n-worker=5
```

---

## Known Warnings

1. **Memory Overcommit**: Redis logs a warning about `vm.overcommit_memory`. This is a non-critical optimization that can be addressed in Phase 01.

2. **Manual Execution Offload**: The deprecation warning about `OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS` suggests setting this to `true` in future for better resource distribution.

---

## Next Steps (Phase 01)

1. Configure automated backups for PostgreSQL
2. Set up worker scaling (1 to 5+ instances)
3. Apply PostgreSQL performance tuning
4. Configure Redis memory overcommit
5. Set up monitoring and alerting

---

**Generated**: 2025-12-25 23:38 UTC
**Phase 00 Status**: COMPLETE

---

## Coolify Cloud Deployment

**Status**: PLANNING
**Target URL**: https://n8n-apex.aiwithapex.com
**Documentation**: [Deploy to Coolify](ongoing-roadmap/deploy-to-coolify.md)

### Current State

The Coolify deployment is currently in planning phase. A one-click n8n service exists in Coolify but will be replaced with the full production stack.

| Aspect | Current | Target |
|--------|---------|--------|
| Service Type | One-click n8n | Docker Compose stack |
| Execution Mode | Single instance | Queue mode + workers |
| Database | PostgreSQL (basic) | PostgreSQL (tuned) |
| Redis | None | Redis 7.4.7 |
| Workers | None | 3 workers |
| Domain | n8n.aiwithapex.com | n8n-apex.aiwithapex.com |

### Pre-Deployment Checklist

- [ ] Backup existing Coolify n8n data
- [ ] Extract encryption key from current service
- [ ] Push `docker-compose.coolify.yml` to GitHub
- [ ] Create new application in Coolify
- [ ] Configure environment variables
- [ ] Deploy and validate
- [ ] Migrate data (if applicable)
- [ ] Update webhook URLs
- [ ] Decommission old service

### Infrastructure UUIDs

| Resource | UUID |
|----------|------|
| Server | `rcgk0og40w0kwogock4k44s0` |
| Project | `m4cck40w0go4k88gwcg4k400` |
| Environment | `sko8scc0c0ok8gcwo0gscw8o` |
| Current n8n | `g8wow80sgg8oo0csg4sgkws0` |

---

**Last Updated**: 2025-12-28
