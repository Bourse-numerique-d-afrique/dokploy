# Webhook Configuration for Auto-Deploy

This guide explains how to configure automatic staging deployments triggered by GitHub Actions.

## Overview

When code is pushed to the `master` branch:
1. GitHub Actions runs tests
2. Builds and publishes Docker images with `:latest` tag
3. Sends webhook to Dokploy staging environment
4. Dokploy automatically pulls and redeploys with new images

**Production deployments remain manual** using specific version tags (e.g., `v0.1.3`).

## Architecture

```
┌─────────────────────┐
│  GitHub Actions     │
│  (master branch)    │
└──────────┬──────────┘
           │
           │ 1. Tests pass
           │ 2. Build images with :latest
           │ 3. Push to ghcr.io
           ↓
    ┌──────────────────┐
    │  Send Webhook    │
    │  POST request    │
    └────────┬─────────┘
             │
             ↓
    ┌──────────────────────┐
    │  Dokploy Staging     │
    │  Receives webhook    │
    │  Pulls :latest       │
    │  Redeploys services  │
    └──────────────────────┘
```

## Setup Instructions

### Step 1: Get Dokploy Webhook URL

1. **Log in to Dokploy** on your staging server
2. **Navigate to your project** (e.g., "Exchange Staging")
3. **Click on the project** to open settings
4. **Find the "Webhooks" or "Git" section**
5. **Generate or copy the webhook URL**

The URL will look something like:
```
https://dokploy.your-server.com/api/deploy/webhook?projectId=abc123&token=xyz789
```

Or you can use Dokploy's redeploy API:
```
https://dokploy.your-server.com/api/projects/{projectId}/redeploy
```

**Note**: Exact webhook format depends on your Dokploy version. Consult Dokploy documentation at https://docs.dokploy.com

### Step 2: Add Webhook URL to GitHub Secrets

1. **Go to GitHub repository**: https://github.com/Bourse-numerique-d-afrique/server
2. **Navigate to Settings** → **Secrets and variables** → **Actions**
3. **Click "New repository secret"**
4. **Add secret**:
   - **Name**: `DOKPLOY_STAGING_WEBHOOK_URL`
   - **Value**: The webhook URL from Step 1
   - **Click "Add secret"**

### Step 3: Test the Webhook

1. **Make a test commit** to the `master` branch:
   ```bash
   git commit --allow-empty -m "test: trigger staging auto-deploy"
   git push origin master
   ```

2. **Watch GitHub Actions**:
   - Go to **Actions** tab in GitHub
   - Watch the workflow execution
   - Verify "Trigger Staging Auto-Deploy" job succeeds

3. **Verify Dokploy Staging**:
   - Log in to Dokploy
   - Check deployment logs
   - Verify services are redeploying with `:latest` images

### Step 4: Verify Auto-Deploy Works

```bash
# Check staging API
curl https://test-api.boursenumeriquedafrique.com/health

# Check clearing house
curl https://test-payments.boursenumeriquedafrique.com/health
```

## Webhook Payload

The GitHub Actions workflow sends this JSON payload:

```json
{
  "event": "docker_image_published",
  "repository": "Bourse-numerique-d-afrique/server",
  "version": "0.1.3",
  "tags": ["latest", "0.1.3"],
  "images": [
    "ghcr.io/bourse-numerique-d-afrique/server:latest",
    "ghcr.io/bourse-numerique-d-afrique/server-clearing-house:latest"
  ],
  "commit": "abc123def456...",
  "actor": "github-username"
}
```

Your Dokploy webhook handler can use this information to:
- Identify which images to pull
- Log deployment metadata
- Send notifications
- Track deployment history

## Alternative: Dokploy Auto-Pull Configuration

If webhooks are not available, you can configure Dokploy to automatically pull and redeploy:

1. **In Dokploy project settings**:
   - Enable "Auto-deploy on image update"
   - Set image to `ghcr.io/bourse-numerique-d-afrique/server:latest`
   - Set poll interval (e.g., every 5 minutes)

2. **For clearing house service**:
   - Enable auto-deploy
   - Set image to `ghcr.io/bourse-numerique-d-afrique/server-clearing-house:latest`

This method polls the registry instead of using webhooks.

## Troubleshooting

### Webhook Returns 404 or 401

**Problem**: Dokploy webhook URL is incorrect or token expired

**Solution**:
1. Regenerate webhook URL in Dokploy
2. Update `DOKPLOY_STAGING_WEBHOOK_URL` secret in GitHub
3. Retry deployment

### Webhook Times Out

**Problem**: Staging server firewall blocking GitHub IPs

**Solution**:
1. Check firewall rules on staging server
2. Allow incoming HTTPS (443) from GitHub webhook IPs
3. Verify server is accessible from internet

### Auto-Deploy Not Triggered

