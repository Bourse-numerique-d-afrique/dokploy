# Cloudflare Tunnel Setup for Local Dokploy

This guide shows how to expose your local Dokploy instance to receive webhooks from GitHub Actions using Cloudflare Tunnel (formerly Argo Tunnel).

## Why Cloudflare Tunnel?

- ✅ **Free**: No cost for personal use
- ✅ **No port forwarding**: Works behind NAT/firewall
- ✅ **Secure**: Encrypted tunnel, no exposed ports
- ✅ **DDoS protection**: Cloudflare's network protection
- ✅ **Custom domain**: Use your own domain
- ✅ **Always on**: Reconnects automatically

## Architecture

```
┌────────────────────┐
│  GitHub Actions    │
│  (Webhook sender)  │
└─────────┬──────────┘
          │
          ↓ HTTPS
┌─────────────────────────────┐
│  Cloudflare Edge Network    │
│  (Public endpoint)          │
└─────────┬───────────────────┘
          │
          ↓ Encrypted tunnel
┌─────────────────────────────┐
│  cloudflared (on your PC)   │
│  Tunnel client daemon       │
└─────────┬───────────────────┘
          │
          ↓ localhost:3000
┌─────────────────────────────┐
│  Dokploy (on your PC)       │
│  Main orchestration node    │
└─────────┬───────────────────┘
          │
          ↓ SSH/Docker API
┌─────────────────────────────┐
│  VPS Servers (internet)     │
│  Deployment nodes           │
└─────────────────────────────┘
```

## Prerequisites

- Cloudflare account (free)
- Domain registered (can be any registrar)
- Domain DNS managed by Cloudflare
- Dokploy running on your PC

## Step-by-Step Setup

### 1. Install cloudflared

**Linux/macOS:**
```bash
# Download and install
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
sudo mv cloudflared-linux-amd64 /usr/local/bin/cloudflared
sudo chmod +x /usr/local/bin/cloudflared
```

**Or use package manager:**
```bash
# Ubuntu/Debian
wget -q https://pkg.cloudflare.com/cloudflare-main.gpg -O- | sudo tee /usr/share/keyrings/cloudflare-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/cloudflare-archive-keyring.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflared.list
sudo apt update
sudo apt install cloudflared
```

**Windows:**
```powershell
# Download from: https://github.com/cloudflare/cloudflared/releases
# Or use winget
winget install --id Cloudflare.cloudflared
```

### 2. Authenticate with Cloudflare

```bash
cloudflared tunnel login
```

This opens a browser window - select your domain/zone.

### 3. Create a Tunnel

```bash
# Create tunnel named "dokploy-local"
cloudflared tunnel create dokploy-local

# Note the tunnel ID and credentials file location
# Example output:
# Tunnel credentials written to /home/username/.cloudflared/[TUNNEL-ID].json
```

### 4. Configure the Tunnel

Create config file at `~/.cloudflared/config.yml`:

```yaml
tunnel: dokploy-local
credentials-file: /home/username/.cloudflared/[TUNNEL-ID].json

ingress:
  # Webhook endpoint for Dokploy
  - hostname: dokploy.boursenumeriquedafrique.com
    service: http://localhost:3000

  # Catch-all rule (required)
  - service: http_status:404
```

**Important**: Replace:
- `[TUNNEL-ID]` with your actual tunnel ID
- `dokploy.boursenumeriquedafrique.com` with your desired subdomain
- `http://localhost:3000` with your Dokploy port (default is usually 3000)

### 5. Create DNS Record

```bash
# Point your subdomain to the tunnel
cloudflared tunnel route dns dokploy-local dokploy.boursenumeriquedafrique.com
```

This creates a CNAME record automatically.

### 6. Start the Tunnel

**Run temporarily (testing):**
```bash
cloudflared tunnel run dokploy-local
```

**Run as system service (production):**

```bash
# Install as service
sudo cloudflared service install

# Start service
sudo systemctl start cloudflared
sudo systemctl enable cloudflared

# Check status
sudo systemctl status cloudflared
```

### 7. Verify Setup

```bash
# Test from another machine or phone (not on same network)
curl https://dokploy.boursenumeriquedafrique.com

# Should reach your local Dokploy instance
```

### 8. Update GitHub Webhook Secret

Now you can use the public URL in your GitHub secrets:

