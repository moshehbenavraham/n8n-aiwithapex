# n8n Installation Plan for WSL2 Ubuntu

> **Optimized for Maximum Performance - Community Edition**
>
> This plan provides a production-grade n8n installation on local WSL2 Ubuntu using Docker Compose with PostgreSQL, Redis, and worker scaling for maximum performance.

> **Custom Fork Support**: This deployment infrastructure is optimized to run with our custom n8n fork at [github.com/moshehbenavraham/n8n](https://github.com/moshehbenavraham/n8n). Toggle between the official and custom fork images via the `N8N_IMAGE` variable in `.env`. See [Custom Fork Guide](ongoing-roadmap/custom-fork.md) for branding and customization details.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [WSL2 Performance Optimization](#wsl2-performance-optimization)
4. [Installation Steps](#installation-steps)
5. [Configuration Files](#configuration-files)
6. [Performance Tuning](#performance-tuning)
7. [Post-Installation](#post-installation)
8. [Maintenance & Monitoring](#maintenance--monitoring)
9. [Troubleshooting](#troubleshooting)
10. [References](#references)

---

## Architecture Overview

### Recommended Architecture for Maximum Performance

```
┌─────────────────────────────────────────────────────────────────────┐
│                         WSL2 Ubuntu                                  │
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │                    Docker Compose Stack                         ││
│  │                                                                 ││
│  │  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐  ││
│  │  │  PostgreSQL  │    │    Redis     │    │   n8n (Main)     │  ││
│  │  │    v16       │◄───│   v6-alpine  │◄───│   Port 5678      │  ││
│  │  │              │    │              │    │   Queue Mode     │  ││
│  │  └──────────────┘    └──────────────┘    └──────────────────┘  ││
│  │         ▲                   ▲                                   ││
│  │         │                   │                                   ││
│  │         │            ┌──────┴───────┐                          ││
│  │         │            │              │                          ││
│  │         ▼            ▼              ▼                          ││
│  │  ┌──────────────┐  ┌─────────┐  ┌─────────┐                    ││
│  │  │   n8n        │  │  n8n    │  │  n8n    │                    ││
│  │  │   Worker 1   │  │ Worker 2│  │ Worker 3│  (Scalable)       ││
│  │  └──────────────┘  └─────────┘  └─────────┘                    ││
│  │                                                                 ││
│  │  Volumes: db_storage | n8n_storage | redis_storage             ││
│  └─────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────┘
```

### Why This Architecture?

| Component | Purpose | Performance Benefit |
|-----------|---------|---------------------|
| **PostgreSQL** | Production database | 10x faster than SQLite under load |
| **Redis** | Message broker & queue | Enables queue mode for distributed execution |
| **Queue Mode** | Separates UI from execution | Editor stays responsive during heavy loads |
| **Workers** | Execute workflows | Parallel processing, scalable |
| **Docker** | Containerization | Isolation, easy updates, reproducible |

### Community Edition Features Available

- Queue mode with Redis workers
- PostgreSQL database backend
- Execution data pruning
- Binary data filesystem storage
- Multiple worker instances
- Health checks & monitoring endpoints

> **Note:** Multi-main high availability requires Enterprise edition. This plan focuses on single-main with scaled workers.

---

## Prerequisites

### System Requirements

| Resource | Minimum | Recommended for Performance |
|----------|---------|----------------------------|
| RAM | 4GB | 8GB+ |
| CPU Cores | 2 | 4+ |
| Storage | 20GB | 50GB+ SSD |
| Node.js (if npm install) | 18.x, 20.x, 22.x | N/A (using Docker) |

### Required Software

1. **WSL2 with Ubuntu** (22.04 LTS or 24.04 LTS recommended)
2. **Docker Engine** (not Docker Desktop - better performance in WSL2)
3. **Docker Compose Plugin** (v2+)

### Pre-Installation Checklist

- [ ] WSL2 is installed and set as default version
- [ ] Ubuntu distribution is installed in WSL2
- [ ] Project folder is in Linux filesystem (NOT `/mnt/c/...`)
- [ ] Sufficient disk space available
- [ ] Internet connection for pulling Docker images

---

## WSL2 Performance Optimization

### Critical: File System Location

**The project MUST be in the Linux filesystem, not the Windows filesystem.**

```bash
# CORRECT - Files in Linux filesystem (fast)
/home/aiwithapex/n8n/

# INCORRECT - Files in Windows filesystem (slow, up to 85% performance loss)
/mnt/c/Users/username/n8n/
```

### Step 1: Configure WSL2 Memory and CPU

Create or edit `%USERPROFILE%\.wslconfig` in Windows:

```ini
[wsl2]
memory=8GB
processors=4
swap=4GB
localhostForwarding=true
kernelCommandLine=vsyscall=emulate

[experimental]
autoMemoryReclaim=gradual
sparseVhd=true
```

Apply changes:
```powershell
# In PowerShell (Windows)
wsl --shutdown
wsl
```

### Step 2: Optimize WSL2 Disk Performance

```bash
# In WSL2 Ubuntu - Enable filesystem metadata optimization
echo 'options 9p cache=loose' | sudo tee -a /etc/modprobe.d/9p.conf
```

### Step 3: Install Docker Engine (Not Docker Desktop)

Docker Engine directly in WSL2 performs better than Docker Desktop for development workloads:

```bash
# Remove any old Docker installations
sudo apt-get remove docker docker-engine docker.io containerd runc 2>/dev/null

# Install prerequisites
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up the repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add your user to the docker group
sudo usermod -aG docker $USER

# Start Docker service
sudo service docker start

# Enable Docker to start on WSL2 boot
echo 'sudo service docker start' >> ~/.bashrc
```

Log out and back in for group changes to take effect.

---

## Installation Steps

### Step 1: Create Project Structure

```bash
cd /home/aiwithapex/n8n

# Create directory structure
mkdir -p {config,data,backups,scripts}

# Set appropriate permissions
chmod 755 config data backups scripts
```

### Step 2: Generate Encryption Key

```bash
# Generate a secure encryption key (SAVE THIS - CRITICAL)
openssl rand -base64 32 > config/encryption_key.txt
chmod 600 config/encryption_key.txt

# Display the key (copy this for .env file)
cat config/encryption_key.txt
```

### Step 3: Create Environment File

Create `.env` file in project root:

```bash
cat > .env << 'EOF'
# ============================================
# n8n Environment Configuration
# ============================================

# CRITICAL: Encryption key for credentials (NEVER CHANGE AFTER SETUP)
N8N_ENCRYPTION_KEY=<paste-your-generated-key-here>

# ============================================
# PostgreSQL Configuration
# ============================================
POSTGRES_USER=n8n
POSTGRES_PASSWORD=<generate-secure-password>
POSTGRES_DB=n8n

# Non-root user for n8n (security best practice)
POSTGRES_NON_ROOT_USER=n8n_user
POSTGRES_NON_ROOT_PASSWORD=<generate-another-secure-password>

# ============================================
# n8n Database Connection
# ============================================
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=postgres
DB_POSTGRESDB_PORT=5445
DB_POSTGRESDB_DATABASE=${POSTGRES_DB}
DB_POSTGRESDB_USER=${POSTGRES_NON_ROOT_USER}
DB_POSTGRESDB_PASSWORD=${POSTGRES_NON_ROOT_PASSWORD}

# ============================================
# Redis Configuration (Queue Mode)
# ============================================
QUEUE_BULL_REDIS_HOST=redis
QUEUE_BULL_REDIS_PORT=6386

# ============================================
# Execution Mode (Critical for Performance)
# ============================================
EXECUTIONS_MODE=queue

# ============================================
# n8n General Configuration
# ============================================
N8N_HOST=0.0.0.0
N8N_PORT=5678
N8N_PROTOCOL=http
WEBHOOK_URL=http://localhost:5678/

# Timezone
GENERIC_TIMEZONE=America/New_York
TZ=America/New_York

# ============================================
# Performance Optimizations
# ============================================
# Use filesystem for binary data (faster than database)
N8N_DEFAULT_BINARY_DATA_MODE=filesystem

# Enable metrics for monitoring
N8N_METRICS=true

# Disable telemetry for privacy/performance
N8N_DIAGNOSTICS_ENABLED=false

# Execution data pruning (prevents database bloat)
EXECUTIONS_DATA_PRUNE=true
EXECUTIONS_DATA_MAX_AGE=168
EXECUTIONS_DATA_PRUNE_MAX_COUNT=50000

# Execution timeout (seconds) - adjust based on your workflow needs
EXECUTIONS_TIMEOUT=3600
EXECUTIONS_TIMEOUT_MAX=7200

# Memory optimization
NODE_OPTIONS=--max-old-space-size=4096

# Offload manual executions to workers
OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true

# Enable health check endpoints for workers
QUEUE_HEALTH_CHECK_ACTIVE=true

# Enable task runners (n8n 2.0+)
N8N_RUNNERS_ENABLED=true
N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true

# ============================================
# Security Settings
# ============================================
N8N_SECURE_COOKIE=false
N8N_EDITOR_BASE_URL=http://localhost:5678

# Concurrency limit (adjust based on system resources)
N8N_CONCURRENCY_PRODUCTION_LIMIT=20
EOF
```

### Step 4: Create Database Initialization Script

```bash
cat > scripts/init-data.sh << 'EOF'
#!/bin/bash
set -e

# Create non-root user for n8n (security best practice)
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER ${POSTGRES_NON_ROOT_USER} WITH PASSWORD '${POSTGRES_NON_ROOT_PASSWORD}';
    GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB} TO ${POSTGRES_NON_ROOT_USER};
    GRANT ALL ON SCHEMA public TO ${POSTGRES_NON_ROOT_USER};
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${POSTGRES_NON_ROOT_USER};
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${POSTGRES_NON_ROOT_USER};
EOSQL

echo "Non-root user ${POSTGRES_NON_ROOT_USER} created successfully"
EOF

chmod +x scripts/init-data.sh
```

### Step 5: Create Docker Compose File

```bash
cat > docker-compose.yml << 'EOF'
version: "3.8"

x-shared: &shared
  restart: unless-stopped
  env_file: .env
  networks:
    - n8n-network

x-n8n-shared: &n8n-shared
  <<: *shared
  image: docker.n8n.io/n8nio/n8n:latest
  environment:
    - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
    - DB_TYPE=${DB_TYPE}
    - DB_POSTGRESDB_HOST=${DB_POSTGRESDB_HOST}
    - DB_POSTGRESDB_PORT=${DB_POSTGRESDB_PORT}
    - DB_POSTGRESDB_DATABASE=${DB_POSTGRESDB_DATABASE}
    - DB_POSTGRESDB_USER=${DB_POSTGRESDB_USER}
    - DB_POSTGRESDB_PASSWORD=${DB_POSTGRESDB_PASSWORD}
    - EXECUTIONS_MODE=${EXECUTIONS_MODE}
    - QUEUE_BULL_REDIS_HOST=${QUEUE_BULL_REDIS_HOST}
    - QUEUE_BULL_REDIS_PORT=${QUEUE_BULL_REDIS_PORT}
    - N8N_DEFAULT_BINARY_DATA_MODE=${N8N_DEFAULT_BINARY_DATA_MODE}
    - EXECUTIONS_DATA_PRUNE=${EXECUTIONS_DATA_PRUNE}
    - EXECUTIONS_DATA_MAX_AGE=${EXECUTIONS_DATA_MAX_AGE}
    - EXECUTIONS_DATA_PRUNE_MAX_COUNT=${EXECUTIONS_DATA_PRUNE_MAX_COUNT}
    - GENERIC_TIMEZONE=${GENERIC_TIMEZONE}
    - TZ=${TZ}
    - NODE_OPTIONS=${NODE_OPTIONS}
    - N8N_METRICS=${N8N_METRICS}
    - N8N_DIAGNOSTICS_ENABLED=${N8N_DIAGNOSTICS_ENABLED}
    - N8N_RUNNERS_ENABLED=${N8N_RUNNERS_ENABLED}
    - N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=${N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS}
  depends_on:
    postgres:
      condition: service_healthy
    redis:
      condition: service_healthy

volumes:
  db_storage:
    driver: local
  n8n_storage:
    driver: local
  redis_storage:
    driver: local

networks:
  n8n-network:
    driver: bridge

services:
  # ============================================
  # PostgreSQL Database
  # ============================================
  postgres:
    <<: *shared
    image: postgres:16-alpine
    container_name: n8n-postgres
    volumes:
      - db_storage:/var/lib/postgresql/data
      - ./scripts/init-data.sh:/docker-entrypoint-initdb.d/init-data.sh:ro
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_NON_ROOT_USER=${POSTGRES_NON_ROOT_USER}
      - POSTGRES_NON_ROOT_PASSWORD=${POSTGRES_NON_ROOT_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -h localhost -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

  # ============================================
  # Redis (Queue Broker)
  # ============================================
  redis:
    <<: *shared
    image: redis:7-alpine
    container_name: n8n-redis
    command: redis-server --appendonly yes --maxmemory 256mb --maxmemory-policy allkeys-lru
    volumes:
      - redis_storage:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s

  # ============================================
  # n8n Main Instance (UI + Webhooks + Triggers)
  # ============================================
  n8n:
    <<: *n8n-shared
    container_name: n8n-main
    ports:
      - "5678:5678"
    volumes:
      - n8n_storage:/home/node/.n8n
      - ./data:/data
    environment:
      - N8N_HOST=${N8N_HOST}
      - N8N_PORT=${N8N_PORT}
      - N8N_PROTOCOL=${N8N_PROTOCOL}
      - WEBHOOK_URL=${WEBHOOK_URL}
      - N8N_EDITOR_BASE_URL=${N8N_EDITOR_BASE_URL}
      - OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=${OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS}
      - EXECUTIONS_TIMEOUT=${EXECUTIONS_TIMEOUT}
      - EXECUTIONS_TIMEOUT_MAX=${EXECUTIONS_TIMEOUT_MAX}
      - N8N_CONCURRENCY_PRODUCTION_LIMIT=${N8N_CONCURRENCY_PRODUCTION_LIMIT}
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:5678/healthz || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  # ============================================
  # n8n Worker (Executes Workflows)
  # ============================================
  n8n-worker:
    <<: *n8n-shared
    container_name: n8n-worker
    command: worker --concurrency=10
    volumes:
      - n8n_storage:/home/node/.n8n
      - ./data:/data
    environment:
      - QUEUE_HEALTH_CHECK_ACTIVE=${QUEUE_HEALTH_CHECK_ACTIVE}
    deploy:
      mode: replicated
      replicas: 1
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 512M
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:5678/healthz || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
EOF
```

### Step 6: Start the Stack

```bash
# Pull images
docker compose pull

# Start all services
docker compose up -d

# View logs (optional)
docker compose logs -f

# Check service health
docker compose ps
```

### Step 7: Verify Installation

```bash
# Check all services are healthy
docker compose ps

# Check n8n logs
docker compose logs n8n

# Check worker logs
docker compose logs n8n-worker

# Test n8n health endpoint
curl http://localhost:5678/healthz

# Test worker health endpoint
docker exec n8n-worker wget -qO- http://localhost:5678/healthz
```

Access n8n at: **http://localhost:5678**

---

## Performance Tuning

### Worker Scaling

Scale workers based on workload:

```bash
# Scale to 3 workers (recommended for moderate workloads)
docker compose up -d --scale n8n-worker=3

# Scale to 5 workers (for heavy workloads)
docker compose up -d --scale n8n-worker=5
```

**Guidelines:**
- Start with 2-3 workers
- Each worker should have concurrency of 5-10
- Monitor memory usage and adjust
- Small multiple workers > one large worker

### Memory Optimization

If experiencing memory issues, adjust in `.env`:

```bash
# Reduce heap size if needed
NODE_OPTIONS=--max-old-space-size=2048

# Reduce concurrency
N8N_CONCURRENCY_PRODUCTION_LIMIT=10
```

### Database Optimization

For PostgreSQL performance, create `config/postgresql.conf`:

```ini
# Performance tuning for n8n workloads
shared_buffers = 256MB
work_mem = 64MB
maintenance_work_mem = 128MB
effective_cache_size = 1GB
random_page_cost = 1.1
checkpoint_completion_target = 0.9
wal_buffers = 16MB
max_connections = 100
```

Mount in docker-compose.yml under postgres service:
```yaml
volumes:
  - ./config/postgresql.conf:/etc/postgresql/postgresql.conf:ro
command: postgres -c config_file=/etc/postgresql/postgresql.conf
```

### Binary Data Storage

For large file handling, filesystem mode is configured. For even better performance with very large files:

```bash
# In .env - already configured
N8N_DEFAULT_BINARY_DATA_MODE=filesystem
```

---

## Post-Installation

### Create Initial Admin Account

1. Navigate to http://localhost:5678
2. Follow the setup wizard
3. Create your admin account
4. Save credentials securely

### Import/Export Workflows

```bash
# Export workflows (backup)
docker exec n8n-main n8n export:workflow --all --output=/data/workflows-backup.json

# Import workflows
docker exec n8n-main n8n import:workflow --input=/data/workflows-backup.json
```

### Create Backup Script

```bash
cat > scripts/backup.sh << 'EOF'
#!/bin/bash
set -e

BACKUP_DIR="/home/aiwithapex/n8n/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "Starting n8n backup..."

# Backup PostgreSQL
docker exec n8n-postgres pg_dump -U n8n n8n | gzip > "$BACKUP_DIR/postgres_$TIMESTAMP.sql.gz"

# Backup n8n data volume
docker run --rm -v n8n_n8n_storage:/data -v "$BACKUP_DIR":/backup alpine tar czf /backup/n8n_data_$TIMESTAMP.tar.gz /data

# Backup environment file
cp /home/aiwithapex/n8n/.env "$BACKUP_DIR/env_$TIMESTAMP.backup"

# Keep only last 7 days of backups
find "$BACKUP_DIR" -name "*.gz" -mtime +7 -delete
find "$BACKUP_DIR" -name "*.backup" -mtime +7 -delete

echo "Backup completed: $TIMESTAMP"
EOF

chmod +x scripts/backup.sh
```

### Schedule Automated Backups

```bash
# Add to crontab
(crontab -l 2>/dev/null; echo "0 2 * * * /home/aiwithapex/n8n/scripts/backup.sh >> /home/aiwithapex/n8n/backups/backup.log 2>&1") | crontab -
```

---

## Maintenance & Monitoring

### Health Checks

```bash
# Check all container status
docker compose ps

# Check n8n main health
curl -s http://localhost:5678/healthz

# Check n8n metrics (if enabled)
curl -s http://localhost:5678/metrics

# Check Redis queue status
docker exec n8n-redis redis-cli info clients
```

### Updating n8n

```bash
# Pull latest images
docker compose pull

# Restart with new images
docker compose down && docker compose up -d

# Verify update
docker compose logs n8n | grep "Version"
```

### Log Management

```bash
# View real-time logs
docker compose logs -f

# View specific service logs
docker compose logs -f n8n
docker compose logs -f n8n-worker

# Clear old logs (Docker handles this, but you can configure)
docker system prune -f
```

### Resource Monitoring

```bash
# Monitor container resources
docker stats

# Check disk usage
docker system df

# Clean unused resources
docker system prune -a --volumes
```

---

## Troubleshooting

### Common Issues

#### 1. Container won't start

```bash
# Check logs
docker compose logs <service-name>

# Check if port is in use
sudo lsof -i :5678
```

#### 2. Database connection issues

```bash
# Check PostgreSQL is running
docker compose ps postgres

# Test connection
docker exec n8n-postgres psql -U n8n -d n8n -c "SELECT 1"
```

#### 3. Workers not processing jobs

```bash
# Check Redis connectivity
docker exec n8n-worker redis-cli -h redis ping

# Check worker logs
docker compose logs n8n-worker

# Verify EXECUTIONS_MODE=queue is set
docker exec n8n-main printenv | grep EXECUTIONS_MODE
```

#### 4. Performance degradation

```bash
# Check if execution data needs pruning
docker exec n8n-postgres psql -U n8n -d n8n -c "SELECT COUNT(*) FROM execution_entity"

# Force prune if needed (n8n handles this automatically)
# Reduce EXECUTIONS_DATA_MAX_AGE in .env
```

#### 5. Out of memory

```bash
# Check memory usage
docker stats --no-stream

# Reduce worker count
docker compose up -d --scale n8n-worker=1

# Reduce NODE_OPTIONS in .env
```

### Recovery Commands

```bash
# Full stack restart
docker compose down && docker compose up -d

# Reset specific service
docker compose restart n8n

# Rebuild without cache
docker compose build --no-cache && docker compose up -d

# Nuclear option: full reset (WARNING: data loss)
docker compose down -v
docker volume rm n8n_db_storage n8n_n8n_storage n8n_redis_storage
docker compose up -d
```

---

## References

### Official Documentation
- [n8n Docker Installation](https://docs.n8n.io/hosting/installation/docker/)
- [n8n Queue Mode Configuration](https://docs.n8n.io/hosting/scaling/queue-mode/)
- [n8n Environment Variables](https://docs.n8n.io/hosting/configuration/environment-variables/)
- [n8n Database Configuration](https://docs.n8n.io/hosting/configuration/supported-databases-settings/)

### Community Resources
- [n8n-io/n8n-hosting GitHub Repository](https://github.com/n8n-io/n8n-hosting)
- [n8n Community Forum](https://community.n8n.io/)
- [n8n Release Notes](https://docs.n8n.io/release-notes/)

### Performance Guides
- [Docker Desktop WSL 2 Best Practices](https://www.docker.com/blog/docker-desktop-wsl-2-best-practices/)
- [n8n Self-Hosted Complete Setup Guide 2025](https://latenode.com/blog/how-to-self-host-n8n-complete-setup-guide-production-deployment-checklist-2025)
- [n8n Queue Mode Scaling Guide](https://www.vibepanda.io/resources/guide/scale-n8n-with-workers)

---

## Quick Reference

### Essential Commands

| Action | Command |
|--------|---------|
| Start stack | `docker compose up -d` |
| Stop stack | `docker compose down` |
| View logs | `docker compose logs -f` |
| Scale workers | `docker compose up -d --scale n8n-worker=3` |
| Update n8n | `docker compose pull && docker compose up -d` |
| Backup | `./scripts/backup.sh` |
| Health check | `curl http://localhost:5678/healthz` |

### Important Files

| File | Purpose |
|------|---------|
| `.env` | Environment configuration |
| `docker-compose.yml` | Service definitions |
| `config/encryption_key.txt` | Encryption key (CRITICAL) |
| `scripts/backup.sh` | Backup automation |
| `scripts/init-data.sh` | Database initialization |

### Port Mapping

| Service | Internal Port | External Port |
|---------|--------------|---------------|
| n8n | 5678 | 5678 |
| PostgreSQL | 5445 | (internal only) |
| Redis | 6386 | (internal only) |

---

*Plan created: December 25, 2025*
*n8n Version: 2.0+ (Community Edition)*
*Target Environment: WSL2 Ubuntu with Docker*
