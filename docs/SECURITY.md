# Security Hardening Guide

Security configuration and hardening checklist for the n8n stack.

## Scope

This guide covers security for the n8n deployment running in WSL2 with external access via ngrok tunnel. The deployment uses a defense-in-depth approach with OAuth at the ngrok edge and n8n's built-in authentication.

## Current Security Status

| Area | Status | Notes |
|------|--------|-------|
| Image Versions | Pinned | n8n:2.1.4, postgres:16.11-alpine, redis:7.4.7-alpine |
| Network Exposure | Localhost + ngrok | Port 5678 local, HTTPS via ngrok tunnel |
| ngrok OAuth | Enabled | Google OAuth restricted to @aiwithapex.com, @apexwebservices.com |
| Webhook Access | Public | /webhook/* paths bypass OAuth for external services |
| Secure Cookie | Enabled | Required for HTTPS ngrok access |
| Secrets | .env file | Gitignored, local only |
| Database | Internal only | Port 5432 not exposed to host |
| Redis | Internal only | Port 6386 not exposed to host |

---

## Security Hardening Checklist

### Environment and Secrets

- [x] `.env` file is gitignored
- [x] `.env.example` contains no real secrets
- [x] N8N_ENCRYPTION_KEY is set and unique
- [x] POSTGRES_PASSWORD is strong (not default)
- [ ] Periodically rotate N8N_ENCRYPTION_KEY (requires credential re-encryption)
- [ ] Periodically rotate database password

### Docker Configuration

- [x] All images pinned to specific versions
- [x] No containers run as root (n8n uses node user)
- [x] Volumes use named volumes (not bind mounts with sensitive data)
- [x] Only necessary ports exposed (5678 for n8n UI)
- [x] Internal services (postgres, redis) not exposed to host

### Network Security

- [x] PostgreSQL port (5432) internal only
- [x] Redis port (6386) internal only
- [x] Services communicate over Docker bridge network
- [ ] Consider binding n8n to 127.0.0.1 instead of 0.0.0.0 for stricter localhost access

### Access Control

- [x] n8n has built-in user authentication enabled
- [x] Owner account created with strong password
- [x] ngrok OAuth enabled for external access
- [ ] Review user accounts periodically
- [ ] Remove unused/test accounts

---

## ngrok OAuth Security

The n8n UI is protected by Google OAuth at the ngrok edge, providing defense-in-depth security.

### Authentication Flow

```
User Request --> ngrok Edge --> Traffic Policy --> OAuth Check
                                                       |
                            +--------------------------+
                            |                          |
                      /webhook/*              All other paths
                            |                          |
                            v                          v
                     [Passthrough]            [Google OAuth]
                            |                          |
                            v                          v
                      n8n webhook              Google Login
                       handler                         |
                                                      v
                                              [Authenticated]
                                                      |
                                                      v
                                                 n8n UI
                                              (then n8n login)
```

### Configuration

OAuth is configured in `config/ngrok.yml` using Traffic Policy:

```yaml
traffic_policy:
  on_http_request:
    - name: "Require Google OAuth for UI access"
      expressions:
        - "!(req.url.path.startsWith('/webhook/') || req.url.path.startsWith('/webhook-test/'))"
      actions:
        - type: oauth
          config:
            provider: google
```

### Webhook Passthrough

Webhook paths are excluded from OAuth to allow external services to trigger workflows:

| Path Pattern | OAuth Required | Reason |
|--------------|----------------|--------|
| `/webhook/*` | No | Production webhook callbacks |
| `/webhook-test/*` | No | Test webhook callbacks |
| All other paths | Yes | UI and API access |

### Security Considerations

1. **Domain-restricted OAuth**: Only @aiwithapex.com and @apexwebservices.com Google accounts can access
2. **Defense in depth**: OAuth + n8n built-in auth = two authentication layers
3. **Webhook exposure**: Webhook paths are public; n8n handles webhook authentication via workflow configuration
4. **Session management**: OAuth sessions managed by ngrok (configurable timeout)

### Domain Restriction

Access is restricted to specific email domains via a traffic policy rule:

```yaml
# Rule 2: Deny access if email domain is not allowed
- name: "Restrict to allowed email domains"
  expressions:
    - "!(req.url.path.startsWith('/webhook/') || req.url.path.startsWith('/webhook-test/'))"
    - "!(actions.ngrok.oauth.identity.email.endsWith('@aiwithapex.com') || actions.ngrok.oauth.identity.email.endsWith('@apexwebservices.com'))"
  actions:
    - type: custom-response
      config:
        status_code: 403
        content: "Access denied. Only @aiwithapex.com and @apexwebservices.com email domains are allowed."
```

**Allowed domains**:
- `@aiwithapex.com`
- `@apexwebservices.com`

Users with other Google accounts will see a 403 error after OAuth login.

### Adding More Domains

To add additional allowed domains, edit `config/ngrok.yml` and add to the expression:

```yaml
expressions:
  - "!(actions.ngrok.oauth.identity.email.endsWith('@aiwithapex.com') || actions.ngrok.oauth.identity.email.endsWith('@apexwebservices.com') || actions.ngrok.oauth.identity.email.endsWith('@newdomain.com'))"
```

Then restart ngrok: `docker compose restart ngrok`

---

## Secure Cookie Configuration

### Current Setting

```bash
# .env
N8N_SECURE_COOKIE=true
```

Secure cookies are enabled because external access is via HTTPS (ngrok tunnel).

### Why Enabled

- **HTTPS via ngrok**: All external access uses `https://n8n.aiwithapex.ngrok.dev`
- **Cookie security**: Prevents session hijacking over insecure connections
- **Browser compatibility**: Modern browsers require Secure flag for cross-site cookies

### Local Development Note

When accessing n8n via `http://localhost:5678` (direct Docker access), login works because:
- Localhost is treated specially by browsers
- Cookies marked Secure can still be set over HTTP on localhost

---

## Network Exposure Considerations

### Current Localhost Configuration

```yaml
# docker-compose.yml
ports:
  - "${N8N_PORT}:5678"  # Binds to 0.0.0.0:5678
```

This binds to all interfaces. For WSL2, the Windows firewall typically blocks external access, but verify your configuration.

### Restricting to Localhost Only

To explicitly bind only to localhost:

```yaml
ports:
  - "127.0.0.1:${N8N_PORT}:5678"
```

### Before Exposing to Network

If you need to expose n8n to your network:

1. **Enable HTTPS** - Use a reverse proxy (nginx, traefik)
2. **Enable secure cookies** - Set `N8N_SECURE_COOKIE=true`
3. **Configure firewall** - Allow only necessary ports
4. **Use strong passwords** - For all n8n user accounts
5. **Consider IP allowlisting** - Limit access to known IPs

---

## Secrets Management

### Current Approach

Secrets stored in `.env` file:
- Gitignored to prevent accidental commits
- Readable only by local user
- Adequate for single-user localhost deployment

### Critical Secrets

| Secret | Location | Purpose |
|--------|----------|---------|
| N8N_ENCRYPTION_KEY | .env | Encrypts stored credentials |
| POSTGRES_PASSWORD | .env | Database authentication |
| User passwords | PostgreSQL | n8n user accounts |

### Key Rotation Procedure

#### N8N_ENCRYPTION_KEY Rotation

**Warning**: Changing this key requires re-entering all stored credentials.

1. Export workflows (optional backup)
2. Note all credentials that need re-entry
3. Stop n8n: `docker compose down`
4. Generate new key: `openssl rand -hex 32`
5. Update `.env` with new key
6. Start n8n: `docker compose up -d`
7. Re-enter all credentials in n8n UI

#### Database Password Rotation

1. Stop all services: `docker compose down`
2. Update POSTGRES_PASSWORD in `.env`
3. Connect to postgres and change password:
   ```bash
   docker compose up -d postgres
   docker exec -it n8n-postgres psql -U n8n -c "ALTER USER n8n PASSWORD 'newpassword';"
   ```
4. Start remaining services: `docker compose up -d`

---

## File Permissions

### Recommended Permissions

```bash
# .env file - owner read only
chmod 600 .env

# Scripts - owner execute
chmod 700 scripts/*.sh

# Config files - owner read only
chmod 600 config/*
```

### Verify Permissions

```bash
ls -la .env
# Should show: -rw------- (600)

ls -la scripts/
# Should show: -rwx------ (700) for .sh files
```

---

## Vulnerability Monitoring

### Image Updates

1. Check for updates periodically:
   ```bash
   docker pull n8nio/n8n:2.1.4
   docker pull postgres:16.11-alpine
   docker pull redis:7.4.7-alpine
   ```

2. Review n8n release notes before upgrading
3. Test upgrades in non-production first
4. See [UPGRADE.md](UPGRADE.md) for upgrade procedures

### Security Advisories

- n8n releases: https://github.com/n8n-io/n8n/releases
- PostgreSQL: https://www.postgresql.org/support/security/
- Redis: https://github.com/redis/redis/security/advisories

---

## Audit Checklist

Perform periodic security review:

### Monthly

- [ ] Review n8n user accounts
- [ ] Check for unused workflows with credentials
- [ ] Verify .env not committed to git: `git status`
- [ ] Check container logs for auth failures

### Quarterly

- [ ] Review image versions for security updates
- [ ] Rotate database password if needed
- [ ] Audit file permissions
- [ ] Review exposed ports: `docker compose ps`

### Annually

- [ ] Consider N8N_ENCRYPTION_KEY rotation
- [ ] Full security configuration review
- [ ] Update this documentation

---

## Related Documentation

- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues
- [UPGRADE.md](UPGRADE.md) - Version upgrade procedures
- [RECOVERY.md](RECOVERY.md) - Disaster recovery
