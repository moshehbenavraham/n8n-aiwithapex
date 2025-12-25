# Session Specification

**Session ID**: `phase00-session01-wsl2-environment-optimization`
**Phase**: 00 - Foundation and Core Infrastructure
**Status**: Not Started
**Created**: 2025-12-25

---

## Important: WSL2 Ubuntu Only

**This entire project runs exclusively through WSL2 Ubuntu.** All commands, file operations, and configurations are executed from within the Ubuntu terminal. There is NO need for PowerShell or Windows Terminal - everything is done from WSL2 Ubuntu.

---

## 1. Session Overview

This session establishes the foundational WSL2 environment required for running a production-grade n8n installation with Docker containers. WSL2 (Windows Subsystem for Linux 2) provides a native Linux kernel running on Windows, enabling near-native Linux performance for Docker workloads. However, by default WSL2 may not allocate sufficient resources for running multiple containers simultaneously.

The session focuses on verifying the existing WSL2 and Ubuntu installation, then optimizing resource allocation to ensure adequate memory (8GB), CPU cores (4), and swap space (2GB) for the n8n stack. These optimizations are critical because the full deployment will include PostgreSQL, Redis, n8n main instance, and n8n worker containers running concurrently.

This is the first session in Phase 00 and serves as the foundation for all subsequent sessions. Without proper WSL2 configuration, Docker installation (Session 02) may fail or perform poorly, and the container workloads may experience memory pressure or CPU throttling.

---

## 2. Objectives

1. Verify WSL2 is installed and configured as the default WSL version
2. Confirm Ubuntu 22.04 or 24.04 LTS is installed and accessible
3. Create or update the .wslconfig file with optimized resource settings (via /mnt/c/ path)
4. Apply and verify the new resource allocations are active in the WSL2 environment

---

## 3. Prerequisites

### Required Sessions
- None (this is the foundation session)

### Required Tools/Knowledge
- WSL2 Ubuntu terminal (all commands run here)
- Basic familiarity with Linux command-line operations
- Understanding of Linux resource commands (free, nproc)

### Environment Requirements
- Windows 10 version 2004+ or Windows 11 (host OS)
- WSL2 feature enabled in Windows
- Ubuntu 22.04 or 24.04 LTS distribution installed
- Minimum 16GB system RAM recommended (to allocate 8GB to WSL2)
- Minimum 4 CPU cores on host system

---

## 4. Scope

### In Scope (MVP)
- Verify WSL version using `wsl.exe --version` (run from Ubuntu)
- Verify Ubuntu distribution version using `cat /etc/os-release`
- Check current resource allocations (memory with `free -h`, CPU with `nproc`)
- Create `.wslconfig` file at `/mnt/c/Users/$USER/.wslconfig` (from Ubuntu)
- Configure memory allocation (8GB)
- Configure CPU/processor allocation (4 cores)
- Configure swap space (2GB)
- Enable localhost forwarding for container access
- Restart WSL to apply configuration changes
- Verify new resource allocations are active
- Document baseline system state for reference
- Verify project directory is in Linux filesystem (not /mnt/c/)

### Out of Scope (Deferred)
- Installing WSL2 from scratch - *Reason: Assumed already installed per PRD*
- Installing Ubuntu distribution - *Reason: Assumed already installed per PRD*
- Network configuration changes - *Reason: Default networking sufficient for localhost*
- Systemd enablement - *Reason: Not required for Docker Engine operation*
- GPU passthrough configuration - *Reason: Not needed for n8n workloads*
- WSL2 kernel updates - *Reason: Default kernel sufficient*

---

## 5. Technical Approach

### Architecture
The WSL2 environment runs as a lightweight virtual machine with a real Linux kernel. Resource allocation is controlled via the `.wslconfig` file located at `/mnt/c/Users/<username>/.wslconfig` (accessible from Ubuntu). This file is read when WSL starts and cannot be changed while WSL is running.

```
Windows Host (accessed via /mnt/c/ from Ubuntu)
+------------------------------------------+
|  /mnt/c/Users/$USER/.wslconfig           |
|  [wsl2]                                  |
|  memory=8GB                              |
|  processors=4                            |
|  swap=2GB                                |
|  localhostForwarding=true                |
+------------------------------------------+
          |
          v
+------------------------------------------+
|  WSL2 VM (Hyper-V)                       |
|  +------------------------------------+  |
|  |  Ubuntu 22.04/24.04 LTS            |  |
|  |  - 8GB RAM allocated               |  |
|  |  - 4 CPU cores                     |  |
|  |  - 2GB swap                        |  |
|  |  - /home/aiwithapex/n8n (project)  |  |
|  +------------------------------------+  |
+------------------------------------------+
```

### Design Patterns
- **Infrastructure as Code**: Configuration stored in .wslconfig file for reproducibility
- **Verification-First**: Check current state before making changes
- **Idempotent Operations**: Running session multiple times produces same result

### Technology Stack
- WSL2 (Windows Subsystem for Linux 2)
- Ubuntu 22.04 LTS or 24.04 LTS
- Bash shell (all commands run from Ubuntu terminal)

---

## 6. Deliverables

### Files to Create
| File | Purpose | Est. Lines |
|------|---------|------------|
| `/mnt/c/Users/$USER/.wslconfig` | WSL2 resource configuration | ~6 |
| `.spec_system/specs/phase00-session01-wsl2-environment-optimization/baseline.md` | System baseline documentation | ~50 |

### Files to Modify
| File | Changes | Est. Lines |
|------|---------|------------|
| None | N/A | N/A |

