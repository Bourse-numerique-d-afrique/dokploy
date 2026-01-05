# Dokploy Remote Server Setup Guide

Complete guide for setting up a remote server to work with Dokploy deployment.

## Prerequisites

- Ubuntu 20.04 LTS or later (or Debian 11+)
- Root SSH access to the server
- Server IP: 51.159.99.20
- Minimum 2GB RAM, 20GB disk space

## Installation Steps

### 1. Initial Server Connection

```bash
# SSH into your server as root
ssh root@51.159.99.20
```

### 2. System Update

```bash
# Update package lists
apt update

# Upgrade installed packages
apt upgrade -y

# Install basic utilities
apt install -y curl wget git ca-certificates gnupg lsb-release
```

### 3. Install Docker

```bash
# Remove old Docker versions if any
apt remove -y docker docker-engine docker.io containerd runc

# Add Docker's official GPG key
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Verify Docker installation
docker --version
docker compose version

# Start and enable Docker service
systemctl start docker
systemctl enable docker

# Test Docker
docker run hello-world
```

### 4. Initialize Docker Swarm

```bash
# Initialize Docker Swarm mode
# Replace with your server's public IP if needed
docker swarm init --advertise-addr 51.159.99.20

# Verify swarm status
docker info | grep Swarm
```

### 5. Create Dokploy Network

```bash
# Create the dokploy network as overlay network for swarm
docker network create --driver overlay --attachable dokploy-network

# Verify network creation
docker network ls | grep dokploy
```

### 6. Install RClone

```bash
# Download and install rclone
curl https://rclone.org/install.sh | bash

# Verify installation
rclone version
```

### 7. Install Nixpacks

```bash
# Install Nixpacks (requires Rust/Cargo or use prebuilt binary)
# Option 1: Using prebuilt binary (recommended)
curl -sSL https://nixpacks.com/install.sh | bash

# Option 2: Using Cargo (if Rust is installed)
# cargo install nixpacks

# Verify installation
nixpacks --version
```

### 8. Install Buildpacks

```bash
# Install Pack CLI (Cloud Native Buildpacks)
# For Linux AMD64
curl -sSL "https://github.com/buildpacks/pack/releases/download/v0.32.1/pack-v0.32.1-linux.tgz" | tar -C /usr/local/bin/ --no-same-owner -xzv pack

# Make it executable
chmod +x /usr/local/bin/pack

# Verify installation
pack version
```

### 9. Install Railpack

```bash
# Railpack is typically installed via npm
# First install Node.js and npm if not present
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# Install railpack globally
npm install -g @railwayapp/cli

# Verify installation
railway --version
```

### 10. Create Main Directory

```bash
# Create Dokploy main directory
mkdir -p /etc/dokploy

# Create subdirectories for logs, data, and configurations
mkdir -p /etc/dokploy/logs
mkdir -p /etc/dokploy/data
mkdir -p /etc/dokploy/traefik
mkdir -p /etc/dokploy/postgres

# Set proper permissions
chmod -R 755 /etc/dokploy
```

### 11. Configure UFW (Firewall)

```bash
# Install UFW if not present
apt install -y ufw

# Set default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (CRITICAL - don't lock yourself out!)
ufw allow 22/tcp

# Allow HTTP and HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Allow Docker Swarm ports
ufw allow 2377/tcp   # Cluster management
ufw allow 7946/tcp   # Container network discovery
ufw allow 7946/udp   # Container network discovery
ufw allow 4789/udp   # Overlay network traffic

# Allow Dokploy web interface (if exposed)
ufw allow 3000/tcp

# Allow application ports (adjust based on your needs)
ufw allow 5700/tcp   # Exchange GraphQL
ufw allow 8500/tcp   # Clearing House
ufw allow 5432/tcp   # PostgreSQL (if external access needed)
ufw allow 8545/tcp   # Ganache (if external access needed)

# Enable UFW
ufw --force enable

# Verify status
ufw status verbose
```

### 12. Install Dokploy (Optional - If Running Dokploy on Remote Server)

If you want to run Dokploy itself on the remote server instead of your laptop:

```bash
# Pull Dokploy image
docker pull dokploy/dokploy:latest

# Create Dokploy service in swarm
docker service create \
  --name dokploy \
  --network dokploy-network \
  --publish 3000:3000 \
  --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
  --mount type=bind,source=/etc/dokploy,target=/etc/dokploy \
  dokploy/dokploy:latest

# Verify service is running
docker service ls
docker service logs dokploy
```

### 13. Install Traefik (Reverse Proxy)

```bash
# Create Traefik configuration
cat > /etc/dokploy/traefik/traefik.yml <<EOF
api:
  dashboard: true
  insecure: true

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: dokploy-network
    swarmMode: true

certificatesResolvers:
  letsencrypt:
    acme:
      email: admin@boursenumeriquedafrique.com
      storage: /etc/traefik/acme.json
      httpChallenge:
        entryPoint: web
EOF

# Create acme.json for Let's Encrypt certificates
touch /etc/dokploy/traefik/acme.json
chmod 600 /etc/dokploy/traefik/acme.json

# Deploy Traefik as a Docker service
docker service create \
  --name traefik \
  --constraint=node.role==manager \
  --publish 80:80 \
  --publish 443:443 \
  --publish 8080:8080 \
  --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock,readonly \
  --mount type=bind,source=/etc/dokploy/traefik,target=/etc/traefik \
  --network dokploy-network \
  --label traefik.enable=true \
  --label traefik.http.routers.api.rule=Host\(\`traefik.boursenumeriquedafrique.com\`\) \
  --label traefik.http.routers.api.service=api@internal \
  --label traefik.http.routers.api.entrypoints=websecure \
  --label traefik.http.routers.api.tls.certresolver=letsencrypt \
  traefik:v2.10

# Verify Traefik is running
docker service ls | grep traefik
docker service logs traefik
```

