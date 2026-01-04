# Fixing "Remote command failed with exit code 1" in Dokploy

This error occurs when a deployment command fails. Here's how to diagnose and fix it.

## Quick Diagnosis Steps

### Step 1: Check Dokploy Logs

In Dokploy UI:
1. Go to your project
2. Click **"Logs"** tab
3. Look for the **red error messages** right before the exit code 1

The logs will show the actual error. Common errors:

```
Error: Cannot pull image
Error: port already in use
Error: environment variable not set
Error: connection refused
```

### Step 2: SSH to Server and Check

```bash
# SSH to your server
ssh root@<server-ip>

# Check Docker logs
docker ps -a  # List all containers (including stopped)
docker logs <container-id>  # Check logs of failed container

# Check Dokploy logs
docker logs dokploy -f
```

## Common Causes & Solutions

### 1. Image Pull Authentication Failed

**Error in logs**:
```
Error response from daemon: pull access denied for ghcr.io/...
Error: Cannot pull image
unauthorized: authentication required
```

**Solution A: Add GitHub Container Registry Credentials**

In Dokploy:
1. Go to **Settings** → **Registry**
2. Click **"Add Registry"**
3. Fill in:
   ```
   Registry URL: ghcr.io
   Username: your-github-username
   Password: your-github-personal-token
   ```
4. Click **"Save"**
5. **Redeploy**

**Generate GitHub Token** (if needed):
1. Go to https://github.com/settings/tokens
2. Click **"Generate new token (classic)"**
3. Select scopes:
   - ✅ `read:packages`
   - ✅ `write:packages`
4. Click **"Generate token"**
5. Copy the token (starts with `ghp_`)
6. Use in Dokploy Registry settings

**Solution B: Make Images Public** (if testing):

```bash
# Go to GitHub repository → Packages
# Click on package (server or client)
# Package settings → Change visibility → Public
```

### 2. Environment Variables Missing

**Error in logs**:
```
Error: JWT_SECRET is required
Error: POSTGRES_PASSWORD is not set
thread 'main' panicked at 'Environment variable not found'
```

**Solution: Add Missing Variables**

In Dokploy:
1. Go to **"Environment"** tab
2. Add the missing variable
3. Click **"Save"**
4. **Redeploy**

**Verify all required variables are set**:

```env
# Staging - Minimum Required
VERSION=latest
POSTGRES_USER=exchange_user
POSTGRES_PASSWORD=your_password_here
POSTGRES_DATABASE=exchange_test
TOKEN_ISSUER=boursenumeriquedafrique-test
JWT_SECRET=your_secret_at_least_32_characters_long_change_this_please
ETH_PRIVATE_KEY=0x4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d
ETH_ADMIN_ADDRESS=0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1
MTN_URL=https://sandbox.momodeveloper.mtn.com
MTN_COLLECTION_PRIMARY_KEY=test_key
MTN_COLLECTION_SECONDARY_KEY=test_key
MTN_DISBURSEMENT_PRIMARY_KEY=test_key
MTN_DISBURSEMENT_SECONDARY_KEY=test_key
MTN_WEBHOOK_HOST=test-payments.boursenumeriquedafrique.com
AIRTEL_CLIENT_ID=test_id
AIRTEL_CLIENT_SECRET=test_secret
AIRTEL_ENVIRONMENT=staging
AIRTEL_CALLBACK_URL=https://test-payments.boursenumeriquedafrique.com/airtel/callback
AIRTEL_DISBURSEMENT_PIN=1234
VITE_APP_SERVER_GRAPHQL_URL=http://test-api.boursenumeriquedafrique.com/graphql
VITE_SERVER_GRAPHQL_WS_URL=ws://test-api.boursenumeriquedafrique.com/graphql/ws
```

### 3. Port Already in Use

**Error in logs**:
```
Error: bind: address already in use
Error starting userland proxy: listen tcp4 0.0.0.0:5700: bind: address already in use
```

**Solution: Stop Conflicting Containers**

```bash
# SSH to server
ssh root@<server-ip>

# Find what's using the port
sudo netstat -tlnp | grep :5700
# or
sudo lsof -i :5700

# Stop the container using that port
docker ps
docker stop <container-id>

# Or stop all containers and redeploy
docker stop $(docker ps -q)
```

**In Dokploy**: Click **"Stop"** → Wait → Click **"Deploy"**

