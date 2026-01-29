# VibeCoder Vercel Deployment Checklist

Use this checklist to ensure a smooth deployment of VibeCoder to Vercel.

## Pre-Deployment Tasks

### Code Preparation

- [ ] All changes are committed and pushed to the deployment branch
- [ ] Run linting checks: `npm run lint`
- [ ] Run tests: `npm test`
- [ ] Build locally to verify: `npm run build`
- [ ] Check for any deprecated dependencies
- [ ] Verify package.json build commands
- [ ] Test the Auth0 validation script: `npm run auth0:check`
- [ ] Run security audit: `npm audit`
- [ ] Check bundle size: `npm run analyze` (if configured)

### Environment Variables

- [ ] Create a `.env.production` file with all required variables
- [ ] Verify Auth0 configuration
  - [ ] AUTH0_BASE_URL=https://your-exact-production-domain.us
  - [ ] AUTH0_SECRET is properly set
  - [ ] AUTH0_ISSUER_BASE_URL is correct
  - [ ] AUTH0_CLIENT_ID matches Auth0 application
  - [ ] AUTH0_CLIENT_SECRET matches Auth0 application
- [ ] Verify Stripe configuration
  - [ ] STRIPE*SECRET_KEY=sk_live*... (live key, not test)
  - [ ] STRIPE*PUBLISHABLE_KEY=pk_live*... (live key, not test)
  - [ ] STRIPE*WEBHOOK_SECRET=whsec*... (production webhook)
  - [ ] NEXT*PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_live*... (live key, not test)
- [ ] Verify database connection string
  - [ ] DATABASE_URL=postgresql://... (production database)
- [ ] Check for any new environment variables added since last deployment

### Database

- [ ] Run database migrations locally to verify: `npm run migrate:dev`
- [ ] Backup production database (if applicable)
- [ ] Verify database user permissions
- [ ] Check connection pooling configuration (for Neon or other providers)
- [ ] Verify database SSL configuration

### External Services

- [ ] Update Auth0 application settings with production URLs
  - [ ] Allowed Callback URLs: https://your-production-domain.us/api/auth/callback
  - [ ] Allowed Logout URLs: https://your-production-domain.us
  - [ ] Allowed Web Origins: https://your-production-domain.us
- [ ] Update Stripe webhook endpoints
  - [ ] Endpoint URL: https://your-production-domain.us/api/webhooks/stripe
  - [ ] Verify correct events are configured
  - [ ] Test webhook delivery with Stripe CLI if possible
- [ ] Verify MailChimp API key and list ID
- [ ] Check any other third-party integrations

### Security Configuration

- [ ] Configure security headers in next.config.js
- [ ] Set up Content Security Policy (CSP)
- [ ] Configure Web Application Firewall (WAF) in Vercel
- [ ] Enable rate limiting for API routes
- [ ] Set up DDoS protection
- [ ] Configure bot protection

### Local Testing

- [ ] Test authentication flow locally
- [ ] Verify subscription page works
- [ ] Test VibeCoder Stack pages require subscription
- [ ] Test print functionality on VibeCoder Stack page
- [ ] Confirm all Auth0 routes work (/auth/login, /auth/logout)
- [ ] Test locally with production-like data: `npm run build && npm start`

## Deployment Steps

### Initial Setup (First Time Only)

- [ ] Connect GitHub repository to Vercel
- [ ] Configure build settings:
  - [ ] Build Command: `npm run build:vercel`
  - [ ] Output Directory: `.next`
  - [ ] Install Command: `npm ci`
- [ ] Set environment variables in Vercel dashboard
- [ ] Configure project settings:
  - [ ] Framework preset: Next.js
  - [ ] Node.js version: 18.x (or latest LTS)
  - [ ] Include source maps: Yes (for better error tracking)

### Deployment

- [ ] Push changes to deployment branch
- [ ] Monitor deployment progress in Vercel dashboard
- [ ] Check build logs for errors
- [ ] Verify deployment URL is accessible
- [ ] Check for any warnings in the build output

### Domain Configuration (First Time Only)

