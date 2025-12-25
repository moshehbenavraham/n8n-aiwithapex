# Port Assignment Reference

**Project**: n8n WSL2 Docker Deployment
**Last Updated**: 2025-12-25
**Purpose**: Centralized port configuration to avoid conflicts with other services

---

## Design Philosophy

This project uses **non-standard ports** for internal services to avoid conflicts with:
- Other PostgreSQL instances (development databases, etc.)
- Other Redis instances (caching, other apps)
- Monitoring stacks from other projects
- Development tools

**Only n8n (5678)** uses the standard port since it's the primary service users interact with.

---

## Core Service Ports

| Service | Port | Standard Port | Protocol | Exposure | Environment Variable |
|---------|------|---------------|----------|----------|---------------------|
| **n8n Main** | 5678 | 5678 | TCP | External (localhost) | `N8N_PORT` |
| **PostgreSQL** | 5445 | 5432 | TCP | Internal only | `DB_POSTGRESDB_PORT` |
| **Redis** | 6386 | 6379 | TCP | Internal only | `QUEUE_BULL_REDIS_PORT` |

---

## Monitoring Stack Ports (Future/Optional)

| Service | Port | Standard Port | Protocol | Exposure | Environment Variable |
|---------|------|---------------|----------|----------|---------------------|
| **Prometheus** | 9095 | 9090 | TCP | Internal/Localhost | `PROMETHEUS_PORT` |
| **Alertmanager** | 9096 | 9093 | TCP | Internal/Localhost | `ALERTMANAGER_PORT` |
| **Grafana** | 3021 | 3000 | TCP | External (localhost) | `GRAFANA_PORT` |
| **Node Exporter** | 9102 | 9100 | TCP | Internal only | `NODE_EXPORTER_PORT` |

---

## Development Ports (Future/Optional)

| Service | Port | Standard Port | Protocol | Purpose | Environment Variable |
|---------|------|---------------|----------|---------|---------------------|
| **n8n Editor Dev** | 8092 | 8081 | TCP | Development mode UI | `N8N_EDITOR_DEV_PORT` |
| **Node.js Debug** | 9230 | 9229 | TCP | Chrome DevTools | `NODE_DEBUG_PORT` |

---

## Port Categories

### External Ports (Accessible from Windows Host)

```
Windows Host --> WSL2 Ubuntu --> Docker Container

localhost:5678  --> n8n Main (Web UI, API, Webhooks)
localhost:3021  --> Grafana (if monitoring enabled)
```

### Internal Ports (Docker Network Only)

```
Docker Network (n8n-network):
  postgres:5445   <-- n8n, n8n-worker
  redis:6386      <-- n8n, n8n-worker
  prometheus:9095 <-- grafana (if enabled)
```

---

## Environment Configuration

### .env File Template

```bash
# ============================================
# PORT CONFIGURATION
# ============================================
# Non-standard ports to avoid conflicts

# Core Services
N8N_PORT=5678                    # Standard - primary user interface
DB_POSTGRESDB_PORT=5445          # Non-standard (avoids 5432 conflicts)
QUEUE_BULL_REDIS_PORT=6386       # Non-standard (avoids 6379 conflicts)

# Monitoring Stack (if enabled)
PROMETHEUS_PORT=9095             # Non-standard (avoids 9090 conflicts)
ALERTMANAGER_PORT=9096           # Non-standard (avoids 9093 conflicts)
GRAFANA_PORT=3021                # Non-standard (avoids 3000 conflicts)
NODE_EXPORTER_PORT=9102          # Non-standard (avoids 9100 conflicts)

# Development (if needed)
N8N_EDITOR_DEV_PORT=8092         # Non-standard (avoids 8081 conflicts)
NODE_DEBUG_PORT=9230             # Non-standard (avoids 9229 conflicts)
```

---

## Docker Compose Port Mapping

### Core Services

