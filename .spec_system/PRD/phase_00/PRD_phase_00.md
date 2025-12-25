# PRD Phase 00: Foundation and Core Infrastructure

**Status**: In Progress
**Sessions**: 4 (initial estimate)
**Estimated Duration**: 9-13 hours

**Progress**: 2/4 sessions (50%)

---

## Important: WSL2 Ubuntu Only

**All commands and operations run exclusively from WSL2 Ubuntu.** There is NO need for PowerShell, CMD, or Windows Terminal. Windows files (like `.wslconfig`) are accessed via `/mnt/c/` from Ubuntu.

---

## Overview

This phase establishes the complete infrastructure for running n8n in production mode on WSL2 Ubuntu. It covers WSL2 optimization, Docker Engine installation, project structure and configuration, and deploying the full n8n stack with PostgreSQL, Redis, and queue-based workers.

---

## Progress Tracker

| Session | Name | Status | Est. Tasks | Validated |
|---------|------|--------|------------|-----------|
| 01 | WSL2 Environment Optimization | Complete | 18 | 2025-12-25 |
| 02 | Docker Engine Installation | Complete | 22 | 2025-12-25 |
| 03 | Project Structure and Configuration | Not Started | ~25-30 | - |
| 04 | Service Deployment and Verification | Not Started | ~20-25 | - |

---

## Completed Sessions

- **Session 01**: WSL2 Environment Optimization (2025-12-25)
  - Configured WSL2 with 8GB RAM, 4 CPUs, 2GB swap
  - Created .wslconfig at /mnt/c/Users/apexw/.wslconfig
  - Documented baseline system state

- **Session 02**: Docker Engine Installation (2025-12-25)
  - Verified Docker Engine 29.1.3 installation (exceeds 24.0.0+ requirement)
  - Verified Docker Compose v5.0.0 (exceeds 2.0.0+ requirement)
  - Confirmed systemd auto-start configuration
  - All 22 tasks verified complete

---

## Upcoming Sessions

- Session 03: Project Structure and Configuration
- Session 04: Service Deployment and Verification

---

## Objectives

1. Verify and optimize WSL2 environment configuration with appropriate memory and CPU allocations
2. Install Docker Engine and Docker Compose Plugin directly in WSL2 (not Docker Desktop)
3. Create project directory structure and all configuration files
4. Deploy PostgreSQL and Redis with health checks and persistence
5. Deploy n8n main instance and worker(s) in queue mode
6. Verify all services healthy and n8n accessible at http://localhost:5678

---

## Prerequisites

- WSL2 installed and set as default WSL version
- Ubuntu 22.04 or 24.04 LTS installed in WSL2
- Write access to /mnt/c/Users/$USER/ (for .wslconfig)
- Sudo access in Ubuntu
- Internet connection for package and image downloads
- Minimum 4GB RAM (8GB recommended) and 2 CPU cores (4 recommended)
- Minimum 20GB storage (50GB+ SSD recommended)

---

## Technical Considerations

### Architecture
- Docker Engine runs directly in WSL2 (not Docker Desktop) for optimal performance
- All project files stored in Linux filesystem (/home/...) to avoid 85% I/O penalty
- Docker Compose orchestrates multi-container deployment
- Named volumes for persistent data storage

### Technologies
- WSL2 with Ubuntu 22.04 or 24.04 LTS
- Docker Engine 24+
- Docker Compose Plugin v2+
- PostgreSQL 16-alpine
- Redis 7-alpine
- n8n 2.0+ Community Edition

### Risks
- **Windows filesystem usage**: Using /mnt/c/ causes up to 85% I/O performance loss. Mitigation: Verify project in Linux filesystem.
- **Memory exhaustion**: Insufficient WSL2 memory causes OOM. Mitigation: Configure .wslconfig with 8GB RAM.
- **Port conflict**: Port 5678 in use blocks n8n. Mitigation: Verify port availability before deployment.
- **Docker Desktop conflict**: Remnants may interfere. Mitigation: Remove conflicting packages.

---

## Success Criteria

Phase complete when:
- [x] WSL2 configured with 8GB RAM and 4 CPU cores
- [ ] All 4 sessions completed
- [x] Docker Engine and Compose installed and functional
- [ ] Project structure created with all config files
- [ ] All containers running and healthy (postgres, redis, n8n, n8n-worker)
- [ ] n8n UI accessible at http://localhost:5678
- [ ] Queue mode verified functional (worker processing jobs)
- [ ] Health and metrics endpoints responding

---

## Dependencies

### Depends On
- None (first phase)

### Enables
- Phase 01: Operations and Optimization
