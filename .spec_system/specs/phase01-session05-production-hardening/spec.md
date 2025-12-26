# Session Specification

**Session ID**: `phase01-session05-production-hardening`
**Phase**: 01 - Operations and Optimization
**Status**: Not Started
**Created**: 2025-12-26

---

## 1. Session Overview

This session is the capstone of Phase 01, transforming the n8n installation from a working development setup into a production-hardened deployment. The primary focus is eliminating unpredictable behavior by pinning all Docker images to specific versions, ensuring the system can be reliably reproduced and updated in a controlled manner.

Beyond version pinning, this session creates comprehensive operational documentation including security hardening procedures, disaster recovery guides, and an operations runbook. The existing TROUBLESHOOTING.md will be enhanced with additional scenarios, and new documentation files will be created for security configurations and recovery procedures.

This session addresses three Active Concerns from Phase 00: the unpinned n8n:latest image tag, the Redis vm.overcommit_memory kernel warning, and the disabled secure cookie setting. Upon completion, the n8n stack will be fully documented, version-controlled, and ready for sustained production operation.

---

## 2. Objectives

1. Pin all Docker images to exact versions (n8n, PostgreSQL, Redis) to prevent unexpected breaking changes from upstream updates
2. Document Redis vm.overcommit_memory kernel fix with clear sudo instructions for user execution
3. Create comprehensive security hardening documentation with actionable checklist
4. Establish disaster recovery and operations runbook documentation

---

## 3. Prerequisites

### Required Sessions
- [x] `phase01-session01-backup-automation` - Backup scripts and cron scheduling in place
- [x] `phase01-session02-worker-scaling` - Worker scaling configured (5 replicas)
- [x] `phase01-session03-postgresql-tuning` - PostgreSQL performance optimized
- [x] `phase01-session04-monitoring-health` - Monitoring scripts and endpoints verified

### Required Tools/Knowledge
- Docker Compose familiarity (image tag syntax)
- Markdown documentation formatting
- Linux sysctl configuration understanding

### Environment Requirements
- All n8n stack containers running and healthy
- Access to container versions via docker inspect
- Git for version controlling configuration changes

---

## 4. Scope

### In Scope (MVP)
- Pin n8n image from `:latest` to `2.1.4`
- Pin PostgreSQL image from `:16-alpine` to `:16.11-alpine`
- Pin Redis image from `:7-alpine` to `:7.4.7-alpine`
- Create `docs/SECURITY.md` with hardening checklist
- Create `docs/RECOVERY.md` with disaster recovery procedures
- Create `docs/RUNBOOK.md` with operations reference
- Document Redis vm.overcommit_memory fix (permanent sysctl config)
- Create version upgrade procedure documentation
- Enhance existing TROUBLESHOOTING.md with additional scenarios
- Version control commit of all configuration changes

### Out of Scope (Deferred)
- SSL/TLS termination - *Reason: Localhost-only deployment*
- Reverse proxy configuration - *Reason: Not required for local use*
- Network firewall rules - *Reason: WSL2 network isolation sufficient*
- Secrets management integration (Vault/etc) - *Reason: .env sufficient for local*
- Automated security scanning - *Reason: Manual review adequate*

---

## 5. Technical Approach

### Architecture
This session is primarily a documentation and configuration hardening effort. No new services or components are introduced. The docker-compose.yml will be modified to use explicit version tags, and documentation files will be created in the existing `docs/` directory structure.

### Design Patterns
- **Semantic Versioning Pinning**: Use exact major.minor.patch versions (not floating tags)
- **Documentation as Code**: All docs in markdown, version controlled alongside configuration
- **Checklist-Driven Operations**: Security and recovery procedures as actionable checklists

### Technology Stack
- Docker Compose v5+ (existing)
- Markdown documentation format
- Bash scripting for any verification scripts
- sysctl for kernel parameter documentation

---

## 6. Deliverables

