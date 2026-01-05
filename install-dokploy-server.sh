#!/bin/bash

# =============================================================================
# Automated Dokploy Server Setup Script
# =============================================================================
# Run this script on your remote server as root
# Usage: curl -sSL https://your-repo/install-dokploy-server.sh | bash
# Or: wget -O - https://your-repo/install-dokploy-server.sh | bash
# Or: scp install-dokploy-server.sh root@51.159.99.20:/tmp/ && ssh root@51.159.99.20 'bash /tmp/install-dokploy-server.sh'
# =============================================================================

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVER_IP="51.159.99.20"
DOKPLOY_DIR="/etc/dokploy"
ADMIN_EMAIL="admin@boursenumeriquedafrique.com"

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root"
    exit 1
fi

print_header "Dokploy Server Setup - Starting Installation"

# =============================================================================
# 1. System Update
# =============================================================================
print_header "Step 1/14: System Update"
print_info "Updating package lists..."
apt update -qq
print_info "Upgrading installed packages..."
apt upgrade -y -qq
print_info "Installing basic utilities..."
apt install -y -qq curl wget git ca-certificates gnupg lsb-release software-properties-common
print_success "System updated successfully"

# =============================================================================
# 2. Install Docker
# =============================================================================
print_header "Step 2/14: Installing Docker"

if command -v docker &> /dev/null; then
    print_warning "Docker already installed: $(docker --version)"
else
    print_info "Removing old Docker versions..."
    apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    print_info "Adding Docker's official GPG key..."
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    print_info "Setting up Docker repository..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    print_info "Installing Docker Engine..."
    apt update -qq
    apt install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    print_info "Starting Docker service..."
    systemctl start docker
    systemctl enable docker

    print_success "Docker installed: $(docker --version)"
fi

# =============================================================================
# 3. Initialize Docker Swarm
# =============================================================================
print_header "Step 3/14: Initializing Docker Swarm"

if docker info 2>/dev/null | grep -q "Swarm: active"; then
    print_warning "Docker Swarm already initialized"
else
    print_info "Initializing Docker Swarm..."
    docker swarm init --advertise-addr $SERVER_IP
    print_success "Docker Swarm initialized"
fi

# =============================================================================
# 4. Create Dokploy Network
# =============================================================================
print_header "Step 4/14: Creating Dokploy Network"

if docker network ls | grep -q dokploy-network; then
    print_warning "Dokploy network already exists"
else
    print_info "Creating dokploy-network..."
    docker network create --driver overlay --attachable dokploy-network
    print_success "Dokploy network created"
fi

# =============================================================================
# 5. Install RClone
# =============================================================================
print_header "Step 5/14: Installing RClone"

if command -v rclone &> /dev/null; then
    print_warning "RClone already installed: $(rclone version --version | head -n1)"
else
    print_info "Installing RClone..."
    curl -sSL https://rclone.org/install.sh | bash
    print_success "RClone installed: $(rclone version --version | head -n1)"
fi

# =============================================================================
# 6. Install Nixpacks
# =============================================================================
print_header "Step 6/14: Installing Nixpacks"

if command -v nixpacks &> /dev/null; then
    print_warning "Nixpacks already installed: $(nixpacks --version)"
else
    print_info "Installing Nixpacks..."
    curl -sSL https://nixpacks.com/install.sh | bash
    print_success "Nixpacks installed: $(nixpacks --version)"
fi

# =============================================================================
# 7. Install Buildpacks (Pack CLI)
# =============================================================================
print_header "Step 7/14: Installing Buildpacks"

if command -v pack &> /dev/null; then
    print_warning "Pack CLI already installed: $(pack version)"
else
    print_info "Installing Pack CLI..."
    PACK_VERSION="v0.32.1"
    curl -sSL "https://github.com/buildpacks/pack/releases/download/${PACK_VERSION}/pack-${PACK_VERSION}-linux.tgz" | tar -C /usr/local/bin/ --no-same-owner -xzv pack
    chmod +x /usr/local/bin/pack
    print_success "Pack CLI installed: $(pack version)"
fi

# =============================================================================
# 8. Install Node.js and Railpack
# =============================================================================
print_header "Step 8/14: Installing Node.js and Railpack"

if command -v node &> /dev/null; then
    print_warning "Node.js already installed: $(node --version)"
else
    print_info "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt install -y -qq nodejs
    print_success "Node.js installed: $(node --version)"
fi

if command -v railway &> /dev/null; then
    print_warning "Railway CLI already installed"
else
    print_info "Installing Railway CLI..."
    npm install -g @railwayapp/cli
    print_success "Railway CLI installed"
fi

# =============================================================================
# 9. Create Main Directories
# =============================================================================
print_header "Step 9/14: Creating Main Directories"

print_info "Creating directory structure..."
mkdir -p $DOKPLOY_DIR/{logs,data,traefik,postgres}
chmod -R 755 $DOKPLOY_DIR
print_success "Directory structure created at $DOKPLOY_DIR"

# =============================================================================
# 10. Install and Configure UFW
# =============================================================================
print_header "Step 10/14: Configuring UFW Firewall"

