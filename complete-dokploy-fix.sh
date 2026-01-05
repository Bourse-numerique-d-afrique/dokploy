#!/bin/bash
# =============================================================================
# Complete Dokploy Server Fix
# Stops services using port 80/443, initializes Swarm, creates network
# Run this on: 51.159.99.20
# =============================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== Complete Dokploy Server Fix ===${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root: sudo bash $0${NC}"
    exit 1
fi

# =============================================================================
# Step 1: Check what's using port 80 and 443
# =============================================================================
echo -e "${BLUE}Step 1: Checking ports 80 and 443...${NC}"

PORT_80=$(ss -tulnp | grep ':80 ' || true)
PORT_443=$(ss -tulnp | grep ':443 ' || true)

if [ -n "$PORT_80" ]; then
    echo -e "${YELLOW}Port 80 is in use:${NC}"
    echo "$PORT_80"
else
    echo -e "${GREEN}✓ Port 80 is free${NC}"
fi

if [ -n "$PORT_443" ]; then
    echo -e "${YELLOW}Port 443 is in use:${NC}"
    echo "$PORT_443"
else
    echo -e "${GREEN}✓ Port 443 is free${NC}"
fi

echo ""

# =============================================================================
# Step 2: Stop common web servers
# =============================================================================
echo -e "${BLUE}Step 2: Stopping services that might be using ports...${NC}"

# Stop nginx if running
if systemctl is-active --quiet nginx 2>/dev/null; then
    echo "Stopping nginx..."
    systemctl stop nginx
    systemctl disable nginx
    echo -e "${GREEN}✓ nginx stopped${NC}"
fi

# Stop apache if running
if systemctl is-active --quiet apache2 2>/dev/null; then
    echo "Stopping apache2..."
    systemctl stop apache2
    systemctl disable apache2
    echo -e "${GREEN}✓ apache2 stopped${NC}"
fi

# Stop httpd (CentOS/RHEL) if running
if systemctl is-active --quiet httpd 2>/dev/null; then
    echo "Stopping httpd..."
    systemctl stop httpd
    systemctl disable httpd
    echo -e "${GREEN}✓ httpd stopped${NC}"
fi

# Check for Traefik containers and stop them
if docker ps --format '{{.Names}}' | grep -q traefik; then
    echo "Stopping Traefik containers..."
    docker ps --format '{{.Names}}' | grep traefik | xargs -r docker stop
    echo -e "${GREEN}✓ Traefik containers stopped${NC}"
fi

# Stop any dokploy-traefik service (swarm)
if docker service ls --format '{{.Name}}' 2>/dev/null | grep -q dokploy-traefik; then
    echo "Removing dokploy-traefik service..."
    docker service rm dokploy-traefik
    sleep 3
    echo -e "${GREEN}✓ dokploy-traefik service removed${NC}"
fi

echo ""

# =============================================================================
# Step 3: Verify ports are now free
# =============================================================================
echo -e "${BLUE}Step 3: Verifying ports are free...${NC}"

PORT_80_CHECK=$(ss -tulnp | grep ':80 ' || true)
PORT_443_CHECK=$(ss -tulnp | grep ':443 ' || true)

if [ -n "$PORT_80_CHECK" ]; then
    echo -e "${RED}✗ Port 80 is still in use:${NC}"
    echo "$PORT_80_CHECK"
    echo ""
    echo -e "${YELLOW}You need to manually stop the service using port 80${NC}"
    echo "Find the process ID (PID) from above and run: kill -9 PID"
    exit 1
else
    echo -e "${GREEN}✓ Port 80 is free${NC}"
fi

if [ -n "$PORT_443_CHECK" ]; then
    echo -e "${YELLOW}⚠ Port 443 is still in use (this might be ok)${NC}"
else
    echo -e "${GREEN}✓ Port 443 is free${NC}"
fi

echo ""

# =============================================================================
# Step 4: Initialize Docker Swarm
# =============================================================================
echo -e "${BLUE}Step 4: Initializing Docker Swarm...${NC}"

if docker info 2>/dev/null | grep -q "Swarm: active"; then
    echo -e "${GREEN}✓ Docker Swarm already initialized${NC}"
