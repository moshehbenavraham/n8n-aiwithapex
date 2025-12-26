# Session Specification

**Session ID**: `phase01-session04-monitoring-health`
**Phase**: 01 - Operations and Optimization
**Status**: Not Started
**Created**: 2025-12-26

---

## 1. Session Overview

This session establishes comprehensive monitoring and health management for the n8n stack running on WSL2. With backup automation, worker scaling, and PostgreSQL tuning now complete, the system requires operational visibility to detect issues, track resource consumption, and facilitate troubleshooting.

The deliverables provide a complete monitoring toolkit using native Docker and bash capabilities, avoiding external dependencies like Prometheus or Grafana. Scripts will monitor container health, resource utilization (memory, CPU, disk), and queue status. A unified log viewer simplifies troubleshooting, while Docker log rotation prevents unbounded disk growth.

This session is a prerequisite for Session 05 (Production Hardening), which requires monitoring infrastructure before the system can be hardened for production use.

---

## 2. Objectives

1. Create comprehensive health check script that validates all containers, endpoints, and services
2. Implement resource monitoring with configurable alert thresholds appropriate for 8GB WSL2 environment
3. Configure Docker log rotation to prevent disk space exhaustion
4. Establish system status dashboard providing single-command operational overview

---

## 3. Prerequisites

### Required Sessions
- [x] `phase00-session04-service-deployment-and-verification` - All containers running and healthy
- [x] `phase01-session01-backup-automation` - Backup infrastructure in place
- [x] `phase01-session02-worker-scaling` - 5 worker replicas to monitor

### Required Tools/Knowledge
- Docker CLI and `docker stats` command
- Bash scripting (following project conventions)
- curl for HTTP endpoint verification
- jq for JSON parsing (pre-installed)

### Environment Requirements
- All n8n stack containers running (postgres, redis, n8n, n8n-worker)
- Access to Docker socket
- Write access to scripts/ and docs/ directories

---

## 4. Scope

### In Scope (MVP)
- Health check script validating containers and /healthz endpoint
- Resource monitoring script with memory (80%), CPU (90%), disk (85%) thresholds
- Unified log viewer with service filtering and tail/follow modes
- System status dashboard script with single-command overview
- Docker daemon log rotation configuration (10MB x 3 files)
- Monitoring runbook documentation
- Troubleshooting decision tree for common issues

### Out of Scope (Deferred)
- Prometheus/Grafana integration - *Reason: PRD non-goal; adds complexity*
- PagerDuty/OpsGenie alerting - *Reason: Localhost environment, no external alerting needed*
- Custom n8n metrics collection - *Reason: Built-in /metrics endpoint sufficient*
- APM and distributed tracing - *Reason: Overkill for single-host deployment*
- Automated alerting actions - *Reason: Manual monitoring appropriate for local dev*

---

## 5. Technical Approach

### Architecture
All monitoring scripts follow the established project pattern: self-contained bash scripts in the `scripts/` directory with consistent logging, error handling, and exit codes. Scripts read configuration from environment or defaults, supporting both interactive use and cron scheduling.

```
+-------------------+     +------------------+     +------------------+
|  health-check.sh  |     | monitor-resources|     |  system-status   |
|                   |     |       .sh        |     |       .sh        |
+--------+----------+     +--------+---------+     +--------+---------+
         |                         |                        |
         v                         v                        v
+--------+----------+     +--------+---------+     +--------+---------+
| Container Health  |     |   Docker Stats   |     |   Aggregated     |
| /healthz endpoint |     |   Memory/CPU     |     |   Dashboard      |
| Docker inspect    |     |   Disk usage     |     |   View           |
+-------------------+     +------------------+     +------------------+
```

### Design Patterns
- **Script header convention**: Comment block with description, usage, exit codes
- **Logging functions**: log_info, log_error, log_success, log_warn (from backup scripts)
- **Configuration section**: SCRIPT_DIR, PROJECT_DIR, and script-specific settings
- **Main function pattern**: `main "$@"` entry point for testability
- **Exit codes**: 0=healthy/success, 1=unhealthy/failure, 2=warning

### Technology Stack
- Bash 5.x (WSL2 Ubuntu default)
- Docker CLI 29.1.3
- curl 7.x/8.x for HTTP checks
- jq 1.6+ for JSON parsing
- awk/sed for text processing

---

## 6. Deliverables

