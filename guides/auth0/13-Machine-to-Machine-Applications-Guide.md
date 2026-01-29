# Auth0 Machine-to-Machine Applications Complete Guide

## Overview

This guide covers everything you need to know about setting up and troubleshooting Auth0 Machine-to-Machine (M2M) applications for the Management API. After spending hours debugging a 401 error, this guide will ensure you never face the same issues again.

## Table of Contents

1. [Understanding M2M Applications](#understanding-m2m-applications)
2. [Initial Setup](#initial-setup)
3. [Common Pitfalls](#common-pitfalls)
4. [Troubleshooting Guide](#troubleshooting-guide)
5. [Testing Procedures](#testing-procedures)
6. [Production Deployment](#production-deployment)
7. [Maintenance](#maintenance)

## Understanding M2M Applications

### What is a Machine-to-Machine Application?

M2M applications are used for server-to-server authentication where no user interaction is involved. In our case, we use M2M to allow our backend to communicate with the Auth0 Management API to manage users.

### Key Components

1. **Client ID**: Public identifier for your M2M application
2. **Client Secret**: Private key (never expose this publicly)
3. **Audience**: The API you're trying to access (for Management API: `https://YOUR_DOMAIN/api/v2/`)
4. **Scopes**: Permissions granted to the M2M application

## Initial Setup

### Step 1: Create M2M Application

1. Go to Auth0 Dashboard → Applications → Applications
2. Click "Create Application"
3. Name: `YourApp Management API - Environment` (e.g., "VibeCoder Management API - Production")
4. Type: Select "Machine to Machine Applications"
5. Click "Create"

### Step 2: Authorize for Management API

1. After creation, you'll see "Authorize Machine to Machine Application"
2. Select "Auth0 Management API" (NOT your custom API)
3. This is crucial - many issues come from selecting the wrong API

### Step 3: Select Required Scopes

Essential scopes for user management:

```
✓ read:users
✓ update:users
✓ create:users
✓ delete:users
✓ read:users_app_metadata
✓ update:users_app_metadata
✓ delete:users_app_metadata (if available)
✓ create:users_app_metadata (if available)
✓ read:user_idp_tokens (if needed)
```

### Step 4: Save Credentials

1. Go to Settings tab of your M2M application
2. Copy and save:
   - Domain (e.g., `vibecoder-prod.us.auth0.com`)
   - Client ID
   - Client Secret

## Common Pitfalls

### 1. Wrong API Selection

**Problem**: Selecting your custom API instead of Auth0 Management API
**Symptom**: 401 Unauthorized errors
**Solution**: Ensure you select "Auth0 Management API" with identifier `https://YOUR_DOMAIN/api/v2/`

### 2. Missing Scopes

**Problem**: Not all required scopes are selected
**Symptom**: 403 Forbidden on specific operations
**Solution**: Go to APIs → Auth0 Management API → Machine To Machine Applications → Select all user-related scopes

### 3. Environment Variable Format

**Problem**: Including `https://` in AUTH0_DOMAIN
**Correct**: `vibecoder-prod.us.auth0.com`
**Incorrect**: `https://vibecoder-prod.us.auth0.com`

### 4. Vercel Deployment Cache

**Problem**: Updated environment variables not taking effect
**Symptom**: Old credentials still being used after update
**Solution**: Force redeploy with `vercel --prod --force`

### 5. Authorization Not Saved

**Problem**: M2M app shows as authorized but still gets 401
**Solution**:

1. Toggle authorization OFF
2. Wait 5 seconds
3. Toggle back ON
4. Re-select all scopes
5. Click "Update"

## Troubleshooting Guide

### Debug Checklist

1. **Verify Tenant**

   ```
   Development: dev-xxxxxx.us.auth0.com
   Production: your-prod.us.auth0.com
   ```

2. **Check Environment Variables**

   ```bash
   AUTH0_DOMAIN=your-domain.auth0.com (no https://)
   AUTH0_MGMT_CLIENT_ID=your-m2m-client-id
   AUTH0_MGMT_CLIENT_SECRET=your-m2m-client-secret
   AUTH0_AUDIENCE=https://your-domain.auth0.com/api/v2/
   ```

3. **Test Token Acquisition**
   ```bash
   curl --request POST \
     --url https://YOUR_DOMAIN/oauth/token \
     --header 'content-type: application/json' \
     --data '{
       "client_id":"YOUR_CLIENT_ID",
       "client_secret":"YOUR_CLIENT_SECRET",
       "audience":"https://YOUR_DOMAIN/api/v2/",
       "grant_type":"client_credentials"
     }'
   ```

### Creating Debug Endpoints

Add this temporary endpoint to test configuration:

```typescript
// pages/api/admin/debug-auth0.ts
import { NextApiRequest, NextApiResponse } from "next";

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  // Only allow in development or for admin users
  if (process.env.NODE_ENV === "production") {
    // Add your admin check here
  }

  const config = {
    environment: process.env.NODE_ENV,
    auth0_config: {
      domain: process.env.AUTH0_DOMAIN || "NOT_SET",
      has_mgmt_client_id: !!process.env.AUTH0_MGMT_CLIENT_ID,
      mgmt_client_id_prefix:
        process.env.AUTH0_MGMT_CLIENT_ID?.substring(0, 8) || "NOT_SET",
      audience: process.env.AUTH0_AUDIENCE || "NOT_SET",
    },
  };

  // Test token acquisition
  let tokenTest = { status: "not_tested" };

  try {
    const response = await fetch(
      `https://${process.env.AUTH0_DOMAIN}/oauth/token`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          client_id: process.env.AUTH0_MGMT_CLIENT_ID,
          client_secret: process.env.AUTH0_MGMT_CLIENT_SECRET,
          audience: `https://${process.env.AUTH0_DOMAIN}/api/v2/`,
          grant_type: "client_credentials",
        }),
      }
    );

    const data = await response.json();
    tokenTest = {
      status: response.ok ? "success" : "failed",
      statusCode: response.status,
      error: data.error,
      error_description: data.error_description,
    };
  } catch (error) {
    tokenTest = { status: "error", message: error.message };
  }

  return res.json({ config, tokenTest });
}
```

## Testing Procedures

### Local Testing Script

Create `scripts/test-auth0-m2m.js`:

```javascript
const https = require("https");

async function testAuth0M2M() {
  console.log("🧪 Testing Auth0 M2M Configuration\n");

  const domain = process.env.AUTH0_DOMAIN || "your-domain.auth0.com";
  const clientId = process.env.AUTH0_MGMT_CLIENT_ID || "your-client-id";
  const clientSecret =
    process.env.AUTH0_MGMT_CLIENT_SECRET || "your-client-secret";

  console.log("📋 Configuration:");
  console.log(`  Domain: ${domain}`);
  console.log(`  Client ID: ${clientId.substring(0, 8)}...`);
  console.log(`  Audience: https://${domain}/api/v2/\n`);

  // Test token acquisition
  const tokenData = await getToken(domain, clientId, clientSecret);

  if (tokenData.access_token) {
    console.log("✅ Token acquired successfully!");

    // Test API call
    const users = await testApiCall(domain, tokenData.access_token);
    if (users) {
      console.log("✅ API call successful!");
      console.log(`📊 Found ${users.length} users`);
    }
  } else {
    console.error("❌ Failed to acquire token");
    console.error(`Error: ${tokenData.error}`);
    console.error(`Description: ${tokenData.error_description}`);
  }
}

async function getToken(domain, clientId, clientSecret) {
  // Implementation here
}

async function testApiCall(domain, accessToken) {
  // Implementation here
}

testAuth0M2M().catch(console.error);
```

## Production Deployment

### Pre-Deployment Checklist

- [ ] Test M2M credentials locally
- [ ] Verify correct Auth0 tenant (production)
- [ ] All environment variables set in Vercel
- [ ] Environment variables set for Production environment only
- [ ] No typos or extra spaces in credentials
- [ ] AUTH0_DOMAIN doesn't include https://

### Deployment Steps

1. **Update Vercel Environment Variables**

   - Go to Settings → Environment Variables
   - Update AUTH0_MGMT_CLIENT_ID
   - Update AUTH0_MGMT_CLIENT_SECRET
   - Ensure set for Production only

2. **Force Deployment**

   ```bash
   vercel --prod --force
   ```

3. **Verify Deployment**
   - Check debug endpoint
   - Test actual functionality
   - Monitor Auth0 logs

### Post-Deployment Verification

1. Check Auth0 Logs

   - Dashboard → Monitoring → Logs
   - Look for successful M2M authentications

2. Test Admin Functions
   - User list/search
   - User creation
   - User updates

## Maintenance

### Regular Tasks

1. **Quarterly Review**

   - Review all M2M applications
   - Remove unused applications
   - Check for excessive permissions

2. **Credential Rotation**

   - Rotate secrets every 90 days
   - Test new credentials before deployment
   - Update documentation

3. **Monitoring**
   - Set up alerts for authentication failures
   - Monitor rate limits
   - Track API usage

### Documentation

Keep track of:

- Which M2M app is for which environment
- When credentials were last rotated
- Which team members have access
- Any custom scopes or configurations

## Emergency Procedures

### If Production Auth Fails

1. **Don't Panic** - Your users can still login (this only affects admin functions)

2. **Quick Diagnosis**

   ```bash
   # Test current credentials
   curl -X POST https://YOUR_DOMAIN/oauth/token \
     -H "Content-Type: application/json" \
     -d '{"client_id":"...","client_secret":"...","audience":"...","grant_type":"client_credentials"}'
   ```

3. **Common Fixes**

   - Re-authorize M2M app in Auth0
   - Create new M2M app if needed
   - Force redeploy in Vercel

4. **Rollback Plan**
   - Keep previous working credentials documented
   - Can create new M2M app without affecting existing setup

## Lessons Learned

1. **Always test new credentials before deployment**
2. **Vercel requires redeployment for new environment variables**
3. **M2M authorization can silently fail - always verify**
4. **Keep debug endpoints ready (but secure them properly)**
5. **Document everything - future you will thank you**

## Related Documentation

- [Auth0 M2M Applications Documentation](https://auth0.com/docs/get-started/auth0-overview/create-applications/machine-to-machine-apps)
- [Auth0 Management API Reference](https://auth0.com/docs/api/management/v2)
- [Vercel Environment Variables](https://vercel.com/docs/environment-variables)

---

_Last Updated: [Current Date]_
_Issue Tracking: If you encounter issues not covered here, please update this guide_