else
    echo "Getting server IP address..."

    # Try to get public IP
    SERVER_IP=$(curl -4s --connect-timeout 5 https://ifconfig.io 2>/dev/null || echo "")

    if [ -z "$SERVER_IP" ]; then
        SERVER_IP=$(curl -4s --connect-timeout 5 https://icanhazip.com 2>/dev/null || echo "")
    fi

    if [ -z "$SERVER_IP" ]; then
        SERVER_IP=$(curl -4s --connect-timeout 5 https://ipecho.net/plain 2>/dev/null || echo "")
    fi

    if [ -z "$SERVER_IP" ]; then
        # Try to get local IP as fallback
        SERVER_IP=$(hostname -I | awk '{print $1}')
    fi

    if [ -z "$SERVER_IP" ]; then
        echo -e "${RED}Could not detect IP automatically.${NC}"
        echo "Please enter your server IP address (51.159.99.20):"
        read -p "Server IP: " SERVER_IP
    fi

    echo "Using IP address: $SERVER_IP"
    echo ""

    # Initialize swarm
    docker swarm init --advertise-addr $SERVER_IP

    echo -e "${GREEN}✓ Docker Swarm initialized${NC}"
fi

echo ""

# =============================================================================
# Step 5: Create Dokploy Network
# =============================================================================
echo -e "${BLUE}Step 5: Creating Dokploy Network...${NC}"

if docker network ls | grep -q dokploy-network; then
    echo -e "${GREEN}✓ Dokploy network already exists${NC}"
else
    docker network create --driver overlay --attachable dokploy-network
    echo -e "${GREEN}✓ Dokploy network created${NC}"
fi

echo ""

# =============================================================================
# Step 6: Create required directories
# =============================================================================
echo -e "${BLUE}Step 6: Creating required directories...${NC}"

mkdir -p /etc/dokploy
mkdir -p /etc/dokploy/traefik
mkdir -p /etc/dokploy/traefik/dynamic
mkdir -p /etc/dokploy/logs
mkdir -p /etc/dokploy/applications
mkdir -p /etc/dokploy/compose
mkdir -p /etc/dokploy/ssh
mkdir -p /etc/dokploy/traefik/dynamic/certificates
mkdir -p /etc/dokploy/monitoring
mkdir -p /etc/dokploy/registry
mkdir -p /etc/dokploy/schedules
mkdir -p /etc/dokploy/volume-backups

chmod 700 /etc/dokploy/ssh

echo -e "${GREEN}✓ Directories created${NC}"
echo ""

# =============================================================================
# Step 7: Final Verification
# =============================================================================
echo -e "${BLUE}Step 7: Final Verification...${NC}"
echo ""

echo -n "Docker installed: "
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓ Yes${NC}"
else
    echo -e "${RED}✗ No - Install Docker first!${NC}"
    exit 1
fi

echo -n "Docker Swarm: "
if docker info 2>/dev/null | grep -q "Swarm: active"; then
    echo -e "${GREEN}✓ Active${NC}"
else
    echo -e "${RED}✗ Not Active${NC}"
    exit 1
fi

echo -n "Dokploy Network: "
if docker network ls | grep -q dokploy-network; then
    echo -e "${GREEN}✓ Created${NC}"
else
    echo -e "${RED}✗ Not Created${NC}"
    exit 1
fi

echo -n "Port 80: "
if ss -tulnp | grep -q ':80 '; then
    echo -e "${RED}✗ Still in use${NC}"
else
    echo -e "${GREEN}✓ Free${NC}"
fi

echo -n "Port 443: "
if ss -tulnp | grep -q ':443 '; then
    echo -e "${YELLOW}⚠ In use${NC}"
else
    echo -e "${GREEN}✓ Free${NC}"
fi

echo ""
echo -e "${GREEN}=== Fix Complete! ===${NC}"
echo ""
echo -e "${BLUE}Next step: Run Dokploy installer${NC}"
echo ""
echo "  curl -sSL https://dokploy.com/install.sh | sh"
echo ""
echo "The installer should now complete successfully!"
