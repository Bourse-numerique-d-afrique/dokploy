#!/bin/bash
# =============================================================================
# Fix Docker Swarm and Dokploy Network
# Run this on: 51.159.99.20
# =============================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== Fixing Docker Swarm and Network ===${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Step 1: Initialize Docker Swarm
echo -e "${BLUE}Step 1: Initializing Docker Swarm...${NC}"

if docker info 2>/dev/null | grep -q "Swarm: active"; then
    echo -e "${GREEN}✓ Docker Swarm already initialized${NC}"
else
    echo "Getting server IP address..."

    # Try to get public IP
    SERVER_IP=$(curl -4s --connect-timeout 5 https://ifconfig.io 2>/dev/null)

    if [ -z "$SERVER_IP" ]; then
        SERVER_IP=$(curl -4s --connect-timeout 5 https://icanhazip.com 2>/dev/null)
    fi

    if [ -z "$SERVER_IP" ]; then
        echo -e "${RED}Could not detect IP automatically.${NC}"
        echo "Please provide your server IP address:"
        read -p "Server IP: " SERVER_IP
    fi

    echo "Using IP address: $SERVER_IP"
    echo ""

    # Initialize swarm
    docker swarm init --advertise-addr $SERVER_IP

    echo -e "${GREEN}✓ Docker Swarm initialized${NC}"
fi

echo ""

# Step 2: Create Dokploy Network
echo -e "${BLUE}Step 2: Creating Dokploy Network...${NC}"

if docker network ls | grep -q dokploy-network; then
    echo -e "${GREEN}✓ Dokploy network already exists${NC}"
else
    docker network create --driver overlay --attachable dokploy-network
    echo -e "${GREEN}✓ Dokploy network created${NC}"
fi

echo ""

# Step 3: Verify
echo -e "${BLUE}Step 3: Verification...${NC}"
echo ""

echo -n "Docker Swarm: "
if docker info 2>/dev/null | grep -q "Swarm: active"; then
    echo -e "${GREEN}✓ Active${NC}"
else
    echo -e "${RED}✗ Not Active${NC}"
fi

echo -n "Dokploy Network: "
if docker network ls | grep -q dokploy-network; then
    echo -e "${GREEN}✓ Created${NC}"
else
    echo -e "${RED}✗ Not Created${NC}"
fi

echo ""
echo -e "${GREEN}=== Fix Complete! ===${NC}"
echo ""
echo "You can now deploy services to this server from Dokploy."
