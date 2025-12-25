# Session 04: Service Deployment and Verification

**Session ID**: `phase00-session04-service-deployment-and-verification`
**Status**: Not Started
**Estimated Tasks**: ~20-25
**Estimated Duration**: 2-3 hours

---

## Important: WSL2 Ubuntu Only

**All commands run exclusively from WSL2 Ubuntu.** Docker commands execute natively in Ubuntu.

---

## Objective

Deploy all Docker containers for the n8n stack, verify service health, confirm queue mode operation, and ensure the complete system is functional and accessible.

---

## Scope

### In Scope (MVP)
- Pull required Docker images (postgres, redis, n8n)
- Deploy PostgreSQL container and verify health
- Deploy Redis container and verify health
- Deploy n8n main container and verify health
- Deploy n8n worker container and verify queue connection
- Verify inter-service connectivity
- Access n8n UI and complete initial setup
- Test queue mode by running a workflow
- Verify health and metrics endpoints
- Document running system state

### Out of Scope
- Worker scaling (Phase 01)
- Backup configuration (Phase 01)
- Performance tuning (Phase 01)
- Custom workflow creation
- External integrations

---

## Prerequisites

- [ ] Session 03 completed (all config files ready)
- [ ] Docker service running
- [ ] Port 5678 available on host
- [ ] Internet connection for image pulls

---

## Deliverables

1. All containers running and healthy:
   - postgres (PostgreSQL 16)
   - redis (Redis 7)
   - n8n (main instance)
   - n8n-worker (queue worker)
2. n8n accessible at http://localhost:5678
3. Initial n8n owner account created
4. Queue mode verified functional
5. Health endpoint responding (/healthz)
6. Metrics endpoint accessible (/metrics)
7. System documentation with container status

---

## Technical Details

### Deployment Sequence
```bash
# Pull images first
docker compose pull

# Start services in dependency order
docker compose up -d postgres
# Wait for postgres healthy
docker compose up -d redis
# Wait for redis healthy
docker compose up -d n8n
# Wait for n8n healthy
docker compose up -d n8n-worker
```

### Health Verification
```bash
# Check all container status
docker compose ps

# Check container health
docker inspect --format='{{.State.Health.Status}}' <container>

# Check logs for errors
docker compose logs --tail=50

# Test n8n health endpoint
curl http://localhost:5678/healthz
```

### Queue Mode Verification
1. Access n8n UI at http://localhost:5678
2. Create owner account
3. Create simple test workflow (Manual Trigger -> Set Node)
4. Execute workflow
5. Verify execution appears in worker logs
6. Confirm execution history in n8n UI

### Service Endpoints
- **n8n UI**: http://localhost:5678
- **Health**: http://localhost:5678/healthz
- **Metrics**: http://localhost:5678/metrics
- **Webhooks**: http://localhost:5678/webhook/...

---

## Success Criteria

- [ ] All 4 containers running (docker compose ps shows 4 healthy)
- [ ] PostgreSQL container healthy and accepting connections
- [ ] Redis container healthy and responding to PING
- [ ] n8n main container healthy and UI accessible
- [ ] n8n worker container connected to queue
- [ ] http://localhost:5678 loads n8n UI
- [ ] Owner account created successfully
- [ ] Test workflow executes via worker (check worker logs)
- [ ] /healthz returns 200 OK
- [ ] /metrics returns Prometheus-format metrics
- [ ] No error logs in any container
- [ ] Container restart policy verified (restart: unless-stopped)
