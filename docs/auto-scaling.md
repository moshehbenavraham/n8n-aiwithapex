# Worker Auto-Scaling

This document describes the n8n worker auto-scaling system, which automatically adjusts the number of worker containers based on Redis Bull queue depth.

## Overview

The auto-scaling system monitors the n8n job queue in Redis and scales workers up when demand increases, or down when the queue is empty. This ensures efficient resource usage while maintaining responsiveness during high-load periods.

### Architecture

```
                    +------------------+
                    |    Cron Job      |
                    |  (every 1 min)   |
                    +--------+---------+
                             |
                             v
              +-----------------------------+
              |   worker-autoscale.sh       |
              |  (scaling controller)       |
              +-----------------------------+
                      |             |
                      v             v
          +---------------+   +-------------------+
          | queue-depth.sh|   | docker compose    |
          | (Redis query) |   | scale n8n-worker  |
          +---------------+   +-------------------+
                 |
                 v
          +---------------+
          |    Redis      |
          |  Bull Queues  |
          +---------------+
```

## Configuration

Auto-scaling is configured via environment variables in `.env`:

| Variable | Default | Description |
|----------|---------|-------------|
| `AUTOSCALE_ENABLED` | `true` | Enable/disable auto-scaling |
| `AUTOSCALE_MIN_WORKERS` | `1` | Minimum worker count (never scale below) |
| `AUTOSCALE_MAX_WORKERS` | `10` | Maximum worker count (never scale above) |
| `AUTOSCALE_HIGH_THRESHOLD` | `20` | Queue depth to trigger scale-up |
| `AUTOSCALE_LOW_THRESHOLD` | `5` | Queue depth to trigger scale-down |
| `AUTOSCALE_COOLDOWN_SECONDS` | `120` | Minimum seconds between scaling operations |
| `AUTOSCALE_LOG_FILE` | `logs/autoscale.log` | Log file for scaling events |

### Example Configuration

```bash
# .env
AUTOSCALE_ENABLED=true
AUTOSCALE_MIN_WORKERS=2
AUTOSCALE_MAX_WORKERS=8
AUTOSCALE_HIGH_THRESHOLD=30
AUTOSCALE_LOW_THRESHOLD=10
AUTOSCALE_COOLDOWN_SECONDS=180
```

## Scripts

### queue-depth.sh

Queries Redis Bull queue for pending job count.

```bash
# Get total pending jobs (default)
./scripts/queue-depth.sh
# Output: 15

# Get detailed breakdown (JSON)
./scripts/queue-depth.sh --json
# Output: {"depth": 15, "wait": 10, "delayed": 5, "priority": 0}

# Get verbose output
./scripts/queue-depth.sh --verbose
```

### worker-autoscale.sh

Main scaling controller that monitors queue depth and adjusts worker count.

```bash
# Check current status
./scripts/worker-autoscale.sh --status

# Run scaling check (dry run - no changes)
./scripts/worker-autoscale.sh --dry-run

# Force immediate scaling check (bypass cooldown)
./scripts/worker-autoscale.sh --force

# Normal operation (run by cron)
./scripts/worker-autoscale.sh
```

## Cron Setup

To enable automatic scaling, install the cron job:

```bash
# View the cron configuration
cat config/cron/worker-autoscale.cron

# Install the cron job
crontab config/cron/worker-autoscale.cron

# Verify installation
crontab -l
```

The cron job runs every minute and:
1. Acquires a lock file to prevent concurrent runs
2. Checks if cooldown period has elapsed
3. Queries current queue depth
4. Calculates target worker count
5. Scales workers if needed
6. Logs the action

## Scaling Behavior

### Scale-Up Triggers

Workers scale up when:
- Queue depth >= `AUTOSCALE_HIGH_THRESHOLD`
- Current workers < `AUTOSCALE_MAX_WORKERS`
- Cooldown period has elapsed

Formula: For every `HIGH_THRESHOLD` jobs above the threshold, add 1 worker.

### Scale-Down Triggers

Workers scale down when:
- Queue depth <= `AUTOSCALE_LOW_THRESHOLD`
- Current workers > `AUTOSCALE_MIN_WORKERS`
- Cooldown period has elapsed

Scale-down is gradual: 1 worker removed per cycle.

### Cooldown Protection

The cooldown period (default 120 seconds) prevents rapid oscillation between scaling up and down. After any scaling operation, no further scaling occurs until the cooldown expires.

## Monitoring

### Check Status

```bash
# View auto-scaling status in health check
./scripts/health-check.sh

# View dedicated status
./scripts/worker-autoscale.sh --status
```

### View Logs

```bash
# Scaling events log
tail -f logs/autoscale.log

# Cron execution log
tail -f /tmp/worker-autoscale-cron.log
```

### Log Format

```
[SCALE] 2025-12-28 10:30:00 [worker-autoscale] Scaling UP from 3 to 5 workers (queue depth: 45)
[INFO] 2025-12-28 10:32:00 [worker-autoscale] Current state: 5 workers, 12 jobs in queue
[INFO] 2025-12-28 10:32:00 [worker-autoscale] No scaling needed (target: 5)
```

## Troubleshooting

### Auto-scaling not working

1. Check if enabled: `grep AUTOSCALE_ENABLED .env`
2. Check cron is installed: `crontab -l`
3. Check for lock file: `ls -la /tmp/worker-autoscale.lock`
4. Check cooldown: `cat /tmp/worker-autoscale.last`
5. Run manually with debug: `./scripts/worker-autoscale.sh --status`

### Workers not scaling up

1. Verify queue has jobs: `./scripts/queue-depth.sh --verbose`
2. Check threshold settings in `.env`
3. Ensure not at max workers: `docker compose ps n8n-worker`

### Workers stuck at minimum

1. Check Redis connectivity: `docker exec n8n-redis redis-cli -p 6386 PING`
2. Verify queue-depth.sh works: `./scripts/queue-depth.sh`
3. Check logs for errors: `tail -50 logs/autoscale.log`

### Lock file stuck

If scaling seems blocked:

```bash
# Check lock file age
ls -la /tmp/worker-autoscale.lock

# Remove stale lock (script handles this automatically after 5 min)
rm /tmp/worker-autoscale.lock
```

## Disabling Auto-Scaling

To disable auto-scaling:

```bash
# Option 1: Set environment variable
echo "AUTOSCALE_ENABLED=false" >> .env

# Option 2: Remove cron job
crontab -r  # Removes all cron jobs for user
# Or edit: crontab -e and remove the worker-autoscale line
```

## Best Practices

1. **Start with conservative thresholds** - Begin with higher thresholds and lower max workers, then tune based on actual load patterns.

2. **Monitor logs during initial deployment** - Watch `logs/autoscale.log` to understand scaling behavior.

3. **Set appropriate cooldown** - Longer cooldown (180-300s) prevents thrashing but slows response to sudden load spikes.

4. **Consider worker startup time** - New workers take 5-10 seconds to become ready. Factor this into threshold decisions.

5. **Keep minimum workers >= 1** - Always have at least one worker ready to handle jobs.

## Related Files

- `scripts/queue-depth.sh` - Queue depth monitoring
- `scripts/worker-autoscale.sh` - Scaling controller
- `scripts/health-check.sh` - Includes scaling status
- `config/cron/worker-autoscale.cron` - Cron job configuration
- `.env` - Auto-scaling configuration
- `logs/autoscale.log` - Scaling event log
