# PRD Phase 02: External Access and Tunnel Infrastructure

**Status**: Not Started
**Sessions**: 3
**Estimated Duration**: 1-2 days

**Progress**: 0/3 sessions (0%)

---

## Important: WSL2 Ubuntu Only

**All commands and operations run exclusively from WSL2 Ubuntu.** There is NO need for PowerShell, CMD, or Windows Terminal. Windows files are accessed via `/mnt/c/` from Ubuntu when needed.

---

## Overview

This phase establishes secure external access to the n8n stack deployed in Phase 00-01 using ngrok as a Docker sidecar container. It provides a stable, custom domain (n8n.aiwithapex.ngrok.dev) for webhook callbacks, implements OAuth authentication and IP restrictions via ngrok Traffic Policies, and designs an extensible architecture for future multi-service tunnel requirements. By the end of this phase, n8n webhooks will be accessible from the public internet while the UI remains protected by authentication.

---

## Progress Tracker

| Session | Name | Status | Est. Tasks | Validated |
|---------|------|--------|------------|-----------|
| 01 | ngrok Container and n8n Webhook Integration | Not Started | ~20-25 | - |
| 02 | Traffic Policies and OAuth Security | Not Started | ~15-20 | - |
| 03 | Multi-Service Architecture and Management | Not Started | ~15-20 | - |

---

## Objectives

1. Deploy ngrok as a Docker sidecar container integrated with the existing n8n Docker Compose stack
2. Configure n8n to use the custom ngrok domain (n8n.aiwithapex.ngrok.dev) for webhook URLs
3. Implement OAuth authentication via ngrok Traffic Policies to protect n8n UI access
4. Configure IP restrictions while allowing webhook traffic to pass through unrestricted
5. Design extensible multi-service tunnel architecture for future integrations (Ollama, APIs, etc.)
6. Create management scripts and documentation for tunnel operations

---

## Prerequisites

