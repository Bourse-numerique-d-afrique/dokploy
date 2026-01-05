#!/bin/bash
# =============================================================================
# Dokploy Server Setup for Bourse Numérique d'Afrique
# Server: 51.159.99.20
# =============================================================================
# Usage: curl -sSL YOUR_GIST_RAW_URL | bash
# Or: wget -O - YOUR_GIST_RAW_URL | bash
# =============================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== Dokploy Server Setup ===${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo bash"
    exit 1
fi

# Step 1: Install Dokploy (official installer)
echo -e "${BLUE}Step 1: Installing Dokploy (official installer)...${NC}"
echo "This includes: Docker, Swarm, Traefik, RClone, Nixpacks, Buildpacks, Railpack"
echo ""

curl -sSL https://dokploy.com/install.sh | sh

echo ""
echo -e "${GREEN}✓ Dokploy installed successfully${NC}"
echo ""

# Step 2: Configure firewall
echo -e "${BLUE}Step 2: Configuring UFW firewall...${NC}"

if ! command -v ufw &> /dev/null; then
    apt install -y ufw
fi

# Reset and configure
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Allow essential ports
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw allow 3000/tcp comment 'Dokploy UI'

# Docker Swarm ports
ufw allow 2377/tcp comment 'Docker Swarm management'
ufw allow 7946/tcp comment 'Docker Swarm discovery'
ufw allow 7946/udp comment 'Docker Swarm discovery'
ufw allow 4789/udp comment 'Docker overlay network'

# Application ports (optional, adjust as needed)
ufw allow 5700/tcp comment 'Exchange GraphQL'
ufw allow 8500/tcp comment 'Clearing House'

# Enable firewall
ufw --force enable

echo -e "${GREEN}✓ Firewall configured${NC}"
echo ""

# Verification
echo -e "${BLUE}Step 3: Verifying installation...${NC}"
echo ""

echo -n "Docker: "
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓ $(docker --version)${NC}"
else
    echo -e "${YELLOW}✗ Not found${NC}"
fi

echo -n "Docker Swarm: "
if docker info 2>/dev/null | grep -q "Swarm: active"; then
    echo -e "${GREEN}✓ Active${NC}"
else
    echo -e "${YELLOW}✗ Not active${NC}"
fi

echo -n "Dokploy Network: "
if docker network ls | grep -q dokploy-network; then
    echo -e "${GREEN}✓ Created${NC}"
else
    echo -e "${YELLOW}✗ Not found${NC}"
fi

echo -n "Traefik: "
if docker ps | grep -q traefik; then
    echo -e "${GREEN}✓ Running${NC}"
else
    echo -e "${YELLOW}✗ Not running${NC}"
fi

echo -n "UFW: "
if ufw status | grep -q "Status: active"; then
    echo -e "${GREEN}✓ Active${NC}"
else
    echo -e "${YELLOW}✗ Inactive${NC}"
fi

echo ""
echo -e "${GREEN}=== Installation Complete! ===${NC}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo ""
echo "1. Access Dokploy UI:"
echo "   http://51.159.99.20:3000"
echo ""
echo "2. Login to GitHub Container Registry (run on this server):"
echo "   echo 'YOUR_GITHUB_TOKEN' | docker login ghcr.io -u YOUR_USERNAME --password-stdin"
echo ""
echo "3. Configure DNS records to point to 51.159.99.20:"
echo "   - test.boursenumeriquedafrique.com"
echo "   - test-api.boursenumeriquedafrique.com"
echo "   - test-payments.boursenumeriquedafrique.com"
echo ""
echo "4. Create your first project in Dokploy UI"
echo ""
echo -e "${YELLOW}IMPORTANT: Save your Dokploy admin credentials!${NC}"
echo ""
