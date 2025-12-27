# Development Guide

Day-to-day operations for the n8n stack.

## Service Management

| Command | Purpose |
|---------|---------|
| `docker compose up -d` | Start all services |
| `docker compose down` | Stop all services |
| `docker compose restart n8n` | Restart specific service |
| `docker compose logs -f` | Stream all logs |
| `docker compose logs n8n --tail=100` | Last 100 lines of n8n |

## Health Checks

```bash
# All services status
docker compose ps

# n8n health endpoint
curl -s http://localhost:5678/healthz

# n8n metrics (Prometheus format)
curl -s http://localhost:5678/metrics | head -20

# PostgreSQL
docker exec n8n-postgres pg_isready -U n8n

# Redis
docker exec n8n-redis redis-cli -p 6386 ping

# Tunnel status
./scripts/tunnel-manage.sh status
```

## Tunnel Management

```bash
# Check tunnel status
./scripts/tunnel-manage.sh status

# Restart tunnel
./scripts/tunnel-manage.sh restart

# Stop tunnel (ngrok only)
./scripts/tunnel-manage.sh stop

# Start tunnel
./scripts/tunnel-manage.sh start

# View ngrok logs
./scripts/view-logs.sh -s ngrok

# Open ngrok inspector
open http://localhost:4040
```

## Scaling Workers

```bash
# Scale to 3 workers
docker compose up -d --scale n8n-worker=3

# Scale to 5 workers
docker compose up -d --scale n8n-worker=5

# Scale back to 1
docker compose up -d --scale n8n-worker=1
```

## Updating n8n

```bash
# Pull latest images
docker compose pull

# Recreate with new images
docker compose up -d

# Verify version
docker compose logs n8n | grep -i version
```

## Database Access

```bash
# Connect to PostgreSQL
docker exec -it n8n-postgres psql -U n8n -d n8n

# Check execution count
docker exec n8n-postgres psql -U n8n -d n8n -c "SELECT COUNT(*) FROM execution_entity"

# Check workflow count
docker exec n8n-postgres psql -U n8n -d n8n -c "SELECT COUNT(*) FROM workflow_entity"
```

## Backup (Manual)

```bash
# PostgreSQL dump
docker exec n8n-postgres pg_dump -U n8n n8n > backups/postgres_$(date +%Y%m%d).sql

# Compress
gzip backups/postgres_$(date +%Y%m%d).sql
```

## Resource Monitoring

```bash
# Live container stats
docker stats

# Disk usage
docker system df

# Clean unused resources
docker system prune -f
```

## Debugging

### View detailed logs
```bash
docker compose logs --timestamps n8n 2>&1 | less
```

### Enter container shell
```bash
docker exec -it n8n-main /bin/sh
```

### Check environment
```bash
docker exec n8n-main printenv | grep N8N
```

## Troubleshooting

### High memory usage
```bash
docker stats --no-stream
# If worker is high, reduce concurrency in docker-compose.yml
```

### Slow workflows
```bash
# Check execution data volume
docker exec n8n-postgres psql -U n8n -d n8n -c \
  "SELECT COUNT(*), MIN(startedAt), MAX(startedAt) FROM execution_entity"
```

### Container keeps restarting
```bash
docker compose logs <service> --tail=50
docker inspect <container-name> --format='{{.State.ExitCode}}'
```
