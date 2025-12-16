# Zeabur Deployment Guide for Skyvern

This guide explains how to deploy Skyvern on the Zeabur platform.

## 🚀 Quick Start

### Prerequisites
1. A Zeabur account (https://zeabur.com)
2. Git repository access to this Skyvern fork
3. An LLM provider API key (OpenAI, Anthropic, etc.)

### Deployment Steps

#### 1. Create a New Project in Zeabur
1. Log in to your Zeabur dashboard
2. Click "Create Project"
3. Connect your GitHub repository

#### 2. Add PostgreSQL Service
1. Click "Add Service" → "Database" → "PostgreSQL"
2. Zeabur will automatically create the database and provide connection string
3. The `DATABASE_STRING` environment variable will be auto-configured

#### 3. Add Skyvern Service
1. Click "Add Service" → "Git"
2. Select your Skyvern repository
3. Zeabur will auto-detect the Dockerfile and build

#### 4. Configure Environment Variables

In the Skyvern service settings, add these environment variables:

##### Required Variables

```bash
# LLM Provider Configuration (choose one)
# For OpenAI:
ENABLE_OPENAI=true
LLM_KEY=OPENAI_GPT4O
OPENAI_API_KEY=your_openai_api_key_here

# For Anthropic Claude:
# ENABLE_ANTHROPIC=true
# LLM_KEY=ANTHROPIC_CLAUDE3.5_SONNET
# ANTHROPIC_API_KEY=your_anthropic_api_key_here

# For Azure OpenAI:
# ENABLE_AZURE=true
# LLM_KEY=AZURE_OPENAI
# AZURE_DEPLOYMENT=your_deployment_name
# AZURE_API_KEY=your_azure_api_key
# AZURE_API_BASE=https://your-resource.openai.azure.com/
# AZURE_API_VERSION=2024-08-01-preview

# Browser Configuration
BROWSER_TYPE=chromium-headful
ENABLE_CODE_BLOCK=true

# Database (auto-configured by Zeabur if PostgreSQL service is added)
# DATABASE_STRING will be automatically set by Zeabur
```

##### Optional Variables

```bash
# Secondary LLM for lightweight tasks
SECONDARY_LLM_KEY=OPENAI_GPT4O_MINI

# Logging
LOG_LEVEL=INFO
ENABLE_LOG_ARTIFACTS=false

# Analytics
ANALYTICS_ID=anonymous

# Skyvern Configuration
MAX_STEPS_PER_RUN=50
MAX_SCRAPING_RETRIES=0
BROWSER_ACTION_TIMEOUT_MS=5000

# Environment
ENV=production
```

#### 5. Deploy

1. After adding environment variables, Zeabur will automatically build and deploy
2. Wait for the build to complete (usually 5-10 minutes)
3. Once deployed, Zeabur will provide a public URL

## 🔧 Port Configuration

**Important:** The updated configuration automatically handles Zeabur's port assignment:

- Zeabur provides a `PORT` environment variable (usually random, e.g., 8080, 3000, etc.)
- Our updated `boot.sh` script reads this `PORT` and configures Nginx accordingly
- **You don't need to manually configure ports** - it's automatic!

### How It Works

1. `boot.sh` reads the `PORT` environment variable from Zeabur
2. Generates Nginx configuration from `nginx.conf.template` with the correct port
3. Starts all services:
   - Backend API: `127.0.0.1:8000` (internal)
   - Frontend Server: `127.0.0.1:8081` (internal)
   - Artifact Server: `127.0.0.1:9090` (internal)
   - Nginx Reverse Proxy: `0.0.0.0:${PORT}` (external, exposed by Zeabur)

## 🐛 Troubleshooting

### Issue: "Address already in use" Error

**Symptoms:** Container fails to start with `bind() to 0.0.0.0:8080 failed (98: Address already in use)`

**Solution:** This should be fixed by the updates in this repository. The container now:
1. Uses `envsubst` to generate Nginx config dynamically
2. Reads the `PORT` environment variable provided by Zeabur
3. Binds to the correct port automatically

If you still see this error:
1. Ensure you're using the latest version of the code (after the port fix)
2. Rebuild the container in Zeabur: Settings → Redeploy
3. Check logs for the actual port being used: Settings → Logs

### Issue: 502 Bad Gateway

**Symptoms:** Website loads but shows 502 errors

**Possible Causes:**
1. Backend API failed to start
2. Database connection issues
3. LLM provider misconfiguration

**Solution:**
1. Check container logs in Zeabur dashboard
2. Look for backend startup errors in logs
3. Verify `DATABASE_STRING` is correctly set (should be auto-configured)
4. Verify LLM API keys are valid
5. Check that `ENABLE_OPENAI` (or your LLM provider) is set to `true`

### Issue: Database Connection Failed

**Symptoms:** Backend crashes with database connection errors

**Solution:**
1. Ensure PostgreSQL service is running in Zeabur
2. Check that `DATABASE_STRING` environment variable is set
3. Zeabur should auto-configure this when you add a PostgreSQL service
4. Manual format: `postgresql+psycopg://username:password@hostname:5432/dbname`

### Issue: LLM API Errors

**Symptoms:** Tasks fail with LLM-related errors

**Solution:**
1. Verify API key is correct
2. Check that `ENABLE_OPENAI` (or appropriate provider) is `true`
3. Verify `LLM_KEY` matches your provider (e.g., `OPENAI_GPT4O`)
4. Check API key has sufficient credits/quota
5. Review logs for specific API error messages

## 📊 Monitoring

### Check Service Status
1. Go to Zeabur dashboard → Your project → Skyvern service
2. Click "Logs" to view real-time logs
3. Check "Metrics" for resource usage

### View Application Logs
Logs are stored in `/data/log/` inside the container:
- `backend.log` - Backend API logs
- `localserver.log` - Frontend server logs
- `artifactserver.log` - Artifact server logs
- Nginx logs - `/var/log/nginx/access.log` and `/var/log/nginx/error.log`

## 🔐 Database Persistence

Zeabur automatically handles PostgreSQL persistence. Your data will be preserved across container restarts.

To backup your database:
1. Use Zeabur's backup feature (if available)
2. Or manually export using `pg_dump` through Zeabur's CLI

## 🌐 Custom Domain

To use a custom domain:
1. Go to your Skyvern service in Zeabur
2. Click "Domains"
3. Add your custom domain
4. Configure DNS according to Zeabur's instructions

## 📝 Environment Variable Reference

See `.env.example` for a complete list of available environment variables.

### Critical Variables for Zeabur

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `ENABLE_OPENAI` | Yes (or other LLM) | Enable your LLM provider | `true` |
| `LLM_KEY` | Yes | LLM model to use | `OPENAI_GPT4O` |
| `OPENAI_API_KEY` | Yes (if using OpenAI) | OpenAI API key | `sk-...` |
| `DATABASE_STRING` | Auto-configured | PostgreSQL connection | Auto-set by Zeabur |
| `BROWSER_TYPE` | Recommended | Browser type | `chromium-headful` |
| `ENV` | Recommended | Environment | `production` |

## 🚦 Health Checks

Zeabur will automatically monitor your service health. The container exposes:
- Health check endpoint: `/api/v1/internal/auth/status`
- Zeabur monitors container status automatically

## 💰 Cost Optimization

### Zeabur Costs
- Zeabur charges based on resource usage
- PostgreSQL database storage
- Container runtime

### LLM Costs
- Monitor your LLM API usage
- Consider using `SECONDARY_LLM_KEY` with a cheaper model for non-critical tasks
- Set `LLM_CONFIG_MAX_TOKENS` to control token usage

## 📚 Additional Resources

- [Skyvern Documentation](https://www.skyvern.com/docs)
- [Zeabur Documentation](https://zeabur.com/docs)
- [Container Deployment Guide](CONTAINER_DEPLOYMENT.md) - Original container deployment docs

## 🆘 Getting Help

If you encounter issues:
1. Check this troubleshooting guide
2. Review container logs in Zeabur dashboard
3. Check Skyvern Discord: https://discord.gg/fG2XXEuQX3
4. Open an issue on GitHub

## 📋 Deployment Checklist

Before deploying, ensure:
- [ ] PostgreSQL service added in Zeabur
- [ ] LLM provider configured (`ENABLE_OPENAI`, `OPENAI_API_KEY`, etc.)
- [ ] `LLM_KEY` set to appropriate model
- [ ] `BROWSER_TYPE` set to `chromium-headful`
- [ ] All required environment variables configured
- [ ] Latest code with port fix deployed
- [ ] Service successfully built and deployed
- [ ] Can access the application via Zeabur-provided URL
- [ ] Can create and run tasks successfully