if command -v ufw &> /dev/null; then
    print_warning "UFW already installed"
else
    print_info "Installing UFW..."
    apt install -y -qq ufw
fi

print_info "Configuring UFW rules..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Critical: Allow SSH first
ufw allow 22/tcp comment 'SSH'

# Web traffic
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'

# Docker Swarm
ufw allow 2377/tcp comment 'Swarm cluster management'
ufw allow 7946/tcp comment 'Swarm node discovery TCP'
ufw allow 7946/udp comment 'Swarm node discovery UDP'
ufw allow 4789/udp comment 'Swarm overlay network'

# Dokploy
ufw allow 3000/tcp comment 'Dokploy web interface'

# Application ports (adjust as needed)
ufw allow 5700/tcp comment 'Exchange GraphQL'
ufw allow 8500/tcp comment 'Clearing House'

print_info "Enabling UFW..."
ufw --force enable

print_success "UFW configured and enabled"
ufw status verbose

# =============================================================================
# 11. Install Traefik
# =============================================================================
print_header "Step 11/14: Installing Traefik"

print_info "Creating Traefik configuration..."
cat > $DOKPLOY_DIR/traefik/traefik.yml <<EOF
api:
  dashboard: true
  insecure: false

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
      email: $ADMIN_EMAIL
      storage: /etc/traefik/acme.json
      httpChallenge:
        entryPoint: web
EOF

touch $DOKPLOY_DIR/traefik/acme.json
chmod 600 $DOKPLOY_DIR/traefik/acme.json

if docker service ls | grep -q traefik; then
    print_warning "Traefik service already exists"
else
    print_info "Deploying Traefik service..."
    docker service create \
      --name traefik \
      --constraint=node.role==manager \
      --publish 80:80 \
      --publish 443:443 \
      --publish 8080:8080 \
      --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock,readonly \
      --mount type=bind,source=$DOKPLOY_DIR/traefik,target=/etc/traefik \
      --network dokploy-network \
      traefik:v2.10

    sleep 5
    print_success "Traefik service deployed"
fi

# =============================================================================
# 12. Configure Docker Registry Authentication
# =============================================================================
print_header "Step 12/14: Docker Registry Configuration"

print_warning "GitHub Container Registry authentication required"
print_info "Run this command to login:"
echo ""
echo "  echo 'YOUR_GITHUB_TOKEN' | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin"
echo ""

# =============================================================================
# 13. Create Verification Script
# =============================================================================
print_header "Step 13/14: Creating Verification Script"

cat > /usr/local/bin/verify-dokploy <<'VERIFY_EOF'
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
    echo "✓ Installed"
else
    echo "✗ Not Installed"
fi

# Check Nixpacks
echo -n "Nixpacks: "
if command -v nixpacks &> /dev/null; then
    echo "✓ Installed"
else
    echo "✗ Not Installed"
fi

# Check Buildpacks
echo -n "Buildpacks: "
if command -v pack &> /dev/null; then
    echo "✓ Installed"
else
    echo "✗ Not Installed"
fi

# Check Railpack
echo -n "Railway CLI: "
if command -v railway &> /dev/null; then
    echo "✓ Installed"
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
    STATUS=$(ufw status | head -n1)
    echo "✓ Installed - $STATUS"
else
    echo "✗ Not Installed"
fi

echo ""
echo "=== Docker Services ==="
docker service ls 2>/dev/null || echo "No services running"

echo ""
echo "=== Docker Networks ==="
docker network ls | grep -E "dokploy|NETWORK"

echo ""
echo "=== Listening Ports ==="
netstat -tuln 2>/dev/null | grep -E ':(80|443|3000|5700|8500|2377|7946|4789) ' || ss -tuln | grep -E ':(80|443|3000|5700|8500|2377|7946|4789) '
VERIFY_EOF

chmod +x /usr/local/bin/verify-dokploy
print_success "Verification script created: /usr/local/bin/verify-dokploy"

# =============================================================================
# 14. Final Verification
# =============================================================================
print_header "Step 14/14: Running Final Verification"

/usr/local/bin/verify-dokploy

# =============================================================================
# Installation Complete
# =============================================================================
print_header "Installation Complete!"

print_success "All components installed successfully!"
echo ""
print_info "Next Steps:"
echo "  1. Configure DNS records to point to $SERVER_IP:"
echo "     - test.boursenumeriquedafrique.com"
echo "     - test-api.boursenumeriquedafrique.com"
echo "     - test-payments.boursenumeriquedafrique.com"
echo ""
echo "  2. Login to GitHub Container Registry:"
echo "     echo 'YOUR_TOKEN' | docker login ghcr.io -u YOUR_USERNAME --password-stdin"
echo ""
echo "  3. Deploy services from Dokploy UI with serverId: MJebnVc8mD_R_mHECttIZ"
echo ""
print_info "To verify installation at any time, run: verify-dokploy"
echo ""
print_warning "IMPORTANT: DNS records must be configured before SSL certificates can be issued!"
