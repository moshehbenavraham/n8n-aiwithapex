# Contributing

Guidelines for maintaining and extending this n8n installation.

> **Custom Fork Optimized**: This deployment infrastructure is designed to run with our custom n8n fork at [github.com/moshehbenavraham/n8n](https://github.com/moshehbenavraham/n8n). See [Custom Fork Guide](docs/ongoing-roadmap/custom-fork.md) for fork development workflow and upstream sync procedures.

## Branch Conventions

- `main` - Production-ready configuration
- `feature/*` - New features or experiments
- `fix/*` - Bug fixes or configuration corrections

## Commit Style

Use conventional commits:
- `feat:` New feature or capability
- `fix:` Bug fix or correction
- `docs:` Documentation changes
- `refactor:` Code/config refactoring
- `chore:` Maintenance tasks

Examples:
```
feat: add prometheus metrics endpoint
fix: correct redis port in backup script
docs: update troubleshooting guide
chore: update n8n to 2.2.0
```

## Making Changes

### Configuration Changes

1. Back up current state: `./scripts/backup-all.sh`
2. Make changes to `.env` or `docker-compose.yml`
3. Validate configuration: `docker compose config`
4. Apply changes: `docker compose up -d`
5. Verify health: `./scripts/health-check.sh`
6. Commit with descriptive message

### Script Changes

1. Edit script in `scripts/` directory
2. Validate syntax: `bash -n scripts/<script>.sh`
3. Test script functionality
4. Ensure ASCII-only content
5. Commit changes

### Documentation Changes

1. Update relevant docs in `docs/` directory
2. Ensure links are valid
3. Keep content concise and current
4. Commit changes

## Testing

Before committing changes:

```bash
# Validate Docker configuration
docker compose config

# Check all services healthy
./scripts/health-check.sh

# Verify versions match pinned
./scripts/verify-versions.sh

# Run full status check
./scripts/system-status.sh
```

## File Standards

- **Line endings**: Unix LF only
- **Encoding**: ASCII (0-127) only
- **Permissions**: Scripts executable (755)
- **Secrets**: Never commit `.env` or credentials

## Related Documentation

- [Development Guide](docs/development.md)
- [Security Guide](docs/SECURITY.md)
- [Upgrade Procedures](docs/UPGRADE.md)
