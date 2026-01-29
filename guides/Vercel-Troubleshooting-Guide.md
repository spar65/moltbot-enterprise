# Vercel Deployment Troubleshooting Guide

This guide provides solutions for common issues encountered when deploying VibeCoder to Vercel, with a focus on Auth0, Stripe, and other integrations.

## Table of Contents

1. [Build Failures](#build-failures)
2. [Auth0 Integration Issues](#auth0-integration-issues)
3. [Stripe Integration Issues](#stripe-integration-issues)
4. [Database Connection Issues](#database-connection-issues)
5. [Environment Variable Problems](#environment-variable-problems)
6. [Performance Issues](#performance-issues)
7. [Debugging Techniques](#debugging-techniques)
8. [Common Error Codes](#common-error-codes)

## Build Failures

### Failed Dependency Installation

**Symptoms:**

- Build fails during the dependency installation phase
- Error messages about missing packages or version conflicts

**Solutions:**

1. Check for incompatible package versions in package.json
2. Verify Node.js version in Vercel settings matches your local environment
3. Clear Vercel cache and redeploy:
   ```bash
   vercel deploy --force
   ```
4. Check for private packages that require authentication

### TypeScript Compilation Errors

**Symptoms:**

- Build fails with TypeScript errors
- Error messages about type mismatches or missing types

**Solutions:**

1. Run `tsc --noEmit` locally to catch errors before deployment
2. Check for missing type definitions (`@types/*` packages)
3. Consider using `typescript.ignoreBuildErrors: true` in next.config.js temporarily to diagnose other issues
4. Update tsconfig.json to match your environment

### Out of Memory During Build

**Symptoms:**

- Build fails with "JavaScript heap out of memory" error
- Build times out without specific error

**Solutions:**

1. Optimize your build process to use less memory
2. Add a .npmrc file with increased memory limit:
   ```
   node_options=--max_old_space_size=4096
   ```
3. Consider splitting your application into smaller chunks
4. Use dynamic imports to reduce initial bundle size

## Auth0 Integration Issues

### MIDDLEWARE_INVOCATION_FAILED Errors

**Symptoms:**

- Authentication middleware fails
- Error message contains "MIDDLEWARE_INVOCATION_FAILED"
- Users can't log in or access protected routes

**Solutions:**

1. **Check AUTH0_BASE_URL**: This is the most common issue. Ensure it matches your production domain exactly:

   ```
   AUTH0_BASE_URL=https://your-exact-production-domain.us
   ```

   Do NOT use VERCEL_URL for this variable.

2. **Verify Auth0 Application Settings**:

   - Allowed Callback URLs: `https://your-production-domain.us/api/auth/callback`
   - Allowed Logout URLs: `https://your-production-domain.us`
   - Allowed Web Origins: `https://your-production-domain.us`

3. **Check Auth0 Logs**:

   - Go to Auth0 Dashboard > Logs
   - Look for failed authentication attempts
   - Check for CORS or redirect URI errors

4. **Enable Debug Mode**:
   - Add `AUTH0_DEBUG=true` to environment variables
   - Check Vercel function logs for detailed error messages

### Session Issues

**Symptoms:**

- Users are repeatedly asked to log in
- Session doesn't persist between page loads
- Random logouts occur

**Solutions:**

1. **Check Cookie Settings**:

   - Ensure cookies are being set correctly
   - Check for secure and SameSite cookie attributes

2. **Verify AUTH0_SECRET**:

   - Ensure AUTH0_SECRET is set and is at least 32 characters long
   - This secret should be consistent across deployments

3. **Check for Cookie Size Limits**:

   - Large session data can exceed cookie size limits
   - Reduce the amount of data stored in the session

4. **Verify HTTPS**:
   - Auth0 requires HTTPS for secure cookies
   - Check that your domain is properly configured with SSL

### Role-Based Access Issues

**Symptoms:**

- Users can log in but can't access role-protected routes
- Admin users don't have proper permissions

**Solutions:**

1. **Check Role Assignment in Auth0**:

   - Verify roles are correctly assigned to users in Auth0
   - Check that role information is included in the JWT token

2. **Verify Role Handling Code**:

   - Check that your application correctly extracts and uses role information
   - Verify middleware that checks roles is working correctly

3. **Inspect JWT Token**:
   - Use jwt.io to decode and inspect tokens
   - Verify that roles or permissions are included in the token

## Stripe Integration Issues

### Webhook Delivery Failures

**Symptoms:**

- Subscriptions aren't being updated after payment
- Stripe dashboard shows failed webhook deliveries
- Payment succeeds but user doesn't get access

**Solutions:**

1. **Check Webhook URL**:

   - Verify the webhook endpoint is correctly configured in Stripe:
     `https://your-domain.us/api/webhooks/stripe`
   - Ensure the URL is publicly accessible

2. **Verify Webhook Secret**:

   - Check that STRIPE_WEBHOOK_SECRET matches the secret in Stripe dashboard
   - Regenerate the webhook secret if necessary

3. **Test with Stripe CLI**:

   ```bash
   stripe listen --forward-to localhost:3000/api/webhooks/stripe
   ```

4. **Check Event Types**:
   - Verify that you're subscribed to the necessary event types:
     - `checkout.session.completed`
     - `customer.subscription.created`
     - `customer.subscription.updated`
     - `invoice.payment_succeeded`

### Payment Processing Issues

**Symptoms:**

- Users can't complete checkout
- Stripe errors during payment process
- Checkout session creation fails

**Solutions:**

1. **Check API Keys**:

   - Verify STRIPE_SECRET_KEY is correct and is a live key for production
   - Ensure NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY is correctly set

2. **Verify Price IDs**:

   - Ensure price IDs in your code match those in Stripe dashboard
   - Check that products and prices are active

3. **Check for Currency Mismatches**:

   - Ensure the currency in your application matches Stripe settings

4. **Enable Detailed Logging**:
   - Add more detailed logging to your Stripe integration
   - Check Stripe dashboard for specific error messages

### Subscription Status Sync Issues

**Symptoms:**

- User's subscription status doesn't update in your application
- Database doesn't reflect current subscription state

**Solutions:**

1. **Check Webhook Processing**:

   - Verify that webhook events are being processed correctly
   - Add logging to webhook handler to track event processing

2. **Verify Database Updates**:

   - Check that subscription data is being properly stored in your database
   - Verify queries that check subscription status

3. **Implement Manual Sync**:
   - Create an admin endpoint to manually sync subscription data
   - Use Stripe API to fetch current subscription status

## Database Connection Issues

### Connection Failures

**Symptoms:**

- API routes fail with database connection errors
- Error messages about connection timeouts or refused connections

**Solutions:**

1. **Check Connection String**:

   - Verify DATABASE_URL is correctly formatted
   - Ensure database server is accessible from Vercel's network

2. **Connection Pooling**:

   - For Neon or other PostgreSQL providers, enable connection pooling
   - Update the DATABASE_URL to use the connection pooling endpoint

3. **Check Firewall Rules**:

   - Ensure your database allows connections from Vercel's IP ranges
   - Add Vercel's IP ranges to your database firewall allowlist

4. **Verify SSL Configuration**:
   - Most cloud databases require SSL connections
   - Add `?sslmode=require` to your PostgreSQL connection string if needed

### Query Performance Issues

**Symptoms:**

- API routes are slow to respond
- Database queries timeout

**Solutions:**

1. **Optimize Queries**:

   - Add appropriate indexes to frequently queried columns
   - Review and optimize slow queries

2. **Connection Pooling**:

   - Ensure you're using connection pooling to avoid connection overhead
   - Check pool size configuration

3. **Serverless Function Optimization**:
   - Use connection pooling that works well with serverless functions
   - Consider using Edge functions for simple database queries

## Environment Variable Problems

### Missing Environment Variables

**Symptoms:**

- Application fails with "Cannot read property of undefined" errors
- Features dependent on environment variables don't work

**Solutions:**

1. **Check Vercel Dashboard**:

   - Verify all required environment variables are set in Vercel dashboard
   - Check for typos in variable names

2. **Environment Scope**:

   - Ensure variables are set for the correct environment (Production, Preview, Development)
   - Check that variables are set at the project level, not just locally

3. **Verify Next.js Configuration**:
   - Check that variables used client-side are prefixed with `NEXT_PUBLIC_`
   - Verify that your code correctly accesses environment variables

### Environment Variable Validation

**Symptoms:**

- Build fails with environment variable validation errors
- Application crashes on startup due to missing configuration

**Solutions:**

1. **Run Validation Script Locally**:

   ```bash
   npm run auth0:check
   ```

2. **Temporarily Bypass Validation**:

   - Add `SKIP_AUTH0_CHECK=true` to environment variables
   - Remove after diagnosing other issues

3. **Check for Required Variables**:
   - Review your validation script to understand which variables are required
   - Ensure all required variables are properly set

## Performance Issues

### Slow Page Loads

**Symptoms:**

- Pages take a long time to load
- Time to First Byte (TTFB) is high
- Poor Core Web Vitals scores

**Solutions:**

1. **Enable Vercel Analytics**:

   - Go to Vercel dashboard > Project Settings > Analytics
   - Enable "Web Vitals" to monitor performance

2. **Optimize Images**:

   - Use Next.js Image component with proper optimization
   - Consider using a CDN for large media files

3. **Implement Caching**:

   - Add appropriate caching headers to static assets
   - Use SWR or React Query for data fetching with caching

4. **Use Edge Functions**:
   - Move critical API routes to Edge Functions for lower latency
   - Implement proper caching strategies

### High Serverless Function Duration

**Symptoms:**

- API routes take a long time to respond
- Vercel dashboard shows high function duration

**Solutions:**

1. **Optimize Database Queries**:

   - Review and optimize slow database queries
   - Add appropriate indexes

2. **Reduce External API Calls**:

   - Cache results of external API calls
   - Use webhooks instead of polling where possible

3. **Implement Timeouts**:

   - Add timeouts to external API calls
   - Use circuit breakers to handle failures gracefully

4. **Consider Edge Functions**:
   - Move suitable API routes to Edge Functions
   - Use Edge Middleware for authentication and simple transformations

## Debugging Techniques

### Enabling Debug Mode

To enable detailed debugging:

1. **Add Debug Environment Variables**:

   ```
   DEBUG=true
   AUTH0_DEBUG=true
   ```

2. **Check Function Logs**:

   - Go to Vercel dashboard > Project > Deployments > [Deployment] > Functions
   - Click on a function to see detailed logs

3. **Add Structured Logging**:
   ```typescript
   console.log(
     JSON.stringify({
       level: "debug",
       message: "Processing webhook",
       event: event.type,
       timestamp: new Date().toISOString(),
     })
   );
   ```

### Local Testing with Vercel Environment

Test your application locally with Vercel environment variables:

1. **Pull Environment Variables**:

   ```bash
   vercel env pull .env.local
   ```

2. **Run Development Server**:

   ```bash
   npm run dev
   ```

3. **Test Production Build Locally**:
   ```bash
   npm run build && npm start
   ```

### Vercel CLI Debugging

Use Vercel CLI for debugging:

1. **Check Deployment Status**:

   ```bash
   vercel ls
   ```

2. **Inspect Deployment**:

   ```bash
   vercel inspect [deployment-id]
   ```

3. **View Logs**:
   ```bash
   vercel logs [deployment-url]
   ```

## Common Error Codes

### HTTP Status Codes

| Code | Description           | Possible Causes                              |
| ---- | --------------------- | -------------------------------------------- |
| 401  | Unauthorized          | Invalid Auth0 configuration, expired tokens  |
| 403  | Forbidden             | User doesn't have required permissions       |
| 404  | Not Found             | Route doesn't exist, resource not found      |
| 429  | Too Many Requests     | Rate limiting, excessive API calls           |
| 500  | Internal Server Error | Unhandled exceptions, database errors        |
| 502  | Bad Gateway           | Upstream service (Auth0, Stripe) unavailable |
| 504  | Gateway Timeout       | Function timeout, slow database queries      |

### Auth0 Error Codes

| Code                 | Description          | Solution                                |
| -------------------- | -------------------- | --------------------------------------- |
| invalid_redirect_uri | Invalid redirect URI | Check Auth0 application settings        |
| consent_required     | Consent required     | Add prompt=consent to Auth0 login URL   |
| login_required       | Login required       | User session expired, redirect to login |
| invalid_token        | Invalid token        | Check AUTH0_SECRET and token validation |

### Stripe Error Codes

| Code                    | Description             | Solution                               |
| ----------------------- | ----------------------- | -------------------------------------- |
| authentication_required | Authentication required | 3D Secure authentication needed        |
| card_declined           | Card declined           | Customer needs to use a different card |
| expired_card            | Expired card            | Customer needs to update card details  |
| incorrect_cvc           | Incorrect CVC           | Customer entered wrong CVC             |
| processing_error        | Processing error        | Temporary issue, retry payment         |

## Additional Resources

- [Vercel Documentation](https://vercel.com/docs)
- [Next.js Deployment Documentation](https://nextjs.org/docs/deployment)
- [Auth0 Next.js SDK Documentation](https://auth0.github.io/nextjs-auth0/modules.html)
- [Stripe Documentation](https://stripe.com/docs)
- [VibeCoder Deployment Guide](./Vercel-Deployment-Guide.md)
- [VibeCoder Deployment Checklist](./Vercel-Deployment-Checklist.md)
