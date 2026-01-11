# Deploy n8n Stack to Coolify

> **Status**: ✅ Deployed & Running
> **Service UUID**: `s0sw00s8swwk4w88kgkkgg0k`
> **URL**: https://n8n-apex.aiwithapex.com

---

## Architecture

```
Internet → Traefik → n8n-main (:5678)
                         │
           ┌─────────────┼─────────────┐
           ▼             ▼             ▼
       Worker-1      Worker-2      Worker-3
           │             │             │
           └─────────────┼─────────────┘
                         │
              ┌──────────┴──────────┐
              ▼                     ▼
          PostgreSQL             Redis
```

| Service | Image | Memory |
|---------|-------|--------|
| postgres | postgres:16.11-alpine | 1GB |
| redis | redis:7.4.7-alpine | 384MB |
| n8n | ghcr.io/moshehbenavraham/n8n:latest | 1GB |
| n8n-worker-1/2/3 | ghcr.io/moshehbenavraham/n8n:latest | 512MB each |

**Capacity**: 30 parallel executions (3 workers × 10 concurrency)

---

## Deployment Status

All complete:
- [x] Service deployed via Coolify API
- [x] All 6 containers running and healthy
- [x] Domain configured: https://n8n-apex.aiwithapex.com
- [x] Health, metrics, signin all verified working

---

## Key UUIDs

| Resource | UUID |
|----------|------|
| Server | `rcgk0og40w0kwogock4k44s0` |
| Project | `m4cck40w0go4k88gwcg4k400` |
| Old n8n Service | `g8wow80sgg8oo0csg4sgkws0` |
| **New n8n-production** | `s0sw00s8swwk4w88kgkkgg0k` |

---

## API Commands

### Check Status
```bash
curl -s "https://coolify.aiwithapex.com/api/v1/services/s0sw00s8swwk4w88kgkkgg0k" \
  -H "Authorization: Bearer ${COOLIFY_API_TOKEN}" | jq '{name, status}'
```

### Restart Service
```bash
curl -X POST "https://coolify.aiwithapex.com/api/v1/services/s0sw00s8swwk4w88kgkkgg0k/restart" \
  -H "Authorization: Bearer ${COOLIFY_API_TOKEN}"
```

### Stop Service
```bash
curl -X POST "https://coolify.aiwithapex.com/api/v1/services/s0sw00s8swwk4w88kgkkgg0k/stop" \
  -H "Authorization: Bearer ${COOLIFY_API_TOKEN}"
```

### Update Environment Variable
```bash
curl -X PATCH "https://coolify.aiwithapex.com/api/v1/services/s0sw00s8swwk4w88kgkkgg0k/envs" \
  -H "Authorization: Bearer ${COOLIFY_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"key": "N8N_LOG_LEVEL", "value": "debug"}'
```

### Update Docker Compose
```bash
COMPOSE_B64=$(cat docker-compose.coolify.yml | base64 -w 0)
curl -X PATCH "https://coolify.aiwithapex.com/api/v1/services/s0sw00s8swwk4w88kgkkgg0k" \
  -H "Authorization: Bearer ${COOLIFY_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"docker_compose_raw\": \"$COMPOSE_B64\"}"
```

---

## Validation

```bash
curl -s "https://n8n-apex.aiwithapex.com/healthz"                        # Health
curl -s "https://n8n-apex.aiwithapex.com/metrics" | head -20             # Metrics
curl -s -o /dev/null -w "%{http_code}" "https://n8n-apex.aiwithapex.com/signin"  # UI
```

---

## Data Migration (Future)

Current deployment is fresh (no data). To migrate from old instance:

**Option A: API Export/Import**
```bash
# Export from old
curl -X GET "https://n8n.aiwithapex.com/api/v1/workflows" \
  -H "X-N8N-API-KEY: <old-api-key>" > workflows.json

# Import to new (after setting up API key)
```

**Option B: Database Dump**
```bash
# Export
docker exec postgresql-g8wow80sgg8oo0csg4sgkws0 pg_dump -U postgres -d n8n > backup.sql

# Import (stop n8n first)
docker exec -i postgres-s0sw00s8swwk4w88kgkkgg0k psql -U postgres -d n8n < backup.sql
```

---

## Rollback

Old service at `n8n.aiwithapex.com` remains running. To rollback:

```bash
# Stop new service
curl -X POST "https://coolify.aiwithapex.com/api/v1/services/s0sw00s8swwk4w88kgkkgg0k/stop" \
  -H "Authorization: Bearer ${COOLIFY_API_TOKEN}"

# Old service is still at n8n.aiwithapex.com
```

---

## Scaling Workers

Edit `docker-compose.coolify.yml`, add `n8n-worker-4`, etc., then:

```bash
COMPOSE_B64=$(cat docker-compose.coolify.yml | base64 -w 0)
curl -X PATCH "https://coolify.aiwithapex.com/api/v1/services/s0sw00s8swwk4w88kgkkgg0k" \
  -H "Authorization: Bearer ${COOLIFY_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"docker_compose_raw\": \"$COMPOSE_B64\"}"

curl -X POST "https://coolify.aiwithapex.com/api/v1/services/s0sw00s8swwk4w88kgkkgg0k/restart" \
  -H "Authorization: Bearer ${COOLIFY_API_TOKEN}"
```

---

## Troubleshooting

| Issue | Check |
|-------|-------|
| Container won't start | `docker logs <container-name>` |
| DB connection | `docker exec postgres-<uuid> pg_isready` |
| Redis connection | `docker exec redis-<uuid> redis-cli ping` |
| Workers idle | `docker logs n8n-worker-1-<uuid>` |

---

## Configuration Reference

### Coolify Auto-Injected Variables
- `SERVICE_FQDN_N8N` - Full URL
- `SERVICE_URL_N8N` - Domain only
- `SERVICE_USER_POSTGRES` / `SERVICE_PASSWORD_POSTGRES`

### Required Variables (set in Coolify)
- `N8N_ENCRYPTION_KEY` - For credential decryption
- `POSTGRES_DB` - Database name (default: n8n)
- `N8N_LOG_LEVEL` - info, warn, error, debug

### Key Features
- PostgreSQL tuning: shared_buffers=256MB, work_mem=16MB
- Redis: maxmemory=256mb, noeviction, AOF persistence
- Queue: QUEUE_WORKER_LOCK_DURATION=60000
- Privacy: Telemetry disabled
- Workers: Read-only volume mounts, 10 concurrency each
