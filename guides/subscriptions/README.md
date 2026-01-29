# VibeCoder Subscription System

This document provides an overview of the VibeCoder subscription system architecture and how the different components work together.

## System Architecture

The subscription system consists of the following key components:

1. **Database Schema** - Stores subscription data and tier information
2. **Stripe Integration** - Handles payments and subscription lifecycle
3. **Subscription Context** - Provides subscription state throughout the app
4. **Protected Content Component** - UI component for access control
5. **Subscription Middleware** - API route protection

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│                 │     │                 │     │                 │
│  Stripe         │────▶│  Database       │────▶│  Subscription   │
│  (Payments)     │     │  (User Data)    │     │  Context (React)│
│                 │     │                 │     │                 │
└─────────────────┘     └─────────────────┘     └────────┬────────┘
                                                         │
                                                         ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│                 │     │                 │     │                 │
│  API            │◀────│  Subscription   │◀────│  Protected      │
│  Endpoints      │     │  Middleware     │     │  Content (UI)   │
│                 │     │                 │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

## Database Schema

The subscription system uses two main tables:

### subscriptions Table

```sql
CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id TEXT NOT NULL UNIQUE,
  tier TEXT NOT NULL CHECK (tier IN ('free', 'basic', 'sync', 'cleanup', 'elite')),
  status TEXT NOT NULL CHECK (status IN ('active', 'inactive', 'cancelled', 'past_due')),
  stripe_subscription_id TEXT,
  stripe_customer_id TEXT,
  current_period_start TIMESTAMP WITH TIME ZONE,
  current_period_end TIMESTAMP WITH TIME ZONE,
  features JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### tools Table

```sql
CREATE TABLE tools (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  tier_requirement TEXT NOT NULL CHECK (tier_requirement IN ('free', 'basic', 'sync', 'cleanup', 'elite')),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

## Subscription Flow

1. **User Registration**

   - User signs up with Auth0
   - Default "free" tier subscription is created

2. **Subscription Purchase**

   - User selects a paid tier
   - Redirected to Stripe Checkout
   - Stripe creates subscription and sends webhook

3. **Webhook Processing**

   - Stripe webhook received by `/api/webhooks/stripe`
   - Subscription data updated in database
   - User gains access to new tier features

4. **Access Control**

   - `SubscriptionProvider` loads user's current tier
   - `ProtectedContent` component controls UI visibility
   - Subscription middleware protects API routes

5. **Subscription Management**
   - User can upgrade/downgrade/cancel in account settings
   - Changes processed through Stripe
   - Database updated via webhooks

## Key Files

| File                               | Purpose                                      |
| ---------------------------------- | -------------------------------------------- |
| `src/lib/database.ts`              | Core subscription types and helper functions |
| `src/pages/api/webhooks/stripe.ts` | Stripe webhook handler                       |
| `contexts/SubscriptionContext.tsx` | React context for subscription state         |
| `components/ProtectedContent.tsx`  | UI component for access control              |
| `src/middleware/subscription.ts`   | API route protection middleware              |
| `pages/test-protection.tsx`        | Example page demonstrating protection        |

## Environment Variables

The following environment variables must be set in `.env.local`:

```
# Stripe API Keys
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...

# Stripe Price IDs
STRIPE_PRICE_ID_BASIC=price_...
STRIPE_PRICE_ID_SYNC=price_...
STRIPE_PRICE_ID_CLEANUP=price_...
STRIPE_PRICE_ID_ELITE=price_...

# Public variables (safe for client-side)
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_...
NEXT_PUBLIC_STRIPE_PRICE_ID_BASIC=${STRIPE_PRICE_ID_BASIC}
NEXT_PUBLIC_STRIPE_PRICE_ID_SYNC=${STRIPE_PRICE_ID_SYNC}
NEXT_PUBLIC_STRIPE_PRICE_ID_CLEANUP=${STRIPE_PRICE_ID_CLEANUP}
NEXT_PUBLIC_STRIPE_PRICE_ID_ELITE=${STRIPE_PRICE_ID_ELITE}
```

## Testing

### Stripe Testing

For testing Stripe integration locally:

1. Install the Stripe CLI: https://stripe.com/docs/stripe-cli
2. Forward webhooks to your local server:
   ```
   stripe listen --forward-to localhost:3000/api/webhooks/stripe
   ```
3. Use Stripe test cards for payments:
   - Success: `4242 4242 4242 4242`
   - Requires Authentication: `4000 0025 0000 3155`
   - Declined: `4000 0000 0000 9995`

### Subscription Testing

To test different subscription tiers:

1. Create test users in Auth0
2. Use Stripe test mode to create subscriptions
3. Visit `/test-protection` to verify access controls
4. Test API endpoints with different user tiers

## Common Issues

### Webhook Errors

If Stripe webhooks aren't being processed:

1. Check webhook signature verification
2. Verify webhook endpoint is publicly accessible
3. Confirm webhook secret is correctly set in `.env.local`
4. Check Stripe dashboard for webhook delivery attempts

### Access Control Issues

If users can't access content they should have access to:

1. Check database to confirm user's subscription tier
2. Verify `SubscriptionContext` is loading correctly
3. Check for typos in tier names (must be exactly: "free", "basic", "sync", "cleanup", "elite")
4. Ensure `SubscriptionProvider` is properly set up in `_app.tsx`

## Documentation

For more detailed information, see:

- [Developer Guide: Implementing Subscription Access Controls](subscription-access-implementation.md)
- [User Guide: Subscription Tiers](subscription-tiers.md)
- [Stripe Deployment Checklist](../Stripe-Deployment-Checklist.md)
- [Cursor Rule: Subscription Access Control](../../.cursor/rules/026-subscription-access-control.mdc)

## Future Improvements

Planned enhancements to the subscription system:

1. **Usage-based billing** - Add metered billing for certain features
2. **Team management** - Enhanced controls for team seats and permissions
3. **Subscription analytics** - Track conversion rates and churn
4. **Coupon system** - Support for promotional discounts
5. **Annual billing** - Discounted annual subscription options