```yaml
services:
  # PostgreSQL - INTERNAL ONLY (no host port mapping)
  postgres:
    # Port 5445 accessible only within n8n-network
    # Connection: postgres:5445 from other containers

  # Redis - INTERNAL ONLY (no host port mapping)
  redis:
    # Port 6386 accessible only within n8n-network
    # Connection: redis:6386 from other containers

  # n8n Main - EXTERNAL
  n8n:
    ports:
      - "5678:5678"
    # Accessible at http://localhost:5678

  # n8n Worker - NO PORTS (connects to redis internally)
  n8n-worker:
    # No port exposure needed
```

### Monitoring Stack (Optional)

```yaml
services:
  prometheus:
    ports:
      - "9095:9090"  # Map internal 9090 to host 9095

  alertmanager:
    ports:
      - "9096:9093"  # Map internal 9093 to host 9096

  grafana:
    ports:
      - "3021:3000"  # Map internal 3000 to host 3021

  node-exporter:
    # Usually internal only, or:
    ports:
      - "9102:9100"  # Map internal 9100 to host 9102
```

---

## Network Architecture

```
+------------------------------------------------------------------+
|                      WINDOWS HOST (WSL2)                         |
|  localhost:5678 ─────────────────────────────────────────────┐   |
|  localhost:3021 ────────────────────────────────────────┐    |   |
|                                                         |    |   |
|  +----------------------------------------------------+ |    |   |
|  |                  WSL2 UBUNTU VM                    | |    |   |
|  |  +----------------------------------------------+  | |    |   |
|  |  |            DOCKER NETWORK                    |  | |    |   |
|  |  |            (n8n-network)                     |  | |    |   |
|  |  |                                              |  | |    |   |
|  |  |  +------------+  +------------+              |  | |    |   |
|  |  |  | postgres   |  |   redis    |              |  | |    |   |
|  |  |  |   :5445    |  |   :6386    |              |  | |    |   |
|  |  |  | (internal) |  | (internal) |              |  | |    |   |
|  |  |  +-----+------+  +-----+------+              |  | |    |   |
|  |  |        |               |                     |  | |    |   |
|  |  |        +-------+-------+                     |  | |    |   |
|  |  |                |                             |  | |    |   |
|  |  |  +-------------+-------------+               |  | |    |   |
|  |  |  |                           |               |  | |    |   |
|  |  |  v                           v               |  | |    |   |
|  |  |  +------------+  +------------+              |  | |    |   |
|  |  |  |  n8n-main  |  | n8n-worker |              |  | |    |   |
|  |  |  |   :5678 ───┼──┼────────────┼──────────────┼──┼─┘    |   |
|  |  |  | (exposed)  |  | (internal) |              |  |      |   |
|  |  |  +------------+  +------------+              |  |      |   |
|  |  |                                              |  |      |   |
|  |  |  +------------+  +------------+              |  |      |   |
|  |  |  | prometheus |  |  grafana   |              |  |      |   |
|  |  |  |   :9095    |  |   :3021 ───┼──────────────┼──┼──────┘   |
|  |  |  | (optional) |  | (optional) |              |  |          |
|  |  |  +------------+  +------------+              |  |          |
|  |  +----------------------------------------------+  |          |
|  +----------------------------------------------------+          |
+------------------------------------------------------------------+
```

---

## Port Conflict Prevention

### Why Non-Standard Ports?

| Standard Port | Common Conflicts | Our Port |
|---------------|------------------|----------|
| 5432 | pgAdmin, local PostgreSQL, DBeaver | **5445** |
| 6379 | Redis Desktop, other Redis instances | **6386** |
| 9090 | Prometheus from other stacks | **9095** |
| 9093 | Alertmanager from other stacks | **9096** |
| 3000 | React dev server, Grafana, other apps | **3021** |
| 9100 | Node exporter from other stacks | **9102** |
| 8081 | Many dev servers, proxies | **8092** |
| 9229 | Other Node.js debug sessions | **9230** |

