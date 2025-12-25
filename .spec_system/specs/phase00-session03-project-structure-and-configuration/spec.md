# Session Specification

**Session ID**: `phase00-session03-project-structure-and-configuration`
**Phase**: 00 - Foundation and Core Infrastructure
**Status**: Not Started
**Created**: 2025-12-25

---

## 1. Session Overview

This session establishes the complete project infrastructure required to deploy the n8n workflow automation stack. With Docker Engine and Docker Compose now verified and functional from Session 02, we transition from tooling installation to configuration authoring - the critical bridge between having the capability to run containers and actually running them.

The session focuses on creating production-quality configuration files that embody security best practices: externalized environment variables, securely generated credentials, properly permissioned files, and a validated Docker Compose definition. Every file created here will be used directly in Session 04's deployment, making accuracy and completeness essential.

This is a configuration-heavy session with no runtime deployment. The goal is to have a complete, validated, deployment-ready configuration that can be brought up with a single `docker compose up -d` command in Session 04. The emphasis is on getting the configuration right the first time - secure credentials, correct service definitions, proper volume mappings, and validated syntax.

---

## 2. Objectives

1. **Create project directory structure** with proper permissions for config, data, backups, and scripts directories
2. **Generate secure credentials** including a cryptographically-strong n8n encryption key and PostgreSQL password
3. **Author complete configuration files** including .env, docker-compose.yml, and postgres-init.sql with all required settings
4. **Validate configuration integrity** by running `docker compose config` to ensure the stack is syntactically correct and deployment-ready

---

## 3. Prerequisites

### Required Sessions
- [x] `phase00-session01-wsl2-environment-optimization` - WSL2 configured with 8GB RAM, 4 CPU cores
- [x] `phase00-session02-docker-engine-installation` - Docker Engine 29.1.3 and Compose v5.0.0 installed

### Required Tools/Knowledge
- Docker Compose v2+ YAML syntax understanding
- Linux file permissions (chmod/chown)
- Environment variable patterns for Docker
- PostgreSQL user/database creation

### Environment Requirements
- Working directory: `/home/aiwithapex/n8n/` (Linux filesystem)
- Docker daemon running: `docker info` succeeds
- Docker Compose available: `docker compose version` succeeds
- OpenSSL available for key generation

---

## 4. Scope

### In Scope (MVP)
- Create directory structure: config/, data/postgres/, data/redis/, data/n8n/files/, backups/, scripts/
- Generate 32-byte base64 encryption key using openssl
- Generate secure PostgreSQL password (24+ characters)
- Create .env file with all PostgreSQL, Redis, n8n, and queue mode variables
- Create docker-compose.yml with postgres, redis, n8n, n8n-worker services
- Create config/postgres-init.sql for database initialization
- Set restrictive permissions on .env (600) and directories (755)
- Validate with `docker compose config`

### Out of Scope (Deferred)
- **Container deployment** - *Reason: Session 04 scope*
- **Backup scripts** - *Reason: Phase 01 scope*
- **Monitoring scripts** - *Reason: Phase 01 scope*
- **PostgreSQL tuning** - *Reason: Phase 01 scope*
- **Worker auto-scaling** - *Reason: Phase 01 scope*
- **SSL/TLS configuration** - *Reason: localhost-only, non-goal per PRD*

---

## 5. Technical Approach

### Architecture
The configuration defines a 4-service Docker Compose stack:
```
                    +------------------+
                    |    n8n (main)    |
                    |    Port 5678     |
                    +--------+---------+
                             |
              +--------------+--------------+
              |                             |
    +---------v---------+         +---------v---------+
    |    PostgreSQL     |         |      Redis        |
    |    Port 5432      |         |     Port 6386     |
    +-------------------+         +-------------------+
              ^                             ^
              |                             |
              +-------------+---------------+
                            |
                    +-------v-------+
                    |  n8n-worker   |
                    |  (queue mode) |
                    +---------------+
```

### Design Patterns
- **Environment Externalization**: All secrets and configuration in .env, never in docker-compose.yml
- **Named Volumes**: Persistent data via Docker volumes rather than bind mounts for data directories
- **Health Checks**: Each service defines health check for orchestration
- **Dependency Ordering**: `depends_on` with `condition: service_healthy` for startup sequencing

### Technology Stack
- Docker Compose v2.x (file format version determined by compose version)
- PostgreSQL 16-alpine
- Redis 7-alpine
- n8n latest (Community Edition)
- Bash for scripting/validation

---

## 6. Deliverables

### Files to Create
| File | Purpose | Est. Lines |
|------|---------|------------|
| `config/postgres-init.sql` | PostgreSQL database/user initialization | ~10 |
| `.env` | Environment variables for all services | ~45 |
| `docker-compose.yml` | Complete service definitions | ~120 |

### Directories to Create
| Directory | Purpose | Permissions |
|-----------|---------|-------------|
| `config/` | Configuration files | 755 |
| `data/postgres/` | PostgreSQL data volume mount point | 755 |
| `data/redis/` | Redis data volume mount point | 755 |
| `data/n8n/` | n8n user data | 755 |
| `data/n8n/files/` | Binary file storage | 755 |
| `backups/` | Backup destination (Phase 01) | 755 |
| `scripts/` | Operational scripts (Phase 01) | 755 |

