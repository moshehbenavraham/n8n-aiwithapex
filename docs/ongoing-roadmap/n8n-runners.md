# n8n Task Runners Implementation Plan

## Status: NOT IMPLEMENTED

This guide covers task runner implementation for **both** deployment environments:

| Environment | Config File | Domain | Purpose |
|-------------|-------------|--------|---------|
| **Local (WSL2 Ubuntu)** | `docker-compose.yml` | n8n.aiwithapex.ngrok.dev | Development + local usage |
| **Production (Coolify VPS)** | `docker-compose.coolify.yml` | n8n.aiwithapex.com | Production workloads |

---

## Why Task Runners?

Task runners execute Code node JavaScript/Python in isolated containers:

| Benefit | Description |
|---------|-------------|
| **Security** | User code runs in sandboxed container, can't access n8n internals |
| **Reliability** | Bad code crashes runner, not worker—auto-recovers |
| **Resource Control** | Separate memory/CPU limits for code execution |
| **n8n 2.0+ Default** | Task runners are enabled by default in n8n 2.0+ |

---

## Architecture Overview - CRITICAL UNDERSTANDING

### The Key Insight: Each Worker Needs Its Own Runner

When using queue mode with workers, **each worker runs its own task broker** on port 5679. This means:

- Each worker needs its own runner sidecar
- Runners connect to THEIR worker's broker, not the main instance
- With `OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true`, main doesn't execute Code nodes

### Correct Architecture (Queue Mode + Workers)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           n8n Main Instance                             │
│  ┌─────────────────┐                                                    │
│  │ Webhook Handler │─────► Redis Queue ─────────────────────────────────┤
│  │ (No Code exec)  │                                                    │
│  └─────────────────┘       OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true    │
│                            N8N_RUNNERS_ENABLED=false (no broker needed) │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                              Redis Queue                                  │
└───────────────────────┬───────────────┬───────────────┬───────────────────┘
                        │               │               │
           ┌────────────▼──┐   ┌────────▼────────┐   ┌──▼────────────┐
           │  n8n-worker-1 │   │  n8n-worker-2   │   │  n8n-worker-3 │
           │ ┌───────────┐ │   │ ┌─────────────┐ │   │ ┌───────────┐ │
           │ │Broker:5679│ │   │ │ Broker:5679 │ │   │ │Broker:5679│ │
           │ └─────┬─────┘ │   │ └──────┬──────┘ │   │ └─────┬─────┘ │
           └───────│───────┘   └────────│────────┘   └───────│───────┘
                   │ WS                 │ WS                 │ WS
           ┌───────▼───────┐   ┌────────▼────────┐   ┌───────▼───────┐
           │runner-worker-1│   │ runner-worker-2 │   │runner-worker-3│
           │  n8nio/runners│   │  n8nio/runners  │   │  n8nio/runners│
           └───────────────┘   └─────────────────┘   └───────────────┘
