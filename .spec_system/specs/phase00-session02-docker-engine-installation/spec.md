# Session Specification

**Session ID**: `phase00-session02-docker-engine-installation`
**Phase**: 00 - Foundation and Core Infrastructure
**Status**: Complete
**Created**: 2025-12-25

---

## 1. Session Overview

This session installs Docker Engine and Docker Compose Plugin directly in WSL2 Ubuntu, establishing the container runtime foundation required for all subsequent sessions. Docker Engine is installed natively in Ubuntu rather than Docker Desktop, following the PRD architectural decision for optimal performance and avoiding Docker Desktop's overhead and licensing considerations.

The installation follows Docker's official repository method, ensuring we receive the latest stable releases with proper GPG signature verification. This approach provides a clean, maintainable installation that can be easily updated through standard apt package management. The session includes WSL2-specific configurations to handle the unique characteristics of running Docker in a Windows Subsystem for Linux environment.

Upon completion, the user will have a fully functional Docker environment capable of running containers without sudo privileges, with an auto-start mechanism configured for convenience. This directly enables Session 03 (docker compose config validation) and Session 04 (container deployment), making it a critical path dependency for the n8n stack deployment.

---

## 2. Objectives

1. Install Docker Engine (v24+), containerd, and Docker CLI from Docker's official repository with GPG verification
2. Install Docker Compose Plugin v2+ as an integrated Docker subcommand
3. Configure non-root Docker access by adding the current user to the docker group
4. Establish a reliable Docker service auto-start mechanism for WSL2 boot persistence

---

## 3. Prerequisites

### Required Sessions
- [x] `phase00-session01-wsl2-environment-optimization` - Provides optimized WSL2 with memory/CPU allocation and filesystem configuration

### Required Tools/Knowledge
- Ubuntu apt package manager (apt-get, apt)
- curl for downloading GPG keys
- gpg for key verification and dearmoring
- Basic understanding of Linux service management

### Environment Requirements
- WSL2 Ubuntu 22.04 or 24.04 LTS
- Internet connection for package downloads
- Sudo access in Ubuntu for package installation
- Sufficient disk space (~2GB for Docker images and packages)

---

## 4. Scope

### In Scope (MVP)
- Check for and remove conflicting Docker packages (docker.io, docker-compose, podman)
- Install Docker prerequisites (ca-certificates, curl, gnupg, lsb-release)
- Add Docker's official GPG key with proper keyring storage
- Configure Docker's apt repository for Ubuntu
- Install docker-ce, docker-ce-cli, containerd.io, docker-buildx-plugin, docker-compose-plugin
- Add current user to docker group for non-root access
- Configure Docker daemon settings optimized for WSL2 (daemon.json)
- Set up Docker service auto-start mechanism via .bashrc
- Verify installation with version checks and hello-world container
- Clean up installation artifacts

### Out of Scope (Deferred)
- Docker Desktop installation - *Reason: Performance overhead, licensing, PRD explicitly excludes*
- Kubernetes/minikube setup - *Reason: Not required for n8n stack, Phase 01+ consideration*
- Docker Swarm configuration - *Reason: Single-host deployment, not needed for local setup*
- External registry authentication - *Reason: Using public Docker Hub images only*
- BuildKit advanced configuration - *Reason: Default BuildKit sufficient, optimization deferred*
- Docker credential helpers - *Reason: No private registry authentication needed*

---

## 5. Technical Approach

### Architecture

Docker Engine runs as a background daemon (dockerd) managed by the init system. In WSL2 without systemd, we use a service-based approach with auto-start via shell initialization. The architecture consists of:

```
+------------------+     +-------------------+     +------------------+
|   Docker CLI     | --> |   Docker Daemon   | --> |   containerd     |
|   (docker)       |     |   (dockerd)       |     |   (containers)   |
+------------------+     +-------------------+     +------------------+
        |                         |
        v                         v
+------------------+     +-------------------+
| Docker Compose   |     |   Docker Socket   |
| Plugin (v2)      |     |   /var/run/docker.sock
+------------------+     +-------------------+
```

### Design Patterns
- **Official Repository Pattern**: Use Docker's official apt repository for reliable, verified packages
- **Keyring Storage Pattern**: Store GPG keys in /etc/apt/keyrings/ (modern apt best practice)
- **Group-Based Access**: Use docker group membership for non-root socket access
- **Idempotent Installation**: Commands are safe to re-run without side effects

### Technology Stack
- Docker Engine CE 24.x+ (latest stable)
- containerd 1.6.x+ (container runtime)
- Docker Compose Plugin 2.x+ (multi-container orchestration)
- Docker BuildKit (default builder)

---

## 6. Deliverables

### Files to Create
| File | Purpose | Est. Lines |
|------|---------|------------|
| `/etc/docker/daemon.json` | Docker daemon configuration for WSL2 | ~10 |
| `/etc/apt/keyrings/docker.gpg` | Docker GPG key for package verification | (binary) |
| `/etc/apt/sources.list.d/docker.list` | Docker apt repository configuration | ~1 |
| `~/.bashrc` addition | Docker auto-start snippet | ~5 |

### Files to Modify
| File | Changes | Est. Lines |
|------|---------|------------|
| `~/.bashrc` | Add Docker service auto-start check | ~5 |

### Packages to Install
| Package | Purpose |
|---------|---------|
| `docker-ce` | Docker Engine daemon and client |
| `docker-ce-cli` | Docker command-line interface |
| `containerd.io` | Container runtime |
| `docker-buildx-plugin` | Extended build capabilities |
| `docker-compose-plugin` | Docker Compose v2 integration |

---

