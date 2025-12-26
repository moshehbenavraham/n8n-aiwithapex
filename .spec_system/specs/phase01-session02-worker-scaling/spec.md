# Session Specification

**Session ID**: `phase01-session02-worker-scaling`
**Phase**: 01 - Operations and Optimization
**Status**: Not Started
**Created**: 2025-12-26

---

## 1. Session Overview

This session transforms the n8n installation from a single-worker configuration to a production-ready multi-worker architecture capable of handling parallel workflow executions. The current setup runs one worker with a concurrency of 10, providing a maximum of 10 simultaneous executions. After this session, the system will support 5 workers with a combined capacity of 50 concurrent executions.

The worker scaling implementation addresses two active concerns from Phase 00: the single worker limitation and the disabled manual execution offload. By enabling `OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS`, the main n8n instance focuses on UI responsiveness and webhook handling while workers process all execution workloads. This separation of concerns improves both user experience and system reliability.

This session is a prerequisite for Session 04 (Monitoring and Health), which requires the scaled worker architecture to be in place for comprehensive health monitoring across all worker instances.

---

## 2. Objectives

1. Configure Docker Compose to deploy and manage 5 n8n worker replicas with resource limits
2. Enable manual execution offloading to distribute all workflow executions to workers
3. Verify queue job distribution across all worker instances
4. Document scaling procedures for operational use

---

## 3. Prerequisites

### Required Sessions
- [x] `phase00-session01-wsl2-environment-optimization` - WSL2 8GB RAM allocation
- [x] `phase00-session02-docker-engine-installation` - Docker Engine with Compose v5
- [x] `phase00-session03-project-structure-and-configuration` - docker-compose.yml and .env
- [x] `phase00-session04-service-deployment-and-verification` - Running n8n stack with queue mode
- [x] `phase01-session01-backup-automation` - Data protection before scaling changes

### Required Tools/Knowledge
- Docker Compose v2+ with deploy syntax
- Understanding of n8n queue mode architecture
- Basic Redis queue concepts

### Environment Requirements
- All containers running and healthy
- WSL2 with 8GB RAM configured (sufficient for 5 workers)
- Redis queue functional (port 6386)

---

## 4. Scope

### In Scope (MVP)
- Add `deploy.replicas: 5` configuration to n8n-worker service
- Add memory resource limits (512MB per worker)
- Remove `container_name` from worker (required for replicas)
- Add `EXECUTIONS_CONCURRENCY=10` to .env
- Add `OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true` to .env
- Add `QUEUE_BULL_REDIS_TIMEOUT_THRESHOLD=60000` to .env
- Test scaling up (1 -> 5 workers)
- Test scaling down (5 -> 2 workers)
- Verify queue distribution via logs
- Document memory usage baseline
- Create scaling procedure documentation

### Out of Scope (Deferred)
- Auto-scaling based on queue depth - *Reason: Requires external monitoring integration*
- Kubernetes-style orchestration - *Reason: Out of project scope (Docker Compose only)*
- Worker-specific configuration - *Reason: All workers should be identical*
- Load balancer configuration - *Reason: Workers pull from queue, no load balancing needed*
- Worker health endpoint per instance - *Reason: Queue mode workers don't expose HTTP endpoints*

---

## 5. Technical Approach

### Architecture

```
                    +------------------+
                    |    n8n Main      |
                    |   (UI/Webhooks)  |
                    +--------+---------+
                             |
                             v
                    +------------------+
                    |      Redis       |
                    |     (Queue)      |
                    +--------+---------+
                             |
         +-------------------+-------------------+
         |         |         |         |         |
         v         v         v         v         v
    +--------+ +--------+ +--------+ +--------+ +--------+
    |Worker 1| |Worker 2| |Worker 3| |Worker 4| |Worker 5|
    +--------+ +--------+ +--------+ +--------+ +--------+

    Total Capacity: 5 workers x 10 concurrency = 50 simultaneous executions
```

### Design Patterns
- **Competing Consumers**: Workers pull jobs from Redis queue independently
- **Resource Limits**: Memory caps prevent individual worker from consuming excessive resources
- **Horizontal Scaling**: Identical workers can be added/removed dynamically

### Technology Stack
- Docker Compose v5.0.0+ with deploy syntax
- Redis 7-alpine (queue broker)
- n8n worker mode with Bull queue library

---

## 6. Deliverables

### Files to Create
| File | Purpose | Est. Lines |
|------|---------|------------|
| `docs/SCALING.md` | Worker scaling procedures and reference | ~80 |