- Phase 00 completed (all 4 sessions) - Core infrastructure deployed
- Phase 01 completed (all 5 sessions) - Operations and optimization configured
- All containers running and healthy (postgres, redis, n8n, n8n-worker x5)
- n8n accessible at http://localhost:5678
- Queue mode verified functional
- ngrok paid plan active with custom domain capability
- ngrok authtoken available from dashboard (https://dashboard.ngrok.com)
- Custom domain (n8n.aiwithapex.ngrok.dev) configured in ngrok dashboard

---

## Technical Considerations

### Architecture

```
                                    Internet
                                        |
                                        v
                    +-------------------+-------------------+
                    |     ngrok Edge    |  Traffic Policies |
                    |  (SSL Termination)| (OAuth, IP Rules) |
                    +-------------------+-------------------+
                                        |
                    n8n.aiwithapex.ngrok.dev:443
                                        |
                                        v
+-----------------------------------------------------------------------+
|                           WSL2 Ubuntu                                  |
|  +------------------------------------------------------------------+ |
|  |                      Docker Network (n8n-network)                 | |
|  |                                                                   | |
|  |  +------------+  +------------+  +------------+  +-------------+ | |
|  |  |  ngrok     |  |   n8n      |  |  postgres  |  |    redis    | | |
|  |  |  container |->|   main     |  |  container |  |  container  | | |
|  |  |  (sidecar) |  | port 5678  |  |            |  |             | | |
|  |  +------------+  +------------+  +------------+  +-------------+ | |
|  |                        |                                          | |
|  |                  +------------+                                   | |
|  |                  | n8n-worker |                                   | |
|  |                  |  (x5)      |                                   | |
|  |                  +------------+                                   | |
|  +------------------------------------------------------------------+ |
+-----------------------------------------------------------------------+
```

### Technologies

- **ngrok/ngrok:alpine** - Official ngrok Docker image (lightweight Alpine variant)
- **ngrok Traffic Policies** - YAML-based rules for OAuth, IP restrictions, rate limiting
- **ngrok.yml** - Configuration file for tunnel definitions and policies
- **Docker Compose** - Sidecar integration with existing stack

### Key Environment Variables

```bash
# ngrok Configuration
NGROK_AUTHTOKEN=<from-ngrok-dashboard>
NGROK_DOMAIN=n8n.aiwithapex.ngrok.dev
NGROK_INSPECTOR_PORT=4040

# n8n Configuration Updates
WEBHOOK_URL=https://n8n.aiwithapex.ngrok.dev/
N8N_HOST=n8n.aiwithapex.ngrok.dev
N8N_PROTOCOL=https
N8N_SECURE_COOKIE=true
```

### Configuration Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| OAuth Provider | Google | Familiar, widely used, good security |
| Web Inspector | Enabled on port 4040 | Essential for debugging webhook traffic |
| IP Restrictions | None initially | OAuth provides sufficient protection; can add later |
| Health Check Integration | Yes | Unified monitoring via existing health-check.sh |

### Risks

- **Tunnel disconnection**: Network issues may disrupt external access. Mitigation: Health checks on ngrok container with automatic restart.
- **OAuth blocking webhooks**: Misconfigured traffic policies may reject valid webhook requests. Mitigation: Explicit passthrough rules for /webhook/ paths.
- **Authtoken exposure**: Leaked token allows unauthorized tunnel creation. Mitigation: Store in .env (gitignored), regenerate if compromised.
- **SSL certificate issues**: n8n may reject self-signed or misconfigured SSL. Mitigation: ngrok handles SSL termination with valid certificates.

### Relevant Considerations

From CONSIDERATIONS.md:
- [P00] **Secure cookie disabled**: N8N_SECURE_COOKIE=false for localhost. Must enable when using HTTPS via ngrok.
- [P00] **Service names as hostnames**: Use Docker service names for internal networking (n8n:5678).
- [P01] **Worker health endpoints**: Workers don't expose HTTP - only main instance needs ngrok tunnel.

---

## Session Details

### Session 01: ngrok Container and n8n Webhook Integration

**Objective**: Deploy ngrok as a Docker sidecar and configure n8n webhooks

**Key Deliverables**:
- ngrok service added to docker-compose.yml
- ngrok.yml configuration file with n8n tunnel
- Environment variable updates for WEBHOOK_URL, N8N_HOST, N8N_PROTOCOL
- Health check configuration for ngrok container
- Web inspector exposed on port 4040
- health-check.sh updated to include ngrok tunnel status
- Verification of webhook functionality through ngrok tunnel

**Tasks (~20-25)**:
1. Create config/ngrok.yml with basic tunnel configuration
2. Add ngrok service to docker-compose.yml as sidecar
3. Configure NGROK_AUTHTOKEN in .env
4. Configure NGROK_DOMAIN in .env
5. Configure NGROK_INSPECTOR_PORT=4040 in .env
6. Expose ngrok web inspector on port 4040 in docker-compose.yml
7. Update WEBHOOK_URL to use ngrok domain
8. Update N8N_HOST to use ngrok domain
9. Update N8N_PROTOCOL to https
10. Enable N8N_SECURE_COOKIE for HTTPS
11. Configure ngrok container health check
12. Add ngrok to n8n-network
13. Configure ngrok container restart policy
14. Test container startup and tunnel establishment
15. Verify ngrok web inspector accessible at http://localhost:4040
16. Verify n8n UI accessible via ngrok domain
17. Test webhook creation and callback
18. Verify webhook execution through tunnel
19. Document ngrok dashboard and inspector monitoring
20. Create tunnel status check script (scripts/tunnel-status.sh)
21. Update existing health-check.sh to include ngrok container and tunnel status
22. Test container restart and tunnel recovery
23. Document troubleshooting for common tunnel issues

---

### Session 02: Traffic Policies and Google OAuth Security

**Objective**: Implement Google OAuth authentication and traffic filtering

**Key Deliverables**:
- Traffic policy configuration file (policy.yml)
- Google OAuth integration via ngrok
- Webhook passthrough rules (no auth for /webhook/*)
- Security documentation

**Tasks (~15-20)**:
1. Research ngrok Google OAuth provider configuration
2. Create traffic policy YAML structure
3. Configure Google OAuth provider in ngrok dashboard
4. Create allow rule for /webhook/* paths (passthrough)
5. Create Google OAuth requirement for all other paths
6. Apply traffic policy to ngrok configuration
7. Test Google OAuth login flow for n8n UI
8. Test webhook passthrough without authentication
9. Verify unauthenticated requests blocked for non-webhook paths
10. Configure authorized Google accounts/domains (optional)
11. Test rate limiting configuration (optional)
12. Document Google OAuth setup and user management
13. Create policy update/reload procedure
14. Update SECURITY.md with ngrok OAuth considerations
15. Test policy changes without container restart
16. Document how to add IP restrictions later if needed

---

### Session 03: Multi-Service Architecture and Management

**Objective**: Design extensible tunnel architecture and management tools

**Key Deliverables**:
- Multi-tunnel configuration structure
- Tunnel management scripts
- Service discovery documentation
- Future service integration guide

**Tasks (~15-20)**:
1. Design multi-tunnel ngrok.yml structure
2. Create placeholder configurations for future services
3. Document tunnel naming conventions
4. Create tunnel start/stop management script
5. Create tunnel status dashboard script
6. Integrate tunnel logs with existing view-logs.sh
7. Document adding new services to tunnel config
8. Create tunnel backup in backup-all.sh
9. Document tunnel failover procedures
10. Create ngrok dashboard quick reference
11. Update RUNBOOK.md with tunnel operations
12. Update TROUBLESHOOTING.md with tunnel issues
13. Create TUNNELS.md documentation
14. Test multi-service configuration readiness
15. Document future Ollama/LLM tunnel considerations

---

## Success Criteria

Phase complete when:
- [ ] ngrok container running and healthy in Docker Compose stack
- [ ] n8n accessible via https://n8n.aiwithapex.ngrok.dev
- [ ] ngrok web inspector accessible at http://localhost:4040
- [ ] Webhooks functional through ngrok tunnel
- [ ] Google OAuth protecting n8n UI access
- [ ] Webhook paths (/webhook/*) passing through without authentication
- [ ] Tunnel status visible in health-check.sh output
- [ ] scripts/tunnel-status.sh created and functional
- [ ] Multi-service configuration structure documented
- [ ] Management scripts created and tested
- [ ] Documentation updated (SECURITY.md, RUNBOOK.md, TUNNELS.md)

---

## Dependencies

### Depends On
- Phase 00: Foundation and Core Infrastructure (complete)
- Phase 01: Operations and Optimization (complete)

### Enables
- External webhook integrations (Slack, GitHub, Telegram, etc.)
- Remote n8n access with authentication
- Future Ollama/LLM API exposure
- Multi-service tunnel management

---

## References

- [ngrok Docker Documentation](https://ngrok.com/docs/using-ngrok-with/docker)
- [ngrok n8n Integration Guide](https://ngrok.com/docs/universal-gateway/examples/n8n)
- [ngrok Traffic Policies](https://ngrok.com/docs/http/traffic-policy/)
- [n8n Webhook Configuration](https://docs.n8n.io/hosting/configuration/#webhook)
- [ngrok Blog: n8n + Docker + Ollama](https://ngrok.com/blog/self-hosted-local-ai-workflows-with-docker-n8n-ollama-and-ngrok-2025/)
