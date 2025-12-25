# Session Specification

**Session ID**: `phase00-session04-service-deployment-and-verification`
**Phase**: 00 - Foundation and Core Infrastructure
**Status**: Not Started
**Created**: 2025-12-25

---

## 1. Session Overview

This is the culminating session of Phase 00, where all the foundation work comes together into a running n8n automation platform. Sessions 01-03 prepared the environment (WSL2 optimization), installed the container runtime (Docker Engine), and created all configuration files (docker-compose.yml, .env, postgres-init.sql). Now we deploy the actual containers and verify the complete system is functional.

The session follows a deliberate deployment sequence: PostgreSQL first (database foundation), then Redis (message broker for queue mode), then n8n main instance (UI, webhooks, triggers), and finally n8n-worker (queue job processor). Each service must be healthy before proceeding to the next, ensuring reliable inter-service connectivity.

Upon completion, you will have a production-ready n8n installation running locally in WSL2, with queue mode enabled for distributed workflow execution. This marks Phase 00 as complete and unlocks Phase 01 operations work (backups, scaling, tuning).

---

## 2. Objectives

1. Deploy all 4 Docker containers in correct dependency order with verified health status
2. Confirm n8n UI is accessible at http://localhost:5678 and complete initial owner setup
3. Verify queue mode operation by executing a test workflow and confirming worker processing
4. Validate health (/healthz) and metrics (/metrics) endpoints are responding correctly

---

## 3. Prerequisites

### Required Sessions
- [x] `phase00-session01-wsl2-environment-optimization` - WSL2 configured with 8GB RAM, 4 CPU cores
- [x] `phase00-session02-docker-engine-installation` - Docker Engine and Compose plugin installed
- [x] `phase00-session03-project-structure-and-configuration` - All config files created and validated

### Required Tools/Knowledge
- Docker Compose CLI commands (docker compose up, ps, logs, exec)
- Basic curl for endpoint testing
- Browser for n8n UI access

### Environment Requirements
- Docker service running (`sudo service docker status`)
- Port 5678 available on host (not used by other services)
- Internet connection for pulling Docker images (~500MB total)
- Project directory: `/home/aiwithapex/n8n`

---

## 4. Scope

### In Scope (MVP)
- Pull Docker images: postgres:16-alpine, redis:7-alpine, n8nio/n8n:latest
- Deploy PostgreSQL container and wait for healthy status
- Deploy Redis container and wait for healthy status
- Deploy n8n main container and wait for healthy status
- Deploy n8n-worker container and verify queue connection
- Verify inter-service connectivity (n8n -> postgres, n8n -> redis)
- Access n8n UI and create initial owner account
- Create and execute a simple test workflow
- Verify workflow execution appears in worker logs (queue mode confirmation)
- Test /healthz endpoint returns 200 OK
- Test /metrics endpoint returns Prometheus-format data
- Document final system state (container status, versions, endpoints)

### Out of Scope (Deferred)
- Worker scaling (1 to 5+ instances) - *Reason: Phase 01 scope*
- Backup script creation and scheduling - *Reason: Phase 01 scope*
- PostgreSQL performance tuning - *Reason: Phase 01 scope*
- Custom workflow development - *Reason: Not part of infrastructure setup*
- External integrations/credentials setup - *Reason: User-specific, post-setup activity*
- SSL/TLS configuration - *Reason: Localhost environment, not needed*

---

## 5. Technical Approach

### Architecture

```
+-------------------+     +------------------+     +------------------+
|    PostgreSQL     |     |      Redis       |     |   n8n-worker     |
|   (n8n-postgres)  |     |   (n8n-redis)    |     |  (queue jobs)    |
|  Port: 5432 int   |     | Port: 6379 int   |     |                  |
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

### Design Patterns
- **Dependency-ordered startup**: Containers start in sequence based on health dependencies
- **Health check gates**: Each service must be healthy before dependents start
- **Shared network**: All containers on `n8n-network` bridge for internal DNS resolution

### Technology Stack
- PostgreSQL 16-alpine: Production database, persistent volume `postgres_data`
- Redis 7-alpine: Message broker for queue mode, persistent volume `redis_data`
- n8n latest (Community Edition): Workflow automation platform
- Docker Compose v2+: Container orchestration

---

## 6. Deliverables

### Files to Create
| File | Purpose | Est. Lines |
|------|---------|------------|
| `docs/DEPLOYMENT_STATUS.md` | Document running system state and verification results | ~80 |

### Files to Modify
| File | Changes | Est. Lines |
|------|---------|------------|
| None | All configuration files ready from Session 03 | - |

### Runtime Artifacts (Not Files)
| Artifact | Purpose |
|----------|---------|
| 4 running containers | postgres, redis, n8n, n8n-worker |
| Named Docker volumes | postgres_data, redis_data, n8n_data |
| n8n owner account | Initial admin user created via UI |
| Test workflow | Simple workflow to verify queue mode |

---

## 7. Success Criteria

### Functional Requirements
- [ ] `docker compose ps` shows 4 containers with status "healthy" or "running"
- [ ] PostgreSQL container accepting connections (pg_isready passes)
- [ ] Redis container responding to PING command
- [ ] n8n UI loads at http://localhost:5678
- [ ] Owner account created successfully via setup wizard
- [ ] Test workflow created and executed
- [ ] Worker logs show job processing (confirms queue mode)
- [ ] `/healthz` returns HTTP 200 OK
- [ ] `/metrics` returns Prometheus-format metrics data

### Testing Requirements
- [ ] Manual testing: All verification commands executed successfully
- [ ] Manual testing: UI walkthrough completed
- [ ] Manual testing: Workflow execution verified end-to-end

### Quality Gates
- [ ] No error messages in container logs (docker compose logs)
- [ ] All containers have restart policy "unless-stopped"
- [ ] Container health checks passing consistently
- [ ] Documentation created with system state

---

## 8. Implementation Notes

### Key Considerations
- **Image pull time**: First pull downloads ~500MB, allow 5-10 minutes on typical connection
- **Startup order matters**: PostgreSQL and Redis must be healthy before n8n starts
- **Health check timing**: Services have start_period configured, allow time for initialization
- **Owner account security**: Use a strong password, this is the admin account
- **WSL2 networking**: localhost:5678 accessible from Windows browser automatically

### Potential Challenges
- **Port 5678 conflict**: Check with `lsof -i :5678` before starting, stop conflicting service
- **Image pull failure**: Retry with `docker compose pull <service>` for specific service
- **Container won't start**: Check logs with `docker compose logs <service> --tail=100`
- **Health check timeout**: Increase start_period in docker-compose.yml if needed
- **Worker not processing**: Verify Redis connectivity, check QUEUE_BULL_REDIS_HOST env var

### Deployment Commands Reference
```bash
# Pre-flight checks
sudo service docker status
lsof -i :5678

