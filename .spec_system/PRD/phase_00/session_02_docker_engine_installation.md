# Session 02: Docker Engine Installation

**Session ID**: `phase00-session02-docker-engine-installation`
**Status**: Not Started
**Estimated Tasks**: ~20-25
**Estimated Duration**: 2-3 hours

---

## Important: WSL2 Ubuntu Only

**All commands run exclusively from WSL2 Ubuntu.** Docker Engine is installed natively in Ubuntu, not Docker Desktop.

---

## Objective

Install Docker Engine and Docker Compose Plugin directly in WSL2 Ubuntu (not Docker Desktop) for optimal performance and full container orchestration capabilities.

---

## Scope

### In Scope (MVP)
- Remove any conflicting Docker packages
- Install Docker Engine prerequisites and repository
- Install Docker Engine and containerd
- Install Docker Compose Plugin v2
- Configure user permissions for Docker access
- Configure Docker daemon settings for WSL2
- Set up Docker service auto-start mechanism
- Verify Docker installation and functionality
- Verify Docker Compose functionality

### Out of Scope
- Docker Desktop installation (explicitly avoided for performance)
- Kubernetes/minikube setup
- Docker Swarm configuration
- External registry authentication
- BuildKit advanced configuration

---

## Prerequisites

- [ ] Session 01 completed (WSL2 optimized)
- [ ] Internet connection for package downloads
- [ ] Sudo access in Ubuntu
- [ ] Ubuntu apt package manager functional

---

## Deliverables

1. Docker Engine installed and running
2. Docker Compose Plugin v2+ installed
3. Current user added to docker group
4. Docker daemon configured for WSL2
5. Docker service auto-start configured
6. Installation verification successful
7. Hello-world container test passed

---

## Technical Details

### Installation Steps
1. Update apt and install prerequisites
2. Add Docker's official GPG key
3. Add Docker repository to apt sources
4. Install docker-ce, docker-ce-cli, containerd.io, docker-compose-plugin
5. Add user to docker group
6. Configure daemon.json if needed
7. Set up service start in .bashrc or via systemd

### Key Commands
```bash
# Add Docker repository
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Install Docker Engine
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Verify installation
docker --version
docker compose version
docker run hello-world
```

### WSL2 Considerations
- Docker service may need manual start after WSL boot
- Use `sudo service docker start` or add to .bashrc
- No systemd required but can be enabled if preferred

---

## Success Criteria

- [ ] Docker Engine installed (version 24+)
- [ ] Docker Compose Plugin v2+ installed
- [ ] User can run docker commands without sudo
- [ ] Docker service starts successfully
- [ ] `docker run hello-world` completes successfully
- [ ] `docker compose version` shows v2+
- [ ] Docker info shows expected storage driver
- [ ] No Docker Desktop remnants present
