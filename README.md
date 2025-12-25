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
│   └── postgres-init.sql
├── data/                # Runtime data (gitignored)
├── backups/             # Backup destination
├── scripts/             # Operational scripts
├── docs/                # Documentation
└── docker-compose.yml   # Stack definition
```

## Services

| Service | Port | Status |
|---------|------|--------|
| n8n UI | 5678 | http://localhost:5678 |
| PostgreSQL | 5432 (internal) | Database |
| Redis | 6386 (internal) | Queue broker |
| n8n Worker | - | Queue processor |

## Documentation

- [Deployment Status](docs/DEPLOYMENT_STATUS.md) - Current system state
- [Port Assignments](docs/PORTS-ASSIGNMENT.md) - Network configuration
- [Architecture](docs/ARCHITECTURE.md) - System design
- [Onboarding](docs/onboarding.md) - Setup checklist
- [Development](docs/development.md) - Operations guide

## Tech Stack

- **Runtime**: Docker Compose on WSL2 Ubuntu
- **Database**: PostgreSQL 16-alpine
- **Queue**: Redis 7-alpine
- **Application**: n8n Community Edition (queue mode)

## Common Commands

```bash
docker compose up -d          # Start
docker compose down           # Stop
docker compose logs -f        # View logs
docker compose ps             # Check status
curl localhost:5678/healthz   # Health check
```

## Project Status

Phase 00 (Foundation) complete. See [PRD](.spec_system/PRD/PRD.md) for roadmap.
