# New Server Checklist

Quick reference for adding a new server to your infrastructure.

## Before You Start

Have ready:
- [ ] Server IP address
- [ ] Server purpose (production/staging/backup)
- [ ] Tailscale auth key (from https://login.tailscale.com/admin/settings/keys)
- [ ] GitHub token (for pulling Docker images)
- [ ] SSH access to the server

## Step-by-Step Checklist

### 1. Initial Server Setup

```bash
# SSH into new server
ssh root@<new-server-ip>

# Update system
apt update && apt upgrade -y

# Set hostname
hostnamectl set-hostname <server-name>
# Example: exchange-backup-prod
```

### 2. Install Tailscale

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Connect to Tailscale network
sudo tailscale up \
  --authkey=tskey-auth-xxxxx-yyyyy \
  --hostname=<server-name> \
  --advertise-tags=tag:server

# Get and save Tailscale IP
tailscale ip -4
# Example: 100.100.100.40
```

**Save this IP!** You'll need it for configuration.

### 3. Verify Tailscale Connectivity

```bash
# Ping other servers
ping 100.100.100.10  # Server 1
ping 100.100.100.20  # Server 2

# Check Tailscale status
sudo tailscale status
```

### 4. Install Docker

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Verify
docker --version
```

### 5. Install Dokploy (Optional)

**Only if this server will run Dokploy:**

```bash
curl -sSL https://dokploy.com/install.sh | sh

# Access at: http://<server-ip>:3000
```

### 6. Join Docker Swarm (If Using Swarm)

**On the manager node**, get the join token:

```bash
# SSH to manager (Server 1)
ssh root@<manager-ip>

# Get worker join token
docker swarm join-token worker
```

**On the new server**, join the swarm:

```bash
# Use Tailscale IP of manager
docker swarm join \
  --token SWMTKN-1-xxxxx-yyyyy \
  100.100.100.10:2377
```

**Verify** (on manager):

```bash
docker node ls
# Should show new server
```

### 7. Configure Firewall

```bash
# Install UFW
apt install -y ufw

# Allow SSH
sudo ufw allow 22/tcp

# Allow Tailscale
sudo ufw allow in on tailscale0

# Allow Docker Swarm (if using swarm)
sudo ufw allow 2377/tcp  # Cluster management
sudo ufw allow 7946/tcp  # Container network discovery
sudo ufw allow 7946/udp
sudo ufw allow 4789/udp  # Overlay network

# Allow specific service ports (adjust as needed)
# sudo ufw allow 80/tcp    # HTTP
# sudo ufw allow 443/tcp   # HTTPS

# Enable firewall
sudo ufw --force enable

# Check status
sudo ufw status
```

### 8. Test Database Access (If Needed)

**If this server needs database access:**

```bash
# Install PostgreSQL client
apt install -y postgresql-client

# Test connection to Server 1 database via Tailscale
PGPASSWORD=your-db-password psql \
  -h 100.100.100.10 \
  -U postgres \
  -d exchange \
  -c "SELECT version();"

# Should connect successfully
```

### 9. Pull Docker Images

```bash
# Login to GitHub Container Registry
docker login ghcr.io -u <github-username> -p <github-token>

# Pull images
docker pull ghcr.io/bourse-numerique-d-afrique/server:latest
docker pull ghcr.io/bourse-numerique-d-afrique/server-clearing-house:latest
docker pull ghcr.io/bourse-numerique-d-afrique/client:latest
```

### 10. Update Documentation

Add to your server inventory:

| Server Name | Public IP | Tailscale IP | Role | Swarm Role |
|-------------|-----------|--------------|------|------------|
| <server-name> | <public-ip> | <tailscale-ip> | <role> | Worker/Manager |

**Update**:
- [ ] `dokploy/README.md` - Server IP mapping section
- [ ] Your private notes/wiki
- [ ] Monitoring systems (if any)

### 11. Add to Dokploy (From Main Node)

**If managing this server from Dokploy:**

1. Log into Dokploy orchestration node
2. Add new server:
   - Host: Use Tailscale IP (e.g., `100.100.100.40`)
   - SSH Key: Add your SSH key
   - Port: 22
3. Test connection
4. Deploy services

### 12. Setup Monitoring (Optional)

```bash
# Install node exporter for Prometheus
docker run -d \
  --name=node-exporter \
  --network=host \
  --restart=always \
  prom/node-exporter:latest

# Verify
curl http://localhost:9100/metrics
```

### 13. Security Hardening

```bash
# Disable password authentication (use SSH keys only)
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd

# Install fail2ban
apt install -y fail2ban
systemctl enable fail2ban
systemctl start fail2ban

# Setup automatic updates
apt install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades
```

### 14. Backup Configuration

```bash
# Export current config
mkdir -p /root/backup
cp /etc/ssh/sshd_config /root/backup/
cp /etc/ufw/user.rules /root/backup/
tailscale status > /root/backup/tailscale-status.txt

# Document installed packages
dpkg --get-selections > /root/backup/packages.txt
```

### 15. Final Verification

```bash
# Check all services
systemctl status docker
systemctl status tailscaled
sudo ufw status

# Check disk space
df -h

# Check memory
free -h

# Check network
ip addr
tailscale status

# Test connectivity to other servers
ping -c 3 100.100.100.10
ping -c 3 100.100.100.20

# Check Docker
docker ps
docker images
```

## Automated Setup Script

Save this as `setup-new-server.sh` on your local machine:

```bash
#!/bin/bash
# setup-new-server.sh - Automated new server setup

set -e

SERVER_IP=$1
SERVER_NAME=$2
TAILSCALE_KEY=$3
GITHUB_TOKEN=$4

if [ -z "$SERVER_IP" ] || [ -z "$SERVER_NAME" ] || [ -z "$TAILSCALE_KEY" ]; then
    echo "Usage: ./setup-new-server.sh <server-ip> <server-name> <tailscale-key> [github-token]"
    exit 1
fi

echo "=== Setting up $SERVER_NAME ($SERVER_IP) ==="

# Update system
ssh root@$SERVER_IP "apt update && apt upgrade -y"

# Set hostname
ssh root@$SERVER_IP "hostnamectl set-hostname $SERVER_NAME"

# Install Tailscale
ssh root@$SERVER_IP "curl -fsSL https://tailscale.com/install.sh | sh"
ssh root@$SERVER_IP "tailscale up --authkey=$TAILSCALE_KEY --hostname=$SERVER_NAME --advertise-tags=tag:server"

# Get Tailscale IP
TAILSCALE_IP=$(ssh root@$SERVER_IP "tailscale ip -4")
echo "✅ Tailscale IP: $TAILSCALE_IP"

# Install Docker
ssh root@$SERVER_IP "curl -fsSL https://get.docker.com | sh"
ssh root@$SERVER_IP "systemctl enable docker && systemctl start docker"

# Setup firewall
ssh root@$SERVER_IP << 'ENDSSH'
apt install -y ufw
ufw allow 22/tcp
ufw allow in on tailscale0
ufw --force enable
ENDSSH

# Login to GitHub registry (if token provided)
if [ -n "$GITHUB_TOKEN" ]; then
    ssh root@$SERVER_IP "echo $GITHUB_TOKEN | docker login ghcr.io -u github --password-stdin"
fi

# Test connectivity
ssh root@$SERVER_IP "ping -c 3 100.100.100.10 || echo 'Warning: Cannot ping Server 1'"

echo "=== Setup Complete ==="
echo ""
echo "Server: $SERVER_NAME"
echo "Public IP: $SERVER_IP"
echo "Tailscale IP: $TAILSCALE_IP"
echo ""
echo "Next steps:"
echo "1. Add to server inventory"
echo "2. Join Docker Swarm (if needed)"
echo "3. Deploy services via Dokploy"
```

**Usage**:
```bash
chmod +x setup-new-server.sh
./setup-new-server.sh \
  203.0.113.50 \
  exchange-backup-prod \
  tskey-auth-xxxxx-yyyyy \
  ghp_xxxxx
```

## Common Post-Setup Tasks

### Deploy Exchange Service

```bash
# Via Docker Compose
docker-compose -f docker-compose.production.yml up -d

# Or via Dokploy web UI
```

### Add to Load Balancer

If using HAProxy/Nginx:

```nginx
upstream exchange_backend {
    server 100.100.100.10:5700;  # Server 1
    server 100.100.100.40:5700;  # New server
}
```

### Setup Backup Scripts

```bash
# Create backup script
cat > /root/backup.sh << 'EOF'
#!/bin/bash
# Backup script
tar -czf /backup/$(date +%Y%m%d)-backup.tar.gz /var/lib/docker
# Copy to another server via Tailscale
scp /backup/*.tar.gz root@100.100.100.10:/backups/
EOF

chmod +x /root/backup.sh

# Add to cron
crontab -e
# Add: 0 2 * * * /root/backup.sh
```

## Troubleshooting

### Tailscale Not Connecting

```bash
# Check Tailscale logs
sudo journalctl -u tailscaled -f

# Restart Tailscale
sudo systemctl restart tailscaled
sudo tailscale up --authkey=<key> --hostname=<name>
```

### Cannot Access Database

```bash
# Check firewall on database server
sudo ufw status

# Check PostgreSQL is listening on Tailscale IP
ss -tlnp | grep 5432

# Test from new server
telnet 100.100.100.10 5432
```

### Docker Swarm Join Fails

```bash
# Check firewall allows swarm ports
sudo ufw allow 2377/tcp
sudo ufw allow 7946/tcp
sudo ufw allow 7946/udp
sudo ufw allow 4789/udp

# Try join again with Tailscale IP
docker swarm join --token <token> 100.100.100.10:2377
```

## Reference Links

- **Tailscale Setup**: [TAILSCALE-SETUP.md](./TAILSCALE-SETUP.md)
- **Deployment Guide**: [DEPLOYMENT.md](./DEPLOYMENT.md)
- **Quick Start**: [QUICK-START.md](./QUICK-START.md)
- **Dokploy Docs**: https://docs.dokploy.com

---

**Last Updated**: 2026-01-03
**Maintainer**: Bourse Numérique d'Afrique Team
