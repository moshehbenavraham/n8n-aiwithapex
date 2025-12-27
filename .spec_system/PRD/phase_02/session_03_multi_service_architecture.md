# Session 03: Multi-Service Architecture and Management

**Session ID**: `phase02-session03-multi-service-architecture`
**Status**: Not Started
**Estimated Tasks**: ~15-20
**Estimated Duration**: 2-3 hours

---

## Objective

Design an extensible multi-service tunnel architecture and create comprehensive management tools for tunnel operations, preparing the infrastructure for future service integrations (Ollama, additional APIs, etc.).

---

## Scope

### In Scope (MVP)
- Multi-tunnel ngrok.yml structure design
- Placeholder configurations for future services
- Tunnel naming conventions and documentation
- Tunnel management scripts (start/stop, status dashboard)
- Integration with existing operational scripts (view-logs.sh, backup-all.sh)
- Comprehensive tunnel documentation (TUNNELS.md, RUNBOOK.md updates)
- Troubleshooting guide for tunnel issues

### Out of Scope
- Actual Ollama/LLM service deployment (future phase)
- Additional ngrok domains (current domain sufficient)
- Load balancing across tunnels
- Tunnel metrics/monitoring dashboards (external tools)

---

## Prerequisites

- [ ] Session 01 completed (ngrok container running, basic tunnel functional)
- [ ] Session 02 completed (traffic policies and OAuth configured)
- [ ] All existing operational scripts functional
- [ ] Understanding of future service requirements (Ollama, etc.)

---

## Deliverables

1. Refactored `config/ngrok.yml` with multi-service structure
2. `scripts/tunnel-manage.sh` - tunnel start/stop/status management
3. Updated `scripts/view-logs.sh` with ngrok log integration
4. Updated `scripts/backup-all.sh` with tunnel configuration backup
5. Comprehensive `docs/TUNNELS.md` documentation
6. Updated `docs/RUNBOOK.md` with tunnel operations
7. Updated `docs/TROUBLESHOOTING.md` with tunnel issues
8. Future service integration guide

---

## Success Criteria

- [ ] ngrok.yml structured for easy multi-service addition
- [ ] Placeholder/template for adding Ollama tunnel documented
- [ ] tunnel-manage.sh provides start/stop/status operations
- [ ] view-logs.sh includes ngrok container logs option
- [ ] backup-all.sh includes ngrok configuration files
- [ ] TUNNELS.md provides comprehensive tunnel documentation
- [ ] RUNBOOK.md includes tunnel operation procedures
- [ ] TROUBLESHOOTING.md covers common tunnel failure scenarios
- [ ] Adding a new service tunnel requires minimal configuration changes
- [ ] Tunnel naming convention documented and consistently applied