### Checking for Conflicts

```bash
# Check if ports are in use (run from WSL2)
for port in 5678 5445 6386 9095 9096 3021 9102 8092 9230; do
  echo -n "Port $port: "
  if ss -tuln | grep -q ":$port "; then
    echo "IN USE"
  else
    echo "available"
  fi
done
```

### Quick Port Check Command

```bash
# Add to ~/.bashrc for convenience
alias check-n8n-ports='for p in 5678 5445 6386; do echo -n "$p: "; ss -tuln | grep -q ":$p " && echo "USED" || echo "free"; done'
```

---

## Service Connection Strings

### Internal Container Connections

```bash
# PostgreSQL (from n8n containers)
postgresql://n8n_user:password@postgres:5445/n8n

# Redis (from n8n containers)
redis://redis:6386
```

### External Connections (from Windows/WSL2)

```bash
# n8n Web UI
http://localhost:5678

# n8n Health Check
http://localhost:5678/healthz

# n8n Metrics (if enabled)
http://localhost:5678/metrics

# Grafana (if monitoring enabled)
http://localhost:3021

# PostgreSQL (direct access - not exposed by default)
# Would need to add port mapping: "5445:5445" to docker-compose.yml
# postgresql://n8n_user:password@localhost:5445/n8n
```

---

## Future Expansion Ports

Reserved for potential future services:

| Purpose | Reserved Port | Notes |
|---------|---------------|-------|
| SMTP Relay | 2526 | Local mail testing |
| pgAdmin | 5051 | Database management UI |
| Redis Commander | 8083 | Redis management UI |
| Webhook Testing | 8888 | Local webhook receiver |
| Backup Service | 8889 | Backup API endpoint |

---

## Firewall Configuration (If Needed)

### UFW Rules (Ubuntu)

```bash
# Allow n8n from localhost only
sudo ufw allow from 127.0.0.1 to any port 5678

# Allow Grafana from localhost only (if enabled)
sudo ufw allow from 127.0.0.1 to any port 3021

# Block external access to all other ports (default)
sudo ufw default deny incoming
```

---

## Quick Reference Card

```
+------------------------------------------+
|           n8n PORT QUICK REF             |
+------------------------------------------+
| SERVICE        | PORT  | ACCESS          |
|----------------|-------|-----------------|
| n8n UI/API     | 5678  | localhost       |
| PostgreSQL     | 5445  | docker internal |
| Redis          | 6386  | docker internal |
| Prometheus     | 9095  | localhost (opt) |
| Grafana        | 3021  | localhost (opt) |
| Alertmanager   | 9096  | docker (opt)    |
| Node Exporter  | 9102  | docker (opt)    |
+------------------------------------------+
| URLs:                                    |
|   n8n:     http://localhost:5678         |
|   Grafana: http://localhost:3021         |
|   Health:  http://localhost:5678/healthz |
+------------------------------------------+
```

---

## Changelog

| Date | Change | Reason |
|------|--------|--------|
| 2025-12-25 | Initial port assignment | Avoid conflicts with standard ports |
| 2025-12-25 | PostgreSQL: 5432 -> 5445 | Conflict with local dev databases |
| 2025-12-25 | Redis: 6379 -> 6386 | Conflict with other Redis instances |
| 2025-12-25 | Prometheus: 9090 -> 9095 | Conflict with other monitoring |
| 2025-12-25 | Alertmanager: 9093 -> 9096 | Conflict with other monitoring |
| 2025-12-25 | Grafana: 3000 -> 3021 | Conflict with dev servers |
| 2025-12-25 | Node Exporter: 9100 -> 9102 | Conflict with other exporters |
| 2025-12-25 | Dev Editor: 8081 -> 8092 | Conflict with proxies |
| 2025-12-25 | Debug: 9229 -> 9230 | Conflict with other debug |
