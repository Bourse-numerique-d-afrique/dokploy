# Dokploy Deployment Troubleshooting

Common issues and solutions when deploying with Dokploy.

## "No such container: select-a-container" Error

This error occurs when Dokploy cannot parse the docker-compose file correctly.

### Solution 1: Use Dokploy-Compatible Compose Files

All compose files have been updated to be Dokploy-compatible:
- ✅ `docker-compose.staging.yml`
- ✅ `docker-compose.production.yml`
- ✅ `docker-compose.clearing-house.yml`

**CRITICAL REQUIREMENTS for Dokploy**:

✅ **Use external `dokploy-network`** (NOT custom networks):
```yaml
networks:
  dokploy-network:
    external: true

services:
  myapp:
    networks:
      - dokploy-network  # Required!
```

✅ **Add Traefik labels** for domain routing (services that need public access):
```yaml
services:
  myapp:
    labels:
      - traefik.enable=true
      - traefik.http.routers.myapp.rule=Host(`domain.com`)
      - traefik.http.routers.myapp.entrypoints=websecure
      - traefik.http.routers.myapp.tls.certResolver=letsencrypt
      - traefik.http.services.myapp.loadbalancer.server.port=3000
```

✅ **Port format** must be `5700` (NOT `"5700:5700"`):
```yaml
ports:
  - 5700  # Correct
  # NOT "5700:5700"
```

✅ **Removed** `container_name` directives (Dokploy manages names)
✅ **Removed** health check conditions from `depends_on` (not supported in Dokploy)
✅ **Simplified** environment variable syntax (array format: `- KEY=value`)
✅ **Simplified** command syntax (array format)
✅ **Simplified** volume names (removed prefixes)
✅ **Removed** inline comments within service definitions

### Solution 2: Verify Environment Variables

Before deploying, ensure all required environment variables are set in Dokploy:

**Required variables** (from `.env.staging.example`):
```env
VERSION=latest
POSTGRES_USER=exchange_user
POSTGRES_PASSWORD=your_password
POSTGRES_DATABASE=exchange_test
TOKEN_ISSUER=boursenumeriquedafrique-test
JWT_SECRET=your_secret_at_least_32_chars
ETH_PRIVATE_KEY=0x4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d
ETH_ADMIN_ADDRESS=0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1
MTN_URL=https://sandbox.momodeveloper.mtn.com
MTN_COLLECTION_PRIMARY_KEY=your_key
MTN_COLLECTION_SECONDARY_KEY=your_key
MTN_DISBURSEMENT_PRIMARY_KEY=your_key
MTN_DISBURSEMENT_SECONDARY_KEY=your_key
MTN_WEBHOOK_HOST=test-payments.boursenumeriquedafrique.com
AIRTEL_CLIENT_ID=your_client_id
AIRTEL_CLIENT_SECRET=your_secret
AIRTEL_ENVIRONMENT=staging
AIRTEL_CALLBACK_URL=https://test-payments.boursenumeriquedafrique.com/airtel/callback
AIRTEL_DISBURSEMENT_PIN=1234
VITE_APP_SERVER_GRAPHQL_URL=http://test-api.boursenumeriquedafrique.com/graphql
VITE_SERVER_GRAPHQL_WS_URL=ws://test-api.boursenumeriquedafrique.com/graphql/ws
```

### Solution 3: Deploy in Dokploy

**Step-by-step**:

1. **Create Project**:
   - Name: `exchange-staging`
   - Type: Docker Compose

2. **Add Compose File**:
   - Copy the content of `docker-compose.staging.yml`
   - Paste into Dokploy's compose editor
   - Click "Save"

3. **Set Environment Variables**:
   - Go to "Environment" tab
   - Add each variable from `.env.staging.example`
   - Click "Save"

4. **Configure Registry** (for private images):
   - Go to "Registry" tab
   - Add GitHub Container Registry:
     ```
     Registry: ghcr.io
     Username: your-github-username
     Password: your-github-token
     ```

5. **Deploy**:
   - Click "Deploy" button
   - Monitor logs for any errors

## Preview Not Showing

If the preview doesn't show containers:

### Check 1: Validate YAML Syntax

Use a YAML validator to check the compose file:

```bash
# Install yamllint
pip install yamllint

# Validate
yamllint docker-compose.staging.yml
```

### Check 2: Verify Variable Substitution

Ensure environment variables are properly substituted:

```bash
# Test locally with docker-compose
docker-compose -f docker-compose.staging.yml config

# This shows the final compose file with all variables substituted
```

### Check 3: Browser Cache

Clear browser cache or try incognito mode:
- Ctrl+Shift+Delete (Chrome/Edge)
- Ctrl+Shift+R (hard refresh)

## Deployment Fails

### Error: "Cannot pull image"

**Cause**: Authentication issue with GitHub Container Registry

**Solution**:
```bash
# Verify image exists
docker pull ghcr.io/bourse-numerique-d-afrique/server:latest

# If fails, check GitHub token has read:packages permission
```

In Dokploy:
1. Go to Settings → Registry
2. Verify credentials
3. Test connection

### Error: "Port already in use"

**Cause**: Port conflict with other containers

**Solution**:
```bash
# On server, check what's using the port
sudo netstat -tlnp | grep :5700

# Stop conflicting container
docker ps
docker stop <container-id>

# Or change port in compose file
```

### Error: "Volume not found"

**Cause**: Volume declaration issue

**Solution**:

In Dokploy, volumes are automatically created. If issues persist:

```bash
# SSH to server
ssh root@<server-ip>

# List volumes
docker volume ls

# Remove old volumes if needed
docker volume rm exchange-staging_timescaledb-data

# Redeploy
```

