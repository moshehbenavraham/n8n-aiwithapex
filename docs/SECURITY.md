# Security Hardening Guide

Security configuration and hardening checklist for the n8n stack.

## Scope

This guide covers security for a **localhost-only** n8n deployment running in WSL2. Network-exposed deployments require additional measures (SSL/TLS, reverse proxy, firewall rules) not covered here.

## Current Security Status

| Area | Status | Notes |
|------|--------|-------|
| Image Versions | Pinned | n8n:2.1.4, postgres:16.11-alpine, redis:7.4.7-alpine |
| Network Exposure | Localhost only | Port 5678 bound to all interfaces |
| Secure Cookie | Disabled | Appropriate for HTTP localhost |
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
- [ ] Review user accounts periodically
- [ ] Remove unused/test accounts

---

## Secure Cookie Configuration

### Current Setting

```bash
# .env
N8N_SECURE_COOKIE=false
```

### When to Enable Secure Cookies

Enable secure cookies (`N8N_SECURE_COOKIE=true`) when:

1. **HTTPS is configured** - Either directly or via reverse proxy
2. **Network exposure** - n8n accessible from other machines
3. **Production internet access** - Any public-facing deployment

### How to Enable

1. Configure SSL/TLS termination (reverse proxy or direct)
2. Update `.env`:
   ```bash
   N8N_SECURE_COOKIE=true
   ```
3. Restart n8n:
   ```bash
   docker compose restart n8n
   ```

### Why Disabled for Localhost

Secure cookies require HTTPS. For localhost HTTP development:
- Browser would reject cookies with Secure flag over HTTP
- Login would fail repeatedly
- Appropriate to leave disabled for local development

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