### Files to Modify
| File | Changes | Est. Lines |
|------|---------|------------|
| `.gitignore` | Add .env and data directories | ~10 |

---

## 7. Success Criteria

### Functional Requirements
- [ ] All directories exist with correct permissions (755 for dirs)
- [ ] Encryption key is 32+ bytes, base64-encoded
- [ ] PostgreSQL password is 24+ characters, alphanumeric
- [ ] .env contains all required variables (no placeholders)
- [ ] .env file permissions are 600 (owner read/write only)
- [ ] docker-compose.yml defines all 4 services (postgres, redis, n8n, n8n-worker)
- [ ] Each service has health check defined
- [ ] postgres-init.sql creates n8n user and database
- [ ] `docker compose config` executes without errors or warnings

### Testing Requirements
- [ ] `docker compose config` validates successfully
- [ ] `docker compose config --services` lists: postgres, redis, n8n, n8n-worker
- [ ] Environment variable interpolation works (no unset variable warnings)

### Quality Gates
- [ ] All files ASCII-encoded (no unicode characters)
- [ ] Unix LF line endings (no CRLF)
- [ ] No secrets in docker-compose.yml (all via ${VAR} references)
- [ ] No hardcoded localhost IPs (use service names for inter-container communication)

---

## 8. Implementation Notes

### Key Considerations
- **Service names as hostnames**: Inside Docker network, services reach each other by service name (e.g., `postgres`, `redis`), not localhost
- **Redis port**: Using non-standard 6386 to avoid conflicts if Redis is also installed on host
- **n8n user ID**: n8n container runs as UID 1000 (node user), data directories should be accessible
- **Queue mode**: Requires EXECUTIONS_MODE=queue and Redis connection variables

### Potential Challenges
- **Volume permissions**: Data directories may need ownership adjustment if container can't write
- **Redis connection string**: n8n uses QUEUE_BULL_REDIS_* variables, not standard REDIS_*
- **PostgreSQL init timing**: Init script only runs on first container start with empty data directory

### ASCII Reminder
All output files must use ASCII-only characters (0-127). No smart quotes, em-dashes, or unicode symbols.

---

## 9. Testing Strategy

### Syntax Validation
- `docker compose config` - Full YAML validation and variable interpolation
- `docker compose config --services` - Verify all 4 services defined
- `docker compose config --volumes` - Verify volume definitions

### File Validation
- Verify .env has no empty values: `grep -E '=$' .env` should return nothing
- Verify postgres-init.sql is valid SQL syntax
- Check file permissions: `ls -la .env` shows `-rw-------`

### Manual Verification
- Review generated encryption key length: should be 44 characters (32 bytes base64)
- Review PostgreSQL password complexity
- Confirm no secrets visible in docker-compose.yml

### Edge Cases
- Empty .env file handling (should not exist in valid state)
- Existing data directories (should not overwrite if present)
- Existing .env (should warn before overwrite)

---

## 10. Dependencies

### External Libraries
- OpenSSL (for key generation) - system package
- Docker Compose v2+ - installed in Session 02

### Other Sessions
- **Depends on**: `phase00-session02-docker-engine-installation` (Docker availability)
- **Depended by**: `phase00-session04-service-deployment-and-verification` (requires all config files)

---

## 11. Configuration Reference

### Environment Variables (.env)

```bash
# ===========================================
# PostgreSQL Configuration
# ===========================================
POSTGRES_USER=n8n
POSTGRES_PASSWORD=<24-char-generated>
POSTGRES_DB=n8n
POSTGRES_HOST=postgres
POSTGRES_PORT=5432

# ===========================================
# Redis Configuration
# ===========================================
REDIS_HOST=redis
REDIS_PORT=6386

# ===========================================
# n8n Core Configuration
# ===========================================
N8N_ENCRYPTION_KEY=<32-byte-base64>
N8N_HOST=localhost
N8N_PORT=5678
N8N_PROTOCOL=http
WEBHOOK_URL=http://localhost:5678/
GENERIC_TIMEZONE=America/New_York
N8N_USER_FOLDER=/home/node/.n8n

# ===========================================
# n8n Queue Mode (Required for Workers)
# ===========================================
EXECUTIONS_MODE=queue
QUEUE_BULL_REDIS_HOST=redis
QUEUE_BULL_REDIS_PORT=6386
QUEUE_HEALTH_CHECK_ACTIVE=true

# ===========================================
# n8n Data Management
# ===========================================
EXECUTIONS_DATA_PRUNE=true
EXECUTIONS_DATA_MAX_AGE=168
EXECUTIONS_DATA_PRUNE_MAX_COUNT=50000
N8N_METRICS=true

# ===========================================
# n8n Security (Localhost Development)
# ===========================================
N8N_SECURE_COOKIE=false

# ===========================================
# Database Connection
# ===========================================
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=postgres
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=n8n
DB_POSTGRESDB_USER=n8n
DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
```

### Docker Compose Services Structure

```yaml
services:
  postgres:    # PostgreSQL 16-alpine, health check via pg_isready
  redis:       # Redis 7-alpine, health check via redis-cli ping
  n8n:         # Main instance, depends_on postgres+redis healthy
  n8n-worker:  # Worker instance, depends_on n8n healthy
```

---

## Next Steps

Run `/tasks` to generate the implementation task checklist.
