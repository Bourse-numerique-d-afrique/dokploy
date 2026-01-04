# Quick Start Guide - Bourse Numérique d'Afrique Deployment

Get your exchange platform running in production in under 1 hour.

## Prerequisites Checklist

- [ ] 3 VPS servers provisioned (or 1 for staging)
- [ ] Dokploy installed on all servers
- [ ] **Tailscale account created** (free at https://tailscale.com)
- [ ] **Tailscale installed on ALL servers** (see TAILSCALE-SETUP.md)
- [ ] Domain `boursenumeriquedafrique.com` purchased
- [ ] GitHub Personal Access Token created
- [ ] MTN MoMo API credentials obtained
- [ ] Airtel Money API credentials obtained
- [ ] Ethereum wallet/keys ready

**⚠️ IMPORTANT**: Tailscale setup is REQUIRED before continuing. It provides secure private networking between servers. See [TAILSCALE-SETUP.md](./TAILSCALE-SETUP.md) for setup instructions.

## 60-Minute Production Deployment

### Step 1: Tailscale Setup (15 minutes)

**On each server**, install and connect to Tailscale:

```bash
# SSH into server
ssh root@<server-ip>

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Connect to your Tailscale network (replace with your auth key)
sudo tailscale up --authkey=tskey-auth-xxxxx-yyyyy --hostname=exchange-api-prod

# Get Tailscale IP (save this!)
tailscale ip -4
# Example output: 100.100.100.10
```

**Server naming convention**:
- Server 1: `exchange-api-prod` (Tailscale IP: 100.100.100.10)
- Server 2: `clearing-house-prod` (Tailscale IP: 100.100.100.20)
- Staging: `exchange-staging` (Tailscale IP: 100.100.100.30)

**Verify connectivity**:
```bash
# From Server 2, ping Server 1
ping 100.100.100.10
```

For detailed instructions, see [TAILSCALE-SETUP.md](./TAILSCALE-SETUP.md).

### Step 2: DNS Setup (5 minutes)

```bash
# Add these A records in your DNS provider:
api.boursenumeriquedafrique.com      → <server-1-ip>
payments.boursenumeriquedafrique.com → <server-2-ip>
boursenumeriquedafrique.com          → <server-3-ip> or Vercel
```

### Step 4: Server 1 - Exchange Core (10 minutes)

1. **Install Dokploy** (if not already):
   ```bash
   ssh root@<server-1-ip>
   curl -sSL https://dokploy.com/install.sh | sh
   ```

2. **Access Dokploy**: `http://<server-1-ip>:3000`

3. **Create Project**: "exchange-core"

4. **Add Docker Compose Service**:
   - Paste: `docker-compose.production.yml`
   - Or Git: `https://github.com/Bourse-numerique-d-afrique/server`

5. **Add Docker Registry**:
   - Registry: `ghcr.io`
   - Username: `<github-username>`
   - Password: `<github-token>`

6. **Set Environment Variables**:
   ```env
   VERSION=v0.1.2
   POSTGRES_USER=exchange_user
   POSTGRES_PASSWORD=<generate-strong-password>
   JWT_SECRET=<generate-64-char-secret>
   # Copy rest from .env.production.example
   ```

7. **Add Domain**: `api.boursenumeriquedafrique.com` → Port `5700`, Enable SSL

8. **Deploy** → Monitor logs

### Step 4: Server 2 - Clearing House (10 minutes)

1. **SSH & Install Dokploy**:
   ```bash
   ssh root@<server-2-ip>
   curl -sSL https://dokploy.com/install.sh | sh
   ```

2. **Access Dokploy**: `http://<server-2-ip>:3000`

3. **Create Project**: "clearing-house"

4. **Add Docker Compose Service**:
   - Paste: `docker-compose.clearing-house.yml`

5. **Add Docker Registry** (same as Server 1)

6. **Set Environment Variables**:
   ```env
   VERSION=v0.1.2
   POSTGRES_HOST=<server-1-private-ip>  # Or public IP
   # MUST use same credentials as Server 1:
   POSTGRES_USER=exchange_user
   POSTGRES_PASSWORD=<same-as-server-1>
   JWT_SECRET=<same-as-server-1>
   # Copy rest from .env.clearing-house.example
   ```

7. **Add Domain**: `payments.boursenumeriquedafrique.com` → Port `8500`, Enable SSL

8. **Deploy** → Verify database connection in logs

### Step 4: Configure Payment Providers (5 minutes)

**MTN MoMo**:
1. Login: https://momodeveloper.mtn.com
2. Set webhook: `https://payments.boursenumeriquedafrique.com:5705/mtn/callback`

**Airtel Money**:
1. Contact Airtel team
2. Provide: `https://payments.boursenumeriquedafrique.com:5706/airtel/callback`

### Step 5: Verify Deployment (2 minutes)

```bash
# Test Exchange API
curl https://api.boursenumeriquedafrique.com/health
# Expected: {"status":"healthy"}

# Test Clearing House
curl https://payments.boursenumeriquedafrique.com/health
# Expected: {"status":"healthy"}

# Test GraphQL
open https://api.boursenumeriquedafrique.com
# Should show GraphQL Playground
```

## 10-Minute Staging Deployment

### Single Server Setup

1. **Install Dokploy** on staging server

2. **Create Project**: "exchange-staging"

3. **Add Docker Compose**:
   - Paste: `docker-compose.staging.yml`

4. **Set Environment Variables** from `.env.staging.example`

5. **Add Domains**:
   - `test-api.boursenumeriquedafrique.com` → Port `5700`
   - `test-payments.boursenumeriquedafrique.com` → Port `8500`

6. **Enable Auto-Deploy**:
   - Settings → Auto Deploy on Git Push
   - Branch: `master`
   - Always pulls `:latest` tag

7. **Deploy**

## Generate Secrets

```bash
# Generate strong JWT secret (64 characters)
openssl rand -base64 64

# Generate database password (32 characters)
openssl rand -base64 32 | tr -d "=+/" | cut -c1-32

# Generate Ethereum private key (use MetaMask or MyEtherWallet)
# Never use generated keys for production without proper security review
```

## Common Issues & Fixes

### ❌ Container won't start
```bash
# Check logs in Dokploy
# Verify all environment variables are set
# Check Docker image was pulled: docker images | grep exchange
```

### ❌ Database connection failed (Server 2)
```bash
# On Server 1, allow Server 2 access:
ufw allow from <server-2-ip> to any port 5432

# Verify connection from Server 2:
psql -h <server-1-ip> -U exchange_user -d exchange
```

### ❌ SSL certificate failed
```bash
# Verify DNS points to server:
dig api.boursenumeriquedafrique.com

# Wait for propagation (10-30 min)
# Retry SSL in Dokploy
```

### ❌ Payment webhook not working
```bash
# Test direct access:
curl https://payments.boursenumeriquedafrique.com:5705/health

# Check firewall:
ufw status | grep 5705

# Verify SSL certificate:
openssl s_client -connect payments.boursenumeriquedafrique.com:5705
```

## Post-Deployment Checklist

Production:
- [ ] Exchange API accessible: https://api.boursenumeriquedafrique.com
- [ ] Clearing House accessible: https://payments.boursenumeriquedafrique.com
- [ ] SSL certificates valid on all domains
- [ ] GraphQL Playground working
- [ ] Database connection established (check logs)
- [ ] MTN webhook configured
- [ ] Airtel webhook configured
- [ ] Firewall rules configured
- [ ] Database backup strategy in place

Staging:
- [ ] Test API accessible: https://test-api.boursenumeriquedafrique.com
- [ ] Auto-deploy enabled
- [ ] Test payment webhooks configured

Security:
- [ ] All secrets are unique and strong
- [ ] JWT_SECRET is 64+ characters
- [ ] Database password is 20+ characters
- [ ] Private keys are secure
- [ ] Firewall allows only necessary ports
- [ ] SSL/TLS enabled on all endpoints

## Next Steps

1. **Deploy Frontend**:
   - Use Vercel/Netlify (recommended)
   - Or deploy to Server 3 with Dokploy
   - Configure: `NEXT_PUBLIC_API_URL=https://api.boursenumeriquedafrique.com`

2. **Set Up Monitoring**:
   - Enable Prometheus in production compose
   - Add Grafana for visualization
   - Configure alerts

3. **Database Backups**:
   - Manual: `docker exec timescaledb pg_dump -U exchange_user exchange > backup.sql`
   - Automated: Use managed database or cron job

4. **Performance Optimization**:
   - Monitor resource usage in Dokploy
   - Scale vertically (upgrade server) when >70% usage
   - Consider managed database for better performance

5. **Compliance**:
   - Review KYC requirements
   - Implement PCI DSS if handling cards
   - Set up audit logging

## Support

- Documentation: `/dokploy/DEPLOYMENT.md`
- GitHub Issues: https://github.com/Bourse-numerique-d-afrique/server/issues
- Dokploy Docs: https://docs.dokploy.com

## Estimated Costs (Monthly)

**Production (Option C - Smart Hybrid)**:
- Server 1 (4GB): $20-40
- Server 2 (2GB): $10-20
- Frontend (Vercel): $0
- Total: **$30-60/month**

**With Managed Database**:
- Add $15-30/month for DigitalOcean Managed DB
- Total: **$45-90/month**

**Staging**:
- Single server (2GB): $10-15/month
