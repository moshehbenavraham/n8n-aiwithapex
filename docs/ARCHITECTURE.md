# Architecture

## System Overview

n8n workflow automation platform running in queue mode with distributed execution.

## Dependency Graph

```
                    http://localhost:5678
                            |
                            v
+------------------+   +---------+   +-------------+
|   PostgreSQL     |<--|  n8n    |-->|   Redis     |
|   (n8n-postgres) |   | (main)  |   | (n8n-redis) |
|   Port: 5432     |   +---------+   |  Port: 6386 |
+------------------+        |        +------+------+
        ^                   |               |
        |                   v               v
        |           +---------------+       |
        +-----------|  n8n-worker   |<------+
                    | (queue jobs)  |
                    +---------------+
```

## Components

### n8n-main
- **Purpose**: UI, webhooks, API, triggers, workflow management
- **Tech**: n8n Community Edition
- **Location**: Container `n8n-main`
- **Port**: 5678 (exposed)

### n8n-worker
- **Purpose**: Execute queued workflow jobs
- **Tech**: n8n worker mode
- **Location**: Container `n8n-worker`
- **Concurrency**: 10 jobs per worker

### PostgreSQL
- **Purpose**: Persistent storage for workflows, credentials, executions
- **Tech**: PostgreSQL 16-alpine
- **Location**: Container `n8n-postgres`
- **Volume**: `n8n_postgres_data`

### Redis
- **Purpose**: Message broker for queue mode
- **Tech**: Redis 7-alpine
- **Location**: Container `n8n-redis`
- **Volume**: `n8n_redis_data`

## Tech Stack Rationale

| Technology | Purpose | Why Chosen |
|------------|---------|------------|
| Docker Compose | Orchestration | Single-file stack definition, easy scaling |
| PostgreSQL | Database | 10x faster than SQLite under load |
| Redis | Queue broker | Required for queue mode with workers |
| WSL2 | Runtime | Native Linux performance, Windows integration |

## Data Flow

1. **Webhook/Trigger** arrives at n8n-main (port 5678)
2. **Job created** and pushed to Redis queue
3. **Worker polls** Redis, picks up job
4. **Worker executes** workflow, reads/writes PostgreSQL
5. **Result stored** in PostgreSQL, status updated

## Network

- **Network**: `n8n-network` (bridge driver)
- **Internal DNS**: Services communicate via container names
- **External**: Only n8n-main exposes port 5678 to host

## Volumes

| Volume | Purpose | Persistence |
|--------|---------|-------------|
| `n8n_postgres_data` | Database files | Critical |
| `n8n_redis_data` | Queue persistence | Important |
| `n8n_n8n_data` | n8n application data | Critical |

## Key Decisions

1. **Queue mode over regular mode**: Separates UI from execution, enables scaling
2. **Named volumes over bind mounts**: Better portability, Docker-managed
3. **Non-standard Redis port (6386)**: Avoids conflicts with other instances
4. **Health checks on all services**: Enables proper startup sequencing
