# n8n Environment Variables Configuration Guide

Reference for optimizing the n8n queue mode deployment with workers and runners.

**Current Setup**: n8n 2.33.4 | Queue mode | 3 workers | 3 runners | PostgreSQL | Redis

**Official Docs**: https://docs.n8n.io/hosting/configuration/environment-variables/

---

## Table of Contents

1. [Execution Settings](#1-execution-settings)
2. [Queue Mode & Redis](#2-queue-mode--redis)
3. [Worker Settings](#3-worker-settings)
4. [Task Runners](#4-task-runners)
5. [Database (PostgreSQL)](#5-database-postgresql)
6. [Logging](#6-logging)
7. [Metrics & Monitoring](#7-metrics--monitoring)
8. [Security](#8-security)
9. [Nodes & Code](#9-nodes--code)
10. [Cache](#10-cache)
11. [General](#11-general)
12. [Current vs Recommended](#12-current-vs-recommended)

---

## 1. Execution Settings

### Currently Configured

```yaml
EXECUTIONS_MODE: queue
EXECUTIONS_DATA_PRUNE: 'true'
EXECUTIONS_DATA_MAX_AGE: '168'          # 7 days
EXECUTIONS_DATA_PRUNE_MAX_COUNT: '50000'
```

### Available Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `EXECUTIONS_MODE` | `regular` | `regular` or `queue` - queue mode required for workers |
| `EXECUTIONS_TIMEOUT` | `-1` | Default timeout (seconds) for all workflows. -1 = disabled |
| `EXECUTIONS_TIMEOUT_MAX` | `3600` | Max timeout users can set per workflow (seconds) |
| `EXECUTIONS_DATA_SAVE_ON_ERROR` | `all` | Save execution data on error: `all`, `none` |
| `EXECUTIONS_DATA_SAVE_ON_SUCCESS` | `all` | Save execution data on success: `all`, `none` |
| `EXECUTIONS_DATA_SAVE_ON_PROGRESS` | `false` | Save progress for each node (more DB writes) |
| `EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS` | `true` | Save data for manual test executions |
| `EXECUTIONS_DATA_PRUNE` | `true` | Enable rolling deletion of old executions |
| `EXECUTIONS_DATA_MAX_AGE` | `336` | Hours before soft-delete (default 14 days) |
| `EXECUTIONS_DATA_PRUNE_MAX_COUNT` | `10000` | Max executions to keep (0 = unlimited) |
| `EXECUTIONS_DATA_HARD_DELETE_BUFFER` | `1` | Hours before hard-delete after soft-delete |
| `EXECUTIONS_DATA_PRUNE_HARD_DELETE_INTERVAL` | `15` | Minutes between hard-delete runs |
| `EXECUTIONS_DATA_PRUNE_SOFT_DELETE_INTERVAL` | `60` | Minutes between soft-delete runs |
| `N8N_CONCURRENCY_PRODUCTION_LIMIT` | `-1` | Max concurrent production executions (-1 = unlimited) |

### Queue Recovery (runs automatically on startup)

| Variable | Default | Description |
|----------|---------|-------------|
| `N8N_EXECUTIONS_QUEUE_RECOVERY_INTERVAL` | `180` | Minutes between queue recovery checks |
| `N8N_EXECUTIONS_QUEUE_RECOVERY_BATCH` | `100` | Batch size for recovery operations |
| `N8N_WORKFLOW_AUTODEACTIVATION_ENABLED` | `false` | Auto-deactivate workflows after repeated crashes |
| `N8N_WORKFLOW_AUTODEACTIVATION_MAX_LAST_EXECUTIONS` | `3` | Crash count before deactivation |

### Recommendations

```yaml
# Consider adding to main n8n service:
EXECUTIONS_TIMEOUT: '3600'                    # 1 hour default timeout
N8N_CONCURRENCY_PRODUCTION_LIMIT: '50'        # Prevent runaway executions
EXECUTIONS_DATA_SAVE_ON_PROGRESS: 'false'     # Keep false for performance
```

---

## 2. Queue Mode & Redis

### Currently Configured

```yaml
QUEUE_BULL_REDIS_HOST: redis
QUEUE_BULL_REDIS_PORT: '6379'
QUEUE_HEALTH_CHECK_ACTIVE: 'true'
QUEUE_BULL_REDIS_TIMEOUT_THRESHOLD: '60000'
QUEUE_WORKER_LOCK_DURATION: '60000'
```

### Available Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `QUEUE_BULL_REDIS_HOST` | `localhost` | Redis host |
| `QUEUE_BULL_REDIS_PORT` | `6379` | Redis port |
| `QUEUE_BULL_REDIS_DB` | `0` | Redis database number |
| `QUEUE_BULL_REDIS_PASSWORD` | `` | Redis password |
| `QUEUE_BULL_REDIS_USERNAME` | `` | Redis username (Redis 6.0+) |
| `QUEUE_BULL_REDIS_TLS` | `false` | Enable TLS for Redis |
| `QUEUE_BULL_REDIS_TIMEOUT_THRESHOLD` | `10000` | Max cumulative timeout (ms) before exit |
| `QUEUE_BULL_REDIS_SLOT_REFRESH_TIMEOUT` | `1000` | Cluster slot refresh timeout (ms) |
| `QUEUE_BULL_REDIS_SLOT_REFRESH_INTERVAL` | `5000` | Cluster slot refresh interval (ms) |
| `QUEUE_BULL_REDIS_CLUSTER_NODES` | `` | Comma-separated cluster nodes `host:port` |
| `QUEUE_BULL_REDIS_DNS_LOOKUP_STRATEGY` | `LOOKUP` | `LOOKUP` or `NONE` |
| `QUEUE_BULL_REDIS_DUALSTACK` | `false` | Enable dual-stack hostname resolution |
| `QUEUE_BULL_PREFIX` | `bull` | Prefix for Bull keys in Redis |
| `QUEUE_HEALTH_CHECK_ACTIVE` | `false` | Enable `/healthz` endpoints on workers |
| `QUEUE_HEALTH_CHECK_PORT` | `5678` | Port for worker health check server |
| `N8N_WORKER_SERVER_ADDRESS` | `::` | IP address for worker server |
| `QUEUE_WORKER_LOCK_DURATION` | `60000` | Worker lease period (ms) for jobs |
| `QUEUE_WORKER_LOCK_RENEW_TIME` | `10000` | Lease renewal frequency (ms) |
| `QUEUE_WORKER_STALLED_INTERVAL` | `30000` | Stalled job check frequency (ms), 0 = disabled |

### Recommendations

```yaml
# Current config is good. Consider adding:
QUEUE_WORKER_STALLED_INTERVAL: '30000'        # Check for stalled jobs every 30s
```

---

## 3. Worker Settings

### Currently Configured (on workers)

```yaml
EXECUTIONS_MODE: queue
EXECUTIONS_CONCURRENCY: '10'
OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS: 'true'  # On main only
```

### Available Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `EXECUTIONS_CONCURRENCY` | `10` | Max concurrent executions per worker |
| `OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS` | `false` | Send manual executions to workers |

### Recommendations

```yaml
# Current EXECUTIONS_CONCURRENCY: 10 is good
# With 3 workers = 30 concurrent executions max
# Consider reducing if memory constrained:
EXECUTIONS_CONCURRENCY: '5'                   # More conservative
```

---

## 4. Task Runners

### Currently Configured

**On Workers:**
```yaml
N8N_RUNNERS_ENABLED: 'true'
N8N_RUNNERS_MODE: external
N8N_RUNNERS_AUTH_TOKEN: '${N8N_RUNNERS_AUTH_TOKEN}'
N8N_RUNNERS_BROKER_LISTEN_ADDRESS: 0.0.0.0
```

**On Runner Containers:**
```yaml
N8N_RUNNERS_AUTH_TOKEN: '${N8N_RUNNERS_AUTH_TOKEN}'
N8N_RUNNERS_TASK_BROKER_URI: 'http://n8n-worker-X:5679'
N8N_RUNNERS_MAX_CONCURRENCY: '5'
N8N_RUNNERS_AUTO_SHUTDOWN_TIMEOUT: '15'
```

### Available Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `N8N_RUNNERS_MODE` | `internal` | `internal` (child process) or `external` (separate container) |
| `N8N_RUNNERS_PATH` | `/runners` | Connection endpoint path |
| `N8N_RUNNERS_AUTH_TOKEN` | `` | Authentication token (required) |
| `N8N_RUNNERS_BROKER_PORT` | `5679` | Task broker port |
| `N8N_RUNNERS_BROKER_LISTEN_ADDRESS` | `127.0.0.1` | Broker bind address |
| `N8N_RUNNERS_MAX_PAYLOAD` | `1073741824` | Max payload size (1GB default) |
| `N8N_RUNNERS_MAX_OLD_SPACE_SIZE` | `` | Node.js heap size (MB), empty = auto |
| `N8N_RUNNERS_MAX_CONCURRENCY` | `10` | Concurrent tasks per runner |
| `N8N_RUNNERS_TASK_TIMEOUT` | `300` | Task timeout (seconds) - 5 min default |
| `N8N_RUNNERS_TASK_REQUEST_TIMEOUT` | `60` | Wait time for available runner (seconds) |
| `N8N_RUNNERS_HEARTBEAT_INTERVAL` | `30` | Heartbeat frequency (seconds) |
| `N8N_RUNNERS_INSECURE_MODE` | `false` | Disable security for legacy JS modules |
| `N8N_RUNNERS_AUTO_SHUTDOWN_TIMEOUT` | `60` | Idle shutdown timeout (seconds) |

### Recommendations

```yaml
# Consider increasing task timeout for long-running code:
N8N_RUNNERS_TASK_TIMEOUT: '600'               # 10 minutes

# Current MAX_CONCURRENCY: 5 per runner is conservative and good
# Total: 3 runners x 5 = 15 concurrent code tasks
```

---

## 5. Database (PostgreSQL)

### Currently Configured

```yaml
DB_TYPE: postgresdb
DB_POSTGRESDB_HOST: postgres
DB_POSTGRESDB_PORT: '5432'
DB_POSTGRESDB_DATABASE: '${POSTGRES_DB:-n8n}'
DB_POSTGRESDB_USER: '${SERVICE_USER_POSTGRES}'
DB_POSTGRESDB_PASSWORD: '${SERVICE_PASSWORD_POSTGRES}'
```

### Available Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_TYPE` | `sqlite` | `sqlite`, `postgresdb`, `mysqldb` (deprecated) |
| `DB_POSTGRESDB_HOST` | `localhost` | PostgreSQL host |
| `DB_POSTGRESDB_PORT` | `5432` | PostgreSQL port |
| `DB_POSTGRESDB_DATABASE` | `n8n` | Database name |
| `DB_POSTGRESDB_USER` | `postgres` | Database user |
| `DB_POSTGRESDB_PASSWORD` | `` | Database password |
| `DB_POSTGRESDB_SCHEMA` | `public` | Schema name |
| `DB_POSTGRESDB_POOL_SIZE` | `2` | Connection pool size |
| `DB_POSTGRESDB_CONNECTION_TIMEOUT` | `20000` | Connection timeout (ms) |
| `DB_POSTGRESDB_IDLE_CONNECTION_TIMEOUT` | `30000` | Idle connection timeout (ms) |
| `DB_POSTGRESDB_SSL_ENABLED` | `false` | Enable SSL |
| `DB_POSTGRESDB_SSL_CA` | `` | SSL CA certificate |
| `DB_POSTGRESDB_SSL_CERT` | `` | SSL certificate |
| `DB_POSTGRESDB_SSL_KEY` | `` | SSL key |
| `DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED` | `true` | Reject unauthorized SSL |
| `DB_LOGGING_ENABLED` | `false` | Enable query logging |
| `DB_LOGGING_OPTIONS` | `error` | Log level: `error`, `query`, `schema`, `warn`, `info`, `log` |
| `DB_LOGGING_MAX_EXECUTION_TIME` | `0` | Log queries slower than X ms (0 = disabled) |
| `DB_TABLE_PREFIX` | `` | Prefix for all table names |
| `DB_PING_INTERVAL_SECONDS` | `2` | Health check interval |

### Recommendations

```yaml
# IMPORTANT: Increase pool size for queue mode with multiple workers!
# Each worker needs connections. Current default of 2 is too low.
DB_POSTGRESDB_POOL_SIZE: '10'                 # Per service instance

# For debugging slow queries:
DB_LOGGING_ENABLED: 'true'
DB_LOGGING_MAX_EXECUTION_TIME: '1000'         # Log queries > 1 second
```

---

## 6. Logging

### Currently Configured

```yaml
N8N_LOG_LEVEL: '${N8N_LOG_LEVEL:-info}'
N8N_LOG_OUTPUT: console
```

### Available Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `N8N_LOG_LEVEL` | `info` | `debug`, `info`, `warn`, `error` |
| `N8N_LOG_OUTPUT` | `console` | `console`, `file`, or both comma-separated |
| `N8N_LOG_FORMAT` | `text` | `text` (human) or `json` (structured) |
| `N8N_LOG_FILE_COUNT_MAX` | `100` | Max log files to retain |
| `N8N_LOG_FILE_SIZE_MAX` | `16` | Max file size (MiB) |
| `N8N_LOG_FILE_LOCATION` | `logs/n8n.log` | Log file path (relative to ~/.n8n) |
| `N8N_LOG_CRON_ACTIVE_INTERVAL` | `0` | Log active cron jobs every X minutes (0 = disabled) |
| `N8N_LOG_SCOPES` | `` | Filter logs by scope (comma-separated) |

### Recommendations

```yaml
# For production with log aggregation:
N8N_LOG_FORMAT: 'json'                        # Structured logs for parsing
N8N_LOG_LEVEL: 'info'                         # Keep info, avoid debug in prod
```

---

## 7. Metrics & Monitoring

### Currently Configured

```yaml
N8N_METRICS: 'true'
```

### Available Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `N8N_METRICS` | `false` | Enable `/metrics` Prometheus endpoint |
| `N8N_METRICS_PREFIX` | `n8n_` | Metric name prefix |
| `N8N_METRICS_INCLUDE_DEFAULT_METRICS` | `true` | Include Node.js/system metrics |
| `N8N_METRICS_INCLUDE_WORKFLOW_ID_LABEL` | `false` | Add workflow ID label |
| `N8N_METRICS_INCLUDE_WORKFLOW_NAME_LABEL` | `false` | Add workflow name label |
| `N8N_METRICS_INCLUDE_NODE_TYPE_LABEL` | `false` | Add node type label |
| `N8N_METRICS_INCLUDE_CREDENTIAL_TYPE_LABEL` | `false` | Add credential type label |
| `N8N_METRICS_INCLUDE_API_ENDPOINTS` | `false` | Expose API endpoint metrics |
| `N8N_METRICS_INCLUDE_API_PATH_LABEL` | `false` | Add API path label |
| `N8N_METRICS_INCLUDE_API_METHOD_LABEL` | `false` | Add HTTP method label |
| `N8N_METRICS_INCLUDE_API_STATUS_CODE_LABEL` | `false` | Add status code label |
| `N8N_METRICS_INCLUDE_CACHE_METRICS` | `false` | Expose cache hit/miss metrics |
| `N8N_METRICS_INCLUDE_MESSAGE_EVENT_BUS_METRICS` | `false` | Internal event metrics |
| `N8N_METRICS_INCLUDE_QUEUE_METRICS` | `false` | Job metrics in queue mode |
| `N8N_METRICS_QUEUE_METRICS_INTERVAL` | `20` | Queue metrics update interval (seconds) |
| `N8N_METRICS_INCLUDE_WORKFLOW_STATISTICS` | `false` | Workflow execution stats |
| `N8N_METRICS_WORKFLOW_STATISTICS_INTERVAL` | `300` | Stats update interval (seconds) |
| `N8N_METRICS_ACTIVE_WORKFLOW_METRIC_INTERVAL` | `60` | Active workflow count interval |

### Recommendations

```yaml
# For better observability in queue mode:
N8N_METRICS_INCLUDE_QUEUE_METRICS: 'true'
N8N_METRICS_INCLUDE_WORKFLOW_ID_LABEL: 'true'
N8N_METRICS_INCLUDE_DEFAULT_METRICS: 'true'
```

---

## 8. Security

### Currently Configured

```yaml
N8N_SECURE_COOKIE: 'true'
```

### Available Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `N8N_SECURE_COOKIE` | `false` | Require HTTPS for cookies |
| `N8N_RESTRICT_FILE_ACCESS_TO` | `~/.n8n-files` | Allowed dirs for file nodes (`;` separated) |
| `N8N_BLOCK_FILE_ACCESS_TO_N8N_FILES` | `true` | Block access to n8n internal dirs |
| `N8N_BLOCK_FILE_PATTERNS` | `^(.*\/)*\.git(\/.*)*$` | Regex patterns for blocked paths |
| `N8N_SECURITY_AUDIT_DAYS_ABANDONED_WORKFLOW` | `90` | Days until workflow considered abandoned |
| `N8N_CONTENT_SECURITY_POLICY` | `{}` | CSP headers (helmet.js format) |
| `N8N_CONTENT_SECURITY_POLICY_REPORT_ONLY` | `false` | Use report-only CSP header |
| `N8N_INSECURE_DISABLE_WEBHOOK_IFRAME_SANDBOX` | `false` | Disable webhook HTML sandbox |
| `N8N_GIT_NODE_DISABLE_BARE_REPOS` | `true` | Disable bare repos in Git node |
| `N8N_GIT_NODE_ENABLE_HOOKS` | `false` | Enable Git hooks (pre-commit, etc.) |
| `N8N_GIT_NODE_ENABLE_ALL_CONFIG_KEYS` | `false` | Allow arbitrary git config |
| `N8N_AWS_SYSTEM_CREDENTIALS_ACCESS_ENABLED` | `false` | Allow AWS system credentials |

### Recommendations

```yaml
# Current security settings are good. Consider:
N8N_BLOCK_FILE_ACCESS_TO_N8N_FILES: 'true'    # Keep enabled (default)
```

---

## 9. Nodes & Code

### Currently Configured

```yaml
N8N_PYTHON_ENABLED: 'true'                    # On workers
```

### Available Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `NODES_INCLUDE` | `[]` | Whitelist of node types to load |
| `NODES_EXCLUDE` | `[executeCommand, localFileTrigger]` | Blacklist of node types |
| `NODES_ERROR_TRIGGER_TYPE` | `n8n-nodes-base.errorTrigger` | Error trigger node type |
| `N8N_PYTHON_ENABLED` | `true` | Enable Python in Code node |

### Recommendations

```yaml
# Default NODES_EXCLUDE disables executeCommand and localFileTrigger
# This is secure. Only change if you specifically need these nodes.
# To enable executeCommand (risky!):
# NODES_EXCLUDE: '["n8n-nodes-base.localFileTrigger"]'
```

---

## 10. Cache

### Available Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `N8N_CACHE_BACKEND` | `auto` | Cache backend: `auto`, `memory`, `redis` |
| `N8N_CACHE_MEMORY_MAX_SIZE` | `3145728` | Max memory cache (bytes) - 3MB default |
| `N8N_CACHE_MEMORY_TTL` | `3600000` | Memory cache TTL (ms) - 1 hour |
| `N8N_CACHE_REDIS_KEY_PREFIX` | `cache` | Redis cache key prefix |
| `N8N_CACHE_REDIS_TTL` | `3600000` | Redis cache TTL (ms) - 1 hour |
| `N8N_REDIS_KEY_PREFIX` | `n8n` | General Redis key prefix |

### Recommendations

```yaml
# For queue mode, Redis cache is recommended:
N8N_CACHE_BACKEND: 'redis'
```

---

## 11. General

### Currently Configured

```yaml
GENERIC_TIMEZONE: America/New_York
N8N_RELEASE_TYPE: stable
N8N_DIAGNOSTICS_ENABLED: 'false'
N8N_VERSION_NOTIFICATIONS_ENABLED: 'false'
```

### Available Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GENERIC_TIMEZONE` | `America/New_York` | Default timezone |
| `N8N_RELEASE_TYPE` | `dev` | Release channel: `stable`, `beta`, `nightly`, `dev`, `rc` |
| `N8N_GRACEFUL_SHUTDOWN_TIMEOUT` | `30` | Shutdown grace period (seconds) |
| `N8N_DEPLOYMENT_TYPE` | `default` | Deployment type identifier |
| `N8N_DIAGNOSTICS_ENABLED` | `true` | Send anonymous diagnostics |
| `N8N_VERSION_NOTIFICATIONS_ENABLED` | `true` | Show version update notifications |
| `N8N_AI_ENABLED` | `false` | Enable AI features |
| `N8N_AI_TIMEOUT_MAX` | `3600000` | AI request timeout (ms) |
| `N8N_PAYLOAD_SIZE_MAX` | `16` | Max payload size (MiB) |
| `N8N_FORMDATA_FILE_SIZE_MAX` | `200` | Max form-data file size (MiB) |
| `N8N_DISABLE_UI` | `false` | Disable web UI |

### Recommendations

```yaml
# For long-running workflows, increase graceful shutdown:
N8N_GRACEFUL_SHUTDOWN_TIMEOUT: '60'           # 60 seconds

# If using AI nodes:
N8N_AI_ENABLED: 'true'
```

---

## 12. Current vs Recommended

### Variables to ADD (High Priority)

| Variable | Recommended Value | Reason |
|----------|-------------------|--------|
| `DB_POSTGRESDB_POOL_SIZE` | `10` | Default 2 is too low for queue mode |
| `N8N_GRACEFUL_SHUTDOWN_TIMEOUT` | `60` | Allow more time for graceful shutdown |
| `N8N_METRICS_INCLUDE_QUEUE_METRICS` | `true` | Better monitoring in queue mode |

### Variables to CONSIDER (Medium Priority)

| Variable | Recommended Value | Reason |
|----------|-------------------|--------|
| `EXECUTIONS_TIMEOUT` | `3600` | Prevent runaway workflows |
| `N8N_CONCURRENCY_PRODUCTION_LIMIT` | `50` | Prevent resource exhaustion |
| `N8N_CACHE_BACKEND` | `redis` | Shared cache across instances |
| `N8N_LOG_FORMAT` | `json` | Better for log aggregation |

### Current Config Assessment

| Category | Status | Notes |
|----------|--------|-------|
| Queue Mode | Good | Properly configured |
| Redis | Good | Appropriate timeouts |
| Workers | Good | 10 concurrency per worker |
| Runners | Good | External mode, proper auth |
| Database | **Needs Fix** | Pool size too low |
| Logging | OK | Consider JSON format |
| Metrics | Partial | Add queue metrics |
| Security | Good | Secure cookies enabled |

---

## Quick Reference: Environment Variables by Service

### Main n8n Service
```yaml
# Add these:
DB_POSTGRESDB_POOL_SIZE: '10'
N8N_GRACEFUL_SHUTDOWN_TIMEOUT: '60'
N8N_METRICS_INCLUDE_QUEUE_METRICS: 'true'
# Optional:
EXECUTIONS_TIMEOUT: '3600'
N8N_CONCURRENCY_PRODUCTION_LIMIT: '50'
N8N_CACHE_BACKEND: 'redis'
```

### Worker Services
```yaml
# Add these:
DB_POSTGRESDB_POOL_SIZE: '10'
N8N_GRACEFUL_SHUTDOWN_TIMEOUT: '60'
```

### Runner Services
```yaml
# Current config is optimal
# No changes needed
```

---

## Sources

- [n8n Environment Variables Overview](https://docs.n8n.io/hosting/configuration/environment-variables/)
- [n8n GitHub - @n8n/config package](https://github.com/n8n-io/n8n/tree/master/packages/%40n8n/config)
- [n8n Scaling/Queue Mode](https://docs.n8n.io/hosting/scaling/queue-mode/)

---

*Generated: 2026-01-22*
