# System Baseline Documentation

**Session ID**: `phase00-session01-wsl2-environment-optimization`
**Captured**: 2025-12-25 11:24
**Purpose**: Document pre-optimization system state for reference

---

## WSL2 Version Information

| Component | Version |
|-----------|---------|
| WSL Version | 2.6.1.0 |
| Kernel Version | 6.6.87.2-1 |
| WSLg Version | 1.0.66 |
| Windows Version | 10.0.26200.7462 |

---

## Ubuntu Distribution

| Property | Value |
|----------|-------|
| Distribution | Ubuntu-24.04 |
| Pretty Name | Ubuntu 24.04.3 LTS |
| Version ID | 24.04 |
| Version Codename | noble |
| WSL Version | 2 |
| State | Running |
| Default Distribution | Yes |

---

## Pre-Optimization Resource Allocation

### Memory (Before .wslconfig)

```
               total        used        free      shared  buff/cache   available
Mem:            31Gi       7.6Gi        17Gi       220Mi       7.0Gi        23Gi
Swap:          8.0Gi          0B       8.0Gi
```

| Metric | Value |
|--------|-------|
| Total Memory | 31GB (default - using host maximum) |
| Total Swap | 8GB |

### CPU (Before .wslconfig)

| Metric | Value |
|--------|-------|
| Processors | 16 (default - using host maximum) |

---

## Post-Optimization Target Settings

### .wslconfig Location

`/mnt/c/Users/apexw/.wslconfig`

### Configuration Applied

```ini
[wsl2]
memory=8GB
processors=4
swap=2GB
localhostForwarding=true
```

### Expected Post-Restart Values

| Resource | Before | After | Change |
|----------|--------|-------|--------|
| Memory | 31GB | 8GB | -23GB |
| Processors | 16 | 4 | -12 |
| Swap | 8GB | 2GB | -6GB |

---

## Environment Verification

### Working Directory

- **Path**: `/home/aiwithapex/n8n`
- **Filesystem**: Linux native (ext4)
- **Status**: Verified as NOT on /mnt/c/

### Project Directory Contents

```
drwxr-xr-x .spec_system
-rw-r--r-- CLAUDE.md
drwxr-xr-x docs
```

---

## WSL Configuration Details

### Default Version
- WSL2 is the default version
- WSL1 is not supported on this machine configuration

### Networking
- localhost forwarding: Will be enabled after restart

---

## Notes

1. No existing .wslconfig was present before this session
2. Host system has ample resources (31GB RAM, 16 CPUs)
3. Optimization reduces WSL2 footprint for dedicated n8n workload
4. Settings require WSL restart (`wsl.exe --shutdown`) to apply

---

## Verification Commands Reference

```bash
# Check WSL version
wsl.exe --version

# Check WSL status
wsl.exe --status

# List distributions
wsl.exe --list --verbose

# Check Ubuntu version
cat /etc/os-release

# Check memory
free -h

# Check CPU count
nproc

# Restart WSL (apply .wslconfig)
wsl.exe --shutdown
```
