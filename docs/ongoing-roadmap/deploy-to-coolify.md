# Deploy n8n Stack to Coolify

> **Status**: ✅ Deployed & Running (Data Migrated)
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
- [x] Data migrated from old one-click install (137 workflows, 72 credentials, 3,570 executions)

---

## Key UUIDs

| Resource | UUID | Status |
|----------|------|--------|
| Server | `rcgk0og40w0kwogock4k44s0` | Active |
| Project | `m4cck40w0go4k88gwcg4k400` | Active |
| Old n8n Service (one-click) | `g8wow80sgg8oo0csg4sgkws0` | Deprecated (data migrated) |
| **n8n-production** | `s0sw00s8swwk4w88kgkkgg0k` | Active |

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

## Data Migration (Completed)

Data successfully migrated from old one-click install on 2026-01-12.

### What Was Migrated
- 137 workflows
- 72 credentials (encrypted with original key)
- 3,570 execution records
- 1 user account

### Migration Process Used

1. **Found encryption key** from old instance config at `/data/coolify/services/g8wow80sgg8oo0csg4sgkws0/`

2. **Set encryption key** on new instance via Coolify API

3. **Exported database** from old PostgreSQL:
   ```bash
   sudo docker run --rm -d --name temp-pg-export \
     -v g8wow80sgg8oo0csg4sgkws0_postgresql-data:/var/lib/postgresql/data \
     -e POSTGRES_USER=<user> -e POSTGRES_PASSWORD=<pass> \
     postgres:16-alpine

   sudo docker exec temp-pg-export pg_dump -U <user> n8n > n8n_backup.sql
   ```

4. **Imported to new instance**:
   ```bash
   docker exec -i <new-postgres-container> psql -U n8n -d n8n < n8n_backup.sql
   ```

5. **Fixed config file mismatch**: Updated encryption key in volume config to match env var

---

## Old Service Cleanup

The old one-click install at `n8n.aiwithapex.com` is deprecated. To stop it:

```bash
curl -X POST "https://coolify.aiwithapex.com/api/v1/services/g8wow80sgg8oo0csg4sgkws0/stop" \
  -H "Authorization: Bearer ${COOLIFY_API_TOKEN}"
```

Data volumes remain at `/data/coolify/services/g8wow80sgg8oo0csg4sgkws0/` if rollback is ever needed.

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
- `N8N_ENCRYPTION_KEY` - Set in Coolify env vars (migrated from old instance)
- `POSTGRES_DB` - Database name (default: n8n)
- `N8N_LOG_LEVEL` - info, warn, error, debug

### Key Features
- PostgreSQL tuning: shared_buffers=256MB, work_mem=16MB
- Redis: maxmemory=256mb, noeviction, AOF persistence
- Queue: QUEUE_WORKER_LOCK_DURATION=60000
- Privacy: Telemetry disabled
- Workers: Read-only volume mounts, 10 concurrency each