1. Go to GitHub repository settings → Secrets
2. Add or update secret:
   - **Name**: `DOKPLOY_STAGING_WEBHOOK_URL`
   - **Value**: `https://dokploy.boursenumeriquedafrique.com/api/webhook/deploy`

   (Adjust the path based on Dokploy's actual webhook endpoint)

### 9. Test the Webhook

```bash
# Make a test commit to trigger GitHub Actions
git commit --allow-empty -m "test: trigger webhook via Cloudflare tunnel"
git push origin master
```

Watch:
1. GitHub Actions logs (should show webhook sent)
2. Cloudflared logs: `sudo journalctl -u cloudflared -f`
3. Dokploy logs (should receive webhook)

## Security Considerations

### 1. Webhook Authentication

Dokploy should validate webhooks. If it doesn't, add authentication:

```yaml
# In config.yml, add Cloudflare Access (optional but recommended)
ingress:
  - hostname: dokploy.boursenumeriquedafrique.com
    service: http://localhost:3000
    originRequest:
      noTLSVerify: false
```

### 2. IP Allowlist (Optional)

Restrict to GitHub webhook IPs in Cloudflare dashboard:
1. Go to Security → WAF
2. Create firewall rule:
   - **Field**: IP Source Address
   - **Operator**: is in
   - **Value**: GitHub's webhook IP ranges
   - **Action**: Allow

GitHub webhook IPs: https://api.github.com/meta (check `hooks` array)

### 3. Rate Limiting

Configure in Cloudflare dashboard to prevent abuse.

## Troubleshooting

### Tunnel Not Connecting

```bash
# Check tunnel status
cloudflared tunnel info dokploy-local

# Check service logs
sudo journalctl -u cloudflared -f

# Test tunnel manually
cloudflared tunnel run dokploy-local
```

### Webhook Not Reaching Dokploy

1. **Check Dokploy is running**:
   ```bash
   curl http://localhost:3000
   ```

2. **Check cloudflared logs**:
   ```bash
   sudo journalctl -u cloudflared -n 100
   ```

3. **Verify DNS**:
   ```bash
   dig dokploy.boursenumeriquedafrique.com
   # Should show CNAME to [TUNNEL-ID].cfargotunnel.com
   ```

4. **Test from internet**:
   ```bash
   curl -v https://dokploy.boursenumeriquedafrique.com/health
   ```

### DNS Not Resolving

- Wait 2-5 minutes for DNS propagation
- Check Cloudflare dashboard → DNS → Records
- Ensure CNAME is proxied (orange cloud)

### Port Conflicts

If Dokploy is on a different port:

```yaml
# Update config.yml
ingress:
  - hostname: dokploy.boursenumeriquedafrique.com
    service: http://localhost:8080  # Your actual port
```

Then restart:
```bash
sudo systemctl restart cloudflared
```

## Managing the Tunnel

### View Tunnel Info
```bash
cloudflared tunnel info dokploy-local
```

### List All Tunnels
```bash
cloudflared tunnel list
```

### Update Configuration
```bash
# Edit config
nano ~/.cloudflared/config.yml

# Restart service
sudo systemctl restart cloudflared
```

### Delete Tunnel
```bash
# Stop service
sudo systemctl stop cloudflared

# Delete tunnel
cloudflared tunnel delete dokploy-local

# Remove DNS record from Cloudflare dashboard
```

## Advanced: Multiple Services

You can expose multiple services through one tunnel:

```yaml
tunnel: dokploy-local
credentials-file: /home/username/.cloudflared/[TUNNEL-ID].json

ingress:
  # Dokploy dashboard
  - hostname: dokploy.boursenumeriquedafrique.com
    service: http://localhost:3000

  # Another local service
  - hostname: dev-api.boursenumeriquedafrique.com
    service: http://localhost:5700

  # Web UI for testing
  - hostname: dev.boursenumeriquedafrique.com
    service: http://localhost:5173

  - service: http_status:404
```

Then route each:
```bash
cloudflared tunnel route dns dokploy-local dokploy.boursenumeriquedafrique.com
cloudflared tunnel route dns dokploy-local dev-api.boursenumeriquedafrique.com
cloudflared tunnel route dns dokploy-local dev.boursenumeriquedafrique.com
```

## Cost Analysis

| Component | Cost |
|-----------|------|
| Cloudflare Tunnel | **Free** |
| Cloudflare DNS | **Free** |
| Domain registration | $10-15/year |
| **Total** | **$10-15/year** |

## Alternative: ngrok (Simpler but Limited)

If you don't want to set up Cloudflare:

```bash
# Install ngrok
brew install ngrok  # macOS
# or download from https://ngrok.com/download

# Expose Dokploy
ngrok http 3000

# Copy the https URL (e.g., https://abc123.ngrok.io)
# Use this as DOKPLOY_STAGING_WEBHOOK_URL
```

**Limitations**:
- Random URL on free plan (changes on restart)
- 40 requests/minute limit
- Less secure than Cloudflare Tunnel
- No custom domain on free plan

**Paid ngrok** ($8/month): Custom domain, more bandwidth

## Recommendation

**For production use**: Cloudflare Tunnel
- Free forever
- Custom domain
- DDoS protection
- Automatic reconnection
- Better security

**For quick testing**: ngrok
- 1-command setup
- No configuration needed
- Good for occasional use

---

**Last Updated**: 2026-01-03
**Maintainer**: Bourse Numérique d'Afrique Team
