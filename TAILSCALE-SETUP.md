# Tailscale Setup for Private Networking

This guide covers Tailscale configuration for secure private networking between your servers, Dokploy orchestration, and Docker Swarm operations.

## Why Tailscale?

Tailscale creates a secure mesh VPN between all your servers:

✅ **Zero-trust security** - Encrypted point-to-point connections
✅ **No firewall changes** - Works behind NAT, no port forwarding
✅ **Private networking** - Servers communicate via private IPs
✅ **Easy management** - Web dashboard, simple CLI
✅ **Free tier** - Up to 100 devices, perfect for small infrastructures
✅ **Docker Swarm** - Secure cluster communication
✅ **Database access** - Clearing house can reach Exchange DB privately

## Architecture

### Without Tailscale (Public Internet)
```
┌─────────────────┐
│  Server 1       │
│  10.1.0.10      │
└────────┬────────┘
         │
         ↓ Public Internet (insecure)
         │
┌────────┴────────┐
│  Server 2       │
│  20.2.0.20      │
└─────────────────┘

❌ Database exposed to public
❌ Unencrypted communication
❌ Complex firewall rules
```

### With Tailscale (Private Mesh VPN)
```
┌─────────────────────────────┐
│       Tailscale Network     │
│       (100.64.0.0/10)       │
│                             │
│  ┌─────────────────────┐   │
│  │ Your PC / Dokploy   │   │
│  │ 100.100.100.1       │   │
│  └──────────┬──────────┘   │
│             │               │
│  ┌──────────┴──────────┐   │
│  │                     │   │
│  ↓                     ↓   │
│  Server 1            Server 2
│  100.100.100.10      100.100.100.20
│  Exchange API        Clearing House
└─────────────────────────────┘

✅ Encrypted mesh network
✅ Private IPs for all services
✅ No exposed database ports
✅ Simple firewall rules
```

## Prerequisites

- Tailscale account (free): https://login.tailscale.com/start
- Root or sudo access on all servers
- Servers running Linux (Ubuntu/Debian/CentOS/etc.)

## Initial Setup

### 1. Create Tailscale Account

1. Go to https://login.tailscale.com/start
2. Sign up with Google, Microsoft, or GitHub
3. Choose a tailnet name (e.g., `boursenumeriquedafrique`)
4. Complete setup

### 2. Generate Auth Key (for servers)

1. Go to https://login.tailscale.com/admin/settings/keys
2. Click **Generate auth key**
3. Configure:
   - **Description**: `Production Servers`
   - **Reusable**: ✅ Checked (can use on multiple servers)
   - **Ephemeral**: ❌ Unchecked (keep devices after disconnect)
   - **Preauthorized**: ✅ Checked (auto-approve devices)
   - **Tags**: Add tag `tag:server` (for ACL management)
4. **Copy the auth key** - looks like `tskey-auth-xxxxxxxxxxxx-yyyyyyyyyyyyyyyy`

**Important**: Store this key securely - you'll need it for every new server.

## Installing Tailscale on Servers

### Option 1: Interactive Installation (First Time)

```bash
# On each server, run:

# 1. Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# 2. Start Tailscale and authenticate
sudo tailscale up

# 3. Follow the URL to authorize the device
# Browser will open - approve the device
```

### Option 2: Automated Installation (With Auth Key)

**Recommended for production** - no manual approval needed:

```bash
# On each server, run:

# 1. Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# 2. Start Tailscale with auth key
sudo tailscale up --authkey=tskey-auth-xxxxxxxxxxxx-yyyyyyyyyyyyyyyy --advertise-tags=tag:server

# 3. Set hostname (optional but recommended)
sudo tailscale set --hostname=exchange-api-prod
```

**Hostname naming convention**:
- `exchange-api-prod` - Production Exchange server
- `clearing-house-prod` - Production Clearing House server
- `exchange-staging` - Staging server
- `dokploy-local` - Your local PC with Dokploy

### Option 3: Automated Script (For Multiple Servers)

Create this script on your local machine to set up new servers:

```bash
#!/bin/bash
# setup-tailscale.sh - Run on new server via SSH

set -e

HOSTNAME=$1
AUTH_KEY="${TAILSCALE_AUTH_KEY}"  # Set as environment variable

if [ -z "$HOSTNAME" ] || [ -z "$AUTH_KEY" ]; then
    echo "Usage: TAILSCALE_AUTH_KEY=tskey-... ./setup-tailscale.sh <hostname>"
    exit 1
fi

echo "Installing Tailscale on $HOSTNAME..."

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Start Tailscale
sudo tailscale up --authkey="$AUTH_KEY" \
    --advertise-tags=tag:server \
    --hostname="$HOSTNAME" \
    --accept-routes \
    --accept-dns=false

# Verify
sleep 5
sudo tailscale status

echo "✅ Tailscale configured successfully!"
echo "Tailscale IP: $(tailscale ip -4)"
```