### Error: Database connection failed

**Cause**: Database not ready when app starts

**Solution**:

The simplified compose uses `depends_on` without conditions. Services will start in order, but may need retry logic.

**Workaround**: After initial deployment, restart the `exchange` service:

```bash
docker restart <exchange-container-id>
```

Or in Dokploy: Click "Restart" on exchange service

## Services Won't Start

### Check Logs

In Dokploy:
1. Go to "Logs" tab
2. Select service (exchange, clearing-house, etc.)
3. Look for errors

Common errors:

**Missing environment variable**:
```
Error: JWT_SECRET is required
```
Solution: Add the missing variable in Dokploy environment settings

**Connection refused**:
```
Error: connect ECONNREFUSED timescaledb:5432
```
Solution: Database service hasn't started yet. Wait and restart dependent service.

**Permission denied**:
```
Error: permission denied while trying to connect
```
Solution: Check POSTGRES_USER and POSTGRES_PASSWORD match in all services

## Network Issues

### Services Can't Communicate

**Verify network**:
```bash
# SSH to server
ssh root@<server-ip>

# Check networks
docker network ls

# Inspect network
docker network inspect <network-id>

# All containers should be on the same network
```

### Frontend Can't Reach API

**Check environment variables**:
```env
# In frontend service
VITE_APP_SERVER_GRAPHQL_URL=http://test-api.boursenumeriquedafrique.com/graphql
```

**Verify DNS**:
```bash
# From your computer
nslookup test-api.boursenumeriquedafrique.com

# Should resolve to staging server IP
```

**Check API is accessible**:
```bash
curl http://<staging-server-ip>:5700/graphql

# Or with domain
curl http://test-api.boursenumeriquedafrique.com/graphql
```

## Resource Issues

### Out of Memory

**Symptoms**:
- Services randomly stopping
- Containers being killed
- OOM (Out of Memory) in logs

**Solution**:
```bash
# Check memory usage
free -h
docker stats

# If low memory, add resource limits to compose
# Or upgrade server
```

**Add to services** (if needed):
```yaml
services:
  exchange:
    # ...
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
```

### Disk Space Full

**Check disk space**:
```bash
df -h

# Check Docker disk usage
docker system df
```

**Clean up**:
```bash
# Remove unused images
docker image prune -a

# Remove unused volumes
docker volume prune

# Full cleanup (CAUTION: removes stopped containers)
docker system prune -a --volumes
```

## Performance Issues

### Slow Container Startup

**Check image size**:
```bash
docker images | grep bourse-numerique-d-afrique
```

**Solutions**:
- Use multi-stage builds (already implemented)
- Ensure server has sufficient resources
- Use SSD storage

### Database Slow Queries

**Check database logs**:
```bash
docker logs <timescaledb-container>
```

**Optimize**:
- Ensure indexes exist
- Check connection pool settings
- Monitor with pgAdmin or similar

## Dokploy-Specific Issues

### Dokploy UI Not Responding

```bash
# Restart Dokploy
docker restart dokploy

# Check Dokploy logs
docker logs dokploy -f
```

### Deployment Stuck

**Force stop and redeploy**:

1. In Dokploy: Click "Stop"
2. Wait for all containers to stop
3. Click "Deploy" again

**Or via CLI**:
```bash
ssh root@<server-ip>

# Stop all project containers
docker-compose -f /path/to/compose.yml down

# Redeploy via Dokploy UI
```

### Auto-deploy Not Working

**Check webhook**:
1. Verify `DOKPLOY_STAGING_WEBHOOK_URL` secret is set in GitHub
2. Check GitHub Actions logs for webhook send status
3. Test webhook manually:

```bash
curl -X POST "https://dokploy-url/api/webhook" \
  -H "Content-Type: application/json" \
  -d '{"event": "docker_image_published"}'
```

## Quick Diagnostics Script

Save this as `diagnose.sh` on your staging server:

```bash
#!/bin/bash
echo "=== Dokploy Deployment Diagnostics ==="
echo ""

echo "1. Docker Version:"
docker --version
echo ""

echo "2. Running Containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

echo "3. Networks:"
docker network ls
echo ""

echo "4. Volumes:"
docker volume ls
echo ""

echo "5. Disk Space:"
df -h /
echo ""

echo "6. Memory:"
free -h
echo ""

echo "7. Recent Container Logs (last 20 lines):"
for container in $(docker ps -q); do
  echo "--- $(docker inspect -f '{{.Name}}' $container) ---"
  docker logs --tail 20 $container 2>&1 | tail -10
  echo ""
done

echo "8. Port Bindings:"
sudo netstat -tlnp | grep -E ':(5700|8500|5432|8545|6379|80|443)' || echo "No ports in use"
echo ""

echo "=== Diagnostics Complete ==="
```

Run it:
```bash
chmod +x diagnose.sh
./diagnose.sh > diagnosis.txt
cat diagnosis.txt
```

## Getting Help

If issues persist:

1. **Check Dokploy Logs**:
   ```bash
   docker logs dokploy -f
   ```

2. **Check GitHub Issues**:
   - Dokploy: https://github.com/dokploy/dokploy/issues
   - Your repo: https://github.com/Bourse-numerique-d-afrique/server/issues

3. **Dokploy Discord**: Join for community support

4. **Collect Information**:
   - Dokploy version
   - Docker version
   - Server OS and specs
   - Error messages from logs
   - Compose file content
   - Environment variables (redact secrets!)

---

**Last Updated**: 2026-01-03
**Maintainer**: Bourse Numérique d'Afrique Team
