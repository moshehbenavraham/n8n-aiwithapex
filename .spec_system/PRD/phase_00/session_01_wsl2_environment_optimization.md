# Session 01: WSL2 Environment Optimization

**Session ID**: `phase00-session01-wsl2-environment-optimization`
**Status**: Not Started
**Estimated Tasks**: ~15-20
**Estimated Duration**: 2-3 hours

---

## Important: WSL2 Ubuntu Only

**All commands and operations run exclusively from WSL2 Ubuntu.** There is no need for PowerShell or Windows Terminal. The Windows .wslconfig file is accessible via `/mnt/c/Users/$USER/.wslconfig` from within Ubuntu.

---

## Objective

Verify WSL2 is properly installed and configured, then optimize the environment for Docker container workloads with appropriate memory and CPU allocations.

---

## Scope

### In Scope (MVP)
- Verify WSL2 version and set as default (using `wsl.exe` from Ubuntu)
- Verify Ubuntu distribution version (22.04 or 24.04 LTS)
- Check current resource allocations
- Create optimized .wslconfig file with 8GB RAM and 4 CPU cores
- Configure swap and memory reclamation settings
- Apply configuration changes and restart WSL
- Verify new settings are active
- Document baseline system state

### Out of Scope
- Installing WSL2 from scratch (assumed already installed)
- Installing Ubuntu distribution (assumed already installed)
- Network configuration changes
- Systemd enablement (optional, not required for Docker)

---

## Prerequisites

- [ ] Windows 10/11 with WSL2 feature enabled (host requirement)
- [ ] Ubuntu 22.04 or 24.04 LTS installed in WSL2
- [ ] Write access to /mnt/c/Users/$USER/ for .wslconfig creation
- [ ] WSL2 Ubuntu terminal (all commands run here)

---

## Deliverables

1. Verified WSL2 version 2 as default
2. Documented Ubuntu distribution version
3. Created/updated `/mnt/c/Users/$USER/.wslconfig` with optimized settings
4. Applied memory allocation (8GB RAM recommended)
5. Applied CPU allocation (4 cores recommended)
6. Verified settings active after WSL restart
7. Baseline system resource documentation

---

## Technical Details

### .wslconfig Settings
```ini
[wsl2]
memory=8GB
processors=4
swap=2GB
localhostForwarding=true
```

### Creating .wslconfig from Ubuntu
```bash
# Get Windows username and create config
WIN_USER=$(cmd.exe /c echo %USERNAME% 2>/dev/null | tr -d '\r')
cat > "/mnt/c/Users/$WIN_USER/.wslconfig" << 'EOF'
[wsl2]
memory=8GB
processors=4
swap=2GB
localhostForwarding=true
EOF
```

### Verification Commands (all from Ubuntu)
- `wsl.exe --version` - Check WSL version
- `wsl.exe --list --verbose` - Check distributions and versions
- `cat /etc/os-release` - Verify Ubuntu version
- `free -h` - Verify memory allocation
- `nproc` - Verify CPU allocation

---

## Success Criteria

- [ ] WSL version 2 confirmed as default
- [ ] Ubuntu version verified (22.04 or 24.04 LTS)
- [ ] .wslconfig created at /mnt/c/Users/$USER/.wslconfig
- [ ] WSL restarted and new settings verified
- [ ] Memory shows 8GB (or user-specified) allocation
- [ ] CPU shows 4 cores (or user-specified) allocation
- [ ] Project location confirmed in Linux filesystem (/home/...)