**Usage**:
```bash
# Copy script to new server
scp setup-tailscale.sh root@new-server:/root/

# Run via SSH
ssh root@new-server "TAILSCALE_AUTH_KEY=tskey-xxx... bash /root/setup-tailscale.sh exchange-api-prod"
```

## Verifying Installation

After installation, verify on each server:

```bash
# Check Tailscale status
sudo tailscale status

# Get Tailscale IP
tailscale ip -4

# Ping another server in the network
ping 100.100.100.10  # Replace with another server's Tailscale IP

# Check connected devices
sudo tailscale status --peers
```

**Expected output**:
```
100.100.100.1   dokploy-local        user@       linux   active; direct 192.168.1.100:41641
100.100.100.10  exchange-api-prod    user@       linux   active; relay "fra", tx 1024 rx 2048
100.100.100.20  clearing-house-prod  user@       linux   active; relay "fra", tx 512 rx 1024
```

## Docker Swarm Integration

### Architecture with Tailscale

```
┌──────────────────────────────────────┐
│      Tailscale Private Network       │
│                                      │
│  ┌──────────────────────────┐       │
│  │  Docker Swarm Cluster    │       │
│  │                          │       │
│  │  Manager Node            │       │
│  │  100.100.100.10:2377     │       │
│  │  (Exchange API Server)   │       │
│  └────────┬─────────────────┘       │
│           │                          │
│  ┌────────┴─────────────────┐       │
│  │ Worker Nodes             │       │
│  │ 100.100.100.20           │       │
│  │ (Clearing House Server)  │       │
│  └──────────────────────────┘       │
└──────────────────────────────────────┘
```

### 1. Initialize Docker Swarm on Manager Node

On **Server 1** (Exchange API - Manager):

```bash
# Get Tailscale IP
TAILSCALE_IP=$(tailscale ip -4)
echo "Tailscale IP: $TAILSCALE_IP"

# Initialize swarm using Tailscale IP
docker swarm init --advertise-addr $TAILSCALE_IP

# Get join token
docker swarm join-token worker

# Save the output - you'll need it for workers
```

**Example output**:
```bash
docker swarm join --token SWMTKN-1-xxxxxxxxx-yyyyyyyyyy 100.100.100.10:2377
```

### 2. Join Worker Nodes

On **Server 2** (Clearing House - Worker):

```bash
# Get manager's Tailscale IP
MANAGER_IP=100.100.100.10  # Exchange server's Tailscale IP

# Join swarm using Tailscale network
docker swarm join --token SWMTKN-1-xxxxxxxxx-yyyyyyyyyy $MANAGER_IP:2377
```

### 3. Verify Swarm Cluster

On **Manager node**:

```bash
# List nodes
docker node ls

# Should show:
# ID              HOSTNAME              STATUS    AVAILABILITY   MANAGER STATUS
# abc123          exchange-api-prod     Ready     Active         Leader
# def456          clearing-house-prod   Ready     Active
```

### 4. Deploy Services Across Swarm

Example docker-compose.yml for swarm:

```yaml
version: '3.8'

services:
  exchange:
    image: ghcr.io/bourse-numerique-d-afrique/server:latest
    deploy:
      replicas: 2
      placement:
        constraints:
          - node.labels.role == api
    networks:
      - tailscale-net
    environment:
      POSTGRES_HOST: 100.100.100.10  # Tailscale IP

  clearing-house:
    image: ghcr.io/bourse-numerique-d-afrique/server-clearing-house:latest
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.labels.role == payments
    networks:
      - tailscale-net
    environment:
      POSTGRES_HOST: 100.100.100.10  # Connect via Tailscale

networks:
  tailscale-net:
    driver: overlay
    attachable: true
```

Deploy:
```bash
docker stack deploy -c docker-compose.yml bourse-stack
```

## Database Access via Tailscale

### Current Setup (Before Tailscale)
```env
# .env.clearing-house
POSTGRES_HOST=10.x.x.x  # VPS provider's private network
# Or worse:
POSTGRES_HOST=<public-ip>  # Exposed to internet 😱
```

### Recommended Setup (With Tailscale)
```env
# .env.clearing-house
POSTGRES_HOST=100.100.100.10  # Exchange server's Tailscale IP
POSTGRES_PORT=5432
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your-password
```

**Benefits**:
✅ Encrypted connection (WireGuard)
✅ No public database exposure
✅ Works from anywhere (even your local PC for debugging)
✅ No firewall rule changes needed

### Firewall Configuration

With Tailscale, you can **block public access** to sensitive ports:

