# Task Checklist

**Session ID**: `phase01-session02-worker-scaling`
**Total Tasks**: 22
**Estimated Duration**: 7-9 hours
**Created**: 2025-12-26

---

## Legend

- `[x]` = Completed
- `[ ]` = Pending
- `[P]` = Parallelizable (can run with other [P] tasks)
- `[S0102]` = Session reference (Phase 01, Session 02)
- `TNNN` = Task ID

---

## Progress Summary

| Category | Total | Done | Remaining |
|----------|-------|------|-----------|
| Setup | 3 | 3 | 0 |
| Foundation | 3 | 3 | 0 |
| Implementation | 8 | 8 | 0 |
| Documentation | 1 | 1 | 0 |
| Testing | 7 | 7 | 0 |
| **Total** | **22** | **22** | **0** |

---

## Setup (3 tasks)

Initial configuration and environment verification.

- [x] T001 [S0102] Verify Docker Compose v5+ installed (`docker compose version`)
- [x] T002 [S0102] Verify all containers running and healthy (`docker compose ps`)
- [x] T003 [S0102] Create docs directory if not exists (`docs/`)

---

## Foundation (3 tasks)

Backup current configuration before modifications.

- [x] T004 [S0102] [P] Create backup of docker-compose.yml (`docker-compose.yml.bak`)
- [x] T005 [S0102] [P] Create backup of .env file (`.env.bak`)
- [x] T006 [S0102] Document current memory baseline with single worker (`docker stats`)

---

## Implementation (8 tasks)

Worker scaling configuration changes.

- [x] T007 [S0102] Add EXECUTIONS_CONCURRENCY=10 to .env (`.env`)
- [x] T008 [S0102] Add OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true to .env (`.env`)
- [x] T009 [S0102] Add QUEUE_BULL_REDIS_TIMEOUT_THRESHOLD=60000 to .env (`.env`)
- [x] T010 [S0102] Remove container_name from n8n-worker service (`docker-compose.yml`)
- [x] T011 [S0102] Add deploy.replicas: 5 to n8n-worker service (`docker-compose.yml`)
- [x] T012 [S0102] Add deploy.resources memory limits 512M to n8n-worker (`docker-compose.yml`)
- [x] T013 [S0102] Add EXECUTIONS_CONCURRENCY env var to n8n-worker service (`docker-compose.yml`)
- [x] T014 [S0102] Add OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS to n8n service (`docker-compose.yml`)

---

## Documentation (1 task)

Create scaling procedure documentation.

- [x] T015 [S0102] Create SCALING.md with procedures and reference (`docs/SCALING.md`)

---

## Testing (7 tasks)

Verification and quality assurance.

- [x] T016 [S0102] Validate docker compose config syntax (`docker compose config`)
- [x] T017 [S0102] Apply changes and scale to 5 workers (`docker compose up -d`)
- [x] T018 [S0102] Verify all 5 workers running and healthy (`docker compose ps n8n-worker`)
- [x] T019 [S0102] Capture memory usage baseline with 5 workers (`docker stats --no-stream`)
- [x] T020 [S0102] Test scale down to 2 workers (`docker compose up -d --scale n8n-worker=2`)
- [x] T021 [S0102] Test scale back to 5 workers (`docker compose up -d`)
- [x] T022 [S0102] Validate all files ASCII-encoded and Unix LF line endings

---

## Completion Checklist

Before marking session complete:

- [x] All tasks marked `[x]`
- [x] All 5 workers running and healthy
- [x] Memory usage under 4GB total (~1.46 GiB)
- [x] docker compose config validates without errors
- [x] All files ASCII-encoded with Unix LF endings
- [x] implementation-notes.md created
- [x] Ready for `/validate`

---

## Notes

### Parallelization
Tasks T004 and T005 (backups) can be worked on simultaneously.

### Task Timing
Target ~20-25 minutes per task.

### Dependencies
- T004-T005 must complete before T007-T014
- T007-T014 must complete before T016
- T016 must pass before T017
- T017 must complete before T018-T021

### Key Implementation Details

**docker-compose.yml n8n-worker changes:**
```yaml
n8n-worker:
  # Remove: container_name: n8n-worker
  deploy:
    replicas: 5
    resources:
      limits:
        memory: 512M
  environment:
    # Add:
    EXECUTIONS_CONCURRENCY: ${EXECUTIONS_CONCURRENCY}
```

**docker-compose.yml n8n service changes:**
```yaml
n8n:
  environment:
    # Add:
    OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS: ${OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS}
```

**.env additions:**
```bash
EXECUTIONS_CONCURRENCY=10
OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true
QUEUE_BULL_REDIS_TIMEOUT_THRESHOLD=60000
```

### Memory Budget
- 5 workers x 512MB = 2.5GB
- postgres: ~256MB
- redis: ~128MB
- n8n main: ~512MB
- **Total: ~3.4GB** (within 8GB WSL2 limit)

---

## Next Steps

Run `/implement` to begin AI-led implementation.