```

### Why NOT a Single Shared Runner?

**WRONG Architecture (what my previous version had):**
```
n8n-main (broker:5679) ◄── single task-runner connects here
n8n-worker-1 (broker:5679) ◄── NO RUNNER - Code nodes FAIL!
n8n-worker-2 (broker:5679) ◄── NO RUNNER - Code nodes FAIL!
n8n-worker-3 (broker:5679) ◄── NO RUNNER - Code nodes FAIL!
```

With `OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true`:
- Main instance **never executes** Code nodes
- Workers pick up jobs from Redis and execute them
- When a worker hits a Code node, IT needs a runner connected to ITS broker

---

## Component Summary

| Component | Purpose | Port | Who Runs It |
|-----------|---------|------|-------------|
| **Redis** | Queue mode job distribution | 6379/6386 | Separate container |
| **Task Broker** | Code node execution coordination | 5679 | Inside each n8n worker |
| **Task Runner** | Executes JS/Python code | 5680 (health) | Sidecar per worker |

### Docker Image

| Wrong | Correct |
|-------|---------|
| `n8nio/n8n-task-runners:latest` | **`n8nio/runners`** |

**Version Matching:** The runners image version should match your n8n version.

---

## Environment Comparison

| Setting | Local (WSL2) | Production (Coolify) |
|---------|--------------|----------------------|
| Workers | 3 replicas (single service) | 3 named services |
| Runners needed | Complex (see below) | 3 (one per worker) |
| Main instance broker | Not needed | Not needed |
| n8n Image | `n8nio/n8n:2.1.4` | `ghcr.io/moshehbenavraham/n8n:latest` |

---

# PART 1: LOCAL (WSL2 Ubuntu) Implementation

## Challenge: Replicated Workers

Your local setup uses `deploy: replicas: 3` which creates anonymous worker instances. This is problematic for task runners because:

1. Each replica gets a random container name/IP
2. You can't easily create stable runner-to-worker connections
3. Docker Compose replicas don't get predictable hostnames

### Option A: Use Internal Mode (Simpler for Development)

For local development, internal mode is acceptable:

```yaml
# In .env - simpler for local dev
N8N_RUNNERS_ENABLED=true
N8N_RUNNERS_MODE=internal  # Runs runner as child process
```

**Pros:** No sidecar containers needed, simpler setup
**Cons:** Less isolation, shares memory with worker

### Option B: Convert to Named Workers (Mirrors Production)

For testing production-like setup locally, convert replicas to named services.

## Step 1.1: Generate Auth Token

```bash
# Generate secure token
openssl rand -hex 32
# Save this - needed for all services
```

## Step 1.2: Add to .env

```bash
# ===========================================
# Task Runner Configuration (n8n 2.0+)
# ===========================================
N8N_RUNNERS_ENABLED=true
N8N_RUNNERS_MODE=external
N8N_RUNNERS_AUTH_TOKEN=<paste-your-generated-token>
N8N_RUNNERS_BROKER_LISTEN_ADDRESS=0.0.0.0
N8N_RUNNERS_MAX_CONCURRENCY=5
N8N_RUNNERS_TASK_TIMEOUT=300
```

## Step 1.3: Update docker-compose.yml

### Option A: Internal Mode (Simple)

Just add to workers:

```yaml
  n8n-worker:
    # ... existing config ...
    environment:
      # ... existing vars ...
      # Task Runners - Internal Mode (no sidecar needed)
      N8N_RUNNERS_ENABLED: "true"
      N8N_RUNNERS_MODE: internal
