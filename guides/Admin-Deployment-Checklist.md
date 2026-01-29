# Admin User and Subscription Management Deployment Checklist

This checklist ensures a smooth deployment of the Admin User and Subscription Management features to production.

## Pre-Deployment Verification

### Database

- [x] Database migrations are applied and verified
- [x] Database schema includes all required tables and views
- [x] Subscription tiers data is populated
- [x] Database tests are passing

### Environment Variables

- [ ] Set `NEXT_PUBLIC_APP_URL` to the production URL in Vercel
- [ ] Set `NODE_ENV=production` in Vercel
- [ ] Verify Auth0 variables are correctly configured for production:
  - [ ] `AUTH0_BASE_URL` matches production URL exactly
  - [ ] `AUTH0_ISSUER_BASE_URL` points to production Auth0 tenant
  - [ ] `AUTH0_CLIENT_ID` and `AUTH0_CLIENT_SECRET` are set
  - [ ] `AUTH0_SECRET` is securely generated
- [ ] Verify Stripe variables are correctly configured for production:
  - [ ] `STRIPE_SECRET_KEY` uses live key (sk*live*\*)
  - [ ] `STRIPE_PUBLISHABLE_KEY` uses live key (pk*live*\*)
  - [ ] `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` uses live key (pk*live*\*)
  - [ ] `STRIPE_WEBHOOK_SECRET` is set to production webhook signing secret
  - [ ] Price IDs are set for all subscription tiers
- [ ] `CRON_API_KEY` is securely generated

### Auth0 Configuration

- [ ] Auth0 application settings are updated for production:
  - [ ] Allowed Callback URLs: `https://your-production-domain.us/api/auth/callback`
  - [ ] Allowed Logout URLs: `https://your-production-domain.us`
  - [ ] Allowed Web Origins: `https://your-production-domain.us`
- [ ] Auth0 roles and permissions are configured
- [ ] Auth0 rules and actions are properly set up

### Stripe Configuration

- [ ] Webhook endpoint is configured in Stripe dashboard: `https://your-domain.us/api/webhooks/stripe`
- [ ] Required webhook events are selected:
  - [ ] `checkout.session.completed`
  - [ ] `customer.subscription.created`
  - [ ] `customer.subscription.updated`
  - [ ] `customer.subscription.deleted`
  - [ ] `invoice.payment_succeeded`
  - [ ] `invoice.payment_failed`
- [ ] Stripe is in live mode (not test mode)

## Deployment Process

### Code Preparation

- [x] All changes are committed to the feature branch
- [ ] Feature branch is merged to main/master branch
- [ ] Tests are passing in CI pipeline

### Vercel Deployment

- [ ] Deploy to staging environment first
- [ ] Verify functionality in staging
- [ ] Deploy to production environment
- [ ] Configure Vercel project settings:
  - [ ] Build Command: `npm run build:vercel`
  - [ ] Output Directory: `.next`
  - [ ] Install Command: `npm ci`
- [ ] Enable Vercel Analytics
- [ ] Configure Vercel Advanced Protection

### Security Configuration

- [ ] Enable Web Application Firewall (WAF) in Vercel
- [ ] Configure rate limiting rules
- [ ] Enable bot protection
- [ ] Verify security headers are properly set

## Post-Deployment Verification

### Basic Functionality

- [ ] Home page loads correctly
- [ ] Navigation works as expected
- [ ] Static assets load properly
- [ ] Responsive design works on different screen sizes

### Authentication

- [ ] Sign up process works
- [ ] Login works
- [ ] Logout works
- [ ] Protected routes require authentication
- [ ] User profile information displays correctly

### Admin Features

- [ ] Admin dashboard is accessible to admin users only
- [ ] User management features work correctly
- [ ] Subscription management features work correctly
- [ ] Admin actions are properly logged

### Subscription Management

- [ ] Subscription page loads correctly
- [ ] Payment process works with live keys
- [ ] Subscription tier access controls work
- [ ] Webhooks are received and processed correctly
- [ ] Test complete subscription flow end-to-end

### CRON Jobs

- [ ] Set up production CRON job for expired subscriptions:
  ```
  0 0 * * * curl -X POST -H "Authorization: Bearer YOUR_CRON_API_KEY" https://yourdomain.com/api/cron/check-expired-subscriptions
  ```
- [ ] Set up webhook monitoring CRON job:
  ```
  0 */6 * * * curl -X POST -H "Authorization: Bearer YOUR_CRON_API_KEY" https://yourdomain.com/api/cron/monitor-webhooks
  ```

## Monitoring and Alerts

- [ ] Set up alerts for webhook failures
- [ ] Set up alerts for payment failures
- [ ] Configure logging for subscription events
- [ ] Set up monitoring for failed webhook deliveries

## Rollback Plan

If issues arise after deployment:

1. Identify the specific component causing problems
2. For webhook issues:
   - Check logs for error details
   - Verify webhook signature and configuration
   - Use Stripe CLI to resend events if necessary
3. For payment issues:
   - Check Stripe Dashboard for payment logs
   - Verify checkout session configuration
4. For database issues:
   - Restore from most recent backup if necessary
5. If necessary, roll back to previous version:
   - In Vercel dashboard, go to "Deployments"
   - Find the last working deployment
   - Click the three dots menu and select "Promote to Production"
   - Verify the rollback was successful
