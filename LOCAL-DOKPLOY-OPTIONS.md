# Running Dokploy Locally with Internet-Accessible Nodes

This guide compares different approaches for running your main Dokploy orchestration node on your local PC while managing deployment nodes on internet-accessible VPS servers.

## The Challenge

Your setup:
```
┌─────────────────────────┐
│  Your PC (Local)        │
│  - Dokploy main node    │
│  - Behind NAT/firewall  │
│  - NOT publicly accessible
└───────────┬─────────────┘
            │ Can SSH out →
            ↓
┌─────────────────────────┐
│  VPS Servers (Internet) │
│  - Deployment nodes     │
│  - Publicly accessible  │
└─────────────────────────┘

❌ Problem: GitHub Actions can't send webhooks to your local PC
```

## Solution Comparison

| Solution | Cost | Setup Difficulty | Pros | Cons | Recommended For |
|----------|------|-----------------|------|------|-----------------|
| **1. Cloudflare Tunnel** | Free | Medium | Secure, custom domain, DDoS protection, always-on | Requires domain | **Production use** |
| **2. ngrok** | Free/$8/mo | Easy | 1-command setup, quick testing | Random URLs (free), rate limits | **Testing only** |
| **3. Tailscale + Webhook Relay** | Free | Hard | Very secure, no exposed endpoints | Complex setup, custom code needed | Advanced users |
| **4. Dokploy on Cheap VPS** | $5/mo | Easy | Simple, reliable, no local setup | Extra cost, one more server | **Simplest production** |
| **5. No Webhooks (Polling)** | Free | Easy | No networking complexity | 5-min deploy delay | Budget/simple setups |

## Option 1: Cloudflare Tunnel (Recommended)

### Overview
Expose your local Dokploy securely with a custom domain, for free.

### Pros
✅ **Free forever** (includes custom domain)
✅ **Secure** - encrypted tunnel, Cloudflare DDoS protection
✅ **Reliable** - auto-reconnects if connection drops
✅ **Professional** - use your own domain
✅ **No port forwarding** - works anywhere

### Cons
❌ Requires domain name ($10-15/year)
❌ Medium setup complexity
❌ Tunnel client must run on PC

### Setup Time
30-60 minutes

### When to Use
- You want production-ready setup
- You have a domain name
- You want webhooks for instant deploys
- You run Dokploy on PC long-term

### See
📄 **[CLOUDFLARE-TUNNEL-SETUP.md](./CLOUDFLARE-TUNNEL-SETUP.md)** - Complete setup guide

---

## Option 2: ngrok

### Overview
Quick tunnel to expose local Dokploy temporarily.

### Pros
✅ **1-command setup** - fastest to get started
✅ **No configuration** - just run and use
✅ **Good for testing** - perfect for CI/CD experiments

### Cons
❌ **Random URLs** on free plan (changes each restart)
❌ **Rate limits** - 40 req/min on free
❌ **No persistence** - URL changes mean updating GitHub secrets
❌ **$8/month** for custom domain

### Setup Time
2 minutes

### Quick Start
```bash
# Install
brew install ngrok  # macOS
# or download from https://ngrok.com/download

# Run (Dokploy on port 3000)
ngrok http 3000

# Copy HTTPS URL
# Example: https://abc123.ngrok.io

# Use this URL in GitHub secrets
DOKPLOY_STAGING_WEBHOOK_URL=https://abc123.ngrok.io/api/webhook/deploy
```

### When to Use
- Quick testing of webhook setup
- Occasional use (not 24/7)
- Don't mind updating webhook URL regularly
- Evaluating if webhooks work for you

---

## Option 3: Tailscale + Custom Webhook Relay

### Overview
Create a secure mesh network and build custom webhook relay.

### Architecture
```
GitHub Actions
    ↓ Webhook
Small relay service on VPS (public)
    ↓ Tailscale VPN
Your PC with Dokploy (in same VPN)
```

### Pros
✅ **Very secure** - VPN-based, zero trust
✅ **No exposed services** - everything private
✅ **Flexible** - full control over relay logic

### Cons
❌ **Complex** - requires custom code
❌ **Maintenance** - you own the relay service
❌ **Overkill** - for most use cases

### Setup Time
2-4 hours (requires coding)

### Basic Relay Service Example

```javascript
// relay.js - Run this on a small VPS ($5/mo)
const express = require('express');
const axios = require('axios');
const app = express();

app.use(express.json());

// Receive webhook from GitHub
app.post('/webhook/relay', async (req, res) => {
  console.log('Received webhook from GitHub');

  try {
    // Forward to Dokploy on Tailscale network
    await axios.post('http://dokploy-pc.tailnet.ts.net:3000/api/webhook/deploy', req.body, {
      headers: { 'Content-Type': 'application/json' }
    });

    res.status(200).send('Relayed');
  } catch (error) {
    console.error('Relay failed:', error.message);
    res.status(500).send('Relay failed');
  }
});

app.listen(8080, () => {
  console.log('Webhook relay running on port 8080');
});
```

Then in GitHub secrets:
```
DOKPLOY_STAGING_WEBHOOK_URL=https://relay.your-vps.com/webhook/relay
```

### When to Use
- You already use Tailscale
- You need maximum security
- You enjoy tinkering with infrastructure
- You want custom webhook processing logic

---

## Option 4: Dokploy on Cheap VPS (Simplest)