### Files to Create
| File | Purpose | Est. Lines |
|------|---------|------------|
| `docs/SECURITY.md` | Security configuration and hardening checklist | ~150 |
| `docs/RECOVERY.md` | Disaster recovery procedures and restore guide | ~200 |
| `docs/RUNBOOK.md` | Day-to-day operations reference | ~250 |
| `docs/UPGRADE.md` | Version upgrade procedure documentation | ~120 |
| `scripts/verify-versions.sh` | Verify pinned versions match running containers | ~50 |

### Files to Modify
| File | Changes | Est. Lines Changed |
|------|---------|------------|
| `docker-compose.yml` | Pin all image versions | ~6 |
| `docs/TROUBLESHOOTING.md` | Add Redis vm.overcommit permanent fix, enhance scenarios | ~30 |

---

## 7. Success Criteria

### Functional Requirements
- [ ] n8n image pinned to `n8nio/n8n:2.1.4` in docker-compose.yml
- [ ] PostgreSQL image pinned to `postgres:16.11-alpine`
- [ ] Redis image pinned to `redis:7.4.7-alpine` (or verified available tag)
- [ ] All containers restart successfully with pinned versions
- [ ] Security documentation covers all checklist items from session spec
- [ ] Recovery procedures cover PostgreSQL restore, n8n data restore, full stack rebuild
- [ ] Runbook covers daily/weekly/monthly operations

### Testing Requirements
- [ ] docker compose down && docker compose up -d succeeds with pinned versions
- [ ] All health checks pass after restart
- [ ] verify-versions.sh script confirms running versions match pinned

### Quality Gates
- [ ] All documentation files ASCII-encoded (no unicode characters)
- [ ] Unix LF line endings in all files
- [ ] Documentation follows existing format in docs/ directory
- [ ] Git commit created with descriptive message

---

## 8. Implementation Notes

### Key Considerations
- Verify Docker Hub has the exact alpine tags before pinning (e.g., `16.11-alpine` may need to be `16.4-alpine` depending on availability)
- The vm.overcommit_memory fix requires sudo access - document clearly for user to execute
- Worker image must match main n8n instance version exactly
- Secure cookie documentation should explain when to enable (network exposure scenarios)

### Potential Challenges
- **Alpine Tag Availability**: Docker Hub may not have exact patch versions with -alpine suffix. Mitigation: Use `docker pull` to verify before updating compose file.
- **Sudo Requirement**: Redis kernel fix needs host-level access. Mitigation: Document with clear instructions, pause for user execution.
- **Documentation Scope Creep**: Risk of over-documenting. Mitigation: Focus on actionable procedures, not exhaustive explanations.

### Relevant Considerations
- [P00] **n8n:latest image tag**: Pinning to 2.1.4 (current running version) eliminates surprise upgrades
- [P00] **Redis vm.overcommit_memory warning**: Documenting permanent fix via /etc/sysctl.d/ configuration
- [P00] **Secure cookie disabled**: Documenting in SECURITY.md with clear enable instructions for network exposure

### ASCII Reminder
All output files must use ASCII-only characters (0-127). Avoid smart quotes, em-dashes, and non-ASCII symbols.

---

## 9. Testing Strategy

### Unit Tests
- N/A (documentation and configuration session)

### Integration Tests
- Restart full stack with pinned versions
- Verify all health endpoints respond
- Run verify-versions.sh to confirm pinned = running

### Manual Testing
- Review each documentation file for completeness and clarity
- Execute one procedure from each runbook section to verify accuracy
- Confirm Redis warning is resolved after vm.overcommit fix

### Edge Cases
- What if Docker Hub tag doesn't exist? Use closest available tag and document
- What if user cannot run sudo? Document workaround or note limitation
- What if version mismatch between main and worker? Always keep in sync

---

## 10. Dependencies

### External Libraries
- None (documentation and configuration only)

### Image Versions to Pin
- `n8nio/n8n:2.1.4` (verified running)
- `postgres:16.11-alpine` (verify Docker Hub availability)
- `redis:7.4.7-alpine` (verify Docker Hub availability)

### Other Sessions
- **Depends on**: phase01-session01 through phase01-session04 (all complete)
- **Depended by**: None (final session of Phase 01)

---

## Next Steps

Run `/tasks` to generate the implementation task checklist.
