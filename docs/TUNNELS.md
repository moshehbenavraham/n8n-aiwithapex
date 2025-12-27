# Tunnel Configuration

This document describes the ngrok tunnel integration for external webhook access to n8n.

## Overview

ngrok provides a secure tunnel that forwards external HTTPS traffic to the n8n instance running inside Docker. This enables webhooks from external services (Slack, GitHub, payment processors, etc.) to reach n8n workflows.

The configuration uses a **multi-service architecture** that supports multiple endpoints with independent traffic policies. Each service can have its own custom domain and authentication rules.

## Architecture

```
                            Internet
                                |
                                v
              n8n.aiwithapex.ngrok.dev:443
                     (ngrok Edge)
                                |
                                v
+-------------------------------------------------------------------+
|                        WSL2 Ubuntu                                 |
|  +---------------------------------------------------------------+ |
|  |                 Docker Network (n8n-network)                  | |
|  |                                                               | |
|  |  +-----------+    +----------+    +----------+    +---------+ | |
|  |  |  ngrok    |--->|  n8n     |    | postgres |    |  redis  | | |
|  |  |  :4040    |    |  :5678   |    |          |    |  :6386  | | |
|  |  +-----------+    +----------+    +----------+    +---------+ | |
|  |                        |                                      | |
|  |                  +------------+                               | |
|  |                  | n8n-worker |                               | |
|  |                  |   (x5)     |                               | |
|  |                  +------------+                               | |
|  +---------------------------------------------------------------+ |
+-------------------------------------------------------------------+
```

## Configuration

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `NGROK_AUTHTOKEN` | ngrok authentication token | `your-authtoken` |
| `NGROK_DOMAIN` | Custom ngrok domain | `n8n.aiwithapex.ngrok.dev` |
| `NGROK_INSPECTOR_PORT` | Web inspector port | `4040` |
| `WEBHOOK_URL` | n8n webhook base URL | `https://n8n.aiwithapex.ngrok.dev/` |
| `N8N_HOST` | n8n host for URLs | `n8n.aiwithapex.ngrok.dev` |
| `N8N_PROTOCOL` | Protocol (http/https) | `https` |
| `N8N_SECURE_COOKIE` | Enable secure cookies | `true` |

### Files

| File | Purpose |
|------|---------|
| `config/ngrok.yml` | ngrok endpoint configuration (v3 multi-service format) |
| `config/ngrok.yml.v2.bak` | Backup of previous v2 configuration |
| `config/ngrok.yml.pre-multiservice.bak` | Backup of single-endpoint config |
| `docker-compose.yml` | ngrok service definition |
| `.env` | Environment variables including ngrok settings |
| `scripts/tunnel-manage.sh` | Unified tunnel management script |
| `scripts/tunnel-status.sh` | Tunnel status display (used by tunnel-manage.sh) |

### ngrok.yml Configuration (v3 Format)

The ngrok configuration uses v3 endpoints format (migrated from deprecated v2 tunnels format):

```yaml
version: 3

# Note: authtoken provided via NGROK_AUTHTOKEN env var in docker-compose.yml

endpoints:
  - name: n8n
    url: https://n8n.aiwithapex.ngrok.dev
    upstream:
      url: http://n8n:5678
    traffic_policy:
      on_http_request:
        # Rule 1: Require OAuth for non-webhook paths
        - name: "Require Google OAuth for UI access"
          expressions:
            - "!(req.url.path.startsWith('/webhook/') || req.url.path.startsWith('/webhook-test/'))"
          actions:
            - type: oauth
              config:
                provider: google

        # Rule 2: Restrict to allowed email domains
        - name: "Restrict to allowed email domains"
          expressions:
            - "!(req.url.path.startsWith('/webhook/') || req.url.path.startsWith('/webhook-test/'))"
            - "!(actions.ngrok.oauth.identity.email.endsWith('@aiwithapex.com') || actions.ngrok.oauth.identity.email.endsWith('@apexwebservices.com'))"
          actions:
            - type: custom-response
              config:
                status_code: 403
                content: "Access denied. Only allowed email domains permitted."
```

**Key Configuration Elements**:

| Element | Description |
|---------|-------------|
| `version: 3` | Uses v3 agent config format (v2 tunnels deprecated) |
| `agent.authtoken` | References `NGROK_AUTHTOKEN` environment variable |
| `endpoints` | Array of endpoint definitions (replaces `tunnels`) |
| `url` | Public HTTPS URL (combines v2 `proto` + `domain`) |
| `upstream.url` | Internal Docker service URL (replaces v2 `addr`) |
| `traffic_policy` | Defines request handling rules |

### Traffic Policy

The traffic policy implements OAuth-based access control:

- **Webhook paths** (`/webhook/*`, `/webhook-test/*`): Pass through without authentication
- **All other paths**: Require Google OAuth login

This is achieved using a CEL (Common Expression Language) expression that excludes webhook paths from the OAuth requirement.

## Setup

### Prerequisites

1. ngrok account with paid plan (for custom domain)
2. Custom domain configured in ngrok dashboard
3. Authtoken from https://dashboard.ngrok.com

### Configuration Steps

1. Set `NGROK_AUTHTOKEN` in `.env`
2. Set `NGROK_DOMAIN` to your custom domain
3. Update `WEBHOOK_URL`, `N8N_HOST`, `N8N_PROTOCOL`, `N8N_SECURE_COOKIE`
4. Start the stack: `docker compose up -d`

## Monitoring

### Tunnel Management Script

The unified tunnel-manage.sh script provides all tunnel operations:

