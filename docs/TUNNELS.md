# Tunnel Configuration

This document describes the ngrok tunnel integration for external webhook access to n8n.

## Overview

ngrok provides a secure tunnel that forwards external HTTPS traffic to the n8n instance running inside Docker. This enables webhooks from external services (Slack, GitHub, payment processors, etc.) to reach n8n workflows.

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
| `config/ngrok.yml` | ngrok endpoint configuration (v3 format) |
| `config/ngrok.yml.v2.bak` | Backup of previous v2 configuration |
| `docker-compose.yml` | ngrok service definition |
| `.env` | Environment variables including ngrok settings |

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

### Tunnel Status Script

Check tunnel status:
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
# View ngrok logs
docker logs n8n-ngrok

# Restart tunnel
docker compose restart ngrok

# Check tunnel status
./scripts/tunnel-status.sh

# View live requests (requires jq)
curl -s http://localhost:4040/api/requests/http | jq '.requests[:5]'
```

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
