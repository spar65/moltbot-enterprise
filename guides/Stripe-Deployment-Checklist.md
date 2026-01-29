# Stripe Integration Deployment Checklist

This checklist ensures a smooth transition of the Stripe integration from development to production for the VibeCoder platform.

## Pre-Deployment Checks

### Environment Variables

- [ ] Verify `STRIPE_SECRET_KEY` is set to production key (sk*live*...)
- [ ] Verify `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` is set to production key (pk*live*...)
- [ ] Update `STRIPE_WEBHOOK_SECRET` to production webhook signing secret
- [ ] Set `CRON_API_KEY` to a secure random string for production
- [ ] Ensure all environment variables are properly set in Vercel project settings

### Stripe Dashboard Configuration

- [ ] Create production price products for each subscription tier:
  - [ ] Basic ($5/month)
  - [ ] Sync ($15/month)
  - [ ] Cleanup ($45/month)
  - [ ] Elite ($100/month)
- [ ] Update price IDs in environment variables:
  - [ ] `NEXT_PUBLIC_STRIPE_PRICE_ID_BASIC`
  - [ ] `NEXT_PUBLIC_STRIPE_PRICE_ID_SYNC`
  - [ ] `NEXT_PUBLIC_STRIPE_PRICE_ID_CLEANUP`
  - [ ] `NEXT_PUBLIC_STRIPE_PRICE_ID_ELITE`
- [ ] Configure webhook endpoint: `https://yourdomain.com/api/webhooks/stripe`
- [ ] Select required events for the webhook:
  - [ ] `customer.subscription.created`
  - [ ] `customer.subscription.updated`
  - [ ] `customer.subscription.deleted`
  - [ ] `invoice.payment_succeeded`
  - [ ] `invoice.payment_failed`
- [ ] Copy webhook signing secret to `STRIPE_WEBHOOK_SECRET`
- [ ] Enable Strong Customer Authentication (SCA) for European customers
- [ ] Verify you're in "View live data" mode (toggle in the top-right) when setting up production

### Database

- [ ] Run database migration for subscription tables:
  ```bash
  node scripts/migrate-schema.js
  ```
- [ ] Verify subscription_tiers table contains all tiers (free, basic, sync, cleanup, elite)
- [ ] Check database connection pooling configuration for production

## Deployment Process

- [ ] Push changes to the production branch
- [ ] Deploy to staging/testing environment first
- [ ] Test complete subscription flow on staging with a test card
- [ ] Verify webhook events are being received and processed
- [ ] Verify CRON job functionality
- [ ] Deploy to production environment

## Post-Deployment Verification

- [ ] Complete a small test purchase ($1 or minimum amount)
- [ ] Verify the subscription is created correctly in Stripe Dashboard
- [ ] Verify webhook events were received and processed
- [ ] Verify subscription data is correctly stored in database
- [ ] Verify user access levels match their subscription tier
- [ ] Test subscription cancellation flow
- [ ] Test subscription upgrade flow
- [ ] Test subscription downgrade flow
- [ ] Verify customer portal functionality

## CRON Job Setup

- [ ] Set up production CRON job to run daily:
  ```
  0 0 * * * curl -X POST -H "Authorization: Bearer YOUR_CRON_API_KEY" https://yourdomain.com/api/cron/check-expired-subscriptions
  ```
- [ ] Set up webhook monitoring CRON job:
  ```
  0 */6 * * * curl -X POST -H "Authorization: Bearer YOUR_CRON_API_KEY" https://yourdomain.com/api/cron/monitor-webhooks
  ```

## Monitoring Setup

- [ ] Set up alerts for webhook failures
- [ ] Set up alerts for payment failures
- [ ] Configure logging for subscription events
- [ ] Create dashboard for subscription metrics
- [ ] Set up monitoring for failed webhook deliveries

## Security Checks

- [ ] Verify TLS/SSL is properly configured
- [ ] Ensure all payment data is processed only via Stripe
- [ ] Confirm no payment information is being logged
- [ ] Validate webhook signatures to prevent fraud
- [ ] Test API security with incorrect tokens/signatures

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
5. Be prepared to roll back to previous version if critical issues arise

## Legal and Compliance

- [ ] Verify Terms of Service includes subscription terms
- [ ] Verify Privacy Policy includes payment processing information
- [ ] Ensure checkout page includes clear pricing information
- [ ] Add cancellation instructions to account management page
- [ ] Verify compliance with local tax regulations

## Final Checks

- [ ] Remove any test mode code or debug statements
- [ ] Verify no test API keys are in production environment
- [ ] Ensure proper error handling is in place
- [ ] Document the implementation for future reference
- [ ] Update API version if needed (current: `2024-04-10`)

## Stripe API Testing

For testing Stripe integration:

- Success card: `4242 4242 4242 4242`
- Requires Authentication: `4000 0025 0000 3155`
- Declined card: `4000 0000 0000 9995`

## Related Documentation

- [Stripe Integration Guide](./Stripe-Integration-Guide.md)
- [Stripe Webhook Guide](./Stripe-Webhook-Guide.md)
- [Stripe Fraud Prevention Guide](./Stripe-Fraud-Prevention-Guide.md)
- [Subscription Tiers](./subscriptions/subscription-tiers.md)
- [Subscription Access Implementation](./subscriptions/subscription-access-implementation.md)
