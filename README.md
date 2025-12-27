# n8n

Production-grade n8n workflow automation platform on WSL2 Ubuntu with Docker Compose.

## Quick Start

```bash
# Start all services
docker compose up -d

# Access n8n
open http://localhost:5678
```

## Repository Structure

```
.
├── config/              # Service configuration files
├── data/                # Runtime data (gitignored)
├── backups/             # Backup destination (postgres/, redis/, n8n/)
├── scripts/             # Operational scripts (12 scripts)
├── docs/                # Documentation (14 guides)
├── logs/                # Application logs
└── docker-compose.yml   # Stack definition
```

## Services

| Service | Port | Status |
|---------|------|--------|
| n8n UI | 5678 | http://localhost:5678 |
| PostgreSQL | 5432 (internal) | Database |
| Redis | 6386 (internal) | Queue broker |
| n8n Worker (x5) | - | Queue processors |

## Documentation

### Getting Started
- [Onboarding](docs/onboarding.md) - Zero-to-running checklist
- [Architecture](docs/ARCHITECTURE.md) - System design
- [Deployment Status](docs/DEPLOYMENT_STATUS.md) - Current system state

### Operations
- [Runbook](docs/RUNBOOK.md) - Daily/weekly/monthly operations
- [Development](docs/development.md) - Day-to-day commands
- [Monitoring](docs/MONITORING.md) - Health and metrics
- [Scaling](docs/SCALING.md) - Worker scaling configuration

### Maintenance
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Problem diagnosis
- [Recovery](docs/RECOVERY.md) - Disaster recovery procedures
- [Upgrade](docs/UPGRADE.md) - Version upgrade procedures
- [Security](docs/SECURITY.md) - Security hardening

### Reference
- [PostgreSQL Tuning](docs/POSTGRESQL_TUNING.md) - Database optimization
- [Port Assignments](docs/PORTS-ASSIGNMENT.md) - Network configuration
- [Environments](docs/environments.md) - Environment configuration

## Tech Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| Docker Compose | v5.0+ | Container orchestration |
| PostgreSQL | 16.11-alpine | Persistent storage |
| Redis | 7.4.7-alpine | Queue broker |
| n8n | 2.1.4 | Workflow automation |

## Common Commands

```bash
# Service management
docker compose up -d              # Start all services
docker compose down               # Stop all services
docker compose up -d --scale n8n-worker=5  # Scale workers

# Health and monitoring
./scripts/system-status.sh        # Full status dashboard
./scripts/health-check.sh         # Quick health check
curl localhost:5678/healthz       # n8n health endpoint

# Backup and maintenance
./scripts/backup-all.sh           # Full backup
./scripts/view-logs.sh -f         # Follow logs
```

## Project Status

All phases complete. See [PRD](.spec_system/PRD/PRD.md) for full details.

| Phase | Name | Status |
|-------|------|--------|
| 00 | Foundation and Core Infrastructure | Complete |
| 01 | Operations and Optimization | Complete |