```bash
# On Exchange Server (where database runs)

# BEFORE Tailscale: Allow from specific IP
sudo ufw allow from <clearing-house-ip> to any port 5432

# AFTER Tailscale: Only allow from Tailscale network
sudo ufw delete allow 5432  # Remove old rule if exists
sudo ufw allow in on tailscale0 to any port 5432

# Allow only Tailscale traffic to database
sudo ufw deny 5432
sudo ufw allow in on tailscale0 proto tcp to any port 5432
```

This ensures database is **only accessible via Tailscale**, not public internet.

## Adding New Servers to Infrastructure

### Standard Procedure

When deploying a new server:

1. **Provision server** (VPS/Cloud)
2. **Install Tailscale** (use automated script above)
3. **Verify connectivity**:
   ```bash
   # From new server, ping existing servers
   ping 100.100.100.10  # Exchange API
   ping 100.100.100.20  # Clearing House
   ```
4. **Update environment files** to use Tailscale IPs
5. **Join Docker Swarm** (if applicable)
6. **Deploy services** via Dokploy

### Quick Add Script

```bash
#!/bin/bash
# add-server-to-infrastructure.sh

NEW_SERVER_IP=$1
NEW_SERVER_NAME=$2
TAILSCALE_AUTH_KEY=$3

if [ -z "$NEW_SERVER_IP" ] || [ -z "$NEW_SERVER_NAME" ] || [ -z "$TAILSCALE_AUTH_KEY" ]; then
    echo "Usage: ./add-server.sh <server-ip> <hostname> <tailscale-auth-key>"
    exit 1
fi

echo "Setting up $NEW_SERVER_NAME ($NEW_SERVER_IP)..."

# 1. Install Tailscale
ssh root@$NEW_SERVER_IP "curl -fsSL https://tailscale.com/install.sh | sh"

# 2. Connect to Tailscale
ssh root@$NEW_SERVER_IP "tailscale up --authkey=$TAILSCALE_AUTH_KEY --hostname=$NEW_SERVER_NAME --advertise-tags=tag:server"

# 3. Get Tailscale IP
TAILSCALE_IP=$(ssh root@$NEW_SERVER_IP "tailscale ip -4")
echo "✅ Tailscale IP: $TAILSCALE_IP"

# 4. Install Docker (if not installed)
ssh root@$NEW_SERVER_IP "curl -fsSL https://get.docker.com | sh"

# 5. Test connectivity
ssh root@$NEW_SERVER_IP "ping -c 3 100.100.100.10"

echo "✅ Server $NEW_SERVER_NAME ready!"
echo "   Public IP: $NEW_SERVER_IP"
echo "   Tailscale IP: $TAILSCALE_IP"
echo ""
echo "Next steps:"
echo "  1. Update .env files with Tailscale IP: $TAILSCALE_IP"
echo "  2. Join Docker Swarm (if needed)"
echo "  3. Deploy services via Dokploy"
```

**Usage**:
```bash
./add-server-to-infrastructure.sh \
    203.0.113.50 \
    exchange-backup \
    tskey-auth-xxxxx-yyyyy
```

## Local PC / Dokploy Setup

### Install on Your PC

**Linux/macOS**:
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --hostname=dokploy-local
```

**Windows**:
```powershell
# Download installer from https://tailscale.com/download/windows
# Or use winget
winget install tailscale.tailscale

# Run Tailscale from system tray
```

### Benefits for Local Development

Once your PC is on Tailscale:

✅ **Access production database** (for debugging):
```bash
psql -h 100.100.100.10 -U postgres -d exchange
```

✅ **Test against production APIs**:
```bash
curl http://100.100.100.10:5700/graphql
```

✅ **Deploy from local Dokploy** to remote servers via Tailscale

✅ **No VPN/SSH tunnels** needed

## Access Control Lists (ACLs)

Control which devices can access what with Tailscale ACLs.

### Basic ACL Configuration

1. Go to https://login.tailscale.com/admin/acls
2. Edit the ACL JSON:

```json
{
  "tagOwners": {
    "tag:server": ["autogroup:admin"],
    "tag:admin": ["autogroup:admin"]
  },
  "acls": [
    // Admin (your PC) can access everything
    {
      "action": "accept",
      "src": ["tag:admin"],
      "dst": ["*:*"]
    },

    // Servers can talk to each other
    {
      "action": "accept",
      "src": ["tag:server"],
      "dst": ["tag:server:*"]
    },

    // Clearing house can access Exchange database
    {
      "action": "accept",
      "src": ["tag:server"],
      "dst": ["tag:server:5432"]
    },

    // Deny all by default
    {
      "action": "deny",
      "src": ["*"],
      "dst": ["*:*"]
    }
  ]
}
```

3. **Test ACLs** before applying
4. **Save**

### Applying Tags

Tag your devices:

```bash
# On each server during setup
sudo tailscale up --advertise-tags=tag:server

