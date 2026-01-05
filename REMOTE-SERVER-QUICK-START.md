# Remote Dokploy Server - Quick Start Guide

Complete setup guide for configuring server 51.159.99.20 to work with Dokploy deployments.

## TL;DR - Get Server Ready in 5 Minutes

### Option 1: Automated Installation (Recommended)

```bash
# From your laptop, copy script to server
scp /tmp/dokploy/install-dokploy-server.sh root@51.159.99.20:/tmp/

# SSH into server and run
ssh root@51.159.99.20
bash /tmp/install-dokploy-server.sh
```

### Option 2: One-Liner Remote Execution

```bash
# Copy and execute in one command
cat /tmp/dokploy/install-dokploy-server.sh | ssh root@51.159.99.20 'bash -s'
```

## What Gets Installed

✓ Docker + Docker Compose
✓ Docker Swarm (initialized)
✓ Dokploy Network (overlay network)
✓ RClone (backup/sync tool)
✓ Nixpacks (build tool)
✓ Buildpacks (Cloud Native Buildpacks)
✓ Railway CLI (deployment tool)
✓ Traefik (reverse proxy with SSL)
✓ UFW Firewall (configured and enabled)
✓ Directory structure at /etc/dokploy

## Post-Installation Checklist

### 1. Login to GitHub Container Registry (REQUIRED)

Your server needs authentication to pull private Docker images:

```bash
# On the remote server (51.159.99.20)
echo 'YOUR_GITHUB_TOKEN' | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
```

To create a GitHub token:
1. Go to https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Select scopes: `read:packages`, `write:packages`
4. Copy token and use in command above

### 2. Configure DNS Records (REQUIRED)

Add these A records in your DNS provider pointing to **51.159.99.20**:

| Domain | Type | Value |
|--------|------|-------|
| test.boursenumeriquedafrique.com | A | 51.159.99.20 |
| test-api.boursenumeriquedafrique.com | A | 51.159.99.20 |
| test-payments.boursenumeriquedafrique.com | A | 51.159.99.20 |

**Check DNS propagation:**
```bash
dig +short test.boursenumeriquedafrique.com
# Should return: 51.159.99.20
```

### 3. Deploy from Dokploy

In your Dokploy UI (running on laptop at https://route.boursenumeriquedafrique.com):

1. Go to exchange-staging project
2. Edit your compose service "services"
3. Make sure `serverId` is set to: **MJebnVc8mD_R_mHECttIZ**
4. Click "Deploy"

The deployment will now work because the server is fully configured!

## Verification Commands

Run these on the server to verify everything is working:

```bash
# Quick verification
verify-dokploy

# Manual checks
docker info | grep Swarm          # Should show "Swarm: active"
docker network ls | grep dokploy  # Should show dokploy-network
docker service ls                 # Should show traefik service
ufw status                        # Should show "Status: active"
```

## Common Issues

### Issue: "Permission denied" when deploying

**Fix:** Make sure you logged into GitHub Container Registry (see step 1)

```bash
docker login ghcr.io -u YOUR_USERNAME
```

### Issue: SSL certificate not issued

**Fix:** DNS must be configured and propagated first

```bash
# Check if DNS is pointing to correct IP
dig +short test-api.boursenumeriquedafrique.com
# Should return: 51.159.99.20
```

### Issue: Deployment fails with "network not found"

**Fix:** Ensure dokploy-network exists

```bash
docker network create --driver overlay --attachable dokploy-network
```

### Issue: UFW blocking connections

**Check open ports:**
```bash
ufw status verbose
```

**Add missing port:**
```bash
ufw allow PORT/tcp
```

## Firewall Ports Reference

| Port | Purpose | Protocol |
|------|---------|----------|
| 22 | SSH | TCP |
| 80 | HTTP | TCP |
| 443 | HTTPS | TCP |
| 2377 | Docker Swarm Management | TCP |
| 7946 | Docker Swarm Discovery | TCP/UDP |
| 4789 | Docker Overlay Network | UDP |
| 3000 | Dokploy Web Interface | TCP |
| 5700 | Exchange GraphQL | TCP |
| 8500 | Clearing House | TCP |

## Files Location

All Dokploy files are stored in:
```
/etc/dokploy/
├── logs/           # Application logs
├── data/           # Persistent data
├── traefik/        # Traefik configuration
│   ├── traefik.yml # Traefik config
│   └── acme.json   # SSL certificates
└── postgres/       # PostgreSQL data
```

## Quick Commands

```bash
# View all Docker services
docker service ls

# View service logs
docker service logs SERVICE_NAME --tail 100 --follow

# Restart a service
docker service update --force SERVICE_NAME

# Check Traefik dashboard
curl http://51.159.99.20:8080/api/http/routers

# View UFW rules
ufw status numbered

# Check what's using a port
netstat -tuln | grep :PORT
```

## Security Hardening (Optional but Recommended)

```bash
# Create non-root user
adduser deploy
usermod -aG docker deploy
usermod -aG sudo deploy

# Disable root SSH login
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl restart sshd

# Change SSH port (example: 2222)
sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
ufw allow 2222/tcp
ufw delete allow 22/tcp
systemctl restart sshd

# Setup fail2ban
apt install -y fail2ban
systemctl enable fail2ban
systemctl start fail2ban
```

## Troubleshooting Commands

```bash
# Check system resources
free -h                    # Memory usage
df -h                      # Disk usage
top                        # CPU usage
docker system df           # Docker disk usage

# Docker cleanup
docker system prune -a     # Remove unused images/containers
docker volume prune        # Remove unused volumes

# View all logs
journalctl -xe             # System logs
journalctl -u docker       # Docker service logs

# Network debugging
ip addr show               # Show IP addresses
netstat -rn                # Show routing table
ping 8.8.8.8              # Test internet connectivity
```

## Support

For issues with:
- **This setup**: Check /tmp/dokploy/SERVER-SETUP-GUIDE.md
- **Dokploy**: https://dokploy.com/docs
- **Docker**: https://docs.docker.com/
- **Traefik**: https://doc.traefik.io/traefik/

## Next Steps

Once server is ready:
1. ✓ Server configured (you just did this!)
2. ⏳ GitHub Container Registry login
3. ⏳ DNS configuration
4. ⏳ Deploy from Dokploy UI
5. ⏳ Verify services are running
6. ⏳ Test applications at staging URLs

**Questions?** Check the detailed guide: `/tmp/dokploy/SERVER-SETUP-GUIDE.md`
