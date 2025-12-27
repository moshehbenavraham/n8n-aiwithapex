# Session 01: ngrok Container and n8n Webhook Integration

**Session ID**: `phase02-session01-ngrok-webhook-integration`
**Status**: Not Started
**Estimated Tasks**: ~20-25
**Estimated Duration**: 2-4 hours

---

## Objective

Deploy ngrok as a Docker sidecar container integrated with the existing n8n stack and configure n8n webhooks to use the custom ngrok domain (n8n.aiwithapex.ngrok.dev).

---

## Scope

### In Scope (MVP)
- ngrok service added to docker-compose.yml as sidecar container
- ngrok.yml configuration file with n8n tunnel definition
- NGROK_AUTHTOKEN and NGROK_DOMAIN configuration in .env
- Environment variable updates (WEBHOOK_URL, N8N_HOST, N8N_PROTOCOL, N8N_SECURE_COOKIE)
- Health check configuration for ngrok container
- ngrok web inspector exposed on port 4040
- health-check.sh updated to include ngrok tunnel status
- scripts/tunnel-status.sh created
- Webhook functionality verified through ngrok tunnel

### Out of Scope
- Traffic policies (Session 02)
- OAuth authentication (Session 02)
- IP restrictions (Session 02)
- Multi-service tunnel configuration (Session 03)
- Tunnel management scripts beyond basic status (Session 03)

---

## Prerequisites

- [ ] Phase 00 and 01 completed (all 9 sessions)
- [ ] All containers running and healthy (postgres, redis, n8n, n8n-worker x5)
- [ ] n8n accessible at http://localhost:5678
- [ ] ngrok paid plan active with custom domain capability
- [ ] ngrok authtoken available from dashboard (https://dashboard.ngrok.com)
- [ ] Custom domain (n8n.aiwithapex.ngrok.dev) configured in ngrok dashboard

---

## Deliverables

1. `config/ngrok.yml` - ngrok tunnel configuration file
2. Updated `docker-compose.yml` with ngrok sidecar service
3. Updated `.env` with ngrok and n8n HTTPS configuration
4. `scripts/tunnel-status.sh` - tunnel status check script
5. Updated `scripts/health-check.sh` with ngrok status
6. `docs/TUNNELS.md` - initial tunnel documentation (basic setup)

---

## Success Criteria

- [ ] ngrok container running and healthy in Docker Compose stack
- [ ] ngrok service on n8n-network communicating with n8n container
- [ ] n8n UI accessible via https://n8n.aiwithapex.ngrok.dev
- [ ] ngrok web inspector accessible at http://localhost:4040
- [ ] Webhooks create URLs using ngrok domain
- [ ] Webhook callbacks successfully routed through tunnel to n8n
- [ ] health-check.sh shows ngrok container and tunnel status
- [ ] tunnel-status.sh provides detailed tunnel information
- [ ] Container restart results in automatic tunnel recovery