### 4. Volume Permission Issues

**Error in logs**:
```
Error: permission denied
chown: changing ownership of '/var/lib/postgresql/data': Permission denied
```

**Solution: Fix Volume Permissions**

```bash
# SSH to server
ssh root@<server-ip>

# List volumes
docker volume ls

# Remove problematic volumes (CAUTION: deletes data)
docker volume rm <volume-name>

# Or fix permissions
docker run --rm -v <volume-name>:/data alpine chown -R 999:999 /data

# Redeploy in Dokploy
```

### 5. Network Issues

**Error in logs**:
```
Error: network not found
Error: could not find an available, non-overlapping IPv4 address pool
```

**Solution: Clean Up Networks**

```bash
# SSH to server
ssh root@<server-ip>

# List networks
docker network ls

# Remove unused networks
docker network prune

# Or remove specific network
docker network rm <network-name>

# Redeploy
```

### 6. Database Connection Failed

**Error in logs**:
```
Error: ECONNREFUSED timescaledb:5432
Error: password authentication failed
Connection refused
```

**Solution A: Wait for Database to Start**

Services may start before database is ready. In Dokploy:
1. Wait 1-2 minutes after deployment
2. Click **"Restart"** on the exchange/clearing-house service

**Solution B: Check Database Credentials**

Ensure same credentials in all services:
```env
POSTGRES_USER=exchange_user
POSTGRES_PASSWORD=same_password_everywhere
POSTGRES_DATABASE=exchange_test
```

**Solution C: Database Not Started**

```bash
# SSH to server
docker ps -a | grep timescale

# If not running, check logs
docker logs <timescaledb-container-id>

# Restart it
docker restart <timescaledb-container-id>
```

### 7. Compose File Syntax Error

**Error in logs**:
```
Error: yaml: line X: mapping values are not allowed in this context
Error: services.exchange.environment must be a mapping
Error: No such container: select-a-container
```

**Solution: Verify Compose File Syntax**

Use the **exact** format from the repo with **Dokploy-specific requirements**:

**CRITICAL: All Dokploy compose files MUST include**:

1. **External `dokploy-network`** (NOT custom networks):
```yaml
networks:
  dokploy-network:
    external: true

services:
  exchange:
    networks:
      - dokploy-network  # Required!
```

2. **Traefik labels** for services with domains:
```yaml
services:
  exchange:
    labels:
      - traefik.enable=true
      - traefik.http.routers.exchange-staging.rule=Host(`test-api.boursenumeriquedafrique.com`)
      - traefik.http.routers.exchange-staging.entrypoints=websecure
      - traefik.http.routers.exchange-staging.tls.certResolver=letsencrypt
      - traefik.http.services.exchange-staging.loadbalancer.server.port=5700
```

3. **Port format** must be `5700` (NOT `"5700:5700"`):
```yaml
ports:
  - 5700  # Correct
  # NOT "5700:5700"
```

4. **Environment variables** in array format:
```yaml
environment:
  - POSTGRES_HOST=timescaledb
  - POSTGRES_PORT=5432
  # NOT THIS:
  # POSTGRES_HOST: timescaledb  (wrong format)
```

Copy the compose file **exactly** from:
```
https://github.com/Bourse-numerique-d-afrique/dokploy/blob/main/docker-compose.staging.yml
```

### 8. Insufficient Server Resources

**Error in logs**:
```
Error: OOMKilled
Error: cannot allocate memory
```

**Solution: Check Server Resources**

```bash
# SSH to server
ssh root@<server-ip>

# Check memory
free -h

# Check disk
df -h

# Check Docker resource usage
docker stats
```

**If low on resources**:
- Upgrade server
- Reduce services (remove prometheus, etc.)
- Add memory limits to services

## Step-by-Step Debugging Process

### 1. Get Detailed Error

In Dokploy:
1. Go to project
2. Click **"Logs"** tab
3. Scroll to the bottom
4. Find the **last error message** before "exit code 1"
5. **Copy the entire error message**

### 2. SSH and Investigate

```bash
# SSH to server
ssh root@<server-ip>

# Check what containers are running
docker ps -a

# Check logs of stopped containers
docker ps -a | grep -i exit
docker logs <stopped-container-id>

# Check Dokploy container logs
docker logs dokploy --tail 100
```

### 3. Test Compose File Locally

