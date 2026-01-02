# DNS Configuration Guide

Complete DNS setup for boursenumeriquedafrique.com deployment.

## Required DNS Records

### Production Environment

| Type | Name     | Value                  | TTL  | Purpose                    |
|------|----------|------------------------|------|----------------------------|
| A    | @        | `<frontend-server-ip>` | 3600 | Main website               |
| A    | api      | `<server-1-ip>`        | 3600 | Exchange API               |
| A    | payments | `<server-2-ip>`        | 3600 | Clearing House/Payments    |
| CNAME| www      | boursenumeriquedafrique.com. | 3600 | WWW redirect        |

### Test/Staging Environment

| Type | Name          | Value                  | TTL  | Purpose                 |
|------|---------------|------------------------|------|-------------------------|
| A    | test          | `<staging-server-ip>`  | 3600 | Test frontend           |
| A    | test-api      | `<staging-server-ip>`  | 3600 | Test Exchange API       |
| A    | test-payments | `<staging-server-ip>`  | 3600 | Test Clearing House     |

## Step-by-Step Configuration

### 1. Get Your Server IP Addresses

```bash
# SSH into each server and get public IP
curl ifconfig.me

# Or use DigitalOcean/AWS dashboard
```

Note down:
- Server 1 (Exchange Core) IP: _________________
- Server 2 (Clearing House) IP: _________________
- Server 3 (Frontend) IP: _________________
- Staging Server IP: _________________

### 2. Access Your DNS Provider

Common providers:
- **Cloudflare**: https://dash.cloudflare.com
- **DigitalOcean**: https://cloud.digitalocean.com/networking/domains
- **Namecheap**: https://ap.www.namecheap.com/domains/list
- **GoDaddy**: https://dcc.godaddy.com/domains

### 3. Add DNS Records

#### Option A: Cloudflare (Recommended)

**Benefits**: Free SSL, DDoS protection, CDN, analytics

1. Add domain to Cloudflare
2. Update nameservers at your registrar to Cloudflare's
3. Add A records:
   ```
   Type: A
   Name: @
   IPv4 address: <frontend-server-ip>
   Proxy status: Proxied (orange cloud)
   TTL: Auto
   ```
   
   ```
   Type: A
   Name: api
   IPv4 address: <server-1-ip>
   Proxy status: DNS only (gray cloud) ⚠️ IMPORTANT
   TTL: Auto
   ```
   
   ```
   Type: A
   Name: payments
   IPv4 address: <server-2-ip>
   Proxy status: DNS only (gray cloud) ⚠️ IMPORTANT
   TTL: Auto
   ```

**Why "DNS only" for API/Payments?**
- Payment provider webhooks need direct access
- No Cloudflare proxy interference with callbacks
- Direct SSL certificate validation

4. Add CNAME for www:
   ```
   Type: CNAME
   Name: www
   Target: boursenumeriquedafrique.com
   Proxy status: Proxied
   TTL: Auto
   ```

#### Option B: Other DNS Providers

1. Navigate to DNS management
2. Click "Add Record" for each entry
3. Fill in Type, Name, Value, TTL
4. Save

### 4. Verify DNS Propagation

```bash
# Check A records
dig api.boursenumeriquedafrique.com
dig payments.boursenumeriquedafrique.com
dig boursenumeriquedafrique.com

# Or use online tool
# https://dnschecker.org
```

Wait for propagation (usually 10-30 minutes, max 48 hours).

### 5. SSL Certificate Notes

