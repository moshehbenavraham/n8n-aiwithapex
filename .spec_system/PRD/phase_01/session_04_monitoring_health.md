# Session 04: Monitoring and Health Management

**Session ID**: `phase01-session04-monitoring-health`
**Status**: Not Started
**Estimated Tasks**: ~20-25
**Estimated Duration**: 2-4 hours

---

## Important: WSL2 Ubuntu Only

**All commands and operations run exclusively from WSL2 Ubuntu.** There is NO need for PowerShell, CMD, or Windows Terminal.

---

## Objective

Establish comprehensive monitoring and health management procedures for the n8n stack, including resource monitoring, log management, health check verification, and basic alerting mechanisms.

---

## Scope

### In Scope (MVP)
- Verify and document health endpoints (/healthz, /metrics)
- Create resource monitoring script (docker stats wrapper)
- Configure log rotation for container logs
- Implement log aggregation/viewing procedures
- Create health check verification script
- Document resource thresholds and alerts
- Set up basic alerting via log monitoring
- Create system status dashboard script
- Document troubleshooting decision tree

### Out of Scope
- External monitoring systems (Prometheus, Grafana)
- PagerDuty/OpsGenie integration
- Custom metrics collection
- APM (Application Performance Monitoring)
- Distributed tracing

---

## Prerequisites

- [ ] All containers running and healthy
- [ ] n8n /healthz and /metrics endpoints accessible
- [ ] Backup procedures in place (Session 01)
- [ ] Worker scaling configured (Session 02)

---

## Deliverables

1. `scripts/health-check.sh` - Comprehensive health verification
2. `scripts/monitor-resources.sh` - Resource monitoring with thresholds
3. `scripts/view-logs.sh` - Unified log viewer
4. `scripts/system-status.sh` - Dashboard-style status report
5. Docker log rotation configuration
6. Monitoring runbook documentation
7. Alert threshold definitions
8. Troubleshooting decision tree

---

## Technical Details

### Health Endpoints
```bash
# n8n health check
curl -s http://localhost:5678/healthz

# n8n metrics (Prometheus format)
curl -s http://localhost:5678/metrics

# Container health status
docker inspect --format='{{.State.Health.Status}}' n8n
```

### Resource Monitoring
```bash
# Real-time stats
docker stats --no-stream

# Memory threshold check (alert if >80%)
docker stats --no-stream --format "table {{.Name}}\t{{.MemPerc}}"
```

### Log Rotation (Docker daemon config)
```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

### System Status Output
```
=== n8n Stack Status ===
Timestamp: 2025-12-26 10:00:00

CONTAINERS:
  postgres:    healthy (up 2 days)
  redis:       healthy (up 2 days)
  n8n:         healthy (up 2 days)
  n8n-worker:  healthy (5 replicas)

RESOURCES:
  Memory: 3.2GB / 8GB (40%)
  CPU: 15% average

QUEUE:
  Pending jobs: 0
  Active jobs: 2

ENDPOINTS:
  /healthz: OK
  /metrics: OK
```

---

## Success Criteria

- [ ] Health check script validates all containers
- [ ] Resource monitoring captures memory, CPU, disk
- [ ] Log rotation configured for all containers
- [ ] Unified log viewer functional
- [ ] System status script provides clear overview
- [ ] Alert thresholds documented (memory >80%, CPU >90%)
- [ ] Troubleshooting decision tree covers common issues
