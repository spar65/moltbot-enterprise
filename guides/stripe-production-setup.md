# VIBEcoder Stripe Production Setup Guide

This guide outlines the steps to transition your Stripe integration from development/testing to production.

## 1. Environment Variables Setup

Create or update your `.env.local` file with the following variables:

```
# Stripe Configuration - PRODUCTION
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_live_REPLACE_WITH_YOUR_PUBLISHABLE_KEY
STRIPE_SECRET_KEY=sk_live_REPLACE_WITH_YOUR_SECRET_KEY
STRIPE_WEBHOOK_SECRET=whsec_REPLACE_WITH_YOUR_WEBHOOK_SECRET

# Stripe Product Price IDs - PRODUCTION
NEXT_PUBLIC_STRIPE_PRICE_ID_BASIC=price_REPLACE_WITH_ACTUAL_PRICE_ID
NEXT_PUBLIC_STRIPE_PRICE_ID_SYNC=price_REPLACE_WITH_ACTUAL_PRICE_ID
NEXT_PUBLIC_STRIPE_PRICE_ID_CLEANUP=price_REPLACE_WITH_ACTUAL_PRICE_ID
NEXT_PUBLIC_STRIPE_PRICE_ID_ELITE=price_REPLACE_WITH_ACTUAL_PRICE_ID
```

For Vercel deployment, add these same environment variables in your Vercel project settings.

## 2. Stripe Dashboard Setup

### Create Products and Prices in Production

1. Log in to your [Stripe Dashboard](https://dashboard.stripe.com/)
2. Ensure you're in "View live data" mode (toggle in the top-right)
3. Go to Products → Create Product for each tier:
   - Basic
   - Sync
   - Cleanup
   - Elite
4. For each product, create a recurring price:
   - Set the appropriate amount
   - Choose "Recurring" billing period (monthly)
   - Copy the "Price ID" (starts with `price_`) and add it to your environment variables

### Set Up Webhook Endpoint

1. In Stripe Dashboard, go to Developers → Webhooks
2. Add an endpoint: `https://your-production-domain.com/api/webhooks/stripe`
3. Select at least these events:
   - `invoice.payment_succeeded`
   - `customer.subscription.deleted`
   - `customer.subscription.updated`
4. After creating the endpoint, reveal and copy the Signing Secret
5. Add this secret as `STRIPE_WEBHOOK_SECRET` in your environment variables

## 3. Testing in Production

Before going live, test the subscription flow in production:

1. Use a real card for testing (or Stripe test cards that work in live mode)
2. Complete a test subscription purchase
3. Verify the webhook events are received and processed correctly
4. Check the customer and subscription are created in your Stripe Dashboard

## 4. Subscription Management Implementation

For a complete subscription system, implement:

1. **Customer Portal**: Allow users to manage their subscriptions

   ```javascript
   // Example: Create a Stripe Customer Portal session
   const session = await stripe.billingPortal.sessions.create({
     customer: stripeCustomerId,
     return_url: "https://your-domain.com/account",
   });
   return { url: session.url };
   ```

2. **Subscription Status Checking**: Add an API endpoint to check subscription status

   ```javascript
   // Example route: /api/subscription-status
   export default async function handler(req, res) {
     const userId = req.session.userId; // Get from your auth system
     const customer = await getStripeCustomerByUserId(userId);

     if (!customer) {
       return res.status(404).json({ active: false });
     }

     const subscriptions = await stripe.subscriptions.list({
       customer: customer.id,
       status: "active",
       limit: 1,
     });

     return res.status(200).json({
       active: subscriptions.data.length > 0,
       subscription: subscriptions.data[0] || null,
     });
   }
   ```

3. **Webhook Fulfillment Logic**: Complete the webhook handler to update your database and provision access
   ```javascript
   // In your webhook handler, add logic for each event:
   case 'invoice.payment_succeeded': {
     const invoice = event.data.object;
     await updateSubscriptionStatus(invoice.customer, invoice.subscription, 'active');
     await grantAccessToFeatures(invoice.customer);
     break;
   }
   ```

## 5. Error Handling and Monitoring

1. Set up Stripe logging to capture events and errors
2. Implement proper error reporting for failed payments
3. Create alerts for critical subscription events

## 6. User Experience Considerations

1. Provide clear subscription confirmation and welcome messages
2. Set up transactional emails for subscription events
3. Display subscription status clearly in your user interface

## 7. Security Considerations

1. Ensure all payment data is processed only via Stripe
2. Never log complete payment information
3. Use TLS/SSL for all communications
4. Validate webhook signatures to prevent fraud

## Stripe API Version

Your code currently uses the Stripe API version `2024-04-10`. Verify this is still current or update as needed.

## Support and Documentation

- [Stripe API Documentation](https://stripe.com/docs/api)
- [Stripe Webhook Events](https://stripe.com/docs/webhooks/stripe-events)
- [Stripe Customer Portal](https://stripe.com/docs/billing/subscriptions/customer-portal)