```bash
# On your server
cd /tmp
nano docker-compose.test.yml
# Paste your compose file

# Create .env file
nano .env
# Paste your environment variables

# Test deployment
docker-compose -f docker-compose.test.yml config
# This shows the final compose with variables substituted

# Check for errors
docker-compose -f docker-compose.test.yml up -d

# Check logs
docker-compose -f docker-compose.test.yml logs

# Cleanup
docker-compose -f docker-compose.test.yml down
```

### 4. Deploy One Service at a Time

To isolate the problem:

**Minimal compose** (test.yml):
```yaml
version: '3.8'

services:
  timescaledb:
    image: timescale/timescaledb-ha:pg17
    restart: unless-stopped
    environment:
      - POSTGRES_USER=exchange_user
      - POSTGRES_PASSWORD=test123
      - POSTGRES_DB=exchange_test
      - TIMESCALEDB_TELEMETRY=off
    ports:
      - "5432:5432"
    volumes:
      - db-data:/var/lib/postgresql/data

volumes:
  db-data:
```

Deploy in Dokploy:
1. Use minimal compose above
2. If it works, add one service at a time
3. Identify which service is causing the issue

## Complete Diagnostic Script

Save as `diagnose-dokploy-error.sh`:

```bash
#!/bin/bash
echo "=== Dokploy Deployment Diagnostics ==="
echo ""

echo "1. Server Resources:"
echo "Memory:"
free -h
echo ""
echo "Disk:"
df -h /
echo ""

echo "2. Docker Status:"
docker --version
docker info | grep -E 'Server Version|Storage Driver|Logging Driver'
echo ""

echo "3. Running Containers:"
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

echo "4. Failed Containers:"
docker ps -a --filter "status=exited" --format "table {{.Names}}\t{{.Status}}"
echo ""

echo "5. Recent Container Logs:"
for container in $(docker ps -a --filter "status=exited" -q); do
  echo "=== $(docker inspect -f '{{.Name}}' $container) ==="
  docker logs --tail 50 $container 2>&1
  echo ""
done

echo "6. Docker Networks:"
docker network ls
echo ""

echo "7. Docker Volumes:"
docker volume ls
echo ""

echo "8. Port Usage:"
sudo netstat -tlnp | grep -E ':(5700|8500|5432|8545|6379|80|443)' || echo "No services ports in use"
echo ""

echo "9. Dokploy Logs (last 50 lines):"
docker logs dokploy --tail 50 2>&1
echo ""

echo "10. Disk Space by Docker:"
docker system df
echo ""

echo "=== Diagnostics Complete ==="
```

Run it:
```bash
chmod +x diagnose-dokploy-error.sh
./diagnose-dokploy-error.sh > diagnosis.txt
cat diagnosis.txt
```

## Quick Fixes Checklist

Try these in order:

- [ ] **1. Check Dokploy logs** for the actual error
- [ ] **2. Verify GitHub Container Registry** credentials are set
- [ ] **3. Verify all environment variables** are set correctly
- [ ] **4. Stop all containers** and redeploy clean
- [ ] **5. Remove old volumes** and redeploy
- [ ] **6. Test with minimal compose** (just database)
- [ ] **7. Check server has enough resources** (memory, disk)
- [ ] **8. Restart Dokploy** itself: `docker restart dokploy`

## Still Having Issues?

### Collect This Information:

1. **Exact error from Dokploy logs**
2. **Output of diagnostics script** (above)
3. **Compose file content** (redact secrets)
4. **Environment variables list** (redact values)
5. **Server specs** (RAM, CPU, disk)
6. **Dokploy version**: Check in Dokploy UI

### Get Help:

- **GitHub Issues**: https://github.com/Bourse-numerique-d-afrique/server/issues
- **Dokploy Discord**: Join for community support
- **Dokploy GitHub**: https://github.com/dokploy/dokploy/issues

## Most Common Solution

In 80% of cases, the issue is:

**Missing GitHub Container Registry credentials**

Fix:
1. Dokploy → Settings → Registry
2. Add:
   ```
   Registry: ghcr.io
   Username: your-github-username
   Password: ghp_your_github_token
   ```
3. Redeploy

**Or make images public** (for testing):
- GitHub → Packages → Package settings → Change visibility → Public

---

**Last Updated**: 2026-01-04
**Maintainer**: Bourse Numérique d'Afrique Team
