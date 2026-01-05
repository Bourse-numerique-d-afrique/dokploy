# Remote Server Setup Using Official Dokploy Installer

This guide uses Dokploy's official installation script to set up server 51.159.99.20.

## Quick Setup (5 Minutes)

### Step 1: Run Official Dokploy Installer

SSH into your server and run:

```bash
ssh root@51.159.99.20

# Run official Dokploy installer
curl -sSL https://dokploy.com/install.sh | sh
```

This installs everything automatically:
- ✓ Docker + Docker Compose
- ✓ Docker Swarm (initialized)
- ✓ dokploy-network (overlay network)
- ✓ Traefik (reverse proxy)
- ✓ RClone, Nixpacks, Buildpacks, Railpack
- ✓ Dokploy application itself

**Note:** The script takes 2-5 minutes to complete.

### Step 2: Access Dokploy on Remote Server

After installation completes:

```bash
# Dokploy will be available at:
http://51.159.99.20:3000
```

Open in browser and complete initial setup:
1. Create admin account
2. Set password
3. Login to Dokploy UI

### Step 3: Configure Firewall (UFW)

The official installer doesn't configure firewall, so add it manually:

```bash
# Install UFW
apt install -y ufw

# Set default policies
ufw default deny incoming
ufw default allow outgoing

# CRITICAL: Allow SSH first!
ufw allow 22/tcp

# Allow Dokploy web interface
ufw allow 3000/tcp

# Allow HTTP/HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Allow Docker Swarm ports
ufw allow 2377/tcp
ufw allow 7946/tcp
ufw allow 7946/udp
ufw allow 4789/udp

# Enable firewall
ufw --force enable

# Verify
ufw status verbose
```

### Step 4: Login to GitHub Container Registry

On the server, authenticate to pull private Docker images:

```bash
echo 'YOUR_GITHUB_TOKEN' | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
```

**How to get a GitHub token:**
1. Go to https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Select scopes: `read:packages`
4. Copy and use in command above

### Step 5: Configure DNS Records

Add these A records pointing to **51.159.99.20**:

| Domain | Type | Value |
|--------|------|-------|
| test.boursenumeriquedafrique.com | A | 51.159.99.20 |
| test-api.boursenumeriquedafrique.com | A | 51.159.99.20 |
| test-payments.boursenumeriquedafrique.com | A | 51.159.99.20 |

**Verify DNS propagation:**
```bash
dig +short test-api.boursenumeriquedafrique.com
# Should return: 51.159.99.20
```

## Deploy Your Application

### Option A: Deploy from Local Dokploy (Your Laptop)

If you want to control deployments from your laptop Dokploy:

1. Open your laptop Dokploy: https://route.boursenumeriquedafrique.com
2. Go to Settings → Servers
3. Add the remote server:
   - Name: Production Server
   - IP: 51.159.99.20
   - Port: 2377
   - Add SSH key
4. In your compose service, select this server
5. Deploy!

### Option B: Deploy Directly on Remote Dokploy

If you want to deploy directly on the remote server:

1. Open remote Dokploy: http://51.159.99.20:3000
2. Create Project: "exchange-staging"
3. Add Docker Compose service
4. Paste your docker-compose.staging.yml
5. Add environment variables
6. Configure domains with Traefik
7. Deploy!

## Using the Official Script via GitHub Gist

Yes, you can save the Dokploy script to a gist:

### Create Gist

1. Go to https://gist.github.com
2. Create new gist
3. Name: `dokploy-install.sh`
4. Paste the Dokploy installation script
5. Create public gist
6. Get raw URL (click "Raw" button)

### Run from Gist

```bash
# Example if your gist raw URL is:
# https://gist.githubusercontent.com/username/abc123/raw/dokploy-install.sh

ssh root@51.159.99.20
curl -sSL https://gist.githubusercontent.com/username/abc123/raw/dokploy-install.sh | sh
```

**However**, it's better to use the official URL:
```bash
curl -sSL https://dokploy.com/install.sh | sh
```

This ensures you always get the latest version.