```bash
# Check tunnel status
./scripts/tunnel-manage.sh status

# Start the tunnel
./scripts/tunnel-manage.sh start

# Stop the tunnel
./scripts/tunnel-manage.sh stop

# Restart the tunnel
./scripts/tunnel-manage.sh restart

# Show help
./scripts/tunnel-manage.sh --help
```

### Tunnel Status Script

For detailed status with JSON output:
```bash
./scripts/tunnel-status.sh
./scripts/tunnel-status.sh --json
```

### Health Check

The health-check.sh script includes ngrok tunnel verification:
```bash
./scripts/health-check.sh
```

### Web Inspector

Access the ngrok web inspector for request debugging:
- URL: http://localhost:4040
- Shows all requests through the tunnel
- Includes request/response bodies and headers

## Troubleshooting

### Tunnel Not Connecting

**Symptoms**: ngrok container exits or restarts repeatedly

**Checks**:
1. Verify authtoken is valid:
   ```bash
   docker logs n8n-ngrok
   ```
2. Check domain is configured in ngrok dashboard
3. Verify internet connectivity

### Webhook URLs Incorrect

**Symptoms**: n8n generates localhost URLs instead of ngrok domain

**Checks**:
1. Verify `.env` settings:
   ```bash
   grep -E "(WEBHOOK_URL|N8N_HOST|N8N_PROTOCOL)" .env
   ```
2. Restart n8n after environment changes:
   ```bash
   docker compose restart n8n
   ```

### Cookie/Session Issues

**Symptoms**: Cannot stay logged in, repeated login prompts

**Checks**:
1. Verify `N8N_SECURE_COOKIE=true` in `.env`
2. Ensure accessing via HTTPS (https://n8n.aiwithapex.ngrok.dev)

### Container Health Check Failing

**Symptoms**: ngrok container shows unhealthy

**Checks**:
1. Check ngrok API:
   ```bash
   curl -s http://localhost:4040/api/tunnels | jq
   ```
2. Verify port 4040 is not in use by another process

### API Unreachable

**Symptoms**: tunnel-status.sh shows API unreachable

**Checks**:
1. Verify container is running:
   ```bash
   docker ps | grep ngrok
   ```
2. Check inspector port binding:
   ```bash
   docker port n8n-ngrok
   ```

## Common Commands

```bash
# Tunnel management (preferred)
./scripts/tunnel-manage.sh start
./scripts/tunnel-manage.sh stop
./scripts/tunnel-manage.sh status
./scripts/tunnel-manage.sh restart

# View ngrok logs
./scripts/view-logs.sh -s ngrok
docker logs n8n-ngrok

# Check tunnel status
./scripts/tunnel-status.sh

# View live requests (requires jq)
curl -s http://localhost:4040/api/requests/http | jq '.requests[:5]'
```

## Multi-Service Architecture

The ngrok configuration supports multiple service endpoints. Each endpoint is defined with:

- **name**: Unique identifier for the endpoint
- **url**: Public ngrok custom domain URL
- **upstream**: Internal Docker service address
- **traffic_policy**: Per-endpoint authentication and access rules

### Current Endpoints

| Endpoint | URL | Backend | Status |
|----------|-----|---------|--------|
| n8n | https://n8n.aiwithapex.ngrok.dev | http://n8n:5678 | Active |
| ollama | https://ollama.aiwithapex.ngrok.dev | http://ollama:11434 | Template (inactive) |

### Adding New Services

To add a new service endpoint:

1. **Add Docker service** to docker-compose.yml
2. **Configure ngrok endpoint** in config/ngrok.yml:
   ```yaml
   - name: service-name
     url: https://service.yourdomain.ngrok.dev
     upstream:
       url: http://service:port
     traffic_policy:
       on_http_request:
         - name: "Require OAuth"
           expressions:
             - "true"
           actions:
             - type: oauth
               config:
                 provider: google
   ```
3. **Restart ngrok**: `./scripts/tunnel-manage.sh restart`
4. **Verify**: `./scripts/tunnel-manage.sh status`

### Ollama Integration (Future)

A template for Ollama LLM service is included but commented out. To enable:

1. Add Ollama service to docker-compose.yml
2. Configure ngrok custom domain for Ollama
3. Uncomment the Ollama endpoint in config/ngrok.yml
4. Update domain and settings as needed
5. Restart ngrok

**Memory Note**: Ollama requires 4GB+ RAM for most LLM models. Ensure WSL2 has sufficient memory allocation before enabling.

## Security Notes

- The ngrok authtoken should never be committed to version control
- The web inspector (port 4040) is only bound locally
- SSL termination happens at the ngrok edge
- Internal Docker traffic remains HTTP (n8n:5678)

### OAuth Authentication

The tunnel is protected by Google OAuth at the ngrok edge:

- **Defense in depth**: OAuth at ngrok edge + n8n built-in authentication
- **Webhook bypass**: `/webhook/*` and `/webhook-test/*` paths pass through without OAuth (required for external services to trigger workflows)
- **Domain restriction**: Only `@aiwithapex.com` and `@apexwebservices.com` Google accounts can access

Users with other Google accounts will be denied with HTTP 403 after OAuth login.

### Security Flow

```
External Request --> ngrok Edge
                         |
                         v
              +-------------------+
              | Traffic Policy    |
              | Evaluation        |
              +-------------------+
                    |         |
           /webhook/*       Other paths
                |                |
                v                v
          [PASSTHROUGH]    [OAuth Required]
                |                |
                v                v
          n8n Webhook      Google OAuth
          Handler          Login Flow
                                |
                                v
                          [Authenticated]
                                |
                                v
                           n8n UI Access
                           (then n8n login)
```
