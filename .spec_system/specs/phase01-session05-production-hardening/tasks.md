# Task Checklist

**Session ID**: `phase01-session05-production-hardening`
**Total Tasks**: 24
**Estimated Duration**: 2-3 hours
**Created**: 2025-12-26

---

## Legend

- `[x]` = Completed
- `[ ]` = Pending
- `[P]` = Parallelizable (can run with other [P] tasks)
- `[S0105]` = Session reference (Phase 01, Session 05)
- `TNNN` = Task ID

---

## Progress Summary

| Category | Total | Done | Remaining |
|----------|-------|------|-----------|
| Setup | 3 | 3 | 0 |
| Foundation | 4 | 4 | 0 |
| Implementation - Documentation | 11 | 11 | 0 |
| Implementation - Scripts | 2 | 2 | 0 |
| Testing | 4 | 4 | 0 |
| **Total** | **24** | **24** | **0** |

---

## Setup (3 tasks)

Environment verification and version discovery.

- [x] T001 [S0105] Verify all containers healthy (`docker compose ps`)
- [x] T002 [S0105] Identify current running image versions via docker inspect
- [x] T003 [S0105] Verify Docker Hub availability of target image tags (postgres:16-alpine exact version, redis:7-alpine exact version)

---

## Foundation (4 tasks)

Version pinning in docker-compose.yml.

- [x] T004 [S0105] [P] Pin n8n image from `:latest` to exact version (`docker-compose.yml`)
- [x] T005 [S0105] [P] Pin PostgreSQL image from `:16-alpine` to exact patch version (`docker-compose.yml`)
- [x] T006 [S0105] [P] Pin Redis image from `:7-alpine` to exact patch version (`docker-compose.yml`)
- [x] T007 [S0105] Restart stack with pinned versions and verify all containers healthy

---

## Implementation - Documentation (11 tasks)

Create comprehensive operational documentation.

### Security Documentation
- [x] T008 [S0105] Create `docs/SECURITY.md` with header, overview, and scope
- [x] T009 [S0105] Add security hardening checklist to SECURITY.md (permissions, secrets, ports)
- [x] T010 [S0105] Add secure cookie and network exposure documentation to SECURITY.md

### Disaster Recovery Documentation
- [x] T011 [S0105] Create `docs/RECOVERY.md` with header, overview, and prerequisites
- [x] T012 [S0105] Add PostgreSQL backup/restore procedures to RECOVERY.md
- [x] T013 [S0105] Add Redis and n8n data recovery procedures to RECOVERY.md
- [x] T014 [S0105] Add full stack rebuild from scratch procedure to RECOVERY.md

### Operations Runbook
- [x] T015 [S0105] Create `docs/RUNBOOK.md` with header, overview, and quick reference
- [x] T016 [S0105] Add daily operations checklist to RUNBOOK.md
- [x] T017 [S0105] Add weekly/monthly maintenance procedures to RUNBOOK.md

### Version Upgrade Documentation
- [x] T018 [S0105] Create `docs/UPGRADE.md` with version upgrade procedures and rollback steps

---

## Implementation - Scripts (2 tasks)

Scripts and troubleshooting enhancements.

- [x] T019 [S0105] Create `scripts/verify-versions.sh` to compare pinned vs running versions
- [x] T020 [S0105] Update `docs/TROUBLESHOOTING.md` with permanent Redis vm.overcommit_memory fix (sysctl.d)

---

## Testing (4 tasks)

Verification and quality assurance.

- [x] T021 [S0105] Run verify-versions.sh and confirm pinned versions match running containers
- [x] T022 [S0105] Verify all containers healthy with `./scripts/health-check.sh`
- [x] T023 [S0105] Validate ASCII encoding on all new/modified files (no unicode)
- [x] T024 [S0105] Final review and create git commit with descriptive message

---

## Completion Checklist

Before marking session complete:

- [ ] All tasks marked `[x]`
- [ ] All containers healthy with pinned versions
- [ ] All documentation files ASCII-encoded
- [ ] verify-versions.sh confirms pinned = running
- [ ] Git commit created
- [ ] Ready for `/validate`

---

## Notes

### Parallelization
Tasks T004-T006 can be completed simultaneously (all edit docker-compose.yml but different sections).
Documentation tasks within each category are sequential for coherent flow.

### Task Timing
- Setup: ~15 minutes
- Foundation: ~20 minutes
- Documentation: ~90 minutes
- Scripts: ~20 minutes
- Testing: ~15 minutes

### Dependencies
- T007 depends on T004-T006 (must pin before restart)
- T021 depends on T019 (must create script before running)
- T024 depends on all other tasks

### Sudo Requirements
T020 documents the vm.overcommit_memory fix which requires sudo. Document the fix but pause for user to execute if applying immediately.

### ASCII Compliance
All documentation files must use ASCII-only characters (0-127). Avoid:
- Smart quotes (" " ' ')
- Em-dashes (-)
- Non-ASCII symbols

---

## Next Steps

Run `/implement` to begin AI-led implementation.
