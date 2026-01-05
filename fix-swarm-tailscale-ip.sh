#!/bin/bash
# =============================================================================
# Fix Docker Swarm to Use Tailscale IP on Manager (Laptop)
# Run this on: YOUR LAPTOP (not the remote server)
# =============================================================================
# This reconfigures Docker Swarm to use Tailscale IP so remote workers can join
# =============================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== Fix Docker Swarm to Use Tailscale IP ===${NC}"
echo ""

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run with sudo: sudo bash $0${NC}"
    exit 1
fi

# =============================================================================
# Step 1: Detect Tailscale IP
# =============================================================================
echo -e "${BLUE}Step 1: Detecting Tailscale IP...${NC}"

# Check if Tailscale is installed
if ! command -v tailscale &> /dev/null; then
    echo -e "${RED}✗ Tailscale is not installed!${NC}"
    echo ""
    echo "Install Tailscale first:"
    echo "  curl -fsSL https://tailscale.com/install.sh | sh"
    exit 1
fi

# Get Tailscale IP
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "")

if [ -z "$TAILSCALE_IP" ]; then
    echo -e "${RED}✗ Could not detect Tailscale IP${NC}"
    echo "Make sure Tailscale is connected:"
    echo "  tailscale status"
    exit 1
fi

echo -e "${GREEN}✓ Tailscale IP detected: $TAILSCALE_IP${NC}"
echo ""

# =============================================================================
# Step 2: Check current Swarm status
# =============================================================================
echo -e "${BLUE}Step 2: Checking current Swarm configuration...${NC}"

if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
    echo -e "${YELLOW}⚠ Docker Swarm is not initialized${NC}"
    echo "Initializing with Tailscale IP..."
    docker swarm init --advertise-addr $TAILSCALE_IP
    echo -e "${GREEN}✓ Swarm initialized with Tailscale IP${NC}"
    exit 0
fi

# Get current advertise address
CURRENT_ADDR=$(docker node inspect self --format '{{.Status.Addr}}' 2>/dev/null || echo "unknown")
echo "Current advertise address: $CURRENT_ADDR"

if [ "$CURRENT_ADDR" = "$TAILSCALE_IP" ]; then
    echo -e "${GREEN}✓ Swarm is already using Tailscale IP!${NC}"
    echo ""
    echo "To get the join token for worker nodes, run:"
    echo "  docker swarm join-token worker"
    exit 0
fi

echo -e "${YELLOW}⚠ Swarm is using wrong IP ($CURRENT_ADDR instead of $TAILSCALE_IP)${NC}"
echo ""

# =============================================================================
# Step 3: Check if there are workers in the swarm
# =============================================================================
echo -e "${BLUE}Step 3: Checking for worker nodes...${NC}"

WORKER_COUNT=$(docker node ls --filter "role=worker" --format "{{.ID}}" 2>/dev/null | wc -l)

if [ "$WORKER_COUNT" -gt 0 ]; then
    echo -e "${RED}✗ There are $WORKER_COUNT worker node(s) in the swarm${NC}"
    echo ""
    echo "You need to remove all workers before changing the advertise address."
    echo ""
    echo "Workers:"
    docker node ls --filter "role=worker"
    echo ""
    echo "To remove a worker:"
    echo "  1. On the worker: docker swarm leave"
    echo "  2. On manager: docker node rm WORKER_ID"
    exit 1
fi

echo -e "${GREEN}✓ No worker nodes (safe to reconfigure)${NC}"
echo ""

# =============================================================================
# Step 4: Check if there are running services
# =============================================================================
echo -e "${BLUE}Step 4: Checking for running services...${NC}"

SERVICE_COUNT=$(docker service ls --quiet 2>/dev/null | wc -l)

if [ "$SERVICE_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠ Warning: There are $SERVICE_COUNT service(s) running${NC}"
    docker service ls
    echo ""
    echo -e "${YELLOW}These services will be temporarily unavailable during reconfiguration.${NC}"
    echo ""
    read -p "Continue? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo "Aborted."
        exit 1
    fi
fi

# =============================================================================
# Step 5: Leave swarm and reinitialize
# =============================================================================
echo -e "${BLUE}Step 5: Reconfiguring Swarm...${NC}"
echo ""

echo "This will:"
echo "  1. Force leave current swarm"
echo "  2. Reinitialize with Tailscale IP ($TAILSCALE_IP)"
echo "  3. All services will need to be recreated"
echo ""
read -p "Are you sure? Type 'yes' to continue: " FINAL_CONFIRM

if [ "$FINAL_CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "Leaving current swarm..."
docker swarm leave --force

echo "Waiting 3 seconds..."
sleep 3

echo "Initializing swarm with Tailscale IP..."
docker swarm init --advertise-addr $TAILSCALE_IP

echo -e "${GREEN}✓ Swarm reconfigured successfully!${NC}"
echo ""

# =============================================================================
# Step 6: Display join token
# =============================================================================
echo -e "${BLUE}Step 6: Worker join token${NC}"
echo ""
echo "To join a worker node to this swarm, run this command on the worker:"
echo ""
docker swarm join-token worker | grep "docker swarm join"
echo ""
echo -e "${YELLOW}Note: Worker nodes must be able to reach $TAILSCALE_IP${NC}"
echo "Make sure workers are on the same Tailscale network!"
echo ""

# =============================================================================
# Step 7: Recreate dokploy-network
# =============================================================================
echo -e "${BLUE}Step 7: Recreating dokploy-network...${NC}"

# Remove old network if exists (it won't work after swarm reinit)
docker network rm dokploy-network 2>/dev/null || true

# Create new overlay network
docker network create --driver overlay --attachable dokploy-network

echo -e "${GREEN}✓ dokploy-network created${NC}"
echo ""

# =============================================================================
# Step 8: Verification
# =============================================================================
echo -e "${BLUE}Step 8: Verification${NC}"
echo ""

echo -n "Swarm Status: "
if docker info 2>/dev/null | grep -q "Swarm: active"; then
    echo -e "${GREEN}✓ Active${NC}"
else
    echo -e "${RED}✗ Not Active${NC}"
fi

echo -n "Advertise Address: "
NEW_ADDR=$(docker node inspect self --format '{{.Status.Addr}}' 2>/dev/null)
if [ "$NEW_ADDR" = "$TAILSCALE_IP" ]; then
    echo -e "${GREEN}✓ $NEW_ADDR (Tailscale IP)${NC}"
else
    echo -e "${YELLOW}⚠ $NEW_ADDR${NC}"
fi

echo -n "Network: "
if docker network ls | grep -q dokploy-network; then
    echo -e "${GREEN}✓ dokploy-network exists${NC}"
else
    echo -e "${RED}✗ dokploy-network not found${NC}"
fi

echo ""
echo -e "${GREEN}=== Configuration Complete! ===${NC}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo ""
echo "1. Restart Dokploy container (if it was running):"
echo "   docker restart dokploy"
echo ""
echo "2. On remote server (51.159.99.20), join as worker:"
echo "   docker swarm leave --force  # If already in a swarm"
echo "   [paste the join command from above]"
echo ""
echo "3. Verify worker joined:"
echo "   docker node ls"
