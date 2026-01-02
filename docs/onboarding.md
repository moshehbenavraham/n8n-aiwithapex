# Onboarding

Zero-to-running checklist for this n8n installation.

> **Custom Fork Optimized**: This deployment infrastructure is designed and optimized to run with our custom n8n fork at [github.com/moshehbenavraham/n8n](https://github.com/moshehbenavraham/n8n). Toggle between official and custom fork images via the `N8N_IMAGE` variable in `.env`.

---

## Deployment Options

This project supports two deployment forms:

| Deployment | Guide | Best For |
|------------|-------|----------|
| **WSL2 (Local)** | This document | Development, local automation |
| **Coolify (Cloud)** | [Deploy to Coolify](ongoing-roadmap/deploy-to-coolify.md) | Production, cloud-hosted |

See [Deployment Comparison](deployment-comparison.md) for detailed differences.

---

## WSL2 Local Onboarding

This section covers setting up n8n on a Windows machine with WSL2 Ubuntu.

### Prerequisites

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
n8n-ngrok      Up (healthy)
n8n-worker     Up (healthy)
```

## Access n8n

### Local Access
1. Open http://localhost:5678
2. Create owner account on first visit
3. Save credentials securely

### External Access (via ngrok)
1. Open https://your.ngrok.domain
2. Authenticate with Google (allowed domains only)
3. Log in with n8n credentials

## Verify Setup

- [x] All 5 containers running: `docker compose ps`
- [x] Health check passes: `curl localhost:5678/healthz`
- [x] UI accessible: http://localhost:5678
- [x] Tunnel active: `./scripts/tunnel-manage.sh status`
- [x] External access: https://your.ngrok.domain
- [x] Can create test workflow

## Environment Variables

Key variables in `.env`:

| Variable | Purpose |
|----------|---------|
| `N8N_ENCRYPTION_KEY` | Credential encryption (never change) |
| `POSTGRES_PASSWORD` | Database password |
| `EXECUTIONS_MODE` | Must be `queue` for workers |
| `GENERIC_TIMEZONE` | Workflow timezone |
| `NGROK_AUTHTOKEN` | ngrok authentication token |
| `NGROK_DOMAIN` | Custom ngrok domain |
| `WEBHOOK_URL` | External webhook base URL |

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

### Tunnel not connecting
```bash
# Check ngrok container logs
docker logs n8n-ngrok

# Verify authtoken is set
grep NGROK_AUTHTOKEN .env
```