# On your PC
sudo tailscale up --advertise-tags=tag:admin
```

Or apply tags via web dashboard: https://login.tailscale.com/admin/machines

## Troubleshooting

### Cannot Ping Other Tailscale Devices

**Check Tailscale status**:
```bash
sudo tailscale status
# All devices should show "active"
```

**Check IP forwarding** (for relay nodes):
```bash
sudo sysctl net.ipv4.ip_forward
# Should be 1
```

**Enable if needed**:
```bash
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### Docker Swarm Not Working Over Tailscale

**Ensure firewall allows Tailscale interface**:
```bash
# Allow all on tailscale0 interface
sudo ufw allow in on tailscale0
```

**Use Tailscale IP explicitly**:
```bash
# When initializing swarm
docker swarm init --advertise-addr $(tailscale ip -4) --listen-addr $(tailscale ip -4):2377
```

### Database Connection Refused

**Check PostgreSQL binds to Tailscale IP**:
```bash
# Edit postgresql.conf
sudo nano /etc/postgresql/*/main/postgresql.conf

# Change:
listen_addresses = 'localhost'
# To:
listen_addresses = 'localhost,100.100.100.10'  # Your Tailscale IP

# Restart
sudo systemctl restart postgresql
```

**Check pg_hba.conf**:
```bash
sudo nano /etc/postgresql/*/main/pg_hba.conf

# Add:
host    all    all    100.64.0.0/10    md5  # Allow Tailscale network
```

### Slow Connection / High Latency

**Check connection type**:
```bash
sudo tailscale status

# Look for "direct" (good) vs "relay" (slower)
100.100.100.10  server1  active; direct 203.0.113.1:41641  # Good - direct
100.100.100.20  server2  active; relay "fra"              # Slower - through relay
```

**Enable direct connections** (if behind strict NAT):
```bash
# Allow UDP 41641 in firewall
sudo ufw allow 41641/udp
```

## Monitoring and Management

### Web Dashboard

Access at: https://login.tailscale.com/admin/machines

**Features**:
- View all connected devices
- See connection status (direct/relay)
- Approve new devices
- Apply tags
- View traffic logs

### CLI Management

```bash
# List all devices
tailscale status

# Get your IP
tailscale ip

# Check routes
tailscale status --peers

# Logout (disconnect)
sudo tailscale logout

# Reconnect
sudo tailscale up

# Update Tailscale
sudo tailscale update
```

### Best Practices

1. **Use descriptive hostnames**: `exchange-api-prod`, not `server1`
2. **Tag devices**: Apply `tag:server`, `tag:staging`, etc.
3. **Document IPs**: Keep a reference of which server has which Tailscale IP
4. **Regular updates**: Update Tailscale client monthly
5. **Use ACLs**: Don't allow unrestricted access
6. **Monitor logs**: Check Tailscale dashboard for connection issues

## Reference: Server IP Mapping

Keep this updated as you add servers:

| Server Name | Public IP | Tailscale IP | Role | Tags |
|-------------|-----------|--------------|------|------|
| dokploy-local | N/A (local) | 100.100.100.1 | Orchestration | tag:admin |
| exchange-api-prod | 203.0.113.10 | 100.100.100.10 | Exchange API, DB | tag:server |
| clearing-house-prod | 203.0.113.20 | 100.100.100.20 | Clearing House | tag:server |
| exchange-staging | 203.0.113.30 | 100.100.100.30 | Staging (all-in-one) | tag:server,tag:staging |

**Store this in a secure location** (password manager, private wiki).

## Cost

| Tier | Devices | Price | Best For |
|------|---------|-------|----------|
| Personal | 100 | **Free** | Small infrastructure |
| Starter | 200 | $6/user/month | Growing teams |
| Premium | Unlimited | $18/user/month | Enterprise |

**For your use case**: Free tier is sufficient (< 10 devices).

## Security Considerations

✅ **Use auth keys** for automated server setup
✅ **Enable 2FA** on Tailscale account
✅ **Apply ACLs** to restrict device communication
✅ **Regular audits** - review connected devices monthly
✅ **Revoke devices** that are no longer used
✅ **Use tags** for organized access control
✅ **Monitor logs** via web dashboard

## Additional Resources

- **Tailscale Docs**: https://tailscale.com/kb/
- **Docker Swarm Guide**: https://tailscale.com/kb/1185/docker/
- **ACL Examples**: https://tailscale.com/kb/1018/acls/
- **Best Practices**: https://tailscale.com/kb/1019/subnets/

---

**Last Updated**: 2026-01-03
**Maintainer**: Bourse Numérique d'Afrique Team
