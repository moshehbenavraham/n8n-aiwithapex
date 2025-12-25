# Session 02: Worker Scaling and Queue Optimization

**Session ID**: `phase01-session02-worker-scaling`
**Status**: Not Started
**Estimated Tasks**: ~20-25
**Estimated Duration**: 2-4 hours

---

## Important: WSL2 Ubuntu Only

**All commands and operations run exclusively from WSL2 Ubuntu.** There is NO need for PowerShell, CMD, or Windows Terminal.

---

## Objective

Configure n8n worker scaling to support 5+ worker instances with optimized concurrency settings, enable manual execution offloading, and verify queue mode performance under load.

---

## Scope

### In Scope (MVP)
- Configure Docker Compose for worker replicas (5 workers)
- Tune worker concurrency settings (5-10 per worker)
- Enable OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS
- Update environment variables for optimal queue performance
- Test scaling up workers (1 -> 5)
- Test scaling down workers (5 -> 2)
- Verify queue distribution across workers
- Memory usage monitoring during scaling
- Document scaling procedures

### Out of Scope
- Auto-scaling based on queue depth (future enhancement)
- Kubernetes-style orchestration
- Worker-specific configuration (all workers identical)
- Load balancer configuration

---

## Prerequisites

- [ ] Phase 00 completed - queue mode operational
- [ ] Single worker currently running and processing jobs
- [ ] Redis queue functional
- [ ] Docker Compose available for scaling commands
- [ ] Sufficient WSL2 memory for additional workers (monitor 8GB limit)

---

## Deliverables

1. Updated `docker-compose.yml` with deploy replicas configuration
2. Updated `.env` with optimized worker settings
3. Worker scaling procedure documentation
4. Concurrency tuning recommendations
5. Memory usage baseline with 5 workers
6. Queue distribution verification
7. Scaling command reference

---

## Technical Details

### Docker Compose Worker Scaling
```yaml
n8n-worker:
  deploy:
    replicas: 5
    resources:
      limits:
        memory: 512M
```

### Environment Variables
```bash
# Worker concurrency (per worker)
EXECUTIONS_CONCURRENCY=10

# Offload manual executions to workers
OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true

# Queue settings
QUEUE_BULL_REDIS_TIMEOUT_THRESHOLD=60000
QUEUE_HEALTH_CHECK_ACTIVE=true
```

### Scaling Commands
```bash
# Scale to 5 workers
docker compose up -d --scale n8n-worker=5

# Scale down to 2 workers
docker compose up -d --scale n8n-worker=2

# Check worker status
docker compose ps n8n-worker
```

### Memory Calculation
- 5 workers x 512MB limit = 2.5GB reserved
- Plus postgres (~256MB) + redis (~128MB) + n8n main (~512MB)
- Total: ~3.5GB of 8GB WSL2 allocation

---

## Success Criteria

- [ ] Docker Compose configured for 5 worker replicas
- [ ] All 5 workers running and healthy
- [ ] Queue jobs distributed across workers
- [ ] Manual execution offload enabled and verified
- [ ] Memory usage stable under 8GB WSL2 limit
- [ ] Scaling up/down procedures documented and tested
- [ ] Worker concurrency optimized (50 total: 5 workers x 10)