# Pull all images
docker compose pull

# Sequential deployment with health verification
docker compose up -d postgres
docker compose ps postgres  # Wait for healthy
docker compose up -d redis
docker compose ps redis     # Wait for healthy
docker compose up -d n8n
docker compose ps n8n       # Wait for healthy
docker compose up -d n8n-worker
docker compose ps           # All 4 should be running

# Verification
curl -s http://localhost:5678/healthz
curl -s http://localhost:5678/metrics | head -20
docker compose logs n8n-worker --tail=20
```

### ASCII Reminder
All output files must use ASCII-only characters (0-127).

---

## 9. Testing Strategy

### Integration Tests (Primary Focus)
- Container connectivity: n8n can query PostgreSQL database
- Container connectivity: n8n can connect to Redis queue
- Worker connectivity: n8n-worker receives and processes jobs from Redis
- End-to-end: Workflow execution flows through queue to worker

### Manual Testing
1. **Container Health Verification**
   - Run `docker compose ps` and verify 4 healthy containers
   - Run `docker inspect` health check for each container

2. **PostgreSQL Verification**
   - Exec into container: `docker compose exec postgres pg_isready`
   - Verify n8n database exists: `docker compose exec postgres psql -U n8n -d n8n -c '\dt'`

3. **Redis Verification**
   - Exec into container: `docker compose exec redis redis-cli ping`
   - Check queue keys: `docker compose exec redis redis-cli keys '*'`

4. **n8n UI Verification**
   - Open http://localhost:5678 in browser
   - Complete owner account setup wizard
   - Navigate to Settings > General to verify version

5. **Queue Mode Verification**
   - Create workflow: Manual Trigger -> Set Node -> End
   - Execute workflow manually
   - Check worker logs: `docker compose logs n8n-worker --tail=50`
   - Verify "Execution started" appears in worker output

6. **Endpoint Verification**
   - `curl http://localhost:5678/healthz` returns 200
   - `curl http://localhost:5678/metrics` returns metrics

### Edge Cases
- Container restart recovery: Stop container, verify auto-restart
- Service dependency: Stop postgres, verify n8n reports database error
- Port availability: Handle 5678 already in use scenario

---

## 10. Dependencies

### External Libraries
- Docker images (pulled from Docker Hub):
  - `postgres:16-alpine`
  - `redis:7-alpine`
  - `n8nio/n8n:latest`

### Other Sessions
- **Depends on**:
  - `phase00-session01-wsl2-environment-optimization` (WSL2 resources)
  - `phase00-session02-docker-engine-installation` (Docker runtime)
  - `phase00-session03-project-structure-and-configuration` (Config files)
- **Depended by**:
  - All Phase 01 sessions (Operations and Optimization)
  - This completes Phase 00 foundation

---

## Configuration Reference

### Existing Files (from Session 03)
```
/home/aiwithapex/n8n/
├── docker-compose.yml      # 4 services defined
├── .env                    # All environment variables
├── config/
│   └── postgres-init.sql   # Database initialization
└── data/
    ├── n8n/files/          # Binary file storage
    ├── postgres/           # (volume mount, not used directly)
    └── redis/              # (volume mount, not used directly)
```

### Service Endpoints
| Service | Internal | External |
|---------|----------|----------|
| PostgreSQL | postgres:5432 | Not exposed |
| Redis | redis:6379 | Not exposed |
| n8n UI | n8n:5678 | localhost:5678 |
| n8n Health | n8n:5678/healthz | localhost:5678/healthz |
| n8n Metrics | n8n:5678/metrics | localhost:5678/metrics |

---

## Next Steps

Run `/tasks` to generate the implementation task checklist.