```

No additional services needed.

### Option B: Named Workers with External Runners

Replace the replicated worker service with named workers:

```yaml
  # REMOVE this block:
  # n8n-worker:
  #   deploy:
  #     replicas: 3

  # ===========================================
  # n8n Worker 1
  # ===========================================
  n8n-worker-1:
    image: ${N8N_IMAGE:-n8nio/n8n:2.1.4}
    container_name: n8n-worker-1
    restart: unless-stopped
    command: worker
    logging:
      driver: json-file
      options:
        max-size: "100m"
        max-file: "5"
    environment:
      # Database
      DB_TYPE: ${DB_TYPE}
      DB_POSTGRESDB_HOST: ${DB_POSTGRESDB_HOST}
      DB_POSTGRESDB_PORT: ${DB_POSTGRESDB_PORT}
      DB_POSTGRESDB_DATABASE: ${DB_POSTGRESDB_DATABASE}
      DB_POSTGRESDB_USER: ${DB_POSTGRESDB_USER}
      DB_POSTGRESDB_PASSWORD: ${DB_POSTGRESDB_PASSWORD}
      # Core
      N8N_ENCRYPTION_KEY: ${N8N_ENCRYPTION_KEY}
      GENERIC_TIMEZONE: ${GENERIC_TIMEZONE}
      N8N_USER_FOLDER: ${N8N_USER_FOLDER}
      # Queue mode
      EXECUTIONS_MODE: ${EXECUTIONS_MODE}
      QUEUE_BULL_REDIS_HOST: ${QUEUE_BULL_REDIS_HOST}
      QUEUE_BULL_REDIS_PORT: ${QUEUE_BULL_REDIS_PORT}
      QUEUE_HEALTH_CHECK_ACTIVE: ${QUEUE_HEALTH_CHECK_ACTIVE}
      EXECUTIONS_CONCURRENCY: ${EXECUTIONS_CONCURRENCY}
      # Task Runners - External Mode
      N8N_RUNNERS_ENABLED: "true"
      N8N_RUNNERS_MODE: external
      N8N_RUNNERS_AUTH_TOKEN: ${N8N_RUNNERS_AUTH_TOKEN}
      N8N_RUNNERS_BROKER_LISTEN_ADDRESS: "0.0.0.0"
      # Logging
      N8N_LOG_LEVEL: ${N8N_LOG_LEVEL:-info}
    volumes:
      - n8n_data:/home/node/.n8n
      - ./data/n8n/files:/home/node/.n8n/files
    depends_on:
      n8n:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "pgrep -x node || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    deploy:
      resources:
        limits:
          memory: 512M
    networks:
      - n8n-network
      - ollama-network

  # Repeat for n8n-worker-2 and n8n-worker-3 (copy above, change names)

  # ===========================================
  # Task Runner for Worker 1
  # ===========================================
  runner-worker-1:
    image: n8nio/runners:latest
    container_name: n8n-runner-worker-1
    restart: unless-stopped
    environment:
      N8N_RUNNERS_AUTH_TOKEN: ${N8N_RUNNERS_AUTH_TOKEN}
      N8N_RUNNERS_TASK_BROKER_URI: http://n8n-worker-1:5679
      N8N_RUNNERS_MAX_CONCURRENCY: ${N8N_RUNNERS_MAX_CONCURRENCY:-5}
      N8N_RUNNERS_AUTO_SHUTDOWN_TIMEOUT: 15
      N8N_RUNNERS_LAUNCHER_LOG_LEVEL: ${N8N_LOG_LEVEL:-info}
    depends_on:
      n8n-worker-1:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "wget --spider -q http://localhost:5680/healthz || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    deploy:
      resources:
        limits:
          memory: 512M
    networks:
      - n8n-network
      - ollama-network

  # ===========================================
  # Task Runner for Worker 2
  # ===========================================
  runner-worker-2:
    image: n8nio/runners:latest
    container_name: n8n-runner-worker-2
    restart: unless-stopped
    environment:
      N8N_RUNNERS_AUTH_TOKEN: ${N8N_RUNNERS_AUTH_TOKEN}
      N8N_RUNNERS_TASK_BROKER_URI: http://n8n-worker-2:5679
      N8N_RUNNERS_MAX_CONCURRENCY: ${N8N_RUNNERS_MAX_CONCURRENCY:-5}
      N8N_RUNNERS_AUTO_SHUTDOWN_TIMEOUT: 15
      N8N_RUNNERS_LAUNCHER_LOG_LEVEL: ${N8N_LOG_LEVEL:-info}
    depends_on:
      n8n-worker-2:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "wget --spider -q http://localhost:5680/healthz || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    deploy:
      resources:
        limits:
          memory: 512M
    networks:
      - n8n-network
      - ollama-network

  # ===========================================
  # Task Runner for Worker 3
  # ===========================================
  runner-worker-3:
    image: n8nio/runners:latest
    container_name: n8n-runner-worker-3
    restart: unless-stopped
    environment:
      N8N_RUNNERS_AUTH_TOKEN: ${N8N_RUNNERS_AUTH_TOKEN}
      N8N_RUNNERS_TASK_BROKER_URI: http://n8n-worker-3:5679
      N8N_RUNNERS_MAX_CONCURRENCY: ${N8N_RUNNERS_MAX_CONCURRENCY:-5}
      N8N_RUNNERS_AUTO_SHUTDOWN_TIMEOUT: 15
      N8N_RUNNERS_LAUNCHER_LOG_LEVEL: ${N8N_LOG_LEVEL:-info}
    depends_on:
      n8n-worker-3:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "wget --spider -q http://localhost:5680/healthz || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    deploy:
      resources:
        limits:
          memory: 512M
    networks:
      - n8n-network
      - ollama-network
```

### Update n8n Main Service

Since workers handle all executions with `OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true`:

```yaml
  n8n:
    # ... existing config ...
    environment:
      # ... existing vars ...
      # Main instance does NOT need runners (offloads to workers)
      # N8N_RUNNERS_ENABLED is NOT set (defaults to false)
      OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS: "true"
```

## Step 1.4: Deploy Locally

```bash
cd /home/aiwithapex/n8n

