# Dokploy Deployment Configuration

Complete deployment setup for Bourse Numérique d'Afrique Exchange Platform.

## 📁 Files Overview

```
dokploy/
├── README.md                       # This file
├── QUICK-START.md                  # 60-minute deployment guide
├── DEPLOYMENT.md                   # Comprehensive deployment documentation
├── DNS-CONFIGURATION.md            # DNS setup guide
├── TAILSCALE-SETUP.md              # Private networking with Tailscale (REQUIRED)
├── NEW-SERVER-CHECKLIST.md         # Step-by-step checklist for adding servers
├── WEBHOOK-CONFIGURATION.md        # Auto-deploy webhook setup
├── LOCAL-DOKPLOY-OPTIONS.md        # Running Dokploy on local PC (with VPS nodes)
└── CLOUDFLARE-TUNNEL-SETUP.md      # Expose local Dokploy for webhooks

../
├── docker-compose.production.yml    # Server 1: Exchange Core
├── docker-compose.clearing-house.yml # Server 2: Clearing House
├── docker-compose.staging.yml       # Staging: All-in-one
├── .env.production.example          # Production environment variables
├── .env.clearing-house.example      # Clearing house environment variables
└── .env.staging.example             # Staging environment variables
```

## 🏗️ Architecture

### Production (3-Server Setup)

```
┌────────────────────────────────────────────────────────────────┐
│                   Tailscale Private Network                     │
│                      (100.64.0.0/10)                           │
│                                                                 │
│  ┌──────────────────┐    ┌──────────────────┐    ┌──────────┐ │
│  │   Server 1       │    │   Server 2       │    │ Server 3 │ │
│  │  Exchange Core   │◄───┤  Clearing House  │    │ Frontend │ │
│  ├──────────────────┤    ├──────────────────┤    ├──────────┤ │
│  │ Exchange API     │    │ Payment Server   │    │ Next.js  │ │
│  │ TimescaleDB      │    │ MTN Callback     │    │ React    │ │
│  │ Ethereum         │    │ Airtel Callback  │    │          │ │
│  │ Redis            │    │                  │    │          │ │
│  └──────────────────┘    └──────────────────┘    └──────────┘ │
│  100.100.100.10          100.100.100.20          Public only  │
└────────────────────────────────────────────────────────────────┘
   api.bourse...com         payments.bourse...com   bourse...com

   🔒 Database accessible only via Tailscale (encrypted)
```

### Staging (Single Server)

```
┌─────────────────────────────────────────┐
│          Staging Server                 │
├─────────────────────────────────────────┤
│ Frontend        :80, :443               │
│ Exchange API    :5700                   │
│ Clearing House  :8500                   │
│ TimescaleDB     :5432                   │
│ Ganache         :8545                   │
│ Redis           :6379                   │
└─────────────────────────────────────────┘
test.boursenumeriquedafrique.com
test-api.boursenumeriquedafrique.com
test-payments.boursenumeriquedafrique.com
```

## 🚀 Quick Start

### For First-Time Deployment

1. **Read Quick Start**: `QUICK-START.md` (30-minute setup)
2. **Configure DNS**: `DNS-CONFIGURATION.md`
3. **Deploy Production**: `DEPLOYMENT.md`

### For Updating Deployment

```bash
# Production - Manual update
# 1. GitHub Actions creates new release: v0.1.3
# 2. In Dokploy, update VERSION=v0.1.3
# 3. Click "Redeploy"

# Staging - Auto-deploy (requires webhook configuration)
# Push to master → Auto-deploys :latest
# See WEBHOOK-CONFIGURATION.md for setup
```

## 📋 Pre-Deployment Checklist

### Infrastructure
- [ ] 3 VPS servers provisioned (or 1 for staging)
- [ ] Dokploy installed on servers (or locally with tunnel - see LOCAL-DOKPLOY-OPTIONS.md)
- [ ] **Tailscale installed on ALL servers** (REQUIRED - see TAILSCALE-SETUP.md)
- [ ] Tailscale IPs documented for all servers
- [ ] Docker Swarm initialized (if using swarm mode)
- [ ] If running Dokploy locally: Cloudflare Tunnel or webhook alternative configured

### Domain & DNS
- [ ] Domain `boursenumeriquedafrique.com` registered
- [ ] DNS A records configured
- [ ] DNS propagation verified

### Credentials & Secrets
- [ ] GitHub Personal Access Token (for ghcr.io)
- [ ] Strong JWT secret generated (64+ chars)
- [ ] Database password generated (20+ chars)
- [ ] Ethereum wallet & private key ready
- [ ] MTN MoMo API credentials
- [ ] Airtel Money API credentials

### Configuration Files
- [ ] `.env.production` created and filled
- [ ] `.env.clearing-house` created and filled
- [ ] `.env.staging` created (if using staging)
- [ ] All secrets are unique and strong