**Problem**: Secret not configured or wrong secret name

**Solution**:
1. Verify secret exists: GitHub → Settings → Secrets → Actions
2. Name must be exactly: `DOKPLOY_STAGING_WEBHOOK_URL`
3. Check workflow logs for "not configured" message

### Images Not Updating

**Problem**: Dokploy cached the `:latest` tag

**Solution**:
1. In Dokploy, manually trigger "Rebuild" (not just "Redeploy")
2. Or use webhook with `--pull always` option
3. Configure Docker to not cache `:latest` tags

## Security Considerations

### Webhook URL Security

- **Keep webhook URL secret**: Don't commit to version control
- **Use HTTPS**: Always use secure webhook endpoints
- **Rotate tokens**: Periodically regenerate Dokploy webhook tokens
- **IP whitelist**: Restrict webhook endpoint to GitHub IPs if possible

### GitHub Actions Secrets

- **Repository secrets**: Only accessible during workflow runs
- **Not visible in logs**: GitHub masks secret values in outputs
- **Access control**: Only repository admins can modify secrets
- **Audit trail**: Secret modifications are logged

## Production Deployment (Manual Process)

Production deployments remain manual for safety:

1. **GitHub Actions creates release**: `v0.1.3`
2. **Review release notes**: Verify changes are safe
3. **Update `.env.production`**: Set `VERSION=v0.1.3`
4. **In Dokploy**:
   - Select production project
   - Update environment variable `VERSION=v0.1.3`
   - Click "Redeploy"
5. **Verify deployment**: Check health endpoints and logs
6. **Monitor**: Watch metrics and error rates

This ensures production is only updated with reviewed, tested releases.

## Workflow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Developer Workflow                        │
└─────────────────────────────────────────────────────────────┘

Developer pushes to master
         │
         ↓
┌────────────────────┐
│  GitHub Actions    │
│  - Run tests       │
│  - Create release  │
│  - Build images    │
│  - Push to ghcr.io │
└─────────┬──────────┘
          │
          ├─────────────────────┬──────────────────────┐
          ↓                     ↓                      ↓
   ┌─────────────┐      ┌──────────────┐      ┌─────────────┐
   │  :latest    │      │  :v0.1.3     │      │  Webhook    │
   │  (Staging)  │      │  (Prod)      │      │  Trigger    │
   └──────┬──────┘      └──────┬───────┘      └──────┬──────┘
          │                    │                     │
          │                    │                     │
   Auto   │             Manual │              Notify │
   Deploy │             Update │              Dokploy│
          ↓                    ↓                     ↓
   ┌─────────────┐      ┌─────────────┐      ┌─────────────┐
   │  Staging    │      │ Production  │      │  Staging    │
   │  Redeploy   │      │ Redeploy    │      │  Redeploy   │
   └─────────────┘      └─────────────┘      └─────────────┘
```

## Monitoring Auto-Deploys

### GitHub Actions
- View workflow runs: https://github.com/Bourse-numerique-d-afrique/server/actions
- Check "Trigger Staging Auto-Deploy" job status
- View webhook payload in logs

### Dokploy
- Monitor deployment logs in real-time
- Check "Last Deployment" timestamp
- Verify container image tags

### Application Health
```bash
# Staging health check
curl https://test-api.boursenumeriquedafrique.com/health

# Compare with production
curl https://api.boursenumeriquedafrique.com/health
```

## Rollback Procedure

If staging auto-deploy breaks something:

1. **Identify last working version**:
   ```bash
   # Check GitHub releases
   gh release list
   ```

2. **Update staging to specific version**:
   - In Dokploy staging project
   - Set `VERSION=v0.1.2` (last working version)
   - Click "Redeploy"

3. **Disable auto-deploy temporarily**:
   - Remove `DOKPLOY_STAGING_WEBHOOK_URL` secret
   - Or add `[skip ci]` to commit messages

4. **Fix the issue** in a separate branch

5. **Re-enable auto-deploy** after fix is merged

## Best Practices

1. **Monitor staging closely**: Check logs after each auto-deploy
2. **Keep staging identical**: Match production configuration as closely as possible
3. **Test thoroughly**: Staging is the last gate before production
4. **Quick rollback**: Always know the last working version
5. **Communicate**: Notify team of auto-deploys in Slack/Discord
6. **Document issues**: Track auto-deploy failures and resolutions

## Additional Resources

- **Dokploy Documentation**: https://docs.dokploy.com
- **GitHub Actions Webhooks**: https://docs.github.com/en/actions
- **Docker Best Practices**: https://docs.docker.com/develop/dev-best-practices/
- **Security Guidelines**: Review GitHub's webhook security docs

---

**Last Updated**: 2026-01-02
**Version**: 1.0
**Maintainer**: Bourse Numérique d'Afrique Team
