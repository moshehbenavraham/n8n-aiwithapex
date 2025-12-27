# Session 02: Traffic Policies and OAuth Security

**Session ID**: `phase02-session02-traffic-policies-oauth`
**Status**: Not Started
**Estimated Tasks**: ~15-20
**Estimated Duration**: 2-3 hours

---

## Objective

Implement Google OAuth authentication via ngrok Traffic Policies to protect n8n UI access while allowing webhook traffic to pass through without authentication.

---

## Scope

### In Scope (MVP)
- Traffic policy YAML configuration file
- Google OAuth provider integration via ngrok
- Webhook passthrough rules (/webhook/* paths without auth)
- OAuth requirement for all non-webhook paths
- Security documentation updates

### Out of Scope
- IP restrictions (deferred - OAuth sufficient initially)
- Rate limiting (optional enhancement)
- Custom OAuth domains/user restrictions (optional enhancement)
- Multi-service traffic policies (Session 03)

---

## Prerequisites

- [ ] Session 01 completed (ngrok container running, tunnel functional)
- [ ] n8n accessible via ngrok domain (https://n8n.aiwithapex.ngrok.dev)
- [ ] ngrok web inspector working at http://localhost:4040
- [ ] Google account available for OAuth configuration
- [ ] Access to ngrok dashboard for OAuth provider setup

---

## Deliverables

1. `config/ngrok-policy.yml` or updated `config/ngrok.yml` with traffic policies
2. Google OAuth provider configured in ngrok dashboard
3. Updated `docs/SECURITY.md` with ngrok OAuth considerations
4. Policy update/reload procedure documented
5. Documentation for adding IP restrictions if needed later

---

## Success Criteria

- [ ] Google OAuth login required when accessing n8n UI via ngrok domain
- [ ] Successful OAuth login grants access to n8n UI
- [ ] /webhook/* paths accessible without authentication
- [ ] Unauthenticated requests to non-webhook paths blocked (401/403)
- [ ] Webhook callbacks continue to function after OAuth implementation
- [ ] OAuth flow documented with screenshots/steps
- [ ] SECURITY.md updated with ngrok security model
- [ ] Policy changes can be applied without full container restart
