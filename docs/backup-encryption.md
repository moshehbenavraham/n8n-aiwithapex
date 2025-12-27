# Backup Encryption and Off-site Storage

This document describes the backup encryption and off-site storage features added in Phase 03.

## Overview

The backup system now supports:
- **GPG symmetric encryption** for all backup files
- **Off-site cloud storage** via rclone (S3, Backblaze B2, and 40+ providers)
- **Automated scheduling** via cron

## Prerequisites

### GPG (pre-installed on most systems)

```bash
# Verify GPG is installed
gpg --version
```

### rclone

```bash
# Install rclone
curl https://rclone.org/install.sh | sudo bash

# Verify installation
rclone version
```

## Configuration

### 1. Set Encryption Passphrase

Add to your `.env` file:

```bash
# Generate a secure passphrase
openssl rand -base64 32

# Add to .env
BACKUP_GPG_PASSPHRASE=<your-generated-passphrase>
```

**Important:**
- Use at least 16 characters (32+ recommended)
- Store the passphrase securely - losing it makes backups unrecoverable
- Never commit the passphrase to version control

### 2. Configure rclone Remote

Run interactive configuration:

```bash
rclone config
```

Or copy the template:

```bash
cp config/rclone.conf.example ~/.config/rclone/rclone.conf
# Edit with your credentials
nano ~/.config/rclone/rclone.conf
```

### 3. Set Off-site Variables

Add to your `.env` file:

```bash
# rclone remote name (from rclone config)
RCLONE_REMOTE=n8n-backup

# Bucket/container name
RCLONE_BUCKET=n8n-backups

# Only sync encrypted files (recommended)
RCLONE_SYNC_ENCRYPTED_ONLY=true
```

## Usage

### Encrypted Backups

Run the standard backup script - encryption happens automatically if `BACKUP_GPG_PASSPHRASE` is set:

```bash
./scripts/backup-all.sh
```

This creates:
- `backups/postgres/n8n_YYYYMMDD_HHMMSS.sql.gz` (original)
- `backups/postgres/n8n_YYYYMMDD_HHMMSS.sql.gz.gpg` (encrypted)
- `backups/redis/dump_YYYYMMDD_HHMMSS.rdb` (original)
- `backups/redis/dump_YYYYMMDD_HHMMSS.rdb.gpg` (encrypted)
- `backups/n8n/n8n_data_YYYYMMDD_HHMMSS.tar.gz` (original)
- `backups/n8n/n8n_data_YYYYMMDD_HHMMSS.tar.gz.gpg` (encrypted)

### Off-site Sync

Sync encrypted backups to cloud storage:

```bash
# Preview what would be synced
./scripts/backup-offsite.sh --dry-run

# Perform actual sync
./scripts/backup-offsite.sh
```

### Restoring from Encrypted Backups

All restore scripts support both encrypted and unencrypted files:

```bash
# Restore PostgreSQL (encrypted)
./scripts/restore-postgres.sh backups/postgres/n8n_20250101_020000.sql.gz.gpg

# Restore Redis (encrypted)
./scripts/restore-redis.sh backups/redis/dump_20250101_020000.rdb.gpg

# Restore n8n data (encrypted)
./scripts/restore-n8n.sh backups/n8n/n8n_data_20250101_020000.tar.gz.gpg
```

## Cron Job Setup

### Recommended Schedule

Add to crontab (`crontab -e`):

```bash
# =============================================================================
# n8n Backup Schedule
# =============================================================================

# Daily encrypted backup at 2:00 AM
0 2 * * * /home/user/n8n/scripts/backup-all.sh >> /home/user/n8n/logs/cron.log 2>&1

# Off-site sync at 3:00 AM (after backups complete)
0 3 * * * /home/user/n8n/scripts/backup-offsite.sh >> /home/user/n8n/logs/cron.log 2>&1

# Weekly cleanup of old backups (Sunday at 1:00 AM)
0 1 * * 0 /home/user/n8n/scripts/cleanup-backups.sh >> /home/user/n8n/logs/cron.log 2>&1
```

