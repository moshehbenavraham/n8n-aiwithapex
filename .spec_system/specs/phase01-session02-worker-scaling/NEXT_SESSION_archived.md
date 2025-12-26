# NEXT_SESSION.md

## Session Recommendation

**Generated**: 2025-12-26
**Project State**: Phase 01 - Operations and Optimization
**Completed Sessions**: 5 (4 in Phase 00, 1 in Phase 01)

---

## Recommended Next Session

**Session ID**: `phase01-session02-worker-scaling`
**Session Name**: Worker Scaling and Queue Optimization
**Estimated Duration**: 2-4 hours
**Estimated Tasks**: ~20-25

---

## Why This Session Next?

### Prerequisites Met
- [x] Phase 00 completed - queue mode operational
- [x] Single worker currently running and processing jobs
- [x] Redis queue functional
- [x] Docker Compose available for scaling commands
- [x] Sufficient WSL2 memory for additional workers (8GB configured)

### Dependencies
- **Builds on**: Phase 00 queue mode infrastructure + Session 01 backup protection
- **Enables**: Session 04 (Monitoring and Health) which explicitly requires worker scaling

### Project Progression
This is the natural next step because:
1. **Sequential order** - Session 02 follows completed Session 01
2. **Blocking dependency** - Session 04 explicitly lists Session 02 as a prerequisite
3. **Active Concerns addressed** - CONSIDERATIONS.md flags two issues this session resolves:
   - [P00] "Single worker instance" - scale to 5+ workers for production throughput
   - [P00] "Manual execution offload" - enable OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS
4. **Foundation complete** - Backup automation (Session 01) protects data before scaling changes

---

## Session Overview

### Objective
Configure n8n worker scaling to support 5+ worker instances with optimized concurrency settings, enable manual execution offloading, and verify queue mode performance under load.

### Key Deliverables
1. Updated `docker-compose.yml` with deploy replicas configuration (5 workers)
2. Updated `.env` with optimized worker settings (concurrency 10 per worker)
3. Worker scaling procedure documentation
4. Memory usage baseline with 5 workers
5. Queue distribution verification across workers
6. Scaling command reference (up/down procedures)

### Scope Summary
- **In Scope (MVP)**: Worker replica configuration, concurrency tuning, manual execution offload, scaling tests (1->5->2), memory monitoring, documentation
- **Out of Scope**: Auto-scaling based on queue depth, Kubernetes orchestration, worker-specific configuration, load balancer

---

## Technical Considerations

### Technologies/Patterns
- Docker Compose `deploy.replicas` for worker scaling
- Docker Compose `--scale` command for dynamic scaling
- Environment variable tuning (EXECUTIONS_CONCURRENCY, OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS)
- Resource limits (512MB per worker container)

### Potential Challenges
- **Memory pressure**: 5 workers x 512MB = 2.5GB + other services (~3.5GB total of 8GB limit)
- **Queue distribution verification**: Need to confirm jobs spread across all workers
- **Graceful scaling**: Ensure in-flight executions complete when scaling down

### Relevant Considerations
- [P00] **Single worker instance**: Currently running 1 worker with concurrency 10. This session scales to 5+ workers for production throughput.
- [P00] **Manual execution offload**: `OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS` not enabled. This session enables it to reduce main instance load.
- [P00] **WSL2 8GB RAM constraint**: Monitor memory usage under load - session includes memory baseline with 5 workers.

---

## Alternative Sessions

If this session is blocked:
1. **phase01-session03-postgresql-tuning** - Has prerequisites met, can run independently. Less optimal because Session 04 depends on Session 02, not Session 03.
2. **phase01-session04-monitoring-health** - Currently blocked (requires Session 02), but could start health endpoint verification portions if Session 02 is partially complete.

---

## Next Steps

Run `/sessionspec` to generate the formal specification.
