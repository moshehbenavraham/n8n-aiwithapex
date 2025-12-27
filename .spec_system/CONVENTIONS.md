# Project Conventions

## Directory Structure

```
/                       # Project root
├── scripts/            # Operational shell scripts
├── tests/              # BATS test files for shell scripts
├── config/             # Configuration files (postgres, etc.)
├── data/               # Persistent data volumes
├── backups/            # Backup storage (postgres/, redis/, n8n/, env/)
├── logs/               # Application and script logs
├── docs/               # Documentation
└── .spec_system/       # Spec system files
```

## Docker Conventions

### Container Naming
- All containers use `n8n-` prefix: `n8n-postgres`, `n8n-redis`, `n8n-main`, `n8n-worker`

### Service Dependencies
- Workers depend on n8n-main (service_healthy)
- n8n-main depends on postgres and redis (service_healthy)

### Health Checks
- All services define healthcheck with: test, interval, timeout, retries, start_period

## Shell Script Conventions

### File Header (required)
```bash
#!/bin/bash
# =============================================================================
# script-name.sh - Short Description
# =============================================================================
# Description: Detailed description of what the script does
# Usage: ./script-name.sh [options]
# Exit Codes: 0=success, 1=error
# =============================================================================
```

### Script Structure
1. `set -o pipefail` after shebang
2. Configuration section with SCRIPT_DIR, PROJECT_DIR
3. Source .env if needed: `source "${PROJECT_DIR}/.env"`
4. Function definitions (log_info, log_error, log_success, check_container)
5. Main function with argument parsing
6. Call `main "$@"` at end

### Logging Functions
```bash
log_info()    { echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') [script-name] $1" | tee -a "$LOG_FILE"; }
log_error()   { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') [script-name] $1" | tee -a "$LOG_FILE"; }
log_success() { echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') [script-name] $1" | tee -a "$LOG_FILE"; }
```

### Naming Conventions
- Backup scripts: `backup-{service}.sh`
- Status/monitoring: `{action}-{target}.sh` (e.g., `health-check.sh`, `view-logs.sh`)
- Variables: UPPER_SNAKE_CASE for globals, lower_snake_case for locals

### Exit Codes
- `0` = Success
- `1` = Error/failure
- `2` = Warning (partial success)

## Environment Variables

### Sections in .env
Group variables with section headers:
```bash
# ===========================================
# Service Configuration
# ===========================================
```

### Naming Pattern
- Database: `POSTGRES_*`, `DB_*`
- Redis: `REDIS_*`, `QUEUE_BULL_REDIS_*`
- n8n: `N8N_*`, `EXECUTIONS_*`, `WEBHOOK_*`

### Sensitive Values
- Never commit: passwords, encryption keys, API tokens
- Store in `.env` (gitignored)
- Keep `.env.bak` as template reference

## Backup Conventions

### Naming Format
- PostgreSQL: `n8n_YYYYMMDD_HHMMSS.sql.gz`
- Redis: `dump_YYYYMMDD_HHMMSS.rdb`
- n8n data: `n8n_data_YYYYMMDD_HHMMSS.tar.gz`

### Retention
- Managed by `cleanup-backups.sh`
- Default: keep last 7 days of backups

## Code Quality

### Required Tools
- **shellcheck**: Lint all .sh files (zero warnings policy)
- **shfmt**: Format shell scripts (consistent indentation with tabs)
- **yamllint**: Lint docker-compose.yml and YAML configs
- **bats**: Bash Automated Testing System for shell script tests

### Shell Script Formatting (shfmt)
All shell scripts must be formatted with shfmt before commit:
```bash
# Check formatting (dry-run)
shfmt -l -d scripts/*.sh

# Apply formatting
shfmt -w scripts/*.sh
```

### Pre-commit Checks
```bash
# Format scripts
shfmt -w scripts/*.sh

# Lint scripts
shellcheck scripts/*.sh

# Lint YAML
yamllint -c .yamllint.yaml docker-compose.yml

# Validate compose
docker compose config --quiet

# Run tests
bats tests/*.bats
```

## Testing Conventions

### BATS Test Framework
All shell scripts have corresponding test files in `tests/`:

| Script | Test File |
|--------|-----------|
| `scripts/backup-all.sh` | `tests/backup-all.bats` |
| `scripts/backup-postgres.sh` | `tests/backup-postgres.bats` |
| `scripts/health-check.sh` | `tests/health-check.bats` |

### Test File Structure
```bash
#!/usr/bin/env bats
# =============================================================================
# Tests for script-name.sh - Description
# =============================================================================

load 'test_helper'

setup() {
    common_setup
}

teardown() {
    common_teardown
}

@test "script-name: descriptive test name" {
    # Test implementation
    run some_function
    assert_success
    assert_output --partial "expected output"
}
```

### Test Helper (tests/test_helper.bash)
Provides common utilities:
- `common_setup` / `common_teardown`: Temp directory management
- `setup_docker_mock`: Mock Docker commands for isolated testing
- `setup_curl_mock`: Mock curl for endpoint testing
- `source_script_functions`: Load script functions for unit testing

### Running Tests
```bash
# Run all tests
bats tests/*.bats

# Run single test file
bats tests/backup-all.bats

# Run with verbose output
bats -v tests/*.bats

# Run specific test by name
bats -f "backup-all: log_info" tests/
```

### Test Categories
1. **Function Tests**: Test individual functions (log_*, check_*, etc.)
2. **Configuration Tests**: Verify default values and settings
3. **Integration Tests**: Test script syntax and executability
4. **Behavior Tests**: Verify script logic using grep patterns

## Git Conventions

### Commit Messages
- Use conventional format: `type: description`
- Types: feat, fix, docs, chore, refactor

### Branch Strategy
- `main`: Production-ready code
- Feature branches for new work