### Overview
Run Dokploy on a $5/month VPS instead of your PC.

### Architecture
```
GitHub Actions
    ↓ Webhook (direct, no tunnel needed)
Dokploy on cheap VPS ($5/mo)
    ↓ Manages deployments on
Production VPS servers
```

### Pros
✅ **Simplest setup** - no tunnels, no relay
✅ **Always accessible** - 24/7 uptime
✅ **Reliable** - no PC dependency
✅ **Clean separation** - orchestration separate from production

### Cons
❌ **Extra cost** - $5/month for orchestration VPS
❌ **One more server** - to maintain and monitor

### Setup Time
15-30 minutes

### VPS Requirements
- **RAM**: 1-2GB sufficient
- **CPU**: 1 core sufficient
- **Disk**: 20GB sufficient
- **Provider**: DigitalOcean, Hetzner, Linode, Vultr

### Cost
$5-6/month for orchestration server

### When to Use
- You want the simplest production setup
- $5/month is acceptable
- You want 24/7 availability
- You don't want to manage tunnels
- **Best for most users**

---

## Option 5: No Webhooks (Use Polling)

### Overview
Skip webhooks entirely, use Dokploy's auto-pull feature.

### How It Works
Instead of GitHub → Webhook → Dokploy, use:
```
GitHub pushes :latest image to ghcr.io
    ↓
Dokploy polls registry every 5 minutes
    ↓
Detects new image → pulls → redeploys
```

### Pros
✅ **No networking complexity** - works anywhere
✅ **Free** - no tunnel, no VPS needed
✅ **Simple** - just enable in Dokploy
✅ **Reliable** - no webhook failures

### Cons
❌ **Delayed deploys** - up to polling interval (e.g., 5 min)
❌ **More registry calls** - polls even when no changes

### Setup Time
5 minutes

### Configuration

In Dokploy project settings:

**For Exchange API:**
1. Enable "Auto-deploy on image update"
2. Image: `ghcr.io/bourse-numerique-d-afrique/server:latest`
3. Poll interval: 5 minutes

**For Clearing House:**
1. Enable "Auto-deploy on image update"
2. Image: `ghcr.io/bourse-numerique-d-afrique/server-clearing-house:latest`
3. Poll interval: 5 minutes

**For Frontend:**
1. Enable "Auto-deploy on image update"
2. Image: `ghcr.io/bourse-numerique-d-afrique/client:latest`
3. Poll interval: 5 minutes

### When to Use
- You rarely deploy (once a day or less)
- 5-minute deploy delay is acceptable
- You want zero networking complexity
- You're on a tight budget
- **Good for personal/small projects**

---

## Decision Matrix

### Choose Cloudflare Tunnel if:
- ✅ You have a domain name
- ✅ You want instant webhook-based deploys
- ✅ You deploy your PC is on most of the time
- ✅ You want production-grade setup
- ✅ You don't want to pay for extra VPS

### Choose ngrok if:
- ✅ You're just testing webhook setup
- ✅ You need quick temporary access
- ✅ You don't mind changing URLs
- ✅ You deploy rarely

### Choose Tailscale + Relay if:
- ✅ You already use Tailscale
- ✅ You need maximum security
- ✅ You enjoy infrastructure projects
- ✅ You can code the relay

### Choose Dokploy on VPS if:
- ✅ You want simplest production setup
- ✅ $5/month is acceptable
- ✅ You want 24/7 reliability
- ✅ You value simplicity over cost
- ✅ **Recommended for most users**

### Choose Polling (no webhooks) if:
- ✅ Deploy delay is acceptable (5 min)
- ✅ You want maximum simplicity
- ✅ You're on tight budget (free)
- ✅ You don't deploy frequently

---

## Hybrid Approach (Best of Both Worlds)

Run Dokploy on your PC for development, and on VPS for production:

### Development
- **Local PC**: Dokploy with Cloudflare Tunnel
- **Purpose**: Test deployments, experiment safely
- **Deploys to**: Staging servers
- **Cost**: Free (just domain)

### Production
- **Cheap VPS**: Dokploy ($5/mo)
- **Purpose**: Manage production deployments
- **Deploys to**: Production servers
- **Cost**: $5/month

### Benefits
- ✅ Safe experimentation locally
- ✅ Reliable production orchestration
- ✅ Clear dev/prod separation
- ✅ Best of both worlds

---

## Quick Recommendation

**For your use case** (PC-based Dokploy with internet VPS nodes):

### Immediate/Testing
👉 **Use ngrok** - Get up and running in 2 minutes

### Short-term Production
👉 **Use Cloudflare Tunnel** - Free, secure, professional

### Long-term Production
👉 **Move Dokploy to $5 VPS** - Simplest, most reliable

### Budget/Simple Projects
👉 **Use polling** - No webhooks needed

---

## Support & Resources

- **Cloudflare Tunnel**: [CLOUDFLARE-TUNNEL-SETUP.md](./CLOUDFLARE-TUNNEL-SETUP.md)
- **Webhook Config**: [WEBHOOK-CONFIGURATION.md](./WEBHOOK-CONFIGURATION.md)
- **Ngrok Docs**: https://ngrok.com/docs
- **Tailscale Docs**: https://tailscale.com/kb/
- **Dokploy Docs**: https://docs.dokploy.com

---

**Last Updated**: 2026-01-03
**Maintainer**: Bourse Numérique d'Afrique Team