## 🔒 Security Best Practices

1. **Never commit `.env` files** (they're in `.gitignore`)
2. **Use strong, unique secrets** for each environment
3. **Enable private networking** between Server 1 & 2
4. **Configure firewall rules** on all servers
5. **Use SSL/TLS** for all domains
6. **Restrict database access** to only Server 1 & 2
7. **Regular backups** of database
8. **Monitor logs** for suspicious activity

## 📊 Monitoring

### Health Checks
```bash
# Exchange API
curl https://api.boursenumeriquedafrique.com/health

# Clearing House
curl https://payments.boursenumeriquedafrique.com/health

# GraphQL Playground
open https://api.boursenumeriquedafrique.com
```

### Logs
Access in Dokploy:
1. Select project
2. Click "Logs" tab
3. Filter by service and level

### Metrics (Optional)
- Enable Prometheus in production
- Add Grafana for visualization
- Configure alerts

## 🔄 CI/CD Workflow

```
Developer → Push to master
    ↓
GitHub Actions
    ↓
Run tests (+ PR checks)
    ↓
Create release (v0.1.x)
    ↓
Build Docker images
    ↓
Push to ghcr.io
    ├─→ :latest (staging auto-deploys via webhook)
    └─→ :v0.1.2 (production manual deploy)
    ↓
Trigger Dokploy webhook (staging only)
    ↓
Staging auto-redeploys
```

**Setup auto-deploy**: See `WEBHOOK-CONFIGURATION.md`

## 🗂️ Environment Variables Reference

### Required for All Environments
- `VERSION`: Docker image tag
- `POSTGRES_*`: Database credentials
- `JWT_SECRET`: Authentication secret
- `ETH_*`: Ethereum configuration
- `MTN_*`: MTN MoMo API keys
- `AIRTEL_*`: Airtel Money API keys

### Environment-Specific
- **Production**: Use production API endpoints and real credentials
- **Staging**: Use sandbox endpoints and test credentials
- **Clearing House**: Must match Exchange Server credentials exactly

See `.env.*.example` files for complete reference.

## 📚 Documentation

| Document                       | Purpose                                  |
|--------------------------------|------------------------------------------|
| `QUICK-START.md`               | Fast 60-minute deployment                |
| `DEPLOYMENT.md`                | Complete step-by-step guide              |
| `DNS-CONFIGURATION.md`         | DNS setup and troubleshooting            |
| `TAILSCALE-SETUP.md`           | **Private networking setup (REQUIRED)**  |
| `NEW-SERVER-CHECKLIST.md`      | Add new servers to infrastructure        |
| `WEBHOOK-CONFIGURATION.md`     | Auto-deploy webhook setup (staging)      |
| `LOCAL-DOKPLOY-OPTIONS.md`     | Run Dokploy locally with VPS nodes       |
| `CLOUDFLARE-TUNNEL-SETUP.md`   | Expose local Dokploy for webhooks        |
| `../README.md`                 | Main project documentation               |
| `../CLAUDE.md`                 | Development guide for Claude Code        |

## 🆘 Troubleshooting

### Common Issues

1. **Container won't start**: Check logs, verify environment variables
2. **Database connection failed**: Check network, firewall, credentials
3. **SSL certificate errors**: Verify DNS propagation, retry in Dokploy
4. **Payment webhooks not working**: Check domain accessibility, SSL, firewall

See `DEPLOYMENT.md` → Troubleshooting section for detailed solutions.

## 💰 Cost Breakdown

### Production (Recommended Setup)
- Server 1 (4GB RAM): $20-40/month
- Server 2 (2GB RAM): $10-20/month
- Frontend (Vercel): $0
- **Total: $30-60/month**

### With Managed Database
- Above + Managed DB: $15-30/month
- **Total: $45-90/month**

### Staging
- Single server (2GB): $10-15/month

## 🔗 Useful Links

- **Dokploy**: https://dokploy.com
- **GitHub Container Registry**: https://ghcr.io
- **MTN Developer Portal**: https://momodeveloper.mtn.com
- **Airtel Integration**: Contact Airtel team
- **Cloudflare DNS**: https://www.cloudflare.com/dns/

## 📞 Support

- **GitHub Issues**: https://github.com/Bourse-numerique-d-afrique/server/issues
- **Documentation**: This directory
- **Dokploy Docs**: https://docs.dokploy.com

## 🎯 Next Steps After Deployment

1. Deploy frontend application
2. Set up monitoring (Prometheus + Grafana)
3. Configure automated database backups
4. Set up status page
5. Implement audit logging
6. Performance optimization
7. Compliance review (KYC, AML)

---

**Last Updated**: 2026-01-02
**Deployment Version**: v0.1.2
**Maintainer**: Bourse Numérique d'Afrique Team
