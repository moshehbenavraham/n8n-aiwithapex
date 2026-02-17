# Changelog

All notable changes to this project are documented in this file.

## [v1.1.0] - 2026-02-05

### Released
- Security hardening and reliability improvements

### Fixed
- Coolify runner crash loop — use `N8N_RUNNERS_CONFIG_PATH` instead of `cp` (2026-02-06)
- Ngrok rate limit per client IP with `bucket_key` (2026-02-17)

### Added
- GitHub `FUNDING.yml` (2026-02-16)

---

## [v1.0.0] - 2026-01-30

### Released
- Align local and Coolify deployments

### Added
- Queue mode optimization with Bull/Redis tuning (2026-01-22)

### Fixed
- Coolify deploy using wrong URL variable (2026-01-21)
- Increase worker memory limits from 512M to 1G (2026-01-18)

---

## Pre-release

### Task Runners & Coolify Production Deploy (2026-01-11 — 2026-01-12)
- Deploy n8n production stack to Coolify with custom fork
- Add task runners with named workers and backup size verification
- Add Python stdlib support for task runners
- Fix worker volume mounts and enable runners/Python for dev
- Fix runner config force copy for existing files
- Fix task runners to run as root with correct launcher command
- Fix runner-init restart policy to silence Coolify degraded warning
- Update README with accurate service counts and structure
- Update deploy-to-coolify docs with completed data migration
- Remove incorrect comment

### Custom Fork & Proxy Support (2026-01-01 — 2026-01-02)
- Add custom fork image toggle and documentation
- Reduce worker replicas from 5 to 3 and sanitize documentation
- Add `N8N_TRUST_PROXY` for reverse proxy support (v2.1.4-custom.2)
- Add custom fork optimization notices to all documentation

### Local LLM Integration (2025-12-30)
- Add local LLM integration with Ollama (external network to lore-sage)

### Coolify Deployment (2025-12-28 — 2025-12-29)
- Add Coolify deployment configuration and documentation
- Update documentation for Coolify deployment migration

### Phase 03 — Advanced Operations (2025-12-28)
- GPG encryption and off-site backup storage
- Queue-based worker auto-scaling
- Docker log rotation and management
- Sysctl optimization and disaster recovery

### Phase 02 — Networking & Security (2025-12-27)
- Ngrok Docker sidecar for webhook access
- Ngrok v3 migration and OAuth security
- Tunnel management and multi-service architecture
- Add Phase 02 structure, `.env.example` template, and project documentation
- Add AI agent files to `.gitignore` and untrack `CLAUDE.md`
- Remove `.spec_system` from repo and add to `.gitignore`

### Phase 01 — Operations & Optimization (2025-12-26)
- Automated backup infrastructure
- Multi-worker queue architecture
- PostgreSQL performance optimization
- Monitoring and health management toolkit
- Production hardening and documentation
- Improve `.gitignore` security patterns
- Add `.gitkeep` files to preserve directory structure

### Phase 00 — Foundation (2025-12-25 — 2025-12-26)
- WSL2 resource configuration
- Docker Engine verification
- Docker Compose stack configuration
- n8n stack deployment