- [ ] Add custom domain in Vercel settings
- [ ] Configure DNS settings as per Vercel instructions
- [ ] Verify domain is properly connected
- [ ] Check SSL certificate is provisioned
- [ ] Test custom domain accessibility

## Post-Deployment Verification

### Basic Functionality

- [ ] Home page loads correctly
- [ ] Navigation works as expected
- [ ] Static assets (images, CSS, JS) load properly
- [ ] Responsive design works on different screen sizes
- [ ] Check console for any JavaScript errors

### Authentication

- [ ] Sign up process works
- [ ] Login works
- [ ] Logout works
- [ ] Protected routes require authentication
- [ ] User profile information displays correctly
- [ ] Confirm all Auth0 routes work (/auth/login, /auth/logout)
- [ ] Test social login providers (if configured)

### Subscription Management

- [ ] Subscription page loads correctly
- [ ] Payment process works (with live keys)
- [ ] Subscription tier access controls work
- [ ] Webhooks are received and processed correctly
- [ ] Test subscription flow end-to-end (Login → Subscribe → Access VibeCoder Stack pages)
- [ ] Test with different subscription tiers
- [ ] Verify subscription management UI works correctly
- [ ] Test subscription cancellation flow

### Critical Features

- [ ] VibeCoder Stack pages are accessible
- [ ] Process pages are accessible
- [ ] Blog posts are accessible
- [ ] Product pages are accessible
- [ ] Test print functionality on VibeCoder Stack page
- [ ] Verify VibeCoder Stack access control works
- [ ] Test process pages authentication
- [ ] Test admin functionality (if applicable)

### Performance

- [ ] Page load times are acceptable (< 3 seconds)
- [ ] API response times are acceptable (< 1 second)
- [ ] No console errors in browser
- [ ] Core Web Vitals are good (use Lighthouse or PageSpeed Insights)
  - [ ] Largest Contentful Paint (LCP): < 2.5 seconds
  - [ ] First Input Delay (FID): < 100 milliseconds
  - [ ] Cumulative Layout Shift (CLS): < 0.1

### Security

- [ ] SSL is working (HTTPS)
- [ ] Authentication is secure
- [ ] API endpoints are properly protected
- [ ] Environment variables are not exposed to client
- [ ] Content Security Policy is working
- [ ] No sensitive data is logged to console
- [ ] Security headers are properly configured

## Monitoring Setup

- [ ] Enable Vercel Analytics
- [ ] Configure performance monitoring
- [ ] Set up error tracking (Sentry or similar)
- [ ] Configure uptime monitoring
- [ ] Set up alerts for critical issues
- [ ] Enable logging for security events

## Monitoring During First 24 Hours

- [ ] Monitor Vercel logs in real-time
- [ ] Check Auth0 logs for authentication issues
- [ ] Verify webhook delivery in Stripe dashboard
- [ ] Monitor database performance
- [ ] Check for any error reports from users
- [ ] Monitor API response times
- [ ] Check for any security alerts

## Rollback Plan

If critical issues are found after deployment:

1. **Immediate Issues**:

   - [ ] Roll back to previous deployment in Vercel dashboard
   - [ ] Verify rollback was successful

2. **Database Issues**:

   - [ ] Restore from backup if database changes caused problems
   - [ ] Verify application works with restored database

3. **Documentation**:
   - [ ] Document the issue and resolution
   - [ ] Update deployment checklist if needed

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

## Final Steps

- [ ] Notify team of successful deployment
- [ ] Monitor application for 24 hours post-deployment
- [ ] Check error logs for any unexpected issues
- [ ] Update documentation if any deployment process changes were made
- [ ] Schedule post-deployment review meeting

## Deployment Information

**Deployment Date**: ******\_\_\_\_******

**Deployed By**: ******\_\_\_\_******

**Vercel Project URL**: ******\_\_\_\_******

**Production URL**: ******\_\_\_\_******

**Deployment Duration**: ******\_\_\_\_******

**Issues Encountered**: ******\_\_\_\_******

**Resolution Steps**: ******\_\_\_\_******
