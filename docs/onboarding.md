# Onboarding

Zero-to-running checklist for this n8n installation.

## Prerequisites

- [x] WSL2 Ubuntu 24.04 installed
- [x] Docker Engine 29.1.3+ installed
- [x] Docker Compose v5.0.0+ installed
- [x] User in `docker` group

## Verify Environment

```bash
# Check Docker
docker --version        # Should be 29.x+
docker compose version  # Should be v5.x+

# Check WSL2 resources
free -h                 # Should show ~8GB
nproc                   # Should show 4
```

## Start Services

```bash
cd /home/aiwithapex/n8n

# Start stack
docker compose up -d

# Verify all healthy
docker compose ps
```

Expected output:
```
NAME           STATUS
n8n-postgres   Up (healthy)
n8n-redis      Up (healthy)
n8n-main       Up (healthy)
n8n-worker     Up (healthy)
```

## Access n8n

1. Open http://localhost:5678
2. Create owner account on first visit
3. Save credentials securely

## Verify Setup

- [x] All 4 containers running: `docker compose ps`
- [x] Health check passes: `curl localhost:5678/healthz`
- [x] UI accessible: http://localhost:5678
- [x] Can create test workflow

## Environment Variables

Key variables in `.env`:

| Variable | Purpose |
|----------|---------|
| `N8N_ENCRYPTION_KEY` | Credential encryption (never change) |
| `POSTGRES_PASSWORD` | Database password |
| `EXECUTIONS_MODE` | Must be `queue` for workers |
| `GENERIC_TIMEZONE` | Workflow timezone |

## Common Issues

### Port 5678 in use
```bash
# Check what's using it
ss -tuln | grep 5678
# Stop conflicting service or change N8N_PORT in .env
```

### Container won't start
```bash
docker compose logs <service-name>
```

### Worker not processing
```bash
# Verify Redis connectivity
docker exec n8n-worker redis-cli -h redis -p 6386 ping
```
