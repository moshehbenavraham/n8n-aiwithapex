# Migration Guide: WSL2 to Coolify

This guide covers migrating from the WSL2 local deployment to the Coolify cloud deployment.

> **Custom Fork Optimized**: Both deployment forms support our custom n8n fork at [github.com/moshehbenavraham/n8n](https://github.com/moshehbenavraham/n8n). The migration process works identically for both official and custom fork images.

---

## Overview

| Source | Destination |
|--------|-------------|
| WSL2 Ubuntu (local) | Coolify (cloud) |
| https://your.ngrok.domain | https://n8n.aiwithapex.com |
| `docker-compose.yml` | `docker-compose.coolify.yml` |
| ngrok tunnel | Traefik reverse proxy |

See [Deployment Comparison](deployment-comparison.md) for detailed differences.

---

## Pre-Migration Checklist

### Critical: Encryption Key

The encryption key is essential for credential migration. Without it, all encrypted credentials become unrecoverable.

```bash
# Extract from WSL2 .env file
grep N8N_ENCRYPTION_KEY /home/aiwithapex/n8n/.env

# Store securely (do NOT commit to git)
# You will need this when configuring Coolify environment variables
```

### Backup Current Data

```bash
# Full backup of WSL2 deployment
./scripts/backup-all.sh

# Verify backup
ls -la backups/postgres/
ls -la backups/n8n/
```

### Document Current State

```bash
# List workflows
curl -X GET "http://localhost:5678/api/v1/workflows" \
  -H "X-N8N-API-KEY: <api-key>" | jq '.data | length'

# List credentials
curl -X GET "http://localhost:5678/api/v1/credentials" \
  -H "X-N8N-API-KEY: <api-key>" | jq '.data | length'

# Document webhook URLs currently in use
# (You'll need to update external services with new URLs)
```

### Verify Coolify Access

- [ ] Can access Coolify dashboard: https://coolify.aiwithapex.com
- [ ] Have API token for Coolify
- [ ] GitHub repository is accessible from Coolify
- [ ] DNS for new domain is configurable

---

## Migration Options

### Option A: Fresh Start (Recommended for Testing)

Best for: Testing the new deployment before full migration

1. Deploy new stack on Coolify (new domain)
2. Manually recreate critical workflows
3. Reconfigure credentials
4. Update external webhook URLs incrementally
5. Run both in parallel during transition
6. Decommission WSL2 when ready

**Pros**: Safe, no data corruption risk, can test thoroughly
**Cons**: Manual effort, requires re-entering credentials

### Option B: Database Migration

Best for: Large deployments with many workflows

1. Stop WSL2 deployment
2. Export PostgreSQL database
3. Deploy Coolify stack
4. Import database
5. Verify credentials decrypt properly
6. Update webhook URLs

**Pros**: Preserves all data including execution history
**Cons**: Downtime required, encryption key must match exactly

### Option C: API Export/Import

Best for: Clean migration of workflows only

1. Export workflows via API
2. Export credentials (encrypted)
3. Deploy Coolify stack
4. Import workflows
5. Re-enter credential values

**Pros**: Clean start, no database manipulation
**Cons**: Credentials must be re-entered, execution history lost

---

## Step-by-Step Migration (Option B: Database)

### Step 1: Prepare WSL2

```bash
cd /home/aiwithapex/n8n

# Stop all containers except PostgreSQL
docker compose stop n8n n8n-worker n8n-ngrok

# Create final backup
./scripts/backup-postgres.sh

# Export database
docker exec n8n-postgres pg_dump -U n8n n8n > migration-export.sql

# Verify export
head -50 migration-export.sql
wc -l migration-export.sql
```

### Step 2: Deploy Coolify Stack

Follow the [Deploy to Coolify](ongoing-roadmap/deploy-to-coolify.md) guide:

1. Create new application in Coolify
2. Connect to GitHub repository
3. Set compose file: `docker-compose.coolify.yml`
4. Configure environment variables:
   - `N8N_ENCRYPTION_KEY` = (same as WSL2)
   - `POSTGRES_DB` = n8n
5. Deploy (but don't start n8n yet)

### Step 3: Stop n8n Services on Coolify

```bash
# Via Coolify API or dashboard
# Stop n8n and worker containers, keep postgres running
```

### Step 4: Import Database

```bash
# Copy SQL file to Coolify server
scp migration-export.sql user@coolify-server:/tmp/

# SSH to Coolify server
ssh user@coolify-server

# Find postgres container
docker ps | grep postgres

# Import database
docker exec -i postgres-<uuid> psql -U n8n n8n < /tmp/migration-export.sql
```

### Step 5: Start n8n on Coolify

```bash
# Via Coolify dashboard or API
# Start n8n and worker containers
```

### Step 6: Verify Migration

```bash
# Check health
curl -s "https://n8n.aiwithapex.com/healthz"

# Login and verify:
# - Workflows appear
# - Credentials decrypt (test by viewing a credential)
# - Execute a test workflow
```

---

## Post-Migration Tasks

### Update Webhook URLs

External services calling webhooks must be updated:

| Service | Old URL | New URL |
|---------|---------|---------|
| GitHub Webhooks | https://your.ngrok.domain/webhook/... | https://n8n.aiwithapex.com/webhook/... |
| Stripe Webhooks | https://your.ngrok.domain/webhook/... | https://n8n.aiwithapex.com/webhook/... |
| Other Services | ... | ... |

### Update n8n Workflows

Some workflows may have hardcoded URLs:

1. Search workflows for `ngrok.dev`
2. Update to new Coolify domain
3. Save and test

### Decommission WSL2 Deployment

Once Coolify is verified working:

```bash
# On WSL2
cd /home/aiwithapex/n8n

# Final backup (keep for archive)
./scripts/backup-all.sh
cp -r backups/ ~/n8n-wsl2-archive/

# Stop all services
docker compose down

# Optionally remove volumes (destroys data!)
# docker compose down -v
```

---

## Rollback Procedure

If migration fails, rollback to WSL2:

### Immediate Rollback (Coolify Not Yet Primary)

```bash
# On WSL2 - restart services
cd /home/aiwithapex/n8n
docker compose up -d

# Verify
./scripts/health-check.sh
```

### Rollback After Cutover

If Coolify was primary and needs rollback:

1. Stop Coolify services
2. Export Coolify database (if any new data)
3. Import to WSL2 PostgreSQL
4. Start WSL2 services
5. Update external webhooks back to ngrok URL

---

## Environment Variable Mapping

| WSL2 (.env) | Coolify (UI) | Notes |
|-------------|--------------|-------|
| `N8N_ENCRYPTION_KEY` | `N8N_ENCRYPTION_KEY` | Must match exactly |
| `POSTGRES_USER` | `SERVICE_USER_POSTGRES` | Coolify auto-generates |
| `POSTGRES_PASSWORD` | `SERVICE_PASSWORD_POSTGRES` | Coolify auto-generates |
| `POSTGRES_DB` | `POSTGRES_DB` | Set manually (n8n) |
| `WEBHOOK_URL` | Auto via `SERVICE_FQDN_N8N` | Coolify injects |
| `N8N_HOST` | Auto via `SERVICE_URL_N8N` | Coolify injects |
| `NGROK_AUTHTOKEN` | N/A | Not needed (uses Traefik) |
| `NGROK_DOMAIN` | N/A | Not needed (uses Traefik) |

---

## Troubleshooting

### Credentials Won't Decrypt

**Cause**: Encryption key mismatch

**Solution**:
1. Verify `N8N_ENCRYPTION_KEY` in Coolify matches WSL2 exactly
2. Check for extra spaces or line breaks
3. Redeploy with correct key

### Database Import Fails

**Cause**: Version mismatch or connection issues

**Solution**:
```bash
# Check PostgreSQL versions match
docker exec n8n-postgres postgres --version  # WSL2
docker exec postgres-<uuid> postgres --version  # Coolify

# Try pg_dump with --no-owner
docker exec n8n-postgres pg_dump -U n8n --no-owner n8n > migration-export.sql
```

### Webhooks Not Working

**Cause**: Domain not configured or DNS not propagated

**Solution**:
1. Verify DNS: `nslookup n8n.aiwithapex.com`
2. Check Coolify domain settings
3. Verify Traefik is routing correctly
4. Check n8n logs for errors

### Workers Not Processing

**Cause**: Redis connection issues

**Solution**:
```bash
# Check Redis is running
docker exec redis-<uuid> redis-cli ping

# Check worker logs
docker logs n8n-worker-1-<uuid>

# Verify queue settings in environment
```

---

## Related Documentation

- [Deployment Comparison](deployment-comparison.md) - WSL2 vs Coolify details
- [Deploy to Coolify](ongoing-roadmap/deploy-to-coolify.md) - Full Coolify setup guide
- [RECOVERY.md](RECOVERY.md) - Disaster recovery procedures
- [Environments](environments.md) - Configuration reference
