# Architecture

## Deployment Forms

This project supports two deployment forms with identical core architecture:

| Deployment | Status | External Access | Documentation |
|------------|--------|-----------------|---------------|
| **WSL2 (Local)** | Operational | ngrok tunnel + OAuth | [Installation Plan](n8n-installation-plan.md) |
| **Coolify (Cloud)** | Planning | Traefik + Let's Encrypt | [Deploy to Coolify](ongoing-roadmap/deploy-to-coolify.md) |

See [Deployment Comparison](deployment-comparison.md) for detailed differences.

---

## System Overview

n8n workflow automation platform running in queue mode with distributed execution.

## Architecture Diagrams

### WSL2 Local Deployment

```
                   Internet (webhooks, external users)
                                |
                                v
                 https://your.ngrok.domain
                        (ngrok Edge + OAuth)
                                |
                                v
+-------------+   http://localhost:5678   +-------------+
|   ngrok     |----------+                |             |
| (n8n-ngrok) |          |                |             |
|  Port: 4040 |          v                |             |
+-------------+     +---------+           |             |
                    |  n8n    |---------->|   Redis     |
+------------------+| (main)  |           | (n8n-redis) |
|   PostgreSQL     ||         |           |  Port: 6386 |
|   (n8n-postgres) |+---------+           +------+------+
|   Port: 5432     |     |                       |
+--------^---------+     |                       |
         |               v                       v
         |        +---------------+              |
         +--------|  n8n-worker   |<-------------+
                  | (queue jobs)  |
                  +---------------+
```

### Coolify Cloud Deployment

```
                    Internet
                        │
                        ▼
              ┌─────────────────┐
              │   Traefik       │ (Coolify-managed)
              │   (HTTPS/TLS)   │
              └────────┬────────┘
                       │
         ┌─────────────┼─────────────┐
         │             │             │
         ▼             ▼             ▼
    ┌─────────┐  ┌──────────┐  ┌──────────┐
    │ n8n-ui  │  │ Webhooks │  │ Metrics  │
    │ :5678   │  │ /webhook │  │ /metrics │
    └────┬────┘  └────┬─────┘  └────┬─────┘
         │            │             │
         └────────────┼─────────────┘
                      │
              ┌───────┴───────┐
              │   n8n-main    │
              │   (Queue)     │
              └───────┬───────┘
                      │
        ┌─────────────┼─────────────┐
        │             │             │
        ▼             ▼             ▼
  ┌──────────┐  ┌──────────┐  ┌──────────┐
  │ Worker 1 │  │ Worker 2 │  │ Worker N │
  │          │  │          │  │  (1-10)  │
  └────┬─────┘  └────┬─────┘  └────┬─────┘
       │             │             │
       └─────────────┼─────────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
         ▼                       ▼
   ┌──────────┐           ┌──────────┐
   │ PostgreSQL│           │  Redis   │
   │  (Data)  │           │ (Queue)  │
   └──────────┘           └──────────┘
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

### ngrok
- **Purpose**: Secure tunnel for external webhook access with OAuth
- **Tech**: ngrok Docker image (v3 config)
- **Location**: Container `n8n-ngrok`
- **Port**: 4040 (web inspector)
- **External URL**: https://your.ngrok.domain

## Tech Stack Rationale

### Core Stack (Both Deployments)

| Technology | Purpose | Why Chosen |
|------------|---------|------------|
| Docker Compose | Orchestration | Single-file stack definition, easy scaling |
| PostgreSQL | Database | 10x faster than SQLite under load |
| Redis | Queue broker | Required for queue mode with workers |

### WSL2 Specific

| Technology | Purpose | Why Chosen |
|------------|---------|------------|
| ngrok | Tunnel | Secure external access with custom domain and OAuth |
| WSL2 | Runtime | Native Linux performance, Windows integration |

### Coolify Specific

| Technology | Purpose | Why Chosen |
|------------|---------|------------|
| Traefik | Reverse proxy | Coolify-managed, automatic SSL via Let's Encrypt |
| Coolify | Orchestration | Simplified deployment, built-in CI/CD |

## Data Flow

### External Webhooks (via ngrok)
1. **External request** arrives at ngrok edge (https://your.ngrok.domain)
2. **Traffic policy** evaluates: webhooks pass through, UI paths require OAuth
3. **ngrok forwards** to n8n-main (http://n8n:5678)
4. **Job created** and pushed to Redis queue
5. **Worker executes** and stores result in PostgreSQL

### Local Access
1. **Webhook/Trigger** arrives at n8n-main (port 5678)
2. **Job created** and pushed to Redis queue
3. **Worker polls** Redis, picks up job
4. **Worker executes** workflow, reads/writes PostgreSQL
5. **Result stored** in PostgreSQL, status updated

## Network

- **Network**: `n8n-network` (bridge driver)
- **Internal DNS**: Services communicate via container names
- **External (local)**: n8n-main exposes port 5678 to host
- **External (internet)**: ngrok exposes n8n via https://your.ngrok.domain
- **ngrok inspector**: Port 4040 exposed to host for debugging

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
5. **ngrok as Docker sidecar**: Integrated with stack, managed via docker compose
6. **OAuth at ngrok edge**: Defense in depth, webhooks bypass authentication
