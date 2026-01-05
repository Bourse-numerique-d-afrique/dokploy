# Cloudflare DNS Setup for Staging Environment

## DNS Records to Add

Add these A records in your Cloudflare DNS for domain `boursenumeriquedafrique.com`:

| Name | Type | Content | Proxy Status | TTL |
|------|------|---------|--------------|-----|
| test | A | 51.159.99.20 | DNS only (gray cloud) | Auto |
| test-api | A | 51.159.99.20 | DNS only (gray cloud) | Auto |
| test-payments | A | 51.159.99.20 | DNS only (gray cloud) | Auto |

**IMPORTANT**: Set Proxy status to **DNS only** (gray cloud icon) ⚠️
- Do NOT use Cloudflare proxy (orange cloud) for now
- Traefik on your server handles SSL certificates via Let's Encrypt
- Cloudflare proxy would interfere with Let's Encrypt verification

## Step-by-Step Instructions

### 1. Login to Cloudflare

Go to: https://dash.cloudflare.com/

### 2. Select Your Domain

Click on `boursenumeriquedafrique.com`

### 3. Go to DNS Settings

Click **DNS** in the left sidebar

### 4. Add First Record (Frontend)

Click **Add record**

```
Type: A
Name: test
IPv4 address: 51.159.99.20
Proxy status: DNS only (click the orange cloud to make it gray)
TTL: Auto
```

Click **Save**

### 5. Add Second Record (API)

Click **Add record**

```
Type: A
Name: test-api
IPv4 address: 51.159.99.20
Proxy status: DNS only (gray cloud)
TTL: Auto
```

Click **Save**

### 6. Add Third Record (Payments)

Click **Add record**

```
Type: A
Name: test-payments
IPv4 address: 51.159.99.20
Proxy status: DNS only (gray cloud)
TTL: Auto
```

Click **Save**

## Verification

### Check DNS Propagation

Wait 2-5 minutes, then verify:

```bash
# Check frontend
dig +short test.boursenumeriquedafrique.com
# Should return: 51.159.99.20

# Check API
dig +short test-api.boursenumeriquedafrique.com
# Should return: 51.159.99.20

# Check payments
dig +short test-payments.boursenumeriquedafrique.com
# Should return: 51.159.99.20
```

Or use online tool: https://dnschecker.org/

### Check Services are Accessible

After DNS propagates (5-30 minutes):

```bash
# Test API (GraphQL Playground)
curl -I https://test-api.boursenumeriquedafrique.com

# Test Payments
curl -I https://test-payments.boursenumeriquedafrique.com

# Test Frontend
curl -I https://test.boursenumeriquedafrique.com
```

**Note**: First access might take 1-2 minutes while Traefik obtains SSL certificates from Let's Encrypt.

## SSL Certificate Generation

After DNS is set up, Traefik will automatically:

1. Detect the new domains (via Traefik labels in compose)
2. Request SSL certificates from Let's Encrypt
3. Configure HTTPS automatically

Monitor Traefik logs:
```bash
docker logs dokploy-traefik -f
```

You should see messages about ACME challenge and certificate generation.

## Troubleshooting

### DNS not resolving

**Problem**: `dig` returns nothing or wrong IP

**Fix**:
1. Wait longer (DNS can take up to 48 hours, usually 5-30 mins)
2. Check Cloudflare DNS page - make sure records are saved
3. Clear DNS cache: `sudo systemd-resolve --flush-caches` (Linux)

### SSL Certificate Error

**Problem**: Browser shows "Your connection is not private"

**Causes**:
1. DNS not propagated yet (wait longer)
2. Cloudflare proxy enabled (must be gray cloud)
3. Let's Encrypt rate limit (wait 1 hour)

**Fix**:
```bash
# Check Traefik logs
docker logs dokploy-traefik --tail 100 | grep -i "acme\|certificate"

# Restart Traefik if needed
docker restart dokploy-traefik
```

### Connection Refused

**Problem**: Can't connect to domain

**Fix**:
```bash
# Check if services are running
docker service ls

# Check Traefik routing
docker logs dokploy-traefik | grep test-api

# Verify firewall
sudo ufw status | grep 443
```

## Cloudflare Proxy (Optional - Later)

Once everything is working with "DNS only" mode, you can optionally enable Cloudflare proxy:

### Benefits of Cloudflare Proxy:
- ✓ DDoS protection
- ✓ CDN (faster global access)
- ✓ Cloudflare SSL (their certificate)
- ✓ Web Application Firewall (WAF)

### To Enable:
1. Go to Cloudflare DNS page
2. Click gray cloud icon → turns orange
3. Set SSL mode: **SSL/TLS** → **Overview** → **Full (strict)**

**Note**: Your server must have valid SSL certificates from Let's Encrypt before enabling Cloudflare proxy.

## Production DNS Records

When ready for production, add these too:

| Name | Type | Content | Note |
|------|------|---------|------|
| @ (or blank) | A | YOUR_PROD_IP | Main site |
| api | A | YOUR_PROD_IP | Production API |
| payments | A | YOUR_PROD_IP | Production payments |

## Quick Reference

```bash
# Current setup
test.boursenumeriquedafrique.com          → 51.159.99.20 (Frontend)
test-api.boursenumeriquedafrique.com      → 51.159.99.20 (Exchange API)
test-payments.boursenumeriquedafrique.com → 51.159.99.20 (Clearing House)

# Services on server
- Frontend:       Port 80  → Traefik → HTTPS (test.boursenumeriquedafrique.com)
- Exchange:       Port 5700 → Traefik → HTTPS (test-api.boursenumeriquedafrique.com)
- Clearing House: Port 8500 → Traefik → HTTPS (test-payments.boursenumeriquedafrique.com)

# Traefik handles
- SSL/TLS certificates (Let's Encrypt)
- HTTP → HTTPS redirect
- Domain routing
```

## Resources

- Cloudflare DNS: https://dash.cloudflare.com/
- DNS Checker: https://dnschecker.org/
- Let's Encrypt Status: https://letsencrypt.status.io/
- Traefik Docs: https://doc.traefik.io/traefik/
