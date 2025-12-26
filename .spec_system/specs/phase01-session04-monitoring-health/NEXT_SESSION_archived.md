# NEXT_SESSION.md

## Session Recommendation

**Generated**: 2025-12-26
**Project State**: Phase 01 - Operations and Optimization
**Completed Sessions**: 7 (4 from Phase 00, 3 from Phase 01)

---

## Recommended Next Session

**Session ID**: `phase01-session04-monitoring-health`
**Session Name**: Monitoring and Health Management
**Estimated Duration**: 2-4 hours
**Estimated Tasks**: ~20-25

---

## Why This Session Next?

### Prerequisites Met
- [x] All containers running and healthy (verified in Phase 00)
- [x] n8n /healthz and /metrics endpoints accessible
- [x] Backup procedures in place (Session 01)
- [x] Worker scaling configured (Session 02)

### Dependencies
- **Builds on**: Session 02 (Worker Scaling) - monitoring now covers 5 worker replicas
- **Builds on**: Session 03 (PostgreSQL Tuning) - can monitor tuned database performance
- **Enables**: Session 05 (Production Hardening) - requires monitoring before hardening

### Project Progression
Session 04 is the natural next step following the optimization work completed in sessions 01-03. With backup automation, worker scaling, and PostgreSQL tuning in place, the system now needs operational visibility. This session establishes the monitoring foundation required before the final production hardening phase. Session 05 explicitly requires "monitoring in place" as a prerequisite, making Session 04 mandatory before proceeding.

---

## Session Overview

### Objective
Establish comprehensive monitoring and health management procedures for the n8n stack, including resource monitoring, log management, health check verification, and basic alerting mechanisms.

### Key Deliverables
1. `scripts/health-check.sh` - Comprehensive health verification for all containers
2. `scripts/monitor-resources.sh` - Resource monitoring with configurable thresholds
3. `scripts/view-logs.sh` - Unified log viewer with filtering options
4. `scripts/system-status.sh` - Dashboard-style status report
5. Docker log rotation configuration
6. Monitoring runbook and troubleshooting decision tree

### Scope Summary
- **In Scope (MVP)**: Health endpoints verification, resource monitoring scripts, log rotation/viewing, system status dashboard, alert thresholds, troubleshooting decision tree
- **Out of Scope**: External monitoring systems (Prometheus, Grafana), PagerDuty/OpsGenie, custom metrics collection, APM, distributed tracing

---

## Technical Considerations

### Technologies/Patterns
- Bash scripting for monitoring utilities
- Docker stats API for resource metrics
- Docker logging driver configuration (json-file with rotation)
- curl for health endpoint verification
- jq for JSON parsing (already available)

### Potential Challenges
- Determining appropriate alert thresholds for WSL2 environment with 8GB RAM limit
- Log rotation configuration requires Docker daemon restart
- Capturing queue depth metrics from Redis requires redis-cli access

### Relevant Considerations
- [P00] **WSL2 8GB RAM constraint**: Resource monitoring thresholds should account for the 8GB limit. Recommend 80% memory alert threshold (6.4GB).
- [P00] **Redis vm.overcommit_memory warning**: Include in troubleshooting guide for visibility; full fix deferred to Session 05.
- [P00] **5 worker replicas**: Monitor all worker instances; `docker stats` will show memory/CPU per worker replica.

---

## Alternative Sessions

If this session is blocked:
1. **phase01-session05-production-hardening** - Cannot proceed; requires monitoring to be in place first
2. **Phase 02 planning** - Could draft Phase 02 sessions while monitoring is blocked

*Note: There are no alternative sessions to implement - Session 04 is required before Session 05 can begin.*

---

## Next Steps

Run `/sessionspec` to generate the formal specification for `phase01-session04-monitoring-health`.
