# n8n Worker Scaling Guide

This document describes how to scale n8n workers in this deployment.

---

## Architecture Overview

```
                +------------------+
                |    n8n Main      |
                |   (UI/Webhooks)  |
                +--------+---------+
                         |
                         v
                +------------------+
                |      Redis       |
                |     (Queue)      |
                +--------+---------+
                         |
     +-------------------+-------------------+
     |         |         |         |         |
     v         v         v         v         v
+--------+ +--------+ +--------+ +--------+ +--------+
|Worker 1| |Worker 2| |Worker 3| |Worker 4| |Worker 5|
+--------+ +--------+ +--------+ +--------+ +--------+

Total Capacity: 3 workers x 10 concurrency = 30 simultaneous executions
```

---

## Current Configuration

| Setting | Value | Location |
|---------|-------|----------|
| Default replicas | 3 | docker-compose.yml |
| Concurrency per worker | 10 | .env (EXECUTIONS_CONCURRENCY) |
| Memory limit per worker | 512 MB | docker-compose.yml |
| Manual execution offload | true | .env (OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS) |
| Redis timeout threshold | 60000 ms | .env (QUEUE_BULL_REDIS_TIMEOUT_THRESHOLD) |

---

## Scaling Operations

### View Current Workers

```bash
docker compose ps n8n-worker --format "table {{.Name}}\t{{.Status}}"
```

### Scale Up (More Workers)

To scale to a specific number of workers:

```bash
# Scale to 5 workers (default)
docker compose up -d

# Scale to 8 workers
docker compose up -d --scale n8n-worker=8

# Scale to 10 workers
docker compose up -d --scale n8n-worker=10
```

### Scale Down (Fewer Workers)

```bash
# Scale to 2 workers
docker compose up -d --scale n8n-worker=2

# Scale to 1 worker (minimum)
docker compose up -d --scale n8n-worker=1
```

### Graceful Scale Down

Workers complete in-flight jobs before stopping. If a worker is terminated during execution:
- The job times out after 60 seconds (QUEUE_BULL_REDIS_TIMEOUT_THRESHOLD)
- Redis automatically re-queues the job
- Another worker picks up the job

---

## Memory Guidelines

### Per-Worker Memory

Each worker is limited to 512 MB. Typical usage is 200-300 MB.

### Scaling Memory Budget

| Workers | Worker Memory | Total Stack | Notes |
|---------|---------------|-------------|-------|
| 1 | 512 MB | ~600 MB | Minimum configuration |
| 2 | 1 GB | ~1.1 GB | Light workloads |
| 5 | 2.5 GB | ~2.8 GB | Default (recommended) |
| 8 | 4 GB | ~4.3 GB | High throughput |
| 10 | 5 GB | ~5.3 GB | Maximum (within 8 GB limit) |

### Monitor Memory Usage

```bash
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}"
```

---

## Capacity Planning

### Execution Capacity

```
Total Concurrent Executions = Workers x EXECUTIONS_CONCURRENCY
```

| Workers | Concurrency | Total Capacity |
|---------|-------------|----------------|
| 1 | 10 | 10 |
| 2 | 10 | 20 |
| 5 | 10 | 50 |
| 8 | 10 | 80 |
| 10 | 10 | 100 |

### When to Scale Up

- Queue depth consistently > 0 (jobs waiting)
- Average execution wait time increasing
- Workflow execution delays reported

### When to Scale Down

- Workers consistently idle
- Memory pressure on host system
- Cost optimization (production environments)

---

## Troubleshooting

### Workers Not Starting

```bash
# Check worker logs
docker compose logs n8n-worker --tail=50

# Check Redis connectivity
docker compose exec redis redis-cli -p 6386 ping
```

### Jobs Not Processing

```bash
# Verify queue mode is active
docker compose exec n8n printenv | grep EXECUTIONS_MODE

# Check worker health
docker compose ps n8n-worker
```

### Memory Issues

```bash
# Check container memory limits
docker inspect n8n-n8n-worker-1 --format='{{.HostConfig.Memory}}'

# View memory usage
docker stats n8n-n8n-worker-1 --no-stream
```

---

## Environment Variables Reference

| Variable | Default | Description |
|----------|---------|-------------|
| EXECUTIONS_CONCURRENCY | 10 | Max concurrent executions per worker |
| OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS | true | Route UI executions to workers |
| QUEUE_BULL_REDIS_TIMEOUT_THRESHOLD | 60000 | Job timeout in milliseconds |
| EXECUTIONS_MODE | queue | Required for worker mode |
| QUEUE_BULL_REDIS_HOST | redis | Redis hostname |
| QUEUE_BULL_REDIS_PORT | 6386 | Redis port |

---

## Related Documentation

- [Docker Compose Deploy](https://docs.docker.com/compose/compose-file/deploy/)
- [n8n Queue Mode](https://docs.n8n.io/hosting/scaling/queue-mode/)
- [n8n Workers](https://docs.n8n.io/hosting/scaling/workers/)
