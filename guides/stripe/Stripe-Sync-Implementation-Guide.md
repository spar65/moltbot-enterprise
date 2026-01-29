# Stripe Sync Implementation Guide

## Overview

This guide documents the complete Stripe sync implementation for AgentMinder/VIBEcoder, including database requirements, API integration, error handling, and testing strategies.

## Database Schema Requirements

### 1. Required Tables and Columns

#### Users Table

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  stripe_customer_id VARCHAR(255),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

#### Subscriptions Table

```sql
CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  stripe_subscription_id VARCHAR(255),
  stripe_price_id VARCHAR(255),
  stripe_customer_id VARCHAR(255),
  tier VARCHAR(50) NOT NULL,
  status VARCHAR(50) NOT NULL,
  amount INTEGER,
  currency VARCHAR(10),
  interval VARCHAR(20),
  current_period_start TIMESTAMP WITH TIME ZONE,
  current_period_end TIMESTAMP WITH TIME ZONE,
  trial_end TIMESTAMP WITH TIME ZONE,
  cancel_at_period_end BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

### 2. Critical Constraints

#### Unique Constraint (REQUIRED)

```sql
ALTER TABLE subscriptions
ADD CONSTRAINT subscriptions_user_id_stripe_subscription_id_unique
UNIQUE (user_id, stripe_subscription_id);
```

**Why**: The sync operation uses `ON CONFLICT (user_id, stripe_subscription_id)` for upsert operations.

#### Status Constraint

```sql
ALTER TABLE subscriptions
ADD CONSTRAINT subscriptions_status_check
CHECK (status IN (
  'active', 'past_due', 'unpaid', 'canceled', 'cancelled',
  'incomplete', 'incomplete_expired', 'trialing', 'paused', 'inactive'
));
```

**Why**: Stripe returns various subscription statuses that must be supported.

## API Implementation

### 1. Sync Endpoint Structure

```typescript
// pages/api/admin/stripe/sync.ts
import { NextApiRequest, NextApiResponse } from "next";
import { withAdminCheck } from "../../../../src/middleware/admin";
import Stripe from "stripe";
import { sql } from "../../../../src/lib/database";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: "2024-04-10" as any,
});

