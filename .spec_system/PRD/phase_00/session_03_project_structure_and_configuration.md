# Session 03: Project Structure and Configuration

**Session ID**: `phase00-session03-project-structure-and-configuration`
**Status**: Not Started
**Estimated Tasks**: ~25-30
**Estimated Duration**: 3-4 hours

---

## Important: WSL2 Ubuntu Only

**All commands run exclusively from WSL2 Ubuntu.** All files are created in the Linux filesystem.

---

## Objective

Create the complete project directory structure and all configuration files required to deploy the n8n stack, including environment variables, Docker Compose definitions, and database initialization scripts.

---

## Scope

### In Scope (MVP)
- Create project directory structure (config, data, backups, scripts)
- Generate secure encryption key for n8n credentials
- Create comprehensive .env file with all required variables
- Create docker-compose.yml with all services defined
- Create PostgreSQL initialization script for n8n user/database
- Create data directories with proper permissions
- Validate configuration syntax and completeness

### Out of Scope
- Actually deploying containers (Session 04)
- Backup script creation (Phase 01)
- Monitoring script creation (Phase 01)
- Performance tuning configuration (Phase 01)

---

## Prerequisites

- [ ] Session 02 completed (Docker installed)
- [ ] Project location in Linux filesystem (/home/...)
- [ ] Docker and Docker Compose functional
- [ ] Understanding of required n8n configuration

---

## Deliverables

1. Project directory structure:
   ```
   /home/aiwithapex/n8n/
   ├── config/
   │   └── postgres-init.sql
   ├── data/
   │   ├── postgres/
   │   ├── redis/
   │   └── n8n/
   │       └── files/
   ├── backups/
   ├── scripts/
   ├── .env
   └── docker-compose.yml
   ```
2. Secure encryption key generated and stored
3. Complete .env file with all service configurations
4. Docker Compose file with PostgreSQL, Redis, n8n main, n8n worker
5. PostgreSQL init script for database/user creation
6. All directories with appropriate permissions

---

## Technical Details

### Environment Variables (.env)
```bash
# PostgreSQL
POSTGRES_USER=n8n
POSTGRES_PASSWORD=<generated>
POSTGRES_DB=n8n

# n8n Core
N8N_ENCRYPTION_KEY=<generated>
N8N_HOST=localhost
N8N_PORT=5678
N8N_PROTOCOL=http
WEBHOOK_URL=http://localhost:5678/

# Queue Mode
EXECUTIONS_MODE=queue
QUEUE_BULL_REDIS_HOST=redis
QUEUE_BULL_REDIS_PORT=6386

# Data Management
N8N_USER_FOLDER=/home/node/.n8n
EXECUTIONS_DATA_PRUNE=true
EXECUTIONS_DATA_MAX_AGE=168
EXECUTIONS_DATA_PRUNE_MAX_COUNT=50000
```

### Docker Compose Services
- **postgres**: PostgreSQL 16-alpine with health check
- **redis**: Redis 7-alpine with append-only persistence
- **n8n**: Main instance (UI, webhooks, triggers)
- **n8n-worker**: Queue worker for execution

### PostgreSQL Init Script
```sql
CREATE USER n8n WITH PASSWORD '<password>';
CREATE DATABASE n8n OWNER n8n;
GRANT ALL PRIVILEGES ON DATABASE n8n TO n8n;
```

---

## Success Criteria

- [ ] All directories created with correct permissions
- [ ] Encryption key generated (32+ bytes, base64)
- [ ] .env file complete with all required variables
- [ ] docker-compose.yml syntactically valid
- [ ] `docker compose config` validates successfully
- [ ] PostgreSQL init script ready
- [ ] No sensitive data in docker-compose.yml (uses .env)
- [ ] .env file permissions restricted (600)
