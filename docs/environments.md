# Environments

This n8n installation runs as a single local development/automation environment with external access via ngrok tunnel.

## Environment Overview

| Environment | URL | Purpose |
|-------------|-----|---------|
| Local (WSL2) | http://localhost:5678 | Development and automation |
| External (ngrok) | https://n8n.aiwithapex.ngrok.dev | Webhooks and remote access |
| ngrok Inspector | http://localhost:4040 | Tunnel debugging |

## Configuration

All configuration is managed through the `.env` file in the project root.

### Core Settings

| Variable | Description |
|----------|-------------|
| `N8N_PORT` | n8n web UI port (default: 5678) |
| `N8N_PROTOCOL` | http (localhost only) |
| `N8N_HOST` | localhost |
| `GENERIC_TIMEZONE` | America/New_York |

### Database Settings

| Variable | Description |
|----------|-------------|
| `POSTGRES_USER` | PostgreSQL username |
| `POSTGRES_PASSWORD` | PostgreSQL password (auto-generated) |
| `POSTGRES_DB` | Database name |
| `DB_TYPE` | postgresdb |

### Queue Settings

| Variable | Description |
|----------|-------------|
| `EXECUTIONS_MODE` | queue (enables workers) |
| `QUEUE_BULL_REDIS_HOST` | redis |
| `QUEUE_BULL_REDIS_PORT` | 6386 |

### Security Settings

| Variable | Description |
|----------|-------------|
| `N8N_ENCRYPTION_KEY` | Credential encryption key (never change) |
| `N8N_SECURE_COOKIE` | true (required for HTTPS via ngrok) |

### Tunnel Settings

| Variable | Description |
|----------|-------------|
| `NGROK_AUTHTOKEN` | ngrok authentication token |
| `NGROK_DOMAIN` | Custom domain (n8n.aiwithapex.ngrok.dev) |
| `NGROK_INSPECTOR_PORT` | Web inspector port (4040) |
| `WEBHOOK_URL` | External webhook base URL |
| `N8N_HOST` | Hostname for URLs (n8n.aiwithapex.ngrok.dev) |
| `N8N_PROTOCOL` | Protocol (https for ngrok) |

## Resource Allocation

Configured in Windows `.wslconfig`:

| Resource | Allocation |
|----------|------------|
| Memory | 8 GB |
| CPU Cores | 4 |
| Swap | 2 GB |

## Container Resources

| Container | CPU Limit | Memory Limit |
|-----------|-----------|--------------|
| n8n-main | No limit | No limit |
| n8n-worker (x5) | No limit | No limit |
| n8n-ngrok | No limit | No limit |
| PostgreSQL | No limit | No limit |
| Redis | No limit | 256 MB |

## Ports

| Service | Internal Port | External Port | Notes |
|---------|---------------|---------------|-------|
| n8n | 5678 | 5678 | Local access |
| ngrok Inspector | 4040 | 4040 | Debug UI |
| ngrok Tunnel | - | 443 | Via n8n.aiwithapex.ngrok.dev |
| PostgreSQL | 5432 | Not exposed | Internal only |
| Redis | 6386 | Not exposed | Internal only |

## Data Persistence

| Volume | Purpose |
|--------|---------|
| `n8n_postgres_data` | PostgreSQL database files |
| `n8n_redis_data` | Redis AOF persistence |
| `n8n_n8n_data` | n8n application data |

## Scaling for Production

If deploying to production, consider:

1. **Enable secure cookies**: Set `N8N_SECURE_COOKIE=true` with HTTPS
2. **Add reverse proxy**: nginx or Traefik with SSL termination
3. **External database**: Managed PostgreSQL service
4. **Monitoring**: Prometheus/Grafana integration
5. **Backup offsite**: Cloud storage for backup copies

## Related Documentation

- [Security Guide](SECURITY.md) - Security hardening
- [Scaling Guide](SCALING.md) - Worker scaling
- [Port Assignments](PORTS-ASSIGNMENT.md) - Network details