**Dokploy Auto-SSL** (Let's Encrypt):
- Automatically provisions SSL when domain is configured
- Requires DNS to be pointing to server first
- Renews automatically every 90 days

**Cloudflare SSL** (if using Cloudflare):
- Set SSL/TLS mode to "Full (strict)"
- Origin certificates: Generate in Cloudflare, install on server
- Or use Dokploy Let's Encrypt (simpler)

## Advanced Configuration

### Private Network (Server 1 ↔ Server 2)

If using DigitalOcean/AWS VPC:

1. **Create VPC/Private Network**
   - DigitalOcean: Enable VPC in same datacenter
   - AWS: Create VPC and subnets

2. **Get Private IPs**
   ```bash
   # On each server
   ip addr show
   # Look for 10.x.x.x address
   ```

3. **Update Clearing House Config**
   ```env
   POSTGRES_HOST=10.x.x.x  # Server 1 private IP
   ```

### Firewall Rules

#### Server 1 (Exchange Core)
```bash
# Allow HTTP/HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Allow GraphQL
ufw allow 5700/tcp

# Allow PostgreSQL from Server 2 only
ufw allow from <server-2-private-ip> to any port 5432

# Allow Prometheus (optional, only if using external monitoring)
ufw allow from <monitoring-server-ip> to any port 9091

# Allow SSH
ufw allow 22/tcp

# Enable firewall
ufw enable
```

#### Server 2 (Clearing House)
```bash
# Allow HTTP/HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Allow main service
ufw allow 8500/tcp

# Allow payment callbacks
ufw allow 5705/tcp  # MTN
ufw allow 5706/tcp  # Airtel

# Allow SSH
ufw allow 22/tcp

# Enable firewall
ufw enable
```

### Email/SMTP (Future)

For transactional emails (password resets, notifications):

| Type | Name         | Value                           | Priority |
|------|--------------|----------------------------------|----------|
| MX   | @            | mail.boursenumeriquedafrique.com | 10       |
| A    | mail         | `<mail-server-ip>`               | -        |
| TXT  | @            | v=spf1 include:_spf.mx... ~all   | -        |
| TXT  | _dmarc       | v=DMARC1; p=none; ...           | -        |

### Status Page (Future)

| Type | Name   | Value           | TTL  |
|------|--------|-----------------|------|
| CNAME| status | status-page.com | 3600 |

## Troubleshooting

### DNS Not Resolving
```bash
# Clear local DNS cache
# Mac
sudo dscacheutil -flushcache

# Linux
sudo systemd-resolve --flush-caches

# Windows
ipconfig /flushdns
```

### SSL Certificate Errors
1. Verify DNS is fully propagated
2. Check domain in Dokploy points to correct service
3. Manually trigger certificate renewal in Dokploy
4. Check server firewall allows ports 80, 443

### Payment Webhooks Not Working
1. Test direct access: `curl https://payments.boursenumeriquedafrique.com:5705/health`
2. Verify DNS points directly to Server 2 (not proxied)
3. Check SSL certificate is valid
4. Verify payment provider can reach your server (no firewall blocking)

## DNS Provider Recommendations

### Best for Production: Cloudflare
- **Free plan includes**:
  - Unlimited DNS records
  - Free SSL certificates
  - DDoS protection
  - CDN (faster website)
  - Web analytics
  - Page rules

- **Setup**: https://www.cloudflare.com/dns/

### Budget Option: DigitalOcean DNS
- **Free with DigitalOcean account**
- Simple interface
- Good for VPS-hosted sites

### Premium Option: Route 53 (AWS)
- **Cost**: ~$0.50/month
- Advanced routing (geolocation, latency-based)
- Health checks
- Integration with AWS services

## Checklist

Production DNS:
- [ ] A record: @ → Frontend server
- [ ] A record: api → Server 1
- [ ] A record: payments → Server 2
- [ ] CNAME: www → boursenumeriquedafrique.com
- [ ] DNS propagation verified
- [ ] SSL certificates auto-provisioned

Staging DNS:
- [ ] A record: test → Staging server
- [ ] A record: test-api → Staging server
- [ ] A record: test-payments → Staging server

Security:
- [ ] Firewall rules configured
- [ ] Private network enabled (if applicable)
- [ ] Payment endpoints accessible
- [ ] SSL/TLS working on all domains
