# Deploy n8n Stack to Coolify

> **Status**: Planning
> **Date**: 2025-12-28
> **Target**: Replace one-click n8n service with full production stack

> **Custom Fork Optimized**: This deployment infrastructure is designed and optimized to run with our custom n8n fork at [github.com/moshehbenavraham/n8n](https://github.com/moshehbenavraham/n8n). The Coolify deployment supports both the official n8n image and the custom fork image via environment variable configuration.

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Current State Analysis](#current-state-analysis)
3. [Target Architecture](#target-architecture)
4. [Pre-Deployment Checklist](#pre-deployment-checklist)
5. [Coolify-Compatible Docker Compose](#coolify-compatible-docker-compose)
6. [Environment Variables](#environment-variables)
7. [Deployment Steps](#deployment-steps)
8. [Data Migration Strategy](#data-migration-strategy)
9. [Post-Deployment Validation](#post-deployment-validation)
10. [Rollback Plan](#rollback-plan)
11. [Monitoring & Maintenance](#monitoring--maintenance)

---

## Executive Summary

### Goal

Replace the existing Coolify one-click n8n service with a full production-grade stack that includes:
- Redis for queue-based execution
- Multiple workers for parallel processing
- Custom PostgreSQL tuning
- Proper health checks and logging

### Current vs Target

| Feature | Current (Coolify) | Target |
|---------|-------------------|--------|
| n8n Version | `latest` (floating) | `2.1.4` (pinned) |
| Execution Mode | Single instance | Queue mode + 3 workers |
| Database | postgres:16-alpine | postgres:16.11-alpine (tuned) |
| Redis | None | redis:7.4.7-alpine |
| Parallel Capacity | 1 | 30 (3 workers × 10 concurrency) |
| Auto-scaling | No | Manual scaling (add workers to compose) |
| Metrics | No | Prometheus endpoint |
| Privacy | Default (telemetry on) | Telemetry disabled |
| Domain | n8n.aiwithapex.com | n8n-apex.aiwithapex.com (new) |

---

## Current State Analysis

### Existing Coolify n8n Service

**Service UUID**: `g8wow80sgg8oo0csg4sgkws0`
**Status**: `running:healthy`
**Domain**: `https://n8n.aiwithapex.com`

**Current Docker Compose** (from Coolify):
```yaml
services:
  n8n:
    image: docker.n8n.io/n8nio/n8n
    environment:
      - N8N_EDITOR_BASE_URL=${SERVICE_FQDN_N8N}
      - WEBHOOK_URL=${SERVICE_FQDN_N8N}
      - N8N_HOST=${SERVICE_URL_N8N}
      - GENERIC_TIMEZONE=Europe/Berlin
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_DATABASE=${POSTGRES_DB:-n8n}
      - DB_POSTGRESDB_HOST=postgresql
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_USER=$SERVICE_USER_POSTGRES
      - DB_POSTGRESDB_PASSWORD=$SERVICE_PASSWORD_POSTGRES
    volumes:
      - n8n-data:/home/node/.n8n
    depends_on:
      postgresql:
        condition: service_healthy
  postgresql:
    image: postgres:16-alpine
    volumes:
      - postgresql-data:/var/lib/postgresql/data
    environment:
      - POSTGRES_USER=$SERVICE_USER_POSTGRES
      - POSTGRES_PASSWORD=$SERVICE_PASSWORD_POSTGRES
      - POSTGRES_DB=${POSTGRES_DB:-n8n}
```

**Key Limitations**:
- No Redis = no queue mode
- No workers = single execution thread
- No version pinning = potential breaking changes
- No metrics = no observability
- No custom PostgreSQL tuning

### Coolify Infrastructure

| Resource | UUID | Notes |
|----------|------|-------|
| Server | `rcgk0og40w0kwogock4k44s0` | localhost (Coolify host) |
| Project | `m4cck40w0go4k88gwcg4k400` | Apex Automations |
| Environment | `sko8scc0c0ok8gcwo0gscw8o` | production |
| Destination | `eswsck00ws0gosc8osk04ksc` | coolify network |
| Proxy | Traefik 3.1.7 | Auto-managed |

---

## Target Architecture

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

---

## Pre-Deployment Checklist

### Phase 1: Preparation

- [ ] **Backup existing n8n data**
  ```bash
  # Export workflows via n8n CLI or API
  curl -X GET "https://n8n.aiwithapex.com/api/v1/workflows" \
    -H "X-N8N-API-KEY: <api-key>" > workflows-backup.json

  # Export credentials (encrypted)
  curl -X GET "https://n8n.aiwithapex.com/api/v1/credentials" \
    -H "X-N8N-API-KEY: <api-key>" > credentials-backup.json
  ```

- [ ] **Extract and verify encryption key** ⚠️ CRITICAL
  ```bash
  # 1. Get the encryption key from Coolify
  # Coolify Dashboard > n8n Service > Environment Variables > N8N_ENCRYPTION_KEY

  # 2. Store securely (do NOT commit to git)
  echo "N8N_ENCRYPTION_KEY=<your-key>" >> ~/.n8n-secrets

  # 3. Verify you have the key before proceeding
  # Without this, all existing credentials become unrecoverable
  ```

- [ ] **Note current webhook URLs**
  - List all active webhooks that external services call
  - Plan URL migration or redirects

- [ ] **Verify DNS access**
  ```bash
  # Ensure you can create the new subdomain
  nslookup n8n-apex.aiwithapex.com
  # Should return NXDOMAIN initially, or your server IP if pre-configured
  ```

- [ ] **Push code to GitHub**
  ```bash
  cd /home/aiwithapex/n8n
  git add -A
  git commit -m "feat: Coolify deployment configuration"
  git push origin main
  ```

### Phase 2: GitHub Repository Setup

- [ ] **Create/verify repository**: `moshehbenavraham/n8n-aiwithapex.git`
- [ ] **Ensure branch**: `main`
- [ ] **Add Coolify-specific files**:
  - `docker-compose.coolify.yml`
  - `.env.coolify.example`

---

## Coolify-Compatible Docker Compose

**Source file**: [`docker-compose.coolify.yml`](../../docker-compose.coolify.yml)

### Architecture Summary

| Service | Image | Memory Limit | Purpose |
|---------|-------|--------------|---------|
| `postgres` | postgres:16.11-alpine | 1GB | Database with tuned settings |
| `redis` | redis:7.4.7-alpine | 384MB | Queue broker with persistence |
| `n8n` | n8nio/n8n:2.1.4 | 1GB | Main instance (UI/webhooks/API) |
| `n8n-worker-1` | n8nio/n8n:2.1.4 | 512MB | Execution worker |
| `n8n-worker-2` | n8nio/n8n:2.1.4 | 512MB | Execution worker |
| `n8n-worker-3` | n8nio/n8n:2.1.4 | 512MB | Execution worker |

**Total Memory**: ~4GB recommended minimum

### Key Configuration Features

- **PostgreSQL tuning**: shared_buffers=256MB, work_mem=16MB, effective_cache_size=512MB
- **Redis production settings**: maxmemory=256mb, noeviction policy, AOF persistence
- **Queue stability**: QUEUE_WORKER_LOCK_DURATION=60000 prevents job loss
- **Privacy**: N8N_DIAGNOSTICS_ENABLED=false, N8N_VERSION_NOTIFICATIONS_ENABLED=false
- **Workers**: Read-only volume mounts, 10 concurrent executions each

### Notes on Coolify Compatibility

1. **SERVICE_FQDN_N8N_5678**: Coolify auto-injects this for Traefik routing
2. **SERVICE_USER_POSTGRES / SERVICE_PASSWORD_POSTGRES**: Coolify auto-generates
3. **No explicit Traefik labels**: Coolify adds them automatically
4. **No explicit network**: Coolify creates one per service
5. **Workers defined individually**: Coolify doesn't support `deploy.replicas` well

---

## Environment Variables

### Required in Coolify UI

| Variable | Value | Notes |
|----------|-------|-------|
| `N8N_ENCRYPTION_KEY` | `<from-current-service>` | Critical: must match existing |
| `POSTGRES_DB` | `n8n` | Database name |
| `N8N_LOG_LEVEL` | `info` | info, warn, error, debug |

### Auto-Generated by Coolify

| Variable | Description |
|----------|-------------|
| `SERVICE_FQDN_N8N` | `https://n8n-apex.aiwithapex.com` |
| `SERVICE_FQDN_N8N_5678` | Port-specific FQDN |
| `SERVICE_URL_N8N` | `n8n-apex.aiwithapex.com` |
| `SERVICE_USER_POSTGRES` | Auto-generated username |
| `SERVICE_PASSWORD_POSTGRES` | Auto-generated password |

---

## Deployment Steps

### Step 1: Create New Application in Coolify

**Via UI:**
1. Go to **Apex Automations** project
2. Click **+ New** → **Application**
3. Select **Docker Compose** build pack
4. Connect to GitHub repository: `moshehbenavraham/n8n-aiwithapex.git`
5. Set branch: `main`
6. Set compose file: `docker-compose.coolify.yml`

**Via API:**
```bash
curl -X POST "https://coolify.aiwithapex.com/api/v1/applications/dockercompose" \
  -H "Authorization: Bearer ${COOLIFY_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "project_uuid": "m4cck40w0go4k88gwcg4k400",
    "server_uuid": "rcgk0og40w0kwogock4k44s0",
    "environment_name": "production",
    "name": "n8n-production",
    "description": "Production n8n with queue mode and workers",
    "instant_deploy": false
  }'
```

### Step 2: Configure Environment Variables

In Coolify UI:
1. Navigate to the new application
2. Go to **Environment Variables**
3. Add:
   ```
   N8N_ENCRYPTION_KEY=<your-existing-key>
   POSTGRES_DB=n8n
   N8N_LOG_LEVEL=info
   ```

### Step 3: Configure Domain

1. Go to application settings
2. Set FQDN: `https://n8n-apex.aiwithapex.com`
3. Enable **Force HTTPS redirect**
4. Enable **GZIP compression**

### Step 4: Deploy

```bash
# Via API
curl -X POST "https://coolify.aiwithapex.com/api/v1/applications/<new-app-uuid>/deploy" \
  -H "Authorization: Bearer ${COOLIFY_API_TOKEN}"
```

Or click **Deploy** in UI.

### Step 5: Verify Deployment

```bash
# Check all containers are healthy
curl -s "https://coolify.aiwithapex.com/api/v1/applications/<uuid>" \
  -H "Authorization: Bearer ${COOLIFY_API_TOKEN}" | jq '.status'

# Check n8n health endpoint
curl -s "https://n8n-apex.aiwithapex.com/healthz"

# Check metrics endpoint
curl -s "https://n8n-apex.aiwithapex.com/metrics" | head -20
```

---

## Data Migration Strategy

### Option A: Fresh Start (Recommended for Testing)

1. Deploy new stack with new domain
2. Manually recreate workflows
3. Reconfigure credentials
4. Update external webhook URLs
5. Decommission old service

### Option B: Database Migration

**Export from old service:**
```bash
# Get old PostgreSQL container
OLD_PG="postgresql-g8wow80sgg8oo0csg4sgkws0"

# Dump database
docker exec $OLD_PG pg_dump -U postgres -d n8n > n8n_backup.sql
```

**Import to new service:**
```bash
# Get new PostgreSQL container (after deployment)
NEW_PG="postgres-<new-uuid>"

# Stop n8n containers first
docker stop n8n-<uuid> n8n-worker-*

# Import
docker exec -i $NEW_PG psql -U postgres -d n8n < n8n_backup.sql

# Restart n8n
docker start n8n-<uuid> n8n-worker-*
```

### Option C: n8n API Export/Import

```bash
# Export all workflows
curl -X GET "https://n8n.aiwithapex.com/api/v1/workflows" \
  -H "X-N8N-API-KEY: <old-api-key>" | \
  jq '.data[]' > workflows.json

# Import to new instance
for workflow in $(cat workflows.json | jq -c '.'); do
  curl -X POST "https://n8n-apex.aiwithapex.com/api/v1/workflows" \
    -H "X-N8N-API-KEY: <new-api-key>" \
    -H "Content-Type: application/json" \
    -d "$workflow"
done
```

---

## Post-Deployment Validation

### Smoke Test Script

Save as `scripts/validate-coolify-deployment.sh`:

```bash
#!/bin/bash
# Comprehensive deployment validation for n8n Coolify stack
# Run after deployment to verify all services are operational

set -e

DOMAIN="${1:-n8n-apex.aiwithapex.com}"
API_KEY="${N8N_API_KEY:-}"
PASS=0
FAIL=0

check() {
    local name="$1"
    local result="$2"
    if [ "$result" = "0" ]; then
        echo "✓ $name"
        ((PASS++))
    else
        echo "✗ $name"
        ((FAIL++))
    fi
}

echo "======================================"
echo "n8n Deployment Validation"
echo "Domain: $DOMAIN"
echo "======================================"

# 1. Health endpoint
echo -e "\n--- Core Services ---"
curl -sf "https://${DOMAIN}/healthz" > /dev/null 2>&1
check "n8n health endpoint" "$?"

# 2. Metrics endpoint (confirms Prometheus is enabled)
METRICS=$(curl -sf "https://${DOMAIN}/metrics" 2>/dev/null | grep -c "n8n_" || echo "0")
[ "$METRICS" -gt 0 ]
check "Prometheus metrics ($METRICS entries)" "$?"

# 3. UI is accessible
curl -sf "https://${DOMAIN}/signin" > /dev/null 2>&1
check "Web UI accessible" "$?"

# 4. Check workers via queue metrics
echo -e "\n--- Queue & Workers ---"
WORKERS=$(curl -sf "https://${DOMAIN}/metrics" 2>/dev/null | grep -c "n8n_queue_" || echo "0")
[ "$WORKERS" -gt 0 ]
check "Queue metrics present" "$?"

# 5. Webhook endpoint (returns 404 for non-existent webhook, but endpoint is up)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://${DOMAIN}/webhook/test-nonexistent")
[ "$HTTP_CODE" = "404" ] || [ "$HTTP_CODE" = "200" ]
check "Webhook endpoint responding (HTTP $HTTP_CODE)" "$?"

# 6. API health (if API key provided)
if [ -n "$API_KEY" ]; then
    echo -e "\n--- API Validation ---"
    API_RESP=$(curl -sf "https://${DOMAIN}/api/v1/workflows" \
        -H "X-N8N-API-KEY: $API_KEY" 2>/dev/null)
    [ -n "$API_RESP" ]
    check "API authentication working" "$?"
fi

# Summary
echo -e "\n======================================"
echo "Results: $PASS passed, $FAIL failed"
echo "======================================"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

### Quick Validation Commands

```bash
# Check all containers are healthy
docker ps --filter "name=n8n" --format "table {{.Names}}\t{{.Status}}"

# Check PostgreSQL connections
docker exec postgres-<uuid> psql -U n8n -c "SELECT count(*) FROM pg_stat_activity;"

# Check Redis queue depth
docker exec redis-<uuid> redis-cli LLEN bull:n8n:queue:waiting

# Check worker job processing
docker logs --tail 20 n8n-worker-1-<uuid> | grep -i "job"
```

### Functional Test Checklist

- [ ] Login to `https://n8n-apex.aiwithapex.com` with existing credentials
- [ ] Verify existing workflows are visible (if migrated)
- [ ] Verify existing credentials decrypt successfully (tests encryption key)
- [ ] Create test workflow: Manual Trigger → Set Node → Respond to Webhook
- [ ] Execute workflow and verify it runs on a worker (check worker logs)
- [ ] Test webhook: Create webhook trigger, call it externally
- [ ] Verify `/metrics` endpoint shows execution counts

---

## Rollback Plan

### Immediate Rollback (< 1 hour)

1. **Stop new service**:
   ```bash
   curl -X POST "https://coolify.aiwithapex.com/api/v1/applications/<new-uuid>/stop" \
     -H "Authorization: Bearer ${COOLIFY_API_TOKEN}"
   ```

2. **Old service is still running** at `n8n.aiwithapex.com`

3. **Delete new service** if not needed:
   ```bash
   curl -X DELETE "https://coolify.aiwithapex.com/api/v1/applications/<new-uuid>" \
     -H "Authorization: Bearer ${COOLIFY_API_TOKEN}"
   ```

### Post-Cutover Rollback

If old service has been stopped:

1. **Restart old service**:
   ```bash
   curl -X POST "https://coolify.aiwithapex.com/api/v1/services/g8wow80sgg8oo0csg4sgkws0/start" \
     -H "Authorization: Bearer ${COOLIFY_API_TOKEN}"
   ```

2. **Update DNS/domain** back to old service

3. **Export any new data** from new service before deletion

---

## Monitoring & Maintenance

### Prometheus Metrics

The new stack exposes metrics at `/metrics`:

```
# Key metrics to monitor
n8n_workflow_executions_total
n8n_workflow_execution_duration_seconds
n8n_active_executions
n8n_queue_depth
```

### Log Access

```bash
# Via Coolify UI: Application → Logs

# Via Docker
docker logs -f n8n-<uuid>
docker logs -f n8n-worker-1-<uuid>
```

### Scaling Workers

To add more workers after deployment:

1. Edit `docker-compose.coolify.yml`
2. Add `n8n-worker-4`, `n8n-worker-5`, etc.
3. Commit and push to GitHub
4. Redeploy in Coolify

### Version Upgrades

1. Update image tag in `docker-compose.coolify.yml`:
   ```yaml
   image: n8nio/n8n:2.2.0  # New version
   ```
2. Commit and push
3. Deploy via Coolify
4. Monitor for issues
5. Rollback if needed

---

## Appendix A: Coolify API Reference

### Authentication

```bash
# NEVER commit actual tokens to version control
# Get from: Coolify Dashboard > Security > API Tokens
export COOLIFY_API_TOKEN="${COOLIFY_API_TOKEN}"
export COOLIFY_API_URL="https://coolify.aiwithapex.com/api/v1"
```

### Useful Endpoints

| Action | Method | Endpoint |
|--------|--------|----------|
| List Applications | GET | `/applications` |
| Get Application | GET | `/applications/{uuid}` |
| Create Docker Compose App | POST | `/applications/dockercompose` |
| Deploy | POST | `/applications/{uuid}/deploy` |
| Stop | POST | `/applications/{uuid}/stop` |
| Start | POST | `/applications/{uuid}/start` |
| Delete | DELETE | `/applications/{uuid}` |
| Get Envs | GET | `/applications/{uuid}/envs` |
| Update Envs | PATCH | `/applications/{uuid}/envs` |

### Key UUIDs

| Resource | UUID |
|----------|------|
| Server | `rcgk0og40w0kwogock4k44s0` |
| Project (Apex Automations) | `m4cck40w0go4k88gwcg4k400` |
| Environment (production) | `sko8scc0c0ok8gcwo0gscw8o` |
| Current n8n Service | `g8wow80sgg8oo0csg4sgkws0` |

---

## Appendix B: Troubleshooting

### Container Won't Start

```bash
# Check logs
docker logs <container-name>

# Check Coolify deployment logs
# UI: Application → Deployments → View Logs
```

### Database Connection Issues

```bash
# Verify PostgreSQL is healthy
docker exec postgres-<uuid> pg_isready

# Check connection from n8n
docker exec n8n-<uuid> wget -qO- http://postgres:5432
```

### Redis Connection Issues

```bash
# Verify Redis is healthy
docker exec redis-<uuid> redis-cli ping

# Check queue status
docker exec redis-<uuid> redis-cli KEYS "bull:*"
```

### Workers Not Processing

```bash
# Check worker logs
docker logs n8n-worker-1-<uuid>

# Verify queue connection
docker exec n8n-worker-1-<uuid> wget -qO- http://redis:6379
```

### Traefik Not Routing

```bash
# Check Traefik dashboard (if enabled)
curl http://localhost:8080/api/http/routers

# Verify container labels
docker inspect n8n-<uuid> | jq '.[0].Config.Labels'
```

---

## Sources

- [Coolify Docker Compose Documentation](https://coolify.io/docs/applications/build-packs/docker-compose)
- [Coolify API Reference](https://coolify.io/docs/api-reference/api/operations/create-dockercompose-application)
- [Coolify Traefik Overview](https://coolify.io/docs/knowledge-base/proxy/traefik/overview)
- [n8n Queue Mode Documentation](https://docs.n8n.io/hosting/scaling/queue-mode/)
