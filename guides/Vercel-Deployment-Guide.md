# VibeCoder Vercel Deployment Guide

This guide provides detailed instructions for deploying VibeCoder to Vercel, including configuration, security, and best practices.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Environment Variables](#environment-variables)
4. [Security Configuration](#security-configuration)
5. [Auth0 Integration](#auth0-integration)
6. [Stripe Integration](#stripe-integration)
7. [Database Configuration](#database-configuration)
8. [Deployment Process](#deployment-process)
9. [Post-Deployment Verification](#post-deployment-verification)
10. [Monitoring and Maintenance](#monitoring-and-maintenance)
11. [Rollback Procedures](#rollback-procedures)
12. [Troubleshooting](#troubleshooting)

## Prerequisites

Before beginning the deployment process, ensure you have:

- A [Vercel account](https://vercel.com/signup) with appropriate team access
- Access to the VibeCoder GitHub repository
- Admin access to the Auth0 tenant
- Admin access to the Stripe dashboard
- PostgreSQL database credentials (Neon or other provider)
- Domain name configuration access (if using a custom domain)

## Initial Setup

### Connecting GitHub Repository to Vercel

1. Log in to Vercel and click "Add New..." > "Project"
2. Select the VibeCoder repository
3. Choose the "Next.js" framework preset
4. Configure build settings:
   - Build Command: `npm run build:vercel`
   - Output Directory: `.next`
   - Install Command: `npm ci`
5. Click "Deploy"

### Verifying Build Scripts

Ensure your `package.json` has the following scripts:

```json
{
  "scripts": {
    "build:vercel": "npm run auth0:check && next build",
    "auth0:check": "node scripts/validate-auth0-config.js"
  }
}
```

Test the validation script locally before deployment:

```bash
npm run auth0:check  # Should pass locally
```

## Environment Variables

### Core Variables

```
NODE_ENV=production
NEXT_PUBLIC_APP_URL=https://your-domain.us
```

### Auth0 Configuration

```
AUTH0_SECRET=your-long-secret-value
AUTH0_BASE_URL=https://your-exact-production-domain.us
AUTH0_ISSUER_BASE_URL=https://your-tenant.auth0.com
AUTH0_CLIENT_ID=your-client-id
AUTH0_CLIENT_SECRET=your-client-secret
```

⚠️ **Critical**: The `AUTH0_BASE_URL` must match your production domain exactly. Do not use VERCEL_URL for this variable.

### Database Configuration

```
DATABASE_URL=postgresql://username:password@host:port/database
SHADOW_DATABASE_URL=postgresql://username:password@host:port/shadow_database
```

### Stripe Configuration

```
STRIPE_SECRET_KEY=sk_live_your_key
STRIPE_PUBLISHABLE_KEY=pk_live_your_key
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_live_your_key
```

⚠️ **Important**: Use live keys for production, not test keys.

### Additional Variables

```
SKIP_AUTH0_CHECK=true  # Only during initial deployment troubleshooting
MAILCHIMP_API_KEY=your-mailchimp-api-key
MAILCHIMP_SERVER_PREFIX=us1
MAILCHIMP_LIST_ID=your-audience-id
```

## Security Configuration

### Web Application Firewall (WAF)

Vercel provides Advanced Protection features that should be enabled for production:

1. Go to Vercel dashboard > Project Settings > Security
2. Enable "Advanced Protection"
3. Configure rate limiting rules appropriate for your application
4. Enable bot protection with appropriate challenge modes

You can also add security headers in your `next.config.js`:

```javascript
// next.config.js
module.exports = {
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: [
          {
            key: "X-Content-Type-Options",
            value: "nosniff",
          },
          {
            key: "X-Frame-Options",
            value: "DENY",
          },
          {
            key: "X-XSS-Protection",
            value: "1; mode=block",
          },
          {
            key: "Referrer-Policy",
            value: "strict-origin-when-cross-origin",
          },
          {
            key: "Content-Security-Policy",
            value: `
              default-src 'self';
              script-src 'self' 'unsafe-inline' 'unsafe-eval' https://js.stripe.com https://*.auth0.com https://cdn.auth0.com;
              style-src 'self' 'unsafe-inline' https://fonts.googleapis.com;
              font-src 'self' https://fonts.gstatic.com data:;
              img-src 'self' data: https://*.auth0.com https://*.stripe.com;
              connect-src 'self' https://*.auth0.com https://api.stripe.com https://*.neon.tech;
              frame-src 'self' https://js.stripe.com https://*.auth0.com;
              object-src 'none';
              base-uri 'self';
              form-action 'self';
              frame-ancestors 'self';
              block-all-mixed-content;
            `
              .replace(/\s+/g, " ")
              .trim(),
          },
          {
            key: "Permissions-Policy",
            value: "camera=(), microphone=(), geolocation=()",
          },
        ],
      },
    ];
  },
};
```

### DDoS Protection

Vercel provides built-in DDoS protection through their Edge Network. To maximize protection:

1. Use Vercel's Edge Functions where appropriate
2. Enable Vercel Analytics to monitor traffic patterns
3. Configure appropriate rate limiting for API routes
4. Use Vercel's Edge Middleware for additional protection

## Auth0 Integration

Auth0 requires special attention when deploying to Vercel:

1. **Update Auth0 Application Settings**:

   - Allowed Callback URLs: `https://your-production-domain.us/api/auth/callback`
   - Allowed Logout URLs: `https://your-production-domain.us`
   - Allowed Web Origins: `https://your-production-domain.us`

2. **Auth0 Environment Variables**:

   - Ensure AUTH0_BASE_URL matches your production URL exactly
   - Do not rely on VERCEL_URL for AUTH0_BASE_URL in production

3. **Auth0 Rules and Actions**:
   - Verify any custom Auth0 rules are properly configured
   - Test login flow end-to-end before deploying

## Stripe Integration

1. **Update Webhook Endpoints**:

   - In the Stripe dashboard, update the webhook endpoint to: `https://your-domain.us/api/webhooks/stripe`
   - Ensure the webhook is configured for the correct events:
     - `checkout.session.completed`
     - `customer.subscription.created`
     - `customer.subscription.updated`
     - `customer.subscription.deleted`
     - `invoice.payment_succeeded`
     - `invoice.payment_failed`

2. **Test Mode vs. Live Mode**:
   - Use test keys for development/preview environments
   - Use live keys only for production environment
   - Verify webhook delivery in Stripe dashboard during deployment

## Database Configuration

1. **Connection Pooling**:

   - For Neon or other PostgreSQL providers, enable connection pooling
   - Update the DATABASE_URL to use the connection pooling endpoint

2. **Database Migrations**:

   - Run migrations before or during deployment:
     ```bash
     npm run migrate:deploy
     ```
   - Or add a build step in package.json to run migrations during deployment

3. **Database Backup**:
   - Create a backup of the production database before major deployments
   - Verify the backup is successful and can be restored if needed

## Deployment Process

### Continuous Deployment

1. Set up GitHub Actions for CI/CD:

```yaml
# .github/workflows/ci.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: "18"
          cache: "npm"

      - name: Install dependencies
        run: npm ci

      - name: Run linting
        run: npm run lint

      - name: Run tests
        run: npm test

      - name: Run security audit
        run: npm audit --audit-level=high

  deploy-preview:
    if: github.event_name == 'pull_request'
    needs: validate
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Deploy Preview
        uses: vercel/action@v3
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          vercel-args: "--preview"

  deploy-production:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    needs: validate
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Deploy to Production
        uses: vercel/action@v3
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          vercel-args: "--prod"
```

### Manual Deployment

To deploy manually from the Vercel dashboard:

1. Go to your project in the Vercel dashboard
2. Click "Deployments" tab
3. Click "Deploy" button
4. Select the branch to deploy
5. Monitor the deployment logs

### Domain Configuration

1. In Vercel, go to Settings > Domains
2. Add your domain and follow the DNS configuration instructions
3. Verify the domain
4. Ensure SSL is properly provisioned

## Post-Deployment Verification

### Basic Functionality

- Home page loads correctly
- Navigation works as expected
- Static assets (images, CSS, JS) load properly
- Responsive design works on different screen sizes

### Authentication

- Sign up process works
- Login works
- Logout works
- Protected routes require authentication
- User profile information displays correctly
- Confirm all Auth0 routes work (/auth/login, /auth/logout)

### Subscription Management

- Subscription page loads correctly
- Payment process works (with live keys)
- Subscription tier access controls work
- Webhooks are received and processed correctly
- Test subscription flow end-to-end (Login → Subscribe → Access VibeCoder Stack pages)
- Test with different subscription tiers

### Critical Features

- VibeCoder Stack pages are accessible
- Process pages are accessible
- Blog posts are accessible
- Product pages are accessible
- Test print functionality on VibeCoder Stack page
- Verify VibeCoder Stack access control works
- Test process pages authentication

### Automated Smoke Tests

Create a smoke test script to verify critical functionality:

```javascript
// scripts/smoke-test.js
const axios = require("axios");
const assert = require("assert");

async function runSmokeTests() {
  const baseUrl = process.env.SMOKE_TEST_URL || "https://your-domain.us";
  console.log(`Running smoke tests against ${baseUrl}`);

  try {
    // Test 1: Homepage loads
    const homeResponse = await axios.get(baseUrl);
    assert.strictEqual(homeResponse.status, 200);
    console.log("✓ Homepage loads successfully");

    // Test 2: API health check
    const healthResponse = await axios.get(`${baseUrl}/api/health`);
    assert.strictEqual(healthResponse.status, 200);
    assert.strictEqual(healthResponse.data.status, "healthy");
    console.log("✓ API health check passed");

    // Add more critical path tests

    console.log("All smoke tests passed!");
    process.exit(0);
  } catch (error) {
    console.error("Smoke tests failed:", error);
    process.exit(1);
  }
}

runSmokeTests();
```

## Monitoring and Maintenance

### Performance Monitoring

1. Enable Vercel Analytics:

   - Go to Vercel dashboard > Project Settings > Analytics
   - Enable "Web Vitals"
   - Configure alerts for performance degradation

2. Set up external monitoring:
   - Configure uptime monitoring with a service like Pingdom or UptimeRobot
   - Set up alerts for service disruptions

### Security Monitoring

1. Monitor Auth0 logs for authentication issues
2. Check Stripe dashboard for webhook delivery and payment issues
3. Set up logging for security events
4. Monitor for unusual traffic patterns or authentication attempts

### Regular Maintenance

1. Update dependencies regularly
2. Run security audits
3. Review and rotate secrets periodically
4. Test disaster recovery procedures

## Rollback Procedures

### Quick Rollback

If critical issues are found after deployment:

1. In Vercel dashboard, go to "Deployments"
2. Find the last working deployment
3. Click the three dots menu and select "Promote to Production"
4. Verify the rollback was successful

### Database Rollback

If database changes caused issues:

1. Restore from backup if database changes caused problems
2. Verify application works with restored database
3. Document the issue and resolution

## Troubleshooting

### Common Issues

1. **Build Failures**:

   - Check build logs for specific errors
   - Ensure all dependencies are properly installed
   - Verify environment variables are correctly set

2. **Auth0 Authentication Issues**:

   - Verify AUTH0_BASE_URL matches your production URL exactly
   - Check Auth0 logs for specific error messages
   - Ensure callback URLs are correctly configured
   - Look for "MIDDLEWARE_INVOCATION_FAILED" errors related to Auth0

3. **Database Connection Issues**:

   - Verify DATABASE_URL is correct and accessible from Vercel
   - Check for connection limits or firewall restrictions
   - Ensure the database user has appropriate permissions

4. **Stripe Webhook Issues**:
   - Verify the webhook endpoint is correctly configured
   - Check that the STRIPE_WEBHOOK_SECRET is correct
   - Monitor Stripe dashboard for webhook delivery failures

### Debug Mode

To enable debug mode for troubleshooting:

1. Add the following environment variables:
   ```
   DEBUG=true
   AUTH0_DEBUG=true
   ```
2. Check Vercel function logs for detailed error messages

## Vercel CLI Reference

Use these commands to manage your Vercel deployment from the command line:

### Authentication and Setup

```bash
# Login to Vercel CLI
vercel login

# Initialize a project (if not already connected to Vercel)
vercel
```

### Deployment Commands

```bash
# Deploy to preview environment
vercel

# Deploy to production
vercel --prod

# List all deployments
vercel ls

# Inspect a specific deployment
vercel inspect [deployment-id]
```

### Environment Variables

```bash
# Pull environment variables to local .env file
vercel env pull

# Add a new environment variable
vercel env add [name]

# Remove an environment variable
vercel env rm [name]
```

### Domain and Rollback Management

```bash
# List domains
vercel domains ls

# Add a domain
vercel domains add [domain-name]

# Rollback to a previous deployment
vercel alias set [deployment-url] [your-domain.us]
```

For detailed Vercel CLI documentation, refer to the [official Vercel CLI documentation](https://vercel.com/docs/cli).

## Additional Resources

- [Vercel Documentation](https://vercel.com/docs)
- [Next.js on Vercel](https://vercel.com/solutions/nextjs)
- [Auth0 Next.js SDK Documentation](https://auth0.github.io/nextjs-auth0/modules.html)
- [Stripe Documentation](https://stripe.com/docs)
- [VibeCoder Deployment Checklist](./Vercel-Deployment-Checklist.md)
