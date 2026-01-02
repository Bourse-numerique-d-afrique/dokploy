# Dokploy Deployment Guide for Bourse Numérique d'Afrique

This guide covers deploying the Exchange platform using Dokploy with a 3-server architecture.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Production Setup                        │
└─────────────────────────────────────────────────────────────┘

Server 1: Exchange Core                Server 2: Clearing House           Server 3: Frontend
api.boursenumeriquedafrique.com        payments.boursenumeriquedafrique.com   boursenumeriquedafrique.com
┌────────────────────────┐            ┌─────────────────────────┐         ┌──────────────────┐
│ Exchange API  :5700    │            │ Clearing House   :8500  │         │ Next.js/React    │
│ TimescaleDB   :5432    │◄───────────┤ MTN Callback     :5705  │         │ Static Assets    │
│ Ethereum      :8545    │            │ Airtel Callback  :5706  │         │ CDN              │
│ Redis         :6379    │            │                         │         └──────────────────┘
│ Prometheus    :9091    │            └─────────────────────────┘
└────────────────────────┘
```

## Prerequisites

### 1. Servers
- **Server 1 (Exchange Core)**: 4GB RAM, 2 CPU, 80GB SSD
- **Server 2 (Clearing House)**: 2GB RAM, 1 CPU, 20GB SSD
- **Server 3 (Frontend)**: 1GB RAM, 1 CPU, 20GB SSD (or use Vercel/Netlify)

### 2. Dokploy Installation
Install Dokploy on each server:
```bash
curl -sSL https://dokploy.com/install.sh | sh
```

Access Dokploy UI: `http://your-server-ip:3000`

### 3. GitHub Access
- Generate GitHub Personal Access Token with `read:packages` permission
- Add to Docker registry credentials in Dokploy

## Step 1: DNS Configuration

Configure the following DNS records in your domain provider:

### A Records
```
Type    Name           Value                TTL
────────────────────────────────────────────────
A       @              <frontend-server-ip>  3600
A       api            <server-1-ip>         3600
A       payments       <server-2-ip>         3600
A       test           <staging-server-ip>   3600
A       test-api       <staging-server-ip>   3600
A       test-payments  <staging-server-ip>   3600
```

### CNAME Records (Optional, for www)
```
Type    Name    Value                               TTL
─────────────────────────────────────────────────────────
CNAME   www     boursenumeriquedafrique.com.        3600
```

Wait for DNS propagation (up to 48 hours, usually 10-30 minutes).

## Step 2: Deploy Server 1 - Exchange Core

### 2.1 Create Project in Dokploy
1. Login to Dokploy on Server 1: `http://<server-1-ip>:3000`
2. Create new project: **"exchange-core"**
3. Choose deployment type: **"Docker Compose"**

### 2.2 Add Docker Compose Configuration
1. Click **"Add Service"** → **"Docker Compose"**
2. Paste contents of `docker-compose.production.yml`
3. Or use **"Git Repository"** method:
   - Repository: `https://github.com/Bourse-numerique-d-afrique/server`
   - Branch: `master`
   - Compose File: `docker-compose.production.yml`

### 2.3 Configure Environment Variables
Add these environment variables in Dokploy:

```env
# Copy from .env.production.example and fill in real values
VERSION=v0.1.2
POSTGRES_USER=exchange_user
POSTGRES_PASSWORD=<strong-password>
POSTGRES_DATABASE=exchange
TOKEN_ISSUER=boursenumeriquedafrique
JWT_SECRET=<64-char-random-secret>
ETH_CLIENT_URL=https://mainnet.infura.io/v3/<project-id>
ETH_PRIVATE_KEY=<your-private-key>
ETH_ADMIN_ADDRESS=<your-admin-address>
MTN_URL=https://momodeveloper.mtn.com
MTN_COLLECTION_PRIMARY_KEY=<key>
MTN_COLLECTION_SECONDARY_KEY=<key>
# ... add all other variables
```

### 2.4 Configure Docker Registry
1. Go to Settings → Docker Registry
2. Add GitHub Container Registry:
   - Registry URL: `ghcr.io`
   - Username: `<your-github-username>`
   - Password: `<github-personal-access-token>`