### Files to Create
| File | Purpose | Est. Lines |
|------|---------|------------|
| `scripts/health-check.sh` | Container and endpoint health validation | ~150 |
| `scripts/monitor-resources.sh` | Resource monitoring with thresholds | ~180 |
| `scripts/view-logs.sh` | Unified log viewer with filtering | ~120 |
| `scripts/system-status.sh` | Dashboard-style status report | ~200 |
| `docs/MONITORING.md` | Monitoring runbook and thresholds | ~150 |
| `docs/TROUBLESHOOTING.md` | Decision tree and common fixes | ~200 |

### Files to Modify
| File | Changes | Est. Lines |
|------|---------|------------|
| `/etc/docker/daemon.json` | Add log rotation config (user runs with sudo) | ~8 |

---

## 7. Success Criteria

### Functional Requirements
- [ ] `health-check.sh` validates all 4 container types (postgres, redis, n8n, n8n-worker)
- [ ] `health-check.sh` verifies /healthz endpoint returns OK
- [ ] `monitor-resources.sh` reports memory, CPU, and disk usage
- [ ] `monitor-resources.sh` exits non-zero when thresholds exceeded
- [ ] `view-logs.sh` supports service filtering (-s postgres|redis|n8n|worker)
- [ ] `view-logs.sh` supports tail mode (-n lines) and follow mode (-f)
- [ ] `system-status.sh` displays containers, resources, queue, and endpoints
- [ ] Docker log rotation configured (10MB max, 3 files retained)

### Testing Requirements
- [ ] All scripts executable and run without errors
- [ ] Scripts work with all containers running
- [ ] Scripts handle missing containers gracefully
- [ ] Threshold alerts trigger correctly (manually tested)

### Quality Gates
- [ ] All files ASCII-encoded (0-127 characters only)
- [ ] Unix LF line endings
- [ ] Scripts pass shellcheck without errors
- [ ] Consistent header/logging conventions with existing scripts
- [ ] Exit codes documented and consistent

---

## 8. Implementation Notes

### Key Considerations
- Worker replicas show as `n8n-n8n-worker-1` through `n8n-n8n-worker-5` in docker stats
- Redis on non-standard port 6386 (not 6379)
- Health endpoint at http://localhost:5678/healthz
- Metrics endpoint at http://localhost:5678/metrics (Prometheus format)

### Potential Challenges
- **Docker daemon.json modification**: Requires sudo; document for user to execute
- **Worker replica detection**: Use `docker compose ps` for accurate count
- **Queue depth metrics**: Requires redis-cli to query Bull queue; may simplify to just pending job count

### Relevant Considerations
- [P00] **WSL2 8GB RAM constraint**: Memory threshold set at 80% (6.4GB) to leave headroom for WSL2 overhead. Alert before system becomes unresponsive.
- [P00] **Redis vm.overcommit_memory warning**: Document in TROUBLESHOOTING.md; full remediation in Session 05.
- [P00] **docker compose (space) not docker-compose**: All scripts must use `docker compose` syntax.
- [P00] **Named Docker volumes**: Reference volumes by name (postgres_data, redis_data, n8n_data) in disk monitoring.

### ASCII Reminder
All output files must use ASCII-only characters (0-127). No Unicode symbols, emojis, or extended characters in scripts or documentation.

---

## 9. Testing Strategy

### Unit Tests
- Verify each script runs with `--help` flag without errors
- Test logging functions produce correct output format
- Verify exit codes match documentation

### Integration Tests
- Run health-check.sh with all containers up (expect exit 0)
- Run health-check.sh with one container stopped (expect exit 1)
- Run monitor-resources.sh and verify threshold detection
- Run system-status.sh and verify all sections populated

### Manual Testing
- Stop a container and verify health-check.sh detects it
- Consume memory and verify threshold alert triggers
- View logs for each service with view-logs.sh
- Verify log rotation after daemon restart (create large log, rotate)

### Edge Cases
- No containers running (all scripts handle gracefully)
- Docker daemon not running (clear error message)
- /healthz endpoint timeout (5-second timeout, report unhealthy)
- Partial worker scaling (fewer than 5 workers running)

---

## 10. Dependencies

### External Libraries
- None (bash built-ins and standard Linux utilities only)

### System Utilities Required
- docker (Docker CLI)
- curl (HTTP requests)
- jq (JSON parsing)
- awk, sed, grep (text processing)
- df, free (disk/memory stats)

### Other Sessions
- **Depends on**: `phase01-session02-worker-scaling` (5 workers to monitor)
- **Depended by**: `phase01-session05-production-hardening` (requires monitoring in place)

---

## Next Steps

Run `/tasks` to generate the implementation task checklist.