## Post-Installation Verification

Run these commands on the server:

```bash
# Check Docker
docker --version
docker compose version

# Check Docker Swarm
docker info | grep Swarm
# Should show: Swarm: active

# Check network
docker network ls | grep dokploy
# Should show: dokploy-network

# Check Traefik
docker ps | grep traefik
# Should show running container

# Check Dokploy
docker ps | grep dokploy
# Should show running container

# Check installations
nixpacks --version
pack version
rclone version

# Check firewall
ufw status verbose
```

## Architecture Differences

### Dokploy on Laptop (Current Setup)
```
Your Laptop (Local)
├── Dokploy UI (https://route.boursenumeriquedafrique.com)
└── Controls → Remote Server (51.159.99.20)
    └── Runs containers
```

### Dokploy on Remote Server (Recommended)
```
Remote Server (51.159.99.20)
├── Dokploy UI (http://51.159.99.20:3000)
└── Runs containers locally
```

**Advantages of remote Dokploy:**
- No need to keep laptop running
- Faster deployments (no network latency)
- More reliable (dedicated server)
- Can use webhooks for auto-deploy

## Complete Setup Script

Here's a complete script you can save to a gist:

```bash
#!/bin/bash
set -e

echo "=== Dokploy Server Setup for 51.159.99.20 ==="
echo ""

# 1. Install Dokploy (official installer)
echo "1. Installing Dokploy..."
curl -sSL https://dokploy.com/install.sh | sh

echo ""
echo "2. Configuring firewall..."
apt install -y ufw

ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Allow required ports
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw allow 3000/tcp  # Dokploy UI
ufw allow 2377/tcp  # Docker Swarm
ufw allow 7946/tcp  # Swarm discovery
ufw allow 7946/udp  # Swarm discovery
ufw allow 4789/udp  # Overlay network

ufw --force enable

echo ""
echo "=== Installation Complete! ==="
echo ""
echo "Next steps:"
echo "1. Access Dokploy: http://51.159.99.20:3000"
echo "2. Login to GitHub: echo 'TOKEN' | docker login ghcr.io -u USERNAME --password-stdin"
echo "3. Configure DNS records to point to 51.159.99.20"
echo "4. Create project and deploy!"
echo ""
echo "Verify installation:"
echo "  docker info | grep Swarm"
echo "  docker network ls | grep dokploy"
echo "  ufw status"
```

Save this to a gist and run:
```bash
curl -sSL YOUR_GIST_RAW_URL | bash
```

## Troubleshooting

### Port 80/443 already in use

If you see warnings about ports 80/443:

```bash
# Check what's using the ports
ss -tulnp | grep ':80 '
ss -tulnp | grep ':443 '

# If it's an old web server, stop it
systemctl stop apache2  # or nginx
systemctl disable apache2
```

### Docker login fails

```bash
# Make sure you have a valid GitHub token with read:packages scope
# Test the token
curl -H "Authorization: token YOUR_TOKEN" https://api.github.com/user
```

### Traefik not starting

```bash
# Check Traefik logs
docker logs dokploy-traefik

# Restart Traefik
docker restart dokploy-traefik
```

## Security Recommendations

After installation:

```bash
# 1. Change SSH port (optional but recommended)
sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
ufw allow 2222/tcp
systemctl restart sshd
# Remember to update UFW to deny port 22 later

# 2. Disable root login (after creating sudo user)
adduser deploy
usermod -aG sudo deploy
usermod -aG docker deploy
# Test sudo access first!
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl restart sshd

# 3. Install fail2ban
apt install -y fail2ban
systemctl enable fail2ban
systemctl start fail2ban
```

## Resources

- Official Dokploy Docs: https://docs.dokploy.com
- Docker Swarm: https://docs.docker.com/engine/swarm/
- Traefik: https://doc.traefik.io/traefik/

## Questions?

- Check official Dokploy documentation
- Join Dokploy Discord: https://discord.gg/dokploy
- GitHub Issues: https://github.com/Dokploy/dokploy/issues
