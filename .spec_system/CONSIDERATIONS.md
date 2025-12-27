# Considerations

> Institutional memory for AI assistants. Updated between phases via /carryforward.
> **Line budget**: 600 max | **Last updated**: Phase 01 (2025-12-26)

---

## Active Concerns

Items requiring attention in upcoming phases. Review before each session.

### Technical Debt
<!-- Max 5 items -->

- [P01] **Backup encryption at rest**: Backup files (*.sql.gz, *.rdb, *.tar.gz) contain sensitive data but are unencrypted. Consider GPG encryption for production deployments.

- [P01] **Off-site backup destination**: All backups stored locally in project directory. Implement cloud storage (S3, B2) integration for true disaster recovery.

- [P01] **Log rotation not applied**: Docker daemon.json log rotation documented but requires sudo to apply. Currently using unlimited log storage.

### External Dependencies
<!-- Max 5 items -->

- [P01] **Redis vm.overcommit_memory warning**: Requires host-level `sudo sysctl vm.overcommit_memory=1` and `/etc/sysctl.d/99-redis.conf` for persistence. Documented in TROUBLESHOOTING.md but not applied.

- [P00] **WSL2 8GB RAM constraint**: System configured with 8GB RAM limit. Current usage ~1.6GB with 5 workers leaves ~6GB headroom. Monitor if adding services.

### Performance / Security
<!-- Max 5 items -->

- [P01] **WSL2 I/O virtualization limits**: Synthetic benchmarks (pgbench) show <5% improvement from tuning due to virtualized disk. Real workloads may benefit more from work_mem/SSD settings.

- [P00] **Secure cookie disabled**: `N8N_SECURE_COOKIE=false` for localhost development. Must enable when exposing to network or adding reverse proxy.

### Architecture
<!-- Max 5 items -->

- [P01] **No auto-scaling**: Worker count fixed at 5. Future phases may implement queue depth monitoring for dynamic scaling.

- [P01] **Worker health endpoints**: Queue mode workers don't expose HTTP endpoints. Health determined by container status only, not application health.

---

## Lessons Learned

Proven patterns and anti-patterns. Reference during implementation.

### What Worked
<!-- Max 15 items -->

- [P00] **Explicit WSL2 resource limits**: Set memory/CPU/swap in .wslconfig for predictable container behavior. Without limits, WSL2 uses host maximum causing resource contention.

- [P00] **Systemd for Docker auto-start**: Use systemd (wsl.conf) over bashrc workarounds. Provides proper service management and starts Docker before shell sessions.

- [P00] **Named Docker volumes**: Use named volumes (`postgres_data`, `redis_data`) over bind mounts for better portability and Docker-native management.

- [P00] **Service names as hostnames**: Use Docker service names (`postgres`, `redis`) for inter-container communication. More reliable than localhost or IP addresses.

- [P00] **Health checks with depends_on**: Implement health checks on all services. Use `depends_on` with `condition: service_healthy` for proper startup sequencing.

- [P00] **Environment variable externalization**: Store all secrets in `.env` with `${VAR}` references in docker-compose.yml. Never hardcode secrets.

- [P01] **Lock files for exclusive script execution**: Use lock files (e.g., `/tmp/backup-all.lock`) to prevent concurrent backup/restore operations that could cause corruption.

- [P01] **Alpine temporary containers for volume backup**: Use `docker run --rm -v volume:/data alpine tar` instead of docker cp for cleaner volume access.

- [P01] **PostgreSQL DROP DATABASE WITH (FORCE)**: PostgreSQL 13+ supports FORCE option to terminate active connections during restore, eliminating need to stop services.

- [P01] **Remove container_name for replicas**: Docker Compose requires removing `container_name` to enable `deploy.replicas`. Auto-generates names like `n8n-n8n-worker-1`.

- [P01] **Bull queue auto-distribution**: Redis Bull queue automatically distributes jobs across competing consumers without manual configuration or routing rules.

- [P01] **Read-only config mounts**: Mount configuration files as `:ro` to prevent accidental modification and enable easy rollback to container defaults.

- [P01] **Separate documentation files**: Create focused docs (SECURITY, RECOVERY, RUNBOOK, UPGRADE) rather than monolithic documents. Improves discoverability.

- [P01] **sysctl.d for permanent kernel settings**: Use `/etc/sysctl.d/*.conf` files for persistent kernel parameters. Survives reboots unlike inline `sysctl` commands.

- [P01] **Exact semantic version pinning**: Pin to `n8n:2.1.4` not `n8n:latest` or `n8n:2`. Prevents unexpected breaking changes in production.

### What to Avoid
<!-- Max 10 items -->

- [P00] **Default WSL2 resources**: Never rely on WSL2 defaults (uses host max). Always set explicit limits in .wslconfig for reproducible environments.

- [P00] **docker-compose hyphen**: Use `docker compose` (space) not `docker-compose` (hyphen) with Docker Engine 20+. The hyphen version is deprecated.

- [P00] **Standard Redis port in multi-project**: Avoid port 6379 when multiple Redis instances may exist. Use project-specific ports (this project uses 6386).

- [P00] **Assuming init script execution**: PostgreSQL init scripts only run on first container start with empty data directory. Plan accordingly for existing volumes.

- [P01] **Assuming container names match service names**: Container names (n8n-postgres) differ from service names (postgres). Always verify with `docker ps`.

- [P01] **Hardcoding default ports**: Source `.env` for project-specific configuration rather than assuming defaults (e.g., Redis 6379 vs project 6386).

- [P01] **Expecting benchmark targets in WSL2**: WSL2 I/O virtualization limits synthetic benchmark gains. Don't chase 20%+ improvements in virtualized environments.

- [P01] **World-writable config files**: PostgreSQL refuses to load config files with mode 666+. Use chmod 644 for config files mounted into containers.

### Tool/Library Notes
<!-- Max 5 items -->

- [P00] **Docker Compose v5.0.0+**: No `version:` field required in compose files. Modern syntax preferred.

- [P00] **n8n queue mode Redis config**: Use `QUEUE_BULL_REDIS_*` variables, not standard `REDIS_*` variables. n8n has separate configuration namespaces.

- [P01] **Docker stats --no-stream**: Use `--no-stream` flag for scripting to get single snapshot instead of continuous output.

- [P01] **pgbench WSL2 limitations**: I/O bound in virtualized environment. Memory tuning shows <5% gains vs 20%+ on native hardware.

- [P01] **listen_addresses for containers**: PostgreSQL requires `listen_addresses = '*'` in custom config for Docker container networking (default 'localhost' fails).

---

## Resolved

Recently closed items (buffer - rotates out after 2 phases).

| Phase | Item | Resolution |
|-------|------|------------|
| P01 | Single worker instance | Scaled to 5 workers with 50 concurrent execution capacity |
| P01 | No backup automation | Full backup system with 7-day retention, cron scheduling |
| P01 | Manual execution offload disabled | Enabled OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true |
| P01 | n8n:latest image tag | Pinned to n8n:2.1.4, postgres:16.11-alpine, redis:7.4.7-alpine |
| P00 | WSL2 environment setup | Configured 8GB/4CPU/2GB swap, localhost forwarding enabled |
| P00 | Docker installation | Verified Docker 29.1.3, Compose 5.0.0, NVIDIA runtime pre-configured |
| P00 | Project structure | Created docker-compose.yml, .env, directory structure, init scripts |
| P00 | Service deployment | All 8 containers healthy (postgres, redis, n8n-main, 5 workers) |

---

*Auto-generated by /carryforward. Manual edits allowed but may be overwritten.*