docker compose down
docker compose pull
docker compose up -d
docker compose ps
```

---

# PART 2: PRODUCTION (Coolify VPS Hostinger) Implementation

Production already uses named workers, making the runner setup straightforward.

### Coolify Auto-Injection Note

The existing `docker-compose.coolify.yml` does NOT have explicit:
- `networks:` configuration
- Coolify labels
- `container_name:` specifications
- `env_file:` references

This is intentional — **Coolify auto-injects these** when deploying. New runner services follow the same pattern as existing workers. If network issues occur, see the Troubleshooting section.

## Step 2.1: Generate Auth Token

```bash
openssl rand -hex 32
# Add to Coolify UI environment variables
```

## Step 2.2: Add Environment Variables in Coolify UI

```bash
N8N_RUNNERS_AUTH_TOKEN=<paste-your-generated-token>
```

## Step 2.3: Update docker-compose.coolify.yml

### Update n8n Main Service

**REMOVE runner configuration from main** (it doesn't execute Code nodes):

```yaml
  n8n:
    # ... existing config ...
    environment:
      # ... existing vars ...
      # Main does NOT need runners - executions offloaded to workers
      # DO NOT add N8N_RUNNERS_ENABLED=true here
      - OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true
```

### Update ALL Three Worker Services

Add to **n8n-worker-1**, **n8n-worker-2**, AND **n8n-worker-3**:

```yaml
      # Task Runners - Workers run brokers
      - N8N_RUNNERS_ENABLED=true
      - N8N_RUNNERS_MODE=external
      - N8N_RUNNERS_AUTH_TOKEN=${N8N_RUNNERS_AUTH_TOKEN}
      - N8N_RUNNERS_BROKER_LISTEN_ADDRESS=0.0.0.0
      - N8N_RUNNERS_MAX_CONCURRENCY=10
      - N8N_RUNNERS_TASK_TIMEOUT=600
```

### Add THREE Task Runner Services (One Per Worker)

Add these after `n8n-worker-3`:

```yaml
  # ===========================================
  # Task Runner for Worker 1
  # ===========================================
  runner-worker-1:
    image: n8nio/runners:latest
    restart: unless-stopped
    environment:
      - N8N_RUNNERS_AUTH_TOKEN=${N8N_RUNNERS_AUTH_TOKEN}
      - N8N_RUNNERS_TASK_BROKER_URI=http://n8n-worker-1:5679
      - N8N_RUNNERS_MAX_CONCURRENCY=10
      - N8N_RUNNERS_AUTO_SHUTDOWN_TIMEOUT=15
      - N8N_RUNNERS_LAUNCHER_LOG_LEVEL=${N8N_LOG_LEVEL:-info}
    depends_on:
      n8n-worker-1:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "wget --spider -q http://localhost:5680/healthz || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'

  # ===========================================
  # Task Runner for Worker 2
  # ===========================================
  runner-worker-2:
    image: n8nio/runners:latest
    restart: unless-stopped
    environment:
      - N8N_RUNNERS_AUTH_TOKEN=${N8N_RUNNERS_AUTH_TOKEN}
      - N8N_RUNNERS_TASK_BROKER_URI=http://n8n-worker-2:5679
      - N8N_RUNNERS_MAX_CONCURRENCY=10
      - N8N_RUNNERS_AUTO_SHUTDOWN_TIMEOUT=15
      - N8N_RUNNERS_LAUNCHER_LOG_LEVEL=${N8N_LOG_LEVEL:-info}
    depends_on:
      n8n-worker-2:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "wget --spider -q http://localhost:5680/healthz || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'

  # ===========================================
  # Task Runner for Worker 3
  # ===========================================
  runner-worker-3:
    image: n8nio/runners:latest
    restart: unless-stopped
    environment:
      - N8N_RUNNERS_AUTH_TOKEN=${N8N_RUNNERS_AUTH_TOKEN}
      - N8N_RUNNERS_TASK_BROKER_URI=http://n8n-worker-3:5679
      - N8N_RUNNERS_MAX_CONCURRENCY=10
      - N8N_RUNNERS_AUTO_SHUTDOWN_TIMEOUT=15
      - N8N_RUNNERS_LAUNCHER_LOG_LEVEL=${N8N_LOG_LEVEL:-info}
    depends_on:
      n8n-worker-3:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "wget --spider -q http://localhost:5680/healthz || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'