### Environment Variables in Cron

Cron runs with a minimal environment. Ensure your scripts source `.env`:

```bash
# The scripts already source .env, but you can also add to crontab:
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

### Verify Cron is Running

```bash
# Check cron service
sudo systemctl status cron

# View recent cron executions
grep CRON /var/log/syslog | tail -20

# View backup logs
tail -f /home/user/n8n/logs/cron.log
```

## Manual Encryption/Decryption

### Encrypt a File

```bash
gpg --symmetric --cipher-algo AES256 --output file.gpg file
```

### Decrypt a File

```bash
gpg --decrypt --output file file.gpg
```

### Verify Encrypted File

```bash
# Check if file is GPG encrypted
file backup.sql.gz.gpg
# Output: backup.sql.gz.gpg: GPG symmetrically encrypted data (AES256 cipher)
```

## Cloud Storage Providers

### Amazon S3

```ini
[n8n-backup]
type = s3
provider = AWS
access_key_id = YOUR_ACCESS_KEY
secret_access_key = YOUR_SECRET_KEY
region = us-east-1
```

### Backblaze B2

```ini
[n8n-backup]
type = b2
account = YOUR_ACCOUNT_ID
key = YOUR_APPLICATION_KEY
```

### DigitalOcean Spaces

```ini
[n8n-backup]
type = s3
provider = DigitalOcean
access_key_id = YOUR_SPACES_KEY
secret_access_key = YOUR_SPACES_SECRET
endpoint = nyc3.digitaloceanspaces.com
```

### Wasabi (S3-compatible, no egress fees)

```ini
[n8n-backup]
type = s3
provider = Wasabi
access_key_id = YOUR_ACCESS_KEY
secret_access_key = YOUR_SECRET_KEY
endpoint = s3.wasabisys.com
```

## Troubleshooting

### "BACKUP_GPG_PASSPHRASE not set"

Ensure the variable is set in `.env`:

```bash
grep BACKUP_GPG_PASSPHRASE .env
```

### "rclone remote not configured"

Run `rclone config` and set up the remote named in `RCLONE_REMOTE`.

### "Cannot connect to remote"

```bash
# Test remote access
rclone lsd n8n-backup:

# Check bucket exists
rclone ls n8n-backup:your-bucket/
```

### "Failed to decrypt backup file"

- Verify you're using the correct passphrase
- Check the file is actually GPG encrypted: `file backup.gpg`
- Try manual decryption: `gpg -d backup.gpg`

### Cron Not Running

```bash
# Check cron service
sudo systemctl status cron

# Check permissions
ls -la /home/user/n8n/scripts/backup-all.sh

# Test script manually
/home/user/n8n/scripts/backup-all.sh
```

## Security Best Practices

1. **Passphrase Storage**: Keep `BACKUP_GPG_PASSPHRASE` only in `.env` (gitignored)
2. **Key Rotation**: Change passphrase periodically and re-encrypt old backups
3. **Access Control**: Restrict cloud bucket permissions to list, read, write, delete
4. **Retention**: Configure cloud bucket lifecycle rules to match local retention
5. **Testing**: Regularly test restore procedures from encrypted backups

## File Reference

| File | Purpose |
|------|---------|
| `scripts/backup-all.sh` | Creates backups with optional encryption |
| `scripts/backup-offsite.sh` | Syncs encrypted backups to cloud |
| `scripts/restore-postgres.sh` | Restores PostgreSQL (supports .gpg) |
| `scripts/restore-redis.sh` | Restores Redis (supports .gpg) |
| `scripts/restore-n8n.sh` | Restores n8n data (supports .gpg) |
| `config/rclone.conf.example` | rclone configuration template |
| `.env` | Contains `BACKUP_GPG_PASSPHRASE` and `RCLONE_*` vars |
