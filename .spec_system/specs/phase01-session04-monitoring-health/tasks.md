# Task Checklist

**Session ID**: `phase01-session04-monitoring-health`
**Total Tasks**: 24
**Estimated Duration**: 8-10 hours
**Created**: 2025-12-26

---

## Legend

- `[x]` = Completed
- `[ ]` = Pending
- `[P]` = Parallelizable (can run with other [P] tasks)
- `[S0104]` = Session reference (Phase 01, Session 04)
- `TNNN` = Task ID

---

## Progress Summary

| Category | Total | Done | Remaining |
|----------|-------|------|-----------|
| Setup | 3 | 3 | 0 |
| Foundation | 5 | 5 | 0 |
| Implementation | 12 | 12 | 0 |
| Testing | 4 | 4 | 0 |
| **Total** | **24** | **24** | **0** |

---

## Setup (3 tasks)

Initial configuration and environment preparation.

- [x] T001 [S0104] Verify prerequisites (docker, curl, jq installed and containers running)
- [x] T002 [S0104] Ensure logs/ directory exists with proper permissions
- [x] T003 [S0104] Ensure docs/ directory exists for documentation files

---

## Foundation (5 tasks)

Create script skeletons with headers, configuration, and logging functions.

- [x] T004 [S0104] [P] Create health-check.sh skeleton with header, config, logging (`scripts/health-check.sh`)
- [x] T005 [S0104] [P] Create monitor-resources.sh skeleton with header, config, logging (`scripts/monitor-resources.sh`)
- [x] T006 [S0104] [P] Create view-logs.sh skeleton with header, config, logging (`scripts/view-logs.sh`)
- [x] T007 [S0104] [P] Create system-status.sh skeleton with header, config, logging (`scripts/system-status.sh`)
- [x] T008 [S0104] Create shared log_warn function pattern for all scripts

---

## Implementation (12 tasks)

Main feature implementation for monitoring scripts.

### health-check.sh Implementation
- [x] T009 [S0104] Implement container health checks using docker inspect (`scripts/health-check.sh`)
- [x] T010 [S0104] Implement /healthz endpoint verification with curl timeout (`scripts/health-check.sh`)
- [x] T011 [S0104] Add worker replica detection and count verification (`scripts/health-check.sh`)

### monitor-resources.sh Implementation
- [x] T012 [S0104] Implement memory monitoring with 80% threshold (`scripts/monitor-resources.sh`)
- [x] T013 [S0104] Implement CPU monitoring with 90% threshold (`scripts/monitor-resources.sh`)
- [x] T014 [S0104] Implement disk monitoring with 85% threshold for data volumes (`scripts/monitor-resources.sh`)

### view-logs.sh Implementation
- [x] T015 [S0104] Implement service filtering with -s flag (postgres|redis|n8n|worker) (`scripts/view-logs.sh`)
- [x] T016 [S0104] Implement tail mode (-n lines) and follow mode (-f) (`scripts/view-logs.sh`)

### system-status.sh Implementation
- [x] T017 [S0104] Implement container status section with health states (`scripts/system-status.sh`)
- [x] T018 [S0104] Implement resource summary section (memory, CPU, disk) (`scripts/system-status.sh`)
- [x] T019 [S0104] Implement queue status section using redis-cli for Bull queue (`scripts/system-status.sh`)
- [x] T020 [S0104] Implement endpoint status section (healthz, n8n web interface) (`scripts/system-status.sh`)

---

## Documentation (3 tasks)

Create monitoring runbook and troubleshooting guide.

- [x] T021 [S0104] [P] Create MONITORING.md with runbook and threshold documentation (`docs/MONITORING.md`)
- [x] T022 [S0104] [P] Create TROUBLESHOOTING.md with decision tree and common fixes (`docs/TROUBLESHOOTING.md`)
- [x] T023 [S0104] Document Docker log rotation config for user to apply with sudo (`docs/MONITORING.md`)

---

## Testing (4 tasks)

Verification and quality assurance.

- [x] T024 [S0104] Run all scripts with --help flag and verify no errors
- [x] T025 [S0104] Execute full integration test (health-check, monitor-resources, system-status)
- [x] T026 [S0104] Validate ASCII encoding and Unix line endings on all files
- [x] T027 [S0104] Run shellcheck on all scripts and fix any warnings

---

## Completion Checklist

Before marking session complete:

- [x] All tasks marked `[x]`
- [x] All scripts executable and run without errors
- [x] All scripts pass shellcheck
- [x] All files ASCII-encoded
- [x] Unix LF line endings verified
- [x] Docker log rotation documented
- [x] implementation-notes.md updated
- [x] Ready for `/validate`

---

## Notes

### Parallelization
Tasks marked `[P]` can be worked on simultaneously:
- T004-T007: Script skeleton creation
- T021-T022: Documentation files

### Task Timing
Target ~20-25 minutes per task.

### Dependencies
- T004-T007 must complete before T009-T020 (implementation needs skeletons)
- T009-T020 can be done in sequence per-script or interleaved
- T024-T027 require all implementation tasks complete

### Key Technical Details
- Workers show as `n8n-n8n-worker-1` through `n8n-n8n-worker-5`
- Redis on port 6386 (not default 6379)
- Health endpoint: http://localhost:5678/healthz
- Metrics endpoint: http://localhost:5678/metrics
- Use `docker compose` (space, not hyphen)
- Exit codes: 0=healthy/success, 1=unhealthy/failure, 2=warning

### Thresholds (WSL2 8GB environment)
- Memory: 80% (6.4GB)
- CPU: 90%
- Disk: 85%
- Log rotation: 10MB max-size, 3 max-file

---

## Next Steps

Run `/implement` to begin AI-led implementation.