```

## Step 2.4: Deploy to Production

```bash
git add docker-compose.coolify.yml
git commit -m "Add per-worker task runners for Code node isolation"
git push origin main
```

## Step 2.5: Verify Production Installation

```bash
ssh user@your-hostinger-vps

# Should see 6 runner-related containers (3 workers + 3 runners)
docker ps | grep -E "worker|runner"

# Check each runner is connected to its worker
docker logs <runner-worker-1-container-id> 2>&1 | grep -i "connect"
docker logs <runner-worker-2-container-id> 2>&1 | grep -i "connect"
docker logs <runner-worker-3-container-id> 2>&1 | grep -i "connect"
```

---

# Environment Variables Reference

## n8n Main Instance (With OFFLOAD=true)

| Variable | Value | Description |
|----------|-------|-------------|
| `OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS` | `true` | Main doesn't execute workflows |
| `N8N_RUNNERS_ENABLED` | **omit or false** | Main doesn't need a broker |

## n8n Workers (Each One)

| Variable | Value | Description |
|----------|-------|-------------|
| `N8N_RUNNERS_ENABLED` | `true` | Worker runs a broker |
| `N8N_RUNNERS_MODE` | `external` | Use sidecar runners |
| `N8N_RUNNERS_AUTH_TOKEN` | secret | Shared with runner |
| `N8N_RUNNERS_BROKER_LISTEN_ADDRESS` | `0.0.0.0` | Allow runner connections |

## Runner Containers (One Per Worker)

| Variable | Value | Description |
|----------|-------|-------------|
| `N8N_RUNNERS_AUTH_TOKEN` | secret | Must match worker |
| `N8N_RUNNERS_TASK_BROKER_URI` | `http://n8n-worker-X:5679` | Connect to **its** worker |
| `N8N_RUNNERS_MAX_CONCURRENCY` | `10` | Parallel tasks |
| `N8N_RUNNERS_AUTO_SHUTDOWN_TIMEOUT` | `15` | Idle shutdown (seconds) |

---

# Resource Impact

## Production (Coolify) - CORRECTED

| Service | Before | After |
|---------|--------|-------|
| n8n main | 1G | 1G (no change) |
| postgres | 1G | 1G |
| redis | 384M | 384M |
| workers (3x) | 512M each | 512M each |
| **runners (3x)** | — | **+512M each = 1.5G** |
| **Total** | ~4.4G | **~5.9G** |

---

# Verification Checklist

## Production (Coolify)

- [ ] Auth token generated and added to Coolify UI
- [ ] Main instance does NOT have `N8N_RUNNERS_ENABLED=true`
- [ ] Main instance has `OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true`
- [ ] Each worker (1, 2, 3) has runner env vars with `N8N_RUNNERS_BROKER_LISTEN_ADDRESS=0.0.0.0`
- [ ] Three runner services added (runner-worker-1, -2, -3)
- [ ] Each runner connects to its worker: `http://n8n-worker-X:5679`
- [ ] All 6 containers healthy (3 workers + 3 runners)
- [ ] Code node execution works

---

# Common Mistakes

## Mistake 1: Single Runner for All Workers

**WRONG:**
```yaml
task-runner:
  N8N_RUNNERS_TASK_BROKER_URI: http://n8n:5679  # Main doesn't execute Code!
```

**CORRECT:**
```yaml
runner-worker-1:
  N8N_RUNNERS_TASK_BROKER_URI: http://n8n-worker-1:5679
runner-worker-2:
  N8N_RUNNERS_TASK_BROKER_URI: http://n8n-worker-2:5679
runner-worker-3:
  N8N_RUNNERS_TASK_BROKER_URI: http://n8n-worker-3:5679
```

## Mistake 2: Enabling Runners on Main

**WRONG:**
```yaml
n8n:
  environment:
    - N8N_RUNNERS_ENABLED=true  # Unnecessary with OFFLOAD=true
```

**CORRECT:**
```yaml
n8n:
  environment:
    - OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true
    # N8N_RUNNERS_ENABLED not set
```

## Mistake 3: Wrong Broker URI Format

**WRONG:**
```yaml
N8N_RUNNERS_TASK_BROKER_URI: redis://redis:6379  # Redis is for queue, not broker!
```

**CORRECT:**
```yaml
N8N_RUNNERS_TASK_BROKER_URI: http://n8n-worker-1:5679  # HTTP to worker's broker
```

