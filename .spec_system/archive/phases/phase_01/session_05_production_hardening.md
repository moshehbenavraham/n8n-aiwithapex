# Session 05: Production Hardening and Documentation

**Session ID**: `phase01-session05-production-hardening`
**Status**: Not Started
**Estimated Tasks**: ~20-25
**Estimated Duration**: 2-4 hours

---

## Important: WSL2 Ubuntu Only

**All commands and operations run exclusively from WSL2 Ubuntu.** There is NO need for PowerShell, CMD, or Windows Terminal.

---

## Objective

Harden the n8n installation for production use by pinning image versions, documenting security configurations, creating comprehensive troubleshooting guides, and establishing recovery procedures.

---

## Scope

### In Scope (MVP)
- Pin n8n Docker image to specific version (from :latest)
- Pin PostgreSQL and Redis images to specific versions
- Document Redis vm.overcommit_memory fix (host-level)
- Create security hardening checklist
- Document secure cookie configuration for network exposure
- Create comprehensive troubleshooting guide
- Document disaster recovery procedures
- Create runbook for common operations
- Version control all configuration files

### Out of Scope
- SSL/TLS termination (localhost only)
- Reverse proxy configuration
- Network firewall rules
- Secrets management systems (Vault, etc.)
- Security scanning/auditing tools

---

## Prerequisites

- [ ] All Phase 01 sessions 01-04 completed
- [ ] Backup and restore procedures tested
- [ ] Monitoring in place
- [ ] Current n8n version identified

---

## Deliverables

1. Updated `docker-compose.yml` with pinned image versions
2. `docs/SECURITY.md` - Security configuration guide
3. `docs/TROUBLESHOOTING.md` - Common issues and solutions
4. `docs/RECOVERY.md` - Disaster recovery procedures
5. `docs/RUNBOOK.md` - Operational procedures reference
6. Security hardening checklist
7. Version upgrade procedure documentation

---

## Technical Details

### Image Version Pinning
```yaml
# docker-compose.yml
services:
  postgres:
    image: postgres:16.1-alpine  # Pin from :16-alpine

  redis:
    image: redis:7.2-alpine      # Pin from :7-alpine

  n8n:
    image: n8nio/n8n:1.70.0      # Pin from :latest

  n8n-worker:
    image: n8nio/n8n:1.70.0      # Match main instance
```

### Redis vm.overcommit_memory Fix
```bash
# Requires host-level access (document for user to run with sudo)
# Add to /etc/sysctl.conf:
vm.overcommit_memory=1

# Apply immediately:
sudo sysctl vm.overcommit_memory=1
```

### Security Checklist
- [ ] Non-root PostgreSQL user configured
- [ ] Encryption key securely stored
- [ ] .env file permissions restricted (600)
- [ ] No exposed database ports externally
- [ ] Secure cookie disabled documented (localhost only)
- [ ] Image versions pinned

### Troubleshooting Categories
1. Container startup failures
2. Database connection issues
3. Queue/worker problems
4. Memory exhaustion
5. Disk space issues
6. Network connectivity
7. Performance degradation

---

## Success Criteria

- [ ] All Docker images pinned to specific versions
- [ ] Security documentation complete
- [ ] Troubleshooting guide covers common scenarios
- [ ] Recovery procedures documented and tested
- [ ] Runbook covers daily operations
- [ ] Redis warning remediation documented
- [ ] Version upgrade procedure established