### 14. Configure GitHub Container Registry Authentication

```bash
# Login to GitHub Container Registry (needed to pull private images)
# Replace YOUR_GITHUB_TOKEN with your actual token
echo "YOUR_GITHUB_TOKEN" | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin

# For swarm, save credentials
mkdir -p /root/.docker
# The login command above already saves to /root/.docker/config.json
```

### 15. Verify Complete Installation

```bash
# Run verification script
cat > /tmp/verify-dokploy-setup.sh <<'EOF'
#!/bin/bash

echo "=== Dokploy Server Setup Verification ==="
echo ""

# Check Docker
echo -n "Docker: "
if command -v docker &> /dev/null; then
    echo "✓ Installed ($(docker --version))"
else
    echo "✗ Not Installed"
fi

# Check Docker Swarm
echo -n "Docker Swarm: "
if docker info 2>/dev/null | grep -q "Swarm: active"; then
    echo "✓ Initialized"
else
    echo "✗ Not Initialized"
fi

# Check Dokploy Network
echo -n "Dokploy Network: "
if docker network ls | grep -q dokploy-network; then
    echo "✓ Created"
else
    echo "✗ Not Created"
fi

# Check RClone
echo -n "RClone: "
if command -v rclone &> /dev/null; then
    echo "✓ Installed ($(rclone version --version | head -n1))"
else
    echo "✗ Not Installed"
fi

# Check Nixpacks
echo -n "Nixpacks: "
if command -v nixpacks &> /dev/null; then
    echo "✓ Installed ($(nixpacks --version))"
else
    echo "✗ Not Installed"
fi

# Check Buildpacks
echo -n "Buildpacks: "
if command -v pack &> /dev/null; then
    echo "✓ Installed ($(pack version))"
else
    echo "✗ Not Installed"
fi

# Check Railpack
echo -n "Railpack: "
if command -v railway &> /dev/null; then
    echo "✓ Installed ($(railway --version))"
else
    echo "✗ Not Installed"
fi

# Check Main Directory
echo -n "Main Directory: "
if [ -d "/etc/dokploy" ]; then
    echo "✓ Created"
else
    echo "✗ Not Created"
fi

# Check UFW
echo -n "UFW: "
if command -v ufw &> /dev/null; then
    echo "✓ Installed"
    ufw status | head -n1
else
    echo "✗ Not Installed"
fi

echo ""
echo "=== Port Status ==="
netstat -tuln | grep -E ':(80|443|3000|5700|8500|2377|7946|4789) '

echo ""
echo "=== Docker Services ==="
docker service ls

echo ""
echo "=== Docker Networks ==="
docker network ls

EOF

chmod +x /tmp/verify-dokploy-setup.sh
/tmp/verify-dokploy-setup.sh
```

## Troubleshooting

### Docker Swarm Issues

```bash
# If swarm init fails, check:
docker swarm leave --force
docker swarm init --advertise-addr 51.159.99.20
```

### Network Issues

```bash
# If dokploy-network creation fails:
docker network rm dokploy-network
docker network create --driver overlay --attachable dokploy-network
```

### Firewall Blocking Connections

```bash
# Check UFW status
ufw status verbose

# Temporarily disable for testing (NOT recommended for production)
ufw disable

# Re-enable after testing
ufw enable
```

### Service Not Starting

```bash
# Check service logs
docker service logs SERVICE_NAME --tail 100

# Check service details
docker service inspect SERVICE_NAME

# Force update service
docker service update --force SERVICE_NAME
```

## Post-Installation

### 1. Configure DNS Records

Add A records pointing to 51.159.99.20:
- test.boursenumeriquedafrique.com
- test-api.boursenumeriquedafrique.com
- test-payments.boursenumeriquedafrique.com
- route.boursenumeriquedafrique.com (if Dokploy runs on remote)

### 2. Test Connectivity

```bash
# From your local machine, test SSH
ssh root@51.159.99.20

# Test HTTP/HTTPS ports
curl http://51.159.99.20
curl https://51.159.99.20
```

### 3. Deploy Your First Service

Now you can deploy from Dokploy UI with `serverId` pointing to this server!

## Security Best Practices

1. **Change default SSH port** from 22 to custom port
2. **Disable root SSH login** - create sudo user instead
3. **Use SSH keys** instead of passwords
4. **Keep UFW enabled** at all times
5. **Regular updates**: `apt update && apt upgrade`
6. **Monitor logs**: Set up log rotation and monitoring
7. **Backup /etc/dokploy** regularly
8. **Use secrets management** for sensitive data

## Additional Resources

- Docker Swarm: https://docs.docker.com/engine/swarm/
- Traefik: https://doc.traefik.io/traefik/
- UFW: https://help.ubuntu.com/community/UFW
- Dokploy: https://dokploy.com/docs

## Support

If you encounter issues:
1. Check service logs: `docker service logs <service-name>`
2. Verify network: `docker network inspect dokploy-network`
3. Check firewall: `ufw status verbose`
4. Review system logs: `journalctl -xe`
