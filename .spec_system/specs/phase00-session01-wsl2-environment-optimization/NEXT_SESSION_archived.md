# NEXT_SESSION.md

## Session Recommendation

**Generated**: 2025-12-25
**Project State**: Phase 00 - Foundation and Core Infrastructure
**Completed Sessions**: 0

---

## Important: WSL2 Ubuntu Only

**All commands run exclusively from WSL2 Ubuntu.** There is no need for PowerShell or Windows Terminal.

---

## Recommended Next Session

**Session ID**: `phase00-session01-wsl2-environment-optimization`
**Session Name**: WSL2 Environment Optimization
**Estimated Duration**: 2-3 hours
**Estimated Tasks**: 15-20

---

## Why This Session Next?

### Prerequisites Met
- [x] Windows 10/11 with WSL2 feature enabled (host requirement)
- [x] Ubuntu 22.04 or 24.04 LTS installed in WSL2 (environmental)
- [x] Write access to /mnt/c/Users/$USER/ for .wslconfig (from Ubuntu)
- [x] WSL2 Ubuntu terminal access (all commands run here)

### Dependencies
- **Builds on**: Nothing (foundation session)
- **Enables**: Session 02 (Docker Engine Installation), and all subsequent sessions

### Project Progression
This is the foundational first session of Phase 00. The WSL2 environment must be verified and optimized before Docker can be installed. Session 02 explicitly lists "Session 01 completed (WSL2 optimized)" as a prerequisite. Starting here ensures the host environment is properly configured with adequate resources (8GB RAM, 4 CPU cores) to support the Docker containers that will run n8n, PostgreSQL, and Redis.

---

## Session Overview

### Objective
Verify WSL2 is properly installed and configured, then optimize the environment for Docker container workloads with appropriate memory and CPU allocations.

### Key Deliverables
1. Verified WSL2 version 2 as default
2. Documented Ubuntu distribution version (22.04 or 24.04 LTS)
3. Created/updated `/mnt/c/Users/$USER/.wslconfig` with optimized settings
4. Applied memory allocation (8GB RAM recommended)
5. Applied CPU allocation (4 cores recommended)
6. Verified settings active after WSL restart
7. Baseline system resource documentation

### Scope Summary
- **In Scope (MVP)**: WSL2 version verification, Ubuntu version check, .wslconfig creation with memory/CPU/swap settings, configuration application, verification of active settings
- **Out of Scope**: Installing WSL2 from scratch, installing Ubuntu, network configuration changes, systemd enablement

---

## Technical Considerations

### Technologies/Patterns
- WSL2 (Windows Subsystem for Linux 2)
- .wslconfig file accessed via /mnt/c/Users/$USER/.wslconfig from Ubuntu
- Linux filesystem verification (must use /home/... not /mnt/c/...)

### Potential Challenges
- WSL must be restarted for .wslconfig changes to take effect
- Running `wsl.exe --shutdown` from Ubuntu will terminate the current session
- After shutdown, open a new Ubuntu terminal to restart with new settings
- Some older Windows versions may have different WSL2 capabilities

---

## Alternative Sessions

If this session is blocked:
1. **None** - This is the foundational session; all other sessions depend on it
2. **Phase 01 sessions** - Cannot be started until Phase 00 is complete

Note: If WSL2 is not installed, the user must install it before proceeding. This is documented as an assumption in the PRD.

---

## Next Steps

Run `/sessionspec` to generate the formal specification.