## 7. Success Criteria

### Functional Requirements
- [x] `docker --version` returns version 24.0.0 or higher (29.1.3)
- [x] `docker compose version` returns version 2.0.0 or higher (v5.0.0)
- [x] `docker info` executes without errors
- [x] `docker run hello-world` completes successfully
- [x] Docker commands work without sudo (after new shell)
- [x] `docker compose version` works as subcommand (not standalone docker-compose)

### Service Requirements
- [x] Docker service starts successfully (`sudo service docker start`)
- [x] Docker socket exists at `/var/run/docker.sock`
- [x] containerd service running alongside dockerd
- [x] Auto-start mechanism triggers on new WSL terminal (systemd)

### Testing Requirements
- [x] Version verification for all components
- [x] Container pull and run test (hello-world)
- [x] Docker Compose dry-run test (`docker compose version`)
- [x] Group membership verification (`groups` shows docker)

### Quality Gates
- [x] No conflicting packages remain (docker.io, podman-docker removed)
- [x] No Docker Desktop remnants or conflicts
- [x] GPG key properly stored in /etc/apt/keyrings/
- [x] Clean apt update with Docker repository
- [x] No errors in Docker daemon logs

---

## 8. Implementation Notes

### Key Considerations

1. **Package Conflicts**: Ubuntu's default docker.io package conflicts with docker-ce. Must be removed first along with any podman-docker that provides Docker CLI compatibility.

2. **GPG Key Storage**: Modern apt requires keys in /etc/apt/keyrings/ directory with explicit signed-by reference in sources list. Older /usr/share/keyrings/ methods are deprecated.

3. **Group Membership Activation**: Adding user to docker group requires a new login session. Use `newgrp docker` for immediate effect in current session, but remind user that new terminals will work automatically.

4. **WSL2 Service Management**: WSL2 may not have systemd enabled by default. Use `sudo service docker start` rather than systemctl. The auto-start mechanism uses a bashrc check.

5. **Storage Driver**: Docker on WSL2 typically uses overlay2 storage driver. Verify with `docker info | grep "Storage Driver"`.

### Potential Challenges

| Challenge | Mitigation |
|-----------|------------|
| Existing docker.io package | Explicitly remove conflicting packages first |
| GPG key download failure | Retry with --retry flag, verify internet connectivity |
| Permission denied on docker socket | Verify group membership, start new shell session |
| Service fails to start | Check /var/log/docker.log, verify no port conflicts |
| WSL distro restart needed | Provide instructions for `wsl --shutdown` if required |

### ASCII Reminder
All output files must use ASCII-only characters (0-127). Avoid smart quotes, em-dashes, and other Unicode characters in configuration files.

---

## 9. Testing Strategy

### Unit Tests (Component Verification)
- Verify each package installed: `dpkg -l | grep docker`
- Verify GPG key: `gpg --show-keys /etc/apt/keyrings/docker.gpg`
- Verify apt source: `cat /etc/apt/sources.list.d/docker.list`
- Verify daemon.json syntax: `cat /etc/docker/daemon.json | python3 -m json.tool`

### Integration Tests (System Verification)
- Docker daemon communicates with containerd
- Docker CLI communicates with daemon via socket
- Docker Compose plugin integrates with Docker CLI
- Container networking functions (hello-world requires network)

### Manual Testing
1. Open new terminal, run `docker ps` without sudo
2. Run `docker run hello-world` and verify output
3. Run `docker compose version` and verify v2+ output
4. Run `docker info` and verify storage driver and status
5. Close and reopen WSL, verify Docker auto-starts

### Edge Cases
- Multiple Ubuntu installations in WSL (each needs separate Docker)
- Docker Desktop previously installed (must be fully removed)
- Snap-installed Docker (must use apt version instead)
- Corporate proxy environments (may need proxy configuration)

---

## 10. Dependencies

### External Repositories
- Docker Official Repository: `https://download.docker.com/linux/ubuntu`
- GPG Key: `https://download.docker.com/linux/ubuntu/gpg`

### System Dependencies
- apt package manager
- curl
- gpg
- ca-certificates
- Linux kernel 5.10+ (provided by WSL2)

### Other Sessions
- **Depends on**: `phase00-session01-wsl2-environment-optimization` (WSL2 configured)
- **Depended by**: `phase00-session03-project-structure-and-configuration` (uses docker compose config)
- **Depended by**: `phase00-session04-service-deployment-and-verification` (uses docker compose up)

---

## 11. Rollback Plan

If installation fails or causes issues:

1. **Stop Docker service**: `sudo service docker stop`
2. **Remove Docker packages**: `sudo apt-get purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin`
3. **Remove Docker data** (optional): `sudo rm -rf /var/lib/docker /var/lib/containerd`
4. **Remove apt source**: `sudo rm /etc/apt/sources.list.d/docker.list`
5. **Remove GPG key**: `sudo rm /etc/apt/keyrings/docker.gpg`
6. **Remove user from docker group**: `sudo gpasswd -d $USER docker`
7. **Remove bashrc addition**: Edit ~/.bashrc to remove auto-start lines
8. **Update apt**: `sudo apt-get update`

---

## 12. Command Reference

### Installation Commands (Executed via Sudo)
```bash
# Remove conflicting packages
sudo apt-get remove docker docker-engine docker.io containerd runc docker-compose podman-docker

# Install prerequisites
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg lsb-release

# Add Docker GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER

# Start Docker service
sudo service docker start
```

### Verification Commands
```bash
docker --version
docker compose version
docker info
docker run hello-world
groups | grep docker
```

---

## Next Steps

Run `/tasks` to generate the implementation task checklist.