### Files to Modify
| File | Changes | Est. Lines Changed |
|------|---------|-------------------|
| `docker-compose.yml` | Add deploy.replicas, resources, remove container_name | ~15 |
| `.env` | Add EXECUTIONS_CONCURRENCY, OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS, QUEUE_BULL_REDIS_TIMEOUT_THRESHOLD | ~10 |

---

## 7. Success Criteria

### Functional Requirements
- [ ] Docker Compose configured with `deploy.replicas: 5` for n8n-worker
- [ ] All 5 worker containers running and healthy
- [ ] Memory limits applied (512MB per worker)
- [ ] OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS enabled
- [ ] EXECUTIONS_CONCURRENCY set to 10 per worker
- [ ] Queue jobs distributed across workers (verified via logs)
- [ ] Manual execution from UI processed by worker (not main)
- [ ] Scaling up (1->5) works via `docker compose up -d`
- [ ] Scaling down (5->2) works via `docker compose up -d --scale n8n-worker=2`

### Testing Requirements
- [ ] Memory usage baseline captured with 5 workers (~3.5GB total)
- [ ] Queue distribution verified by creating test workflow
- [ ] Graceful scale-down verified (in-flight jobs complete)

### Quality Gates
- [ ] All files ASCII-encoded
- [ ] Unix LF line endings
- [ ] YAML document start marker (---) preserved
- [ ] docker compose config validates without errors
- [ ] All containers healthy after changes

---

## 8. Implementation Notes

### Key Considerations
- **Remove container_name**: Docker Compose requires unique container names; replicas auto-generate names like `n8n-n8n-worker-1`, `n8n-n8n-worker-2`, etc.
- **Memory calculation**: 5 workers x 512MB = 2.5GB + postgres (~256MB) + redis (~128MB) + n8n main (~512MB) = ~3.4GB of 8GB limit
- **Shared volume consideration**: All workers share `n8n_data` volume - this is correct for queue mode

### Potential Challenges
- **Log identification**: With multiple workers, logs must be filtered by container. Mitigation: Use `docker compose logs n8n-worker` to see all, or filter by replica name.
- **Scale-down job loss**: Jobs being processed during scale-down could be lost if not handled gracefully. Mitigation: Redis queue re-queues incomplete jobs after timeout.
- **Resource contention**: Five workers competing for CPU. Mitigation: Resource limits prevent any single worker from starving others.

### Relevant Considerations
- [P00] **Single worker instance**: Currently running 1 worker with concurrency 10. This session scales to 5+ workers for 50 total concurrent executions.
- [P00] **Manual execution offload**: OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS not enabled. Enabling it ensures UI-triggered executions route to workers, keeping main instance responsive.
- [P00] **WSL2 8GB RAM constraint**: Memory baseline with 5 workers must stay well under 8GB. Target: ~3.5GB leaves ~4.5GB headroom.
- [P00] **docker-compose hyphen**: Use `docker compose` (space) not `docker-compose` (hyphen). Already correct in project.
- [P00] **YAML document start marker**: Keep `---` at start of docker-compose.yml.

### ASCII Reminder
All output files must use ASCII-only characters (0-127).

---

## 9. Testing Strategy

### Verification Tests
1. **Worker count verification**
   ```bash
   docker compose ps n8n-worker --format "table {{.Name}}\t{{.Status}}"
   # Should show 5 workers, all "Up" or "healthy"
   ```

2. **Memory usage check**
   ```bash
   docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}"
   # Total should be under 4GB
   ```

3. **Queue distribution test**
   - Create a simple workflow in n8n UI
   - Execute it 10 times in quick succession
   - Check logs to verify different workers picked up jobs:
   ```bash
   docker compose logs n8n-worker --tail=50 | grep "Execution"
   ```

### Manual Testing
1. Scale workers from 1 to 5, verify all healthy
2. Execute workflow via UI, confirm worker processes it (not main)
3. Scale workers from 5 to 2, verify no job loss
4. Scale back to 5, verify queue continues working

### Edge Cases
- Worker crash during execution: Job should be re-queued by Redis
- All workers at max concurrency: Jobs queue in Redis until capacity available
- Redis connection loss: Workers should reconnect with exponential backoff

---

## 10. Dependencies

### External Libraries
- Docker Compose v5.0.0+ (already installed)
- Redis 7-alpine (already deployed)
- n8n with Bull queue library (built into n8n image)

### Other Sessions
- **Depends on**:
  - `phase00-session04-service-deployment-and-verification` (running queue mode)
  - `phase01-session01-backup-automation` (data protection)
- **Depended by**:
  - `phase01-session04-monitoring-health` (requires scaled workers for monitoring)

---

## Next Steps

Run `/tasks` to generate the implementation task checklist.
