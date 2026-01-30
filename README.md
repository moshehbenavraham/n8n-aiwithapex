# n8n

**Version 1.0.0**

Production-grade n8n workflow automation platform with Docker Compose, queue mode, distributed workers, and task runners.

> **Optimized for Custom Fork**: This deployment infrastructure is designed and optimized to run with our custom n8n fork at [github.com/moshehbenavraham/n8n](https://github.com/moshehbenavraham/n8n). The fork enables custom branding, white-labeling, and enterprise customizations while maintaining upstream compatibility. See [Custom Fork Guide](docs/custom-fork.md) for details.

## Deployment Options

This project supports **two deployment forms**:

| Deployment | Environment | URL | Status |
|------------|-------------|-----|--------|
| **WSL2 (Local)** | Ubuntu on Windows | https://your.ngrok.domain | Operational |
| **Coolify (Cloud)** | Coolify-managed server | https://your.custom.vps.domain | Planning |

See [Deployment Comparison](docs/deployment-comparison.md) for detailed differences.

---

## Quick Start (WSL2 Local)

```bash
# Start all services
docker compose up -d

# Access n8n (local)
open http://localhost:5678

# Access n8n (external via ngrok)
open https://your.ngrok.domain
```

## Quick Start (Coolify)

See [Deploy to Coolify](docs/deploy-to-coolify.md) for cloud deployment.

## Repository Structure

```
.
├── config/              # Service configuration
│   ├── ngrok.yml        # ngrok tunnel configuration
│   ├── postgresql.conf  # PostgreSQL tuning
│   ├── postgres-init.sql # Database initialization
│   ├── n8n-task-runners.json # Task runner configuration (JS + Python)
│   ├── daemon.json      # Docker daemon settings
│   └── cron/            # Scheduled task configs
├── data/                # Runtime data (gitignored)
│   ├── n8n/             # n8n user data
│   ├── postgres/        # PostgreSQL data
│   ├── redis/           # Redis data
│   └── benchmark/       # Benchmark results
├── backups/             # Backup destination
│   ├── postgres/        # Database backups
│   ├── redis/           # Redis snapshots
│   ├── n8n/             # n8n workflow exports
│   ├── ngrok/           # Tunnel config backups
│   └── env/             # Environment backups
├── scripts/             # Operational scripts (22 scripts)
├── docs/                # Documentation (26 guides)
│   └── ongoing-roadmap/ # Future development docs
├── tests/               # BATS test files (22 tests)
├── logs/                # Application logs
├── docker-compose.yml           # WSL2/Local stack definition
└── docker-compose.coolify.yml   # Coolify stack definition
```

## Services

| Service | Container | Port | Description |
|---------|-----------|------|-------------|
| n8n UI | n8n-main | 5678 | Main workflow editor and API |
| n8n (external) | n8n-ngrok | 443 | Secure tunnel via ngrok |
| ngrok Inspector | n8n-ngrok | 4040 | Tunnel monitoring dashboard |
| PostgreSQL | n8n-postgres | 5432 (internal) | Persistent database storage |
| Redis | n8n-redis | 6386 (internal) | Queue broker for workers |
| n8n Worker 1 | n8n-worker-1 | - | Queue processor |
| n8n Worker 2 | n8n-worker-2 | - | Queue processor |
| n8n Worker 3 | n8n-worker-3 | - | Queue processor |
| Task Runner 1 | n8n-runner-worker-1 | - | JavaScript/Python code executor |
| Task Runner 2 | n8n-runner-worker-2 | - | JavaScript/Python code executor |
| Task Runner 3 | n8n-runner-worker-3 | - | JavaScript/Python code executor |

### External Network Integration

The stack connects to an external Ollama network for local LLM support:
- Network: `lore-sage_luminari-network`
- Models: deepseek-r1:8b, qwen2.5:7b, nomic-embed-text
- See [Local LLM Integration](docs/n8n-with-local-llms.md) for configuration

## Documentation

### Deployment Guides
- [Deployment Comparison](docs/deployment-comparison.md) - WSL2 vs Coolify side-by-side
- [Installation Plan (WSL2)](docs/n8n-installation-plan.md) - Complete local setup guide
- [Deploy to Coolify](docs/deploy-to-coolify.md) - Cloud deployment guide
- [Migration Guide](docs/migration-wsl2-to-coolify.md) - Moving from WSL2 to Coolify

### Getting Started
- [Onboarding](docs/onboarding.md) - Zero-to-running checklist (WSL2)
- [Architecture](docs/ARCHITECTURE.md) - System design (both deployments)
- [Deployment Status](docs/DEPLOYMENT_STATUS.md) - Current system state
- [Development](docs/development.md) - Day-to-day commands

### Operations
- [Runbook](docs/RUNBOOK.md) - Daily/weekly/monthly operations
- [Monitoring](docs/MONITORING.md) - Health and metrics
- [Scaling](docs/SCALING.md) - Worker scaling configuration
- [Auto-Scaling](docs/auto-scaling.md) - Queue-based automatic scaling
- [Tunnels](docs/TUNNELS.md) - ngrok tunnel and external access

### Advanced Features
- [Task Runners](docs/ongoing-roadmap/n8n-runners.md) - External code execution (JS + Python)
- [Local LLM Integration](docs/n8n-with-local-llms.md) - Ollama integration for AI workflows
- [Custom Fork](docs/custom-fork.md) - Custom n8n fork configuration

### Maintenance
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Problem diagnosis
- [Recovery](docs/RECOVERY.md) - Disaster recovery procedures
- [Disaster Recovery](docs/disaster-recovery.md) - Full DR procedures
- [Upgrade](docs/UPGRADE.md) - Version upgrade procedures
- [Security](docs/SECURITY.md) - Security and OAuth

### Backup & Storage
- [Backup Encryption](docs/backup-encryption.md) - GPG encryption for backups
- [Log Management](docs/log-management.md) - Log rotation and cleanup

### Reference
- [PostgreSQL Tuning](docs/POSTGRESQL_TUNING.md) - Database optimization
- [Port Assignments](docs/PORTS-ASSIGNMENT.md) - Network configuration
- [Environments](docs/environments.md) - Environment configuration

## Tech Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| Docker Compose | v2.0+ | Container orchestration |
| PostgreSQL | 16.11-alpine | Persistent storage |
| Redis | 7.4.7-alpine | Queue broker |
| n8n | 2.6.1 (Obsidian Forge) | Workflow automation |
| n8n Task Runners | latest | External code execution (JS/Python) |
| ngrok | alpine | Secure tunnel with OAuth |

## Common Commands

```bash
# Service management
docker compose up -d              # Start all services
docker compose down               # Stop all services
docker compose ps                 # View service status

# Health and monitoring
./scripts/system-status.sh        # Full status dashboard
./scripts/health-check.sh         # Quick health check
curl localhost:5678/healthz       # n8n health endpoint
./scripts/queue-depth.sh          # Check queue depth

# Tunnel management
./scripts/tunnel-manage.sh status   # Tunnel status
./scripts/tunnel-manage.sh restart  # Restart tunnel
./scripts/tunnel-status.sh          # Detailed tunnel info

# Worker and scaling
./scripts/worker-autoscale.sh       # Auto-scale based on queue
./scripts/monitor-resources.sh      # Resource monitoring

# Backup and maintenance
./scripts/backup-all.sh           # Full backup (postgres, redis, n8n, env)
./scripts/backup-postgres.sh      # Database backup only
./scripts/restore-postgres.sh     # Restore from backup
./scripts/cleanup-backups.sh      # Clean old backups
./scripts/cleanup-logs.sh         # Clean old logs
./scripts/view-logs.sh -f         # Follow logs

# Testing and verification
./scripts/verify-versions.sh      # Verify component versions
./scripts/postgres-benchmark.sh   # Database performance test
./scripts/test-recovery.sh        # Test recovery procedures
```

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `system-status.sh` | Full system status dashboard |
| `health-check.sh` | Quick health verification |
| `backup-all.sh` | Comprehensive backup (all components) |
| `backup-postgres.sh` | PostgreSQL database backup |
| `backup-redis.sh` | Redis data backup |
| `backup-n8n.sh` | n8n workflows export |
| `backup-offsite.sh` | Sync backups to remote storage |
| `restore-postgres.sh` | Restore PostgreSQL from backup |
| `restore-redis.sh` | Restore Redis from backup |
| `restore-n8n.sh` | Restore n8n workflows |
| `cleanup-backups.sh` | Remove old backup files |
| `cleanup-logs.sh` | Log rotation and cleanup |
| `tunnel-manage.sh` | ngrok tunnel management |
| `tunnel-status.sh` | Detailed tunnel status |
| `queue-depth.sh` | Monitor Redis queue depth |
| `worker-autoscale.sh` | Auto-scale workers by queue |
| `monitor-resources.sh` | Resource usage monitoring |
| `postgres-benchmark.sh` | Database performance testing |
| `verify-versions.sh` | Verify component versions |
| `view-logs.sh` | View and follow logs |
| `test-recovery.sh` | Test backup/restore procedures |
| `apply-sysctl.sh` | Apply system optimizations |