---

# Rollback Plan

```bash
# On each worker, switch to internal mode (no sidecars needed):
N8N_RUNNERS_MODE=internal

# Or disable runners entirely:
N8N_RUNNERS_ENABLED=false

# Remove runner services from docker-compose
# Redeploy
```

---

# Troubleshooting

## Runner Can't Connect to Worker

**Symptom:** Runner logs show connection refused

**Check:**
1. Worker has `N8N_RUNNERS_BROKER_LISTEN_ADDRESS=0.0.0.0`
2. Runner URI matches worker service name: `http://n8n-worker-X:5679`
3. Runner depends on worker health

## Code Node Hangs/Fails

**Symptom:** Code nodes timeout or error

**Check:**
1. Verify runner is connected to its worker (not main)
2. Check runner logs for errors
3. Ensure `N8N_RUNNERS_ENABLED=true` on workers (not main)

## Main Instance Starts Broker Anyway

**Known Issue:** Even with `N8N_RUNNERS_ENABLED=false`, main may start broker.
This is a bug (see [GitHub #23313](https://github.com/n8n-io/n8n/issues/23313)).

**Workaround:** This doesn't affect functionality if workers have their own runners.

## Coolify Network Issues (Runner Can't Reach Worker)

**Symptom:** Runner logs show "connection refused" or DNS resolution failure

**Cause:** Coolify auto-injects network configuration, but sometimes new services may not be properly added to the same network as existing services.

**Fix:** Add explicit network configuration to runner services. First, find the network ID from your deployed containers:

```bash
# SSH to VPS, find the Coolify-generated network
docker network ls | grep n8n
# Example output: s0sw00s8swwk4w88kgkkgg0k

# Or inspect an existing worker
docker inspect n8n-worker-1 | grep -A5 Networks
```

Then add to each runner service in `docker-compose.coolify.yml`:

```yaml
  runner-worker-1:
    image: n8nio/runners:latest
    # ... existing config ...
    networks:
      <coolify-network-id>: null  # Replace with actual network ID
```

**Alternative Fix:** If Coolify allows, you can define an explicit network at the bottom of your compose file:

```yaml
networks:
  default:
    name: n8n-runners-network
    driver: bridge
```

And ensure all services (workers and runners) are on this network.

## Coolify Labels (Why We Don't Add Them)

Per [Coolify documentation](https://coolify.io/docs/knowledge-base/docker/compose), Coolify **auto-injects** these labels if not present:
- `coolify.managed=true`
- `coolify.applicationId=<generated>`
- `coolify.type=application`

**Why we avoid proactive labels:**

| Reason | Explanation |
|--------|-------------|
| **Auto-injection** | Coolify adds them automatically |
| **Dynamic IDs** | `applicationId`, `serviceId` are generated per deployment—hardcoding breaks portability |
| **Known bugs** | [GitHub #1737](https://github.com/coollabsio/coolify/issues/1737) reports custom labels issues in compose |
| **Consistency** | Existing services in `docker-compose.coolify.yml` have no labels |

**When you WOULD add labels:**
Only for Traefik proxy (external access), which runners don't need:

```yaml
labels:
  - traefik.enable=true
  - "traefik.http.routers.myservice.rule=Host(`mydomain.com`)"
```

**If runners aren't showing in Coolify UI** (rare), you can try adding only the basic label:

```yaml
  runner-worker-1:
    labels:
      - coolify.managed=true
```

But this is typically not needed.

---

# References

- [n8n Task Runners Documentation](https://docs.n8n.io/hosting/configuration/task-runners/)
- [Task Runner Environment Variables](https://docs.n8n.io/hosting/configuration/environment-variables/task-runners/)
- [n8n v2.0 Breaking Changes](https://docs.n8n.io/2-0-breaking-changes/)
- [Docker Hub: n8nio/runners](https://hub.docker.com/r/n8nio/runners)
- [Queue Mode Configuration](https://docs.n8n.io/hosting/scaling/queue-mode/)
- [n8n-autoscaling (reference implementation)](https://github.com/conor-is-my-name/n8n-autoscaling)
- [GitHub Issue #23313 - Broker starting unexpectedly](https://github.com/n8n-io/n8n/issues/23313)