### Commands to Execute (All from Ubuntu)
| Command | Purpose |
|---------|---------|
| `wsl.exe --version` | Verify WSL version |
| `wsl.exe --status` | Check WSL status and default version |
| `wsl.exe --list --verbose` | List distributions with versions |
| `cat /etc/os-release` | Verify Ubuntu version |
| `free -h` | Check memory allocation |
| `nproc` | Check CPU allocation |
| `wsl.exe --shutdown` | Restart WSL to apply changes (terminates session) |

---

## 7. Success Criteria

### Functional Requirements
- [ ] WSL version command returns version 2.x.x or higher
- [ ] WSL status shows WSL2 as default version
- [ ] Ubuntu distribution shows version 22.04 or 24.04 LTS
- [ ] .wslconfig file exists at /mnt/c/Users/$USER/.wslconfig
- [ ] .wslconfig contains memory=8GB setting
- [ ] .wslconfig contains processors=4 setting
- [ ] .wslconfig contains swap=2GB setting
- [ ] .wslconfig contains localhostForwarding=true setting
- [ ] After restart, `free -h` shows approximately 8GB total memory
- [ ] After restart, `nproc` returns 4
- [ ] Current working directory is in Linux filesystem (/home/...)
- [ ] Project directory /home/aiwithapex/n8n exists and is accessible

### Testing Requirements
- [ ] All verification commands execute without errors
- [ ] Memory and CPU values match configuration after restart

### Quality Gates
- [ ] All configuration files use ASCII-only characters
- [ ] Unix LF line endings in any created Linux files
- [ ] Baseline documentation is complete and accurate

---

## 8. Implementation Notes

### Key Considerations
- The .wslconfig file is created via `/mnt/c/Users/$USER/` path from Ubuntu
- Changes to .wslconfig require a full WSL restart (`wsl.exe --shutdown`)
- Running `wsl.exe --shutdown` from within Ubuntu will terminate your current session
- After shutdown, simply open a new Ubuntu terminal to restart WSL with new settings
- Memory allocation should not exceed 50-75% of host system RAM
- If host has fewer than 4 cores, adjust processors setting accordingly

### Potential Challenges
- **Insufficient host RAM**: If host has less than 12GB RAM, reduce WSL2 allocation to 4-6GB
- **Existing .wslconfig**: May need to merge settings with existing configuration
- **Finding Windows username**: Use `cmd.exe /c echo %USERNAME%` or check `/mnt/c/Users/` directory

### ASCII Reminder
All output files must use ASCII-only characters (0-127). The .wslconfig file uses standard INI format with ASCII characters only.

---

## 9. Testing Strategy

### Unit Tests
- N/A (configuration session, no code to unit test)

### Integration Tests
- N/A (configuration session)

### Manual Testing (All from Ubuntu terminal)
1. Run `wsl.exe --version` and verify output shows 2.x.x
2. Run `wsl.exe --status` and verify "Default Version: 2"
3. Run `wsl.exe --list --verbose` and verify Ubuntu shows VERSION 2
4. Run `cat /etc/os-release` and verify VERSION_ID is 22.04 or 24.04
5. Run `free -h` and verify total memory is approximately 8GB
6. Run `nproc` and verify output is 4
7. Run `pwd` and verify path starts with /home/ (not /mnt/c/)

### Edge Cases
- Host system has less than 16GB RAM (adjust memory setting)
- Host system has fewer than 4 CPU cores (adjust processors setting)
- Existing .wslconfig with conflicting settings (merge carefully)
- Multiple Ubuntu distributions installed (verify correct one is default)

---

## 10. Dependencies

### External Libraries
- None

### System Dependencies
- Windows 10 version 2004+ or Windows 11 (host OS)
- WSL2 Windows feature enabled
- Hyper-V Windows feature enabled (for WSL2)

### Other Sessions
- **Depends on**: None (foundation session)
- **Depended by**:
  - `phase00-session02-docker-engine-installation` (requires optimized WSL2)
  - All subsequent Phase 00 sessions
  - All Phase 01 sessions

---

## 11. Reference Commands

All commands are executed from the Ubuntu terminal within WSL2.

### WSL Management Commands (from Ubuntu)
```bash
# Check WSL version
wsl.exe --version

# Check WSL status and default version
wsl.exe --status

# List all distributions with their WSL versions
wsl.exe --list --verbose

# Shutdown WSL completely (required after .wslconfig changes)
# WARNING: This will terminate your current Ubuntu session
wsl.exe --shutdown

# Set WSL2 as default (if needed)
wsl.exe --set-default-version 2
```

### System Verification Commands (from Ubuntu)
```bash
# Check Ubuntu version
cat /etc/os-release

# Check memory allocation
free -h

# Check CPU count
nproc

# Check current directory is in Linux filesystem
pwd
# Should return /home/... not /mnt/c/...

# Check project directory
ls -la /home/aiwithapex/n8n

# Find Windows username for .wslconfig path
ls /mnt/c/Users/
# Or use: cmd.exe /c echo %USERNAME%
```

### Creating .wslconfig (from Ubuntu)
```bash
# Determine Windows user directory
WIN_USER=$(cmd.exe /c echo %USERNAME% 2>/dev/null | tr -d '\r')

# Create or overwrite .wslconfig
cat > "/mnt/c/Users/$WIN_USER/.wslconfig" << 'EOF'
[wsl2]
memory=8GB
processors=4
swap=2GB
localhostForwarding=true
EOF

# Verify file was created
cat "/mnt/c/Users/$WIN_USER/.wslconfig"
```

### .wslconfig Template
```ini
[wsl2]
memory=8GB
processors=4
swap=2GB
localhostForwarding=true
```

---

## Next Steps

Run `/tasks` to generate the implementation task checklist.