async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  try {
    await sql`BEGIN`;

    // Fetch Stripe data
    const [stripeCustomers, stripeSubscriptions] = await Promise.all([
      stripe.customers.list({ limit: 100, expand: ["data.subscriptions"] }),
      stripe.subscriptions.list({
        limit: 100,
        status: "all",
        expand: ["data.customer"],
      }),
    ]);

    // Sync logic here...

    await sql`COMMIT`;

    res.status(200).json({
      success: true,
      syncedCustomers: customerCount,
      syncedSubscriptions: subscriptionCount,
      errors: errorCount,
      duration: Date.now() - startTime,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    await sql`ROLLBACK`;
    res.status(500).json({ error: "Internal server error" });
  }
}

export default withAdminCheck(handler);
```

### 2. Handling Timestamps

**Critical Issue**: Stripe subscription objects may have undefined timestamps.

```typescript
// Safe timestamp handling
const currentPeriodStart = subscription.current_period_start
  ? new Date(subscription.current_period_start * 1000).toISOString()
  : null;

const currentPeriodEnd = subscription.current_period_end
  ? new Date(subscription.current_period_end * 1000).toISOString()
  : null;

const created = subscription.created
  ? new Date(subscription.created * 1000).toISOString()
  : new Date().toISOString();
```

### 3. User Creation During Sync

```typescript
// Upsert user - create if doesn't exist
await sql`
  INSERT INTO users (
    id,
    email, 
    stripe_customer_id,
    created_at,
    updated_at
  ) VALUES (
    gen_random_uuid(),
    ${customer.email.toLowerCase()},
    ${customer.id},
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
  )
  ON CONFLICT (email) DO UPDATE SET
    stripe_customer_id = EXCLUDED.stripe_customer_id,
    updated_at = CURRENT_TIMESTAMP
`;
```

### 4. Subscription Upsert with All Fields

```typescript
await sql`
  INSERT INTO subscriptions (
    id,
    user_id, 
    stripe_subscription_id,
    stripe_price_id,
    stripe_customer_id,
    tier,
    status,
    amount,
    currency,
    interval,
    current_period_start,
    current_period_end,
    trial_end,
    cancel_at_period_end,
    created_at,
    updated_at
  )
  VALUES (
    gen_random_uuid(),
    ${userId},
    ${subscription.id},
    ${priceData?.id || null},
    ${stripeCustomerId},
    ${tier},
    ${subscription.status},
    ${amount},
    ${currency},
    ${interval},
    ${currentPeriodStart},
    ${currentPeriodEnd},
    ${trialEnd},
    ${subscription.cancel_at_period_end || false},
    ${created},
    CURRENT_TIMESTAMP
  )
  ON CONFLICT (user_id, stripe_subscription_id) DO UPDATE SET
    stripe_price_id = EXCLUDED.stripe_price_id,
    stripe_customer_id = EXCLUDED.stripe_customer_id,
    tier = EXCLUDED.tier,
    status = EXCLUDED.status,
    amount = EXCLUDED.amount,
    currency = EXCLUDED.currency,
    interval = EXCLUDED.interval,
    current_period_start = EXCLUDED.current_period_start,
    current_period_end = EXCLUDED.current_period_end,
    trial_end = EXCLUDED.trial_end,
    cancel_at_period_end = EXCLUDED.cancel_at_period_end,
    updated_at = CURRENT_TIMESTAMP
`;
```

## Environment Variables

### Production Configuration

```bash
# Use the primary STRIPE_SECRET_KEY (contains live key in production)
STRIPE_SECRET_KEY=sk_live_51REMktEbrdIIhAd8...

# Public key for client-side
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_live_51REMktEbrdIIhAd8...

# Webhook secret
STRIPE_WEBHOOK_SECRET=whsec_Uxo7pAYLZy15rlqQSXsOJYxT...
```

**Important**: In production, `STRIPE_SECRET_KEY` contains the live key, not test key.

## Common Issues and Solutions

### 1. "No unique or exclusion constraint matching the ON CONFLICT specification"

**Solution**: Add the required unique constraint:

```sql
ALTER TABLE subscriptions
ADD CONSTRAINT subscriptions_user_id_stripe_subscription_id_unique
UNIQUE (user_id, stripe_subscription_id);
```

### 2. "Invalid input syntax for type timestamp"

**Solution**: Handle undefined timestamps properly:

```typescript
${subscription.current_period_start ? new Date(subscription.current_period_start * 1000) : null}
```

### 3. "Invalid status value"

**Solution**: Update the status constraint to include all Stripe statuses.

### 4. Missing columns

**Solution**: Add all required columns:

- stripe_subscription_id
- stripe_price_id
- stripe_customer_id
- current_period_start
- current_period_end
- amount, currency, interval

## Testing Strategy

### 1. Mock Stripe Responses

```typescript
// tests/utils/stripe-test-utils.tsx
export const stripeTestUtils = {
  mockSuccessfulSync() {
    global.fetch = jest.fn(() =>
      Promise.resolve({
        ok: true,
        status: 200,
        json: () =>
          Promise.resolve({
            success: true,
            syncedCustomers: 2,
            syncedSubscriptions: 1,
            errors: 0,
            errorDetails: [],
            duration: 1250,
            message: "Sync completed: 2 customers and 1 subscriptions synced",
            timestamp: new Date().toISOString(),
            stats: {
              totalStripeCustomers: 2,
              totalStripeSubscriptions: 1,
              successRate: "100%",
            },
          }),
      })
    ) as jest.Mock;
  },
};
```

### 2. Test Coverage Areas

- Successful sync scenarios
- Undefined timestamp handling
- User creation during sync
- Unique constraint conflicts
- Error handling and rollback
- Stats and reporting

## Debugging Scripts

### Check Sync Status

```javascript
// scripts/check-sync-status.js
const { neon } = require("@neondatabase/serverless");

async function checkSyncStatus() {
  const sql = neon(process.env.DATABASE_URL);

  const users = await sql`
    SELECT COUNT(*) as count FROM users 
    WHERE stripe_customer_id IS NOT NULL
  `;

  const subscriptions = await sql`
    SELECT COUNT(*) as count FROM subscriptions
  `;

  console.log(`Users with Stripe ID: ${users[0].count}`);
  console.log(`Subscriptions: ${subscriptions[0].count}`);
}
```

### Add Missing Constraints

```javascript
// scripts/add-subscription-unique-constraint.js
async function addUniqueConstraint() {
  const sql = neon(process.env.DATABASE_URL);

  await sql`
    ALTER TABLE subscriptions 
    ADD CONSTRAINT subscriptions_user_id_stripe_subscription_id_unique 
    UNIQUE (user_id, stripe_subscription_id)
  `;

  console.log("✅ Unique constraint added");
}
```

## Deployment Checklist

1. **Database Preparation**

   - [ ] Verify all required columns exist
   - [ ] Add unique constraint on (user_id, stripe_subscription_id)
   - [ ] Update status constraint to include all Stripe statuses
   - [ ] Clean any duplicate data

2. **Code Deployment**

   - [ ] Deploy updated sync.ts with timestamp handling
   - [ ] Verify environment variables are set correctly
   - [ ] Test sync button in staging first

3. **Post-Deployment**
   - [ ] Clean existing subscriptions if needed
   - [ ] Run sync via admin panel
   - [ ] Verify all subscriptions synced correctly
   - [ ] Check for any errors in logs

## Best Practices

1. **Always use transactions** for sync operations
2. **Handle null/undefined values** explicitly for all Stripe fields
3. **Use lowercase emails** for consistency
4. **Log but don't fail** for individual record errors
5. **Include comprehensive stats** in sync response
6. **Test with production-like data** including edge cases

## Related Documentation

- [020-stripe-integration.mdc](../../.cursor/rules/020-stripe-integration.mdc)
- [Stripe API Documentation](https://stripe.com/docs/api)
- [Neon Database Documentation](https://neon.tech/docs)