### 2.5 Configure Domain
1. Go to Domains tab
2. Add domain: `api.boursenumeriquedafrique.com`
3. Enable SSL (Let's Encrypt auto-configuration)
4. Port: `5700` (Exchange GraphQL endpoint)

### 2.6 Deploy
1. Click **"Deploy"**
2. Monitor logs for startup
3. Verify health: `curl https://api.boursenumeriquedafrique.com/health`

## Step 3: Deploy Server 2 - Clearing House

### 3.1 Create Project in Dokploy
1. Login to Dokploy on Server 2: `http://<server-2-ip>:3000`
2. Create new project: **"clearing-house"**
3. Choose: **"Docker Compose"**

### 3.2 Add Docker Compose Configuration
1. Paste contents of `docker-compose.clearing-house.yml`

### 3.3 Configure Environment Variables

**CRITICAL**: Database connection to Server 1

#### Option A: Private Network (Recommended)
If using DigitalOcean VPC, AWS VPC, or private network:
```env
POSTGRES_HOST=10.x.x.x  # Private IP of Server 1
POSTGRES_PORT=5432
```

#### Option B: Public Connection (Less Secure)
If no private network, use firewall rules to restrict access:
```env
POSTGRES_HOST=<server-1-public-ip>
POSTGRES_PORT=5432
```

**Configure Server 1 Firewall**:
```bash
# On Server 1, allow PostgreSQL from Server 2 only
ufw allow from <server-2-ip> to any port 5432
```

#### All Other Variables
```env
VERSION=v0.1.2
POSTGRES_USER=exchange_user  # Same as Server 1
POSTGRES_PASSWORD=<same-as-server-1>  # Must match!
POSTGRES_DATABASE=exchange  # Same as Server 1
TOKEN_ISSUER=boursenumeriquedafrique  # Must match Server 1!
JWT_SECRET=<same-as-server-1>  # Must match!
MTN_WEBHOOK_HOST=payments.boursenumeriquedafrique.com
AIRTEL_CALLBACK_URL=https://payments.boursenumeriquedafrique.com/airtel/callback
# ... add all other payment variables
```

### 3.4 Configure Docker Registry
Same as Server 1 (GitHub Container Registry credentials)

### 3.5 Configure Domains
Add three domains in Dokploy:
1. **Main**: `payments.boursenumeriquedafrique.com` → Port `8500`
2. **MTN**: `payments.boursenumeriquedafrique.com` → Port `5705` (for `/mtn` path)
3. **Airtel**: `payments.boursenumeriquedafrique.com` → Port `5706` (for `/airtel` path)

Enable SSL for all domains.

### 3.6 Deploy
1. Click **"Deploy"**
2. Monitor logs
3. Verify database connection: Check logs for successful DB connection
4. Test health: `curl https://payments.boursenumeriquedafrique.com/health`

### 3.7 Configure Payment Provider Webhooks

#### MTN MoMo
1. Login to MTN Developer Portal: https://momodeveloper.mtn.com
2. Go to your Collection product
3. Set webhook URL: `https://payments.boursenumeriquedafrique.com:5705/mtn/callback`
4. Save

#### Airtel Money
1. Contact Airtel integration team
2. Provide callback URL: `https://payments.boursenumeriquedafrique.com:5706/airtel/callback`

## Step 4: Deploy Server 3 - Frontend (Optional with Dokploy)

### Option A: Dokploy Deployment

#### 4.1 Create Project
1. Login to Dokploy on Server 3
2. Create project: **"frontend"**
3. Choose: **"Dockerfile"** or **"Docker Compose"**

#### 4.2 Add Frontend Repository
1. Repository: `https://github.com/your-org/frontend`
2. Branch: `main`
3. Build command: `npm run build` (or framework-specific)

#### 4.3 Configure Environment Variables
```env
NEXT_PUBLIC_API_URL=https://api.boursenumeriquedafrique.com
NEXT_PUBLIC_WS_URL=wss://api.boursenumeriquedafrique.com
```

#### 4.4 Configure Domain
- Domain: `boursenumeriquedafrique.com`
- Enable SSL

### Option B: Vercel/Netlify (Recommended)

**Vercel:**
1. Import repository
2. Add environment variable: `NEXT_PUBLIC_API_URL=https://api.boursenumeriquedafrique.com`
3. Deploy
4. Add custom domain: `boursenumeriquedafrique.com`

**Benefits**: Better CDN, automatic previews, zero config

## Step 5: Deploy Staging Environment

### Single Server Setup
1. Create project: **"exchange-staging"**
2. Use `docker-compose.staging.yml`
3. Configure environment from `.env.staging.example`
4. Domains:
   - `test-api.boursenumeriquedafrique.com` → Port `5700`
   - `test-payments.boursenumeriquedafrique.com` → Port `8500`
5. Enable **Auto-Deploy** from GitHub (`:latest` tag)

### Auto-Deploy Configuration
1. Go to project settings
2. Enable "Auto Deploy on Git Push"
3. Branch: `master`
4. This will auto-deploy whenever GitHub Actions pushes new `:latest` images

## Step 6: Monitoring & Maintenance

### Health Checks
```bash
# Exchange API
curl https://api.boursenumeriquedafrique.com/health

# Clearing House
curl https://payments.boursenumeriquedafrique.com/health

# GraphQL Playground
open https://api.boursenumeriquedafrique.com
```

### View Logs
In Dokploy:
1. Select project
2. Click "Logs" tab
3. Select service
4. Filter by level (info, error, warn)

### Database Backups

#### Manual Backup
```bash
# SSH into Server 1
ssh user@server-1-ip

# Backup database
docker exec timescaledb pg_dump -U exchange_user exchange > backup_$(date +%Y%m%d).sql

# Download backup
scp user@server-1-ip:backup_*.sql ./
```

#### Automated Backups (Recommended)
Use managed database (DigitalOcean, AWS RDS) for automatic backups.

### Update Deployment

#### Production (Manual)
1. GitHub Actions builds new version: `v0.1.3`
2. In Dokploy, update environment variable: `VERSION=v0.1.3`
3. Click "Redeploy"
4. Monitor logs

#### Staging (Automatic)
1. Push to `master` branch
2. GitHub Actions builds and pushes `:latest`
3. Dokploy auto-deploys (if enabled)

## Troubleshooting

### Issue: Clearing House can't connect to database
**Solution:**
1. Check network connectivity: `ping <server-1-ip>` from Server 2
2. Verify firewall rules on Server 1
3. Check POSTGRES_HOST environment variable
4. Ensure credentials match exactly

### Issue: Payment callbacks not received
**Solution:**
1. Verify domains are accessible: `curl https://payments.boursenumeriquedafrique.com:5705/health`
2. Check SSL certificates are valid
3. Verify payment provider webhook configuration
4. Check firewall allows inbound on ports 5705, 5706

### Issue: Container fails to start
**Solution:**
1. Check Dokploy logs for error messages
2. Verify all environment variables are set
3. Check Docker image was pulled successfully
4. Verify sufficient disk space: `df -h`

### Issue: Database connection pool exhausted
**Solution:**
1. Increase max_connections in PostgreSQL config
2. Review application connection pooling
3. Check for connection leaks in logs
4. Scale database resources

## Security Checklist

- [ ] All environment variables use strong, unique secrets
- [ ] JWT_SECRET is 64+ characters random string
- [ ] Database passwords are strong (20+ characters)
- [ ] Firewall configured to allow only necessary ports
- [ ] SSL certificates are valid and auto-renewing
- [ ] Private network configured for Server 1 ↔ Server 2
- [ ] Database accessible only from Server 1 & 2
- [ ] Payment provider webhooks use HTTPS
- [ ] Regular database backups configured
- [ ] Monitoring alerts configured

## Scaling Strategies

### Vertical Scaling (Increase Server Resources)
- Monitor CPU, RAM, disk usage in Dokploy
- Upgrade server size when consistently >70% usage

### Horizontal Scaling
1. **Database**: Move to managed cluster (DigitalOcean Managed DB, AWS RDS)
2. **Exchange API**: Deploy multiple instances with load balancer
3. **Redis**: Use Redis Cluster for high availability

### Load Balancing (Future)
Add Nginx/HAProxy in front of multiple Exchange API instances

## Support & Resources

- Dokploy Docs: https://docs.dokploy.com
- GitHub Issues: https://github.com/Bourse-numerique-d-afrique/server/issues
- Exchange Status: https://status.boursenumeriquedafrique.com (future)
