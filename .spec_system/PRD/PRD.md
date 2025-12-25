# n8n WSL2 Production Setup - Product Requirements Document

## Important: WSL2 Ubuntu Only

**This entire project runs exclusively through WSL2 Ubuntu.** All commands, file operations, and configurations are executed from within the Ubuntu terminal. There is NO need for PowerShell, CMD, or Windows Terminal - everything is done from WSL2 Ubuntu.

- Windows filesystem is accessed via `/mnt/c/` when needed (e.g., `.wslconfig`)
- Windows executables can be called from Ubuntu using `.exe` suffix (e.g., `wsl.exe --version`)
- All Docker, git, and project commands run natively in Ubuntu

---

## Overview

This project delivers a production-grade n8n workflow automation platform running on local WSL2 Ubuntu. The architecture uses Docker Compose to orchestrate PostgreSQL (database), Redis (message broker), and n8n with queue mode enabled for distributed workflow execution.

The setup is optimized for maximum performance on WSL2 by leveraging Docker Engine directly (not Docker Desktop), storing all files in the Linux filesystem, and configuring appropriate memory and CPU allocations. The Community Edition provides queue mode with scalable workers, execution data pruning, and binary data filesystem storage.

This installation serves as a local development and automation environment capable of handling moderate to heavy workflow loads through horizontal worker scaling.

## Goals

1. Deploy a production-ready n8n instance on WSL2 Ubuntu with Docker Compose
2. Configure PostgreSQL 16 as the database backend for 10x performance improvement over SQLite
3. Enable queue mode with Redis for distributed workflow execution
4. Implement scalable worker architecture for parallel workflow processing
5. Establish automated backup procedures with retention policies
6. Optimize WSL2 and Docker configuration for maximum I/O and memory performance
7. Provide health monitoring and metrics endpoints for operational visibility

## Non-Goals

- Multi-main high availability (requires Enterprise Edition)
- Using Docker Desktop (Docker Engine directly in WSL2 performs better)
- Storing project files in Windows filesystem (/mnt/c/...) due to 85% performance loss
- Using SQLite database backend
- Direct npm/Node.js installation (containerized approach preferred)
- External/cloud hosting (local WSL2 only)
- SSL/TLS termination (localhost development environment)
- Custom n8n node development
- Integration with external monitoring systems (Prometheus, Grafana)

## Users and Use Cases

### Primary Users

- **Developer/Engineer**: Runs automation workflows locally for development, testing, and personal productivity
- **Self-Hosted Administrator**: Manages the n8n installation, scaling, backups, and updates

### Key Use Cases

1. Execute workflow automations triggered by webhooks, schedules, or manual runs
2. Scale workers up/down based on workflow processing demands
3. Back up and restore workflow definitions and execution data
4. Update n8n to new versions with minimal downtime
5. Monitor system health and resource utilization
6. Troubleshoot and recover from container or service failures

## Requirements

### MVP Requirements

**Infrastructure**
- WSL2 with Ubuntu 22.04 LTS or 24.04 LTS installed and configured
- Docker Engine and Docker Compose Plugin v2+ installed in WSL2
- Project directory located in Linux filesystem (/home/...)
- Minimum 4GB RAM allocated to WSL2 (8GB recommended)
- Minimum 2 CPU cores allocated (4 recommended)
- Minimum 20GB storage (50GB+ SSD recommended)

**Core Services**
- PostgreSQL 16-alpine container with persistent volume storage
- Redis 7-alpine container with append-only persistence and memory limits
- n8n main instance container (UI, webhooks, triggers) on port 5678
- n8n worker container(s) with configurable concurrency
- Docker bridge network for inter-service communication

**Configuration**
- Environment file (.env) with all service configuration
- Secure encryption key generated and stored for credential encryption
- Database initialization script for non-root user creation
- Health checks configured for all services
- Queue mode enabled (EXECUTIONS_MODE=queue)

**Data Management**
- Binary data stored in filesystem mode (not database)
- Execution data pruning enabled with configurable retention
- Named Docker volumes for PostgreSQL, Redis, and n8n data

**Operations**
- Backup script for PostgreSQL, n8n data, and environment files
- Automated backup scheduling via cron
- Container health monitoring via Docker health checks

### Deferred Requirements

- PostgreSQL performance tuning configuration file
- Worker auto-scaling based on queue depth
- Log aggregation and centralized logging
- External monitoring integration (Prometheus/Grafana)
- Reverse proxy with SSL termination
- Multi-environment configuration (dev/staging/prod)

## Non-Functional Requirements

- **Performance**: PostgreSQL provides 10x performance improvement over SQLite under load. Filesystem binary storage faster than database storage. WSL2 configured with 8GB RAM and 4 CPU cores for optimal performance.
- **Security**: Non-root PostgreSQL user for n8n connections. Encryption key for credential storage. Secure cookie disabled for localhost. No exposed database or Redis ports externally.
- **Reliability**: Health checks on all containers with automatic restart on failure. Execution data pruning prevents database bloat. Append-only Redis persistence.
- **Scalability**: Workers can be scaled from 1 to 5+ instances via docker compose scale. Each worker supports 5-10 concurrent executions. Queue mode separates UI responsiveness from execution load.
- **Maintainability**: Single docker-compose.yml defines entire stack. Environment variables centralized in .env file. Standard Docker commands for updates and management.

## Constraints and Dependencies

- WSL2 must be installed and set as default WSL version
- Ubuntu distribution must be installed in WSL2
- Files must be in Linux filesystem (not /mnt/c/) for acceptable performance
- Internet connection required for pulling Docker images
- Port 5678 must be available on the host
- Community Edition limitations apply (no multi-main HA)
- Docker service must be started manually or via bashrc on WSL2 boot

## Phases

This system delivers the product via phases. Each phase is implemented via multiple 2-4 hour sessions (15-30 tasks each).

| Phase | Name | Sessions | Status |
|-------|------|----------|--------|
| 00 | Foundation and Core Infrastructure | 4 | Not Started |
| 01 | Operations and Optimization | TBD | Not Started |

## Phase 00: Foundation and Core Infrastructure

### Objectives

1. Verify and optimize WSL2 environment configuration
2. Install Docker Engine and Docker Compose Plugin
3. Create project directory structure and configuration files
4. Deploy PostgreSQL and Redis with health checks and persistence
5. Deploy n8n main instance and worker(s) in queue mode
6. Verify all services healthy and n8n accessible

### Sessions

| Session | Name | Est. Tasks |
|---------|------|------------|
| 01 | WSL2 Environment Optimization | ~15-20 |
| 02 | Docker Engine Installation | ~20-25 |
| 03 | Project Structure and Configuration | ~25-30 |
| 04 | Service Deployment and Verification | ~20-25 |

Session specifications located in `.spec_system/PRD/phase_00/`.

## Phase 01: Operations and Optimization

### Objectives

1. Create and schedule automated backup procedures
2. Implement worker scaling configuration
3. Configure PostgreSQL performance tuning
4. Establish monitoring and health check procedures
5. Document troubleshooting and recovery procedures

### Sessions (To Be Defined)

Sessions are defined via `/phasebuild` as `session_NN_name.md` stubs under `.spec_system/PRD/phase_01/`.

## Technical Stack

- **Host OS**: WSL2 Ubuntu 22.04 or 24.04 LTS - native Linux environment with Windows integration
- **Container Runtime**: Docker Engine - better performance than Docker Desktop in WSL2
- **Orchestration**: Docker Compose v2+ - declarative multi-container management
- **Database**: PostgreSQL 16-alpine - production-grade persistence, 10x faster than SQLite
- **Message Broker**: Redis 7-alpine - queue mode support for distributed execution
- **Application**: n8n 2.0+ Community Edition - workflow automation with queue mode support
- **Shell**: Bash - scripting for automation and maintenance

## Success Criteria

- [ ] WSL2 configured with appropriate memory (8GB) and CPU (4 cores) allocation
- [ ] Docker Engine and Compose Plugin installed and functional in WSL2
- [ ] Project directory structure created in Linux filesystem
- [ ] Environment file (.env) configured with secure credentials
- [ ] Encryption key generated and stored securely
- [ ] PostgreSQL container running and healthy
- [ ] Redis container running and healthy
- [ ] n8n main container running and accessible at http://localhost:5678
- [ ] n8n worker container running and processing queue jobs
- [ ] Queue mode verified functional (jobs processed by workers)
- [ ] Health endpoints responding (/healthz)
- [ ] Metrics endpoint accessible (/metrics)
- [ ] Backup script created and tested
- [ ] Automated backup scheduled via cron
- [ ] Worker scaling verified (scale up/down works)

## Risks

- **Windows filesystem usage**: Using /mnt/c/ path causes up to 85% I/O performance loss. Mitigation: Enforce Linux filesystem location during setup verification.
- **Memory exhaustion**: Insufficient WSL2 memory allocation causes container OOM. Mitigation: Configure .wslconfig with 8GB memory and monitor with docker stats.
- **Database bloat**: Unbounded execution history grows database indefinitely. Mitigation: Enable execution pruning with 168-hour max age and 50000 max count.
- **Worker queue disconnect**: Redis connectivity issues prevent job processing. Mitigation: Health checks with automatic container restart and Redis persistence.
- **Encryption key loss**: Lost encryption key makes stored credentials unrecoverable. Mitigation: Store key in dedicated file with restricted permissions and include in backups.
- **Port conflict**: Port 5678 already in use blocks n8n startup. Mitigation: Document port check command in troubleshooting.

## Assumptions

- WSL2 is already installed and configured as the default WSL version
- User has administrative access to install Docker and modify WSL configuration
- Ubuntu distribution is already installed in WSL2
- Sufficient disk space is available (minimum 20GB free)
- Internet connection is available for pulling Docker images
- User is familiar with basic Docker and command-line operations
- No other services are using port 5678

## Open Questions

1. Should Docker service auto-start be configured via systemd or bashrc approach?
2. What is the preferred timezone for the installation (currently set to America/New_York)?
3. Should worker concurrency be set to 5 or 10 per worker instance?
4. What backup retention period is preferred (currently 7 days)?
5. Should PostgreSQL performance tuning configuration be included in Phase 00 or Phase 01?
