# Stripe Integration - Complete Implementation and Debugging Guide

## Overview

This guide provides a complete walkthrough for integrating Stripe payment processing with webhook handling, including common issues and their solutions. This is based on real debugging experience where we solved critical webhook processing and database synchronization issues.

## Table of Contents

1. [Initial Setup](#initial-setup)
2. [Database Schema Implementation](#database-schema-implementation)
3. [Environment Configuration](#environment-configuration)
4. [Stripe Dashboard Configuration](#stripe-dashboard-configuration)
5. [Webhook Implementation](#webhook-implementation)
6. [Database Synchronization Patterns](#database-synchronization-patterns)
7. [Complete Working Implementations](#complete-working-implementations)
8. [Common Issues and Debugging](#common-issues-and-debugging)
9. [The Critical Bugs We Discovered](#the-critical-bugs-we-discovered)
10. [Testing and Verification](#testing-and-verification)
11. [Production Deployment Checklist](#production-deployment-checklist)

---

## Initial Setup

### Prerequisites

- Stripe account with webhook permissions
- Next.js application with database
- Environment variables configured

### Required Environment Variables

```bash
# Basic Stripe Configuration
STRIPE_SECRET_KEY=sk_test_your-secret-key
STRIPE_PUBLISHABLE_KEY=pk_test_your-publishable-key
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_your-publishable-key

# Webhook Configuration
STRIPE_WEBHOOK_SECRET=whsec_your-webhook-secret

# Database Configuration
DATABASE_URL=postgresql://username:password@host:5432/database
```

---

## Database Schema Implementation

### Issues We Encountered

During implementation, we discovered several database schema issues that had to be resolved:

#### 1. Missing Subscription Tracking Tables

**Problem**: No proper tables for tracking Stripe subscriptions and their relationship to users.

**Solution**: Create comprehensive subscription tracking schema:

```sql
-- Create subscriptions table
CREATE TABLE subscriptions (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  stripe_subscription_id VARCHAR(255) UNIQUE NOT NULL,
  stripe_customer_id VARCHAR(255) NOT NULL,
  status VARCHAR(50) NOT NULL,
  price_id VARCHAR(255),
  quantity INTEGER DEFAULT 1,
  trial_end TIMESTAMP,
  current_period_start TIMESTAMP,
  current_period_end TIMESTAMP,
  cancel_at_period_end BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Create webhook events log table
CREATE TABLE webhook_events (
  id SERIAL PRIMARY KEY,
  stripe_event_id VARCHAR(255) UNIQUE NOT NULL,
  event_type VARCHAR(100) NOT NULL,
  processed_at TIMESTAMP DEFAULT NOW(),
  processing_time_ms INTEGER,
  success BOOLEAN DEFAULT TRUE,
  error_message TEXT,
  raw_data JSONB
);

-- Create payment failures tracking
CREATE TABLE payment_failures (
  id SERIAL PRIMARY KEY,
  stripe_invoice_id VARCHAR(255),
  stripe_customer_id VARCHAR(255),
  stripe_subscription_id VARCHAR(255),
  attempt_count INTEGER DEFAULT 1,
  failure_reason TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Add indexes for performance
CREATE INDEX idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_stripe_id ON subscriptions(stripe_subscription_id);
CREATE INDEX idx_webhook_events_type ON webhook_events(event_type);
CREATE INDEX idx_webhook_events_processed ON webhook_events(processed_at);
```

#### 2. User Table Enhancements

**Problem**: Users table missing Stripe customer tracking.

**Solution**: Add Stripe customer relationship:

```sql
-- Add Stripe customer ID to users table
ALTER TABLE users ADD COLUMN stripe_customer_id VARCHAR(255) UNIQUE;
ALTER TABLE users ADD COLUMN subscription_tier VARCHAR(50) DEFAULT 'free';

-- Add index for performance
CREATE INDEX idx_users_stripe_customer ON users(stripe_customer_id);
```

### Database Migration Script

Create this migration file to apply all changes:

```sql
-- migrations/003_stripe_integration.sql

-- Add Stripe customer tracking to users
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'users' AND column_name = 'stripe_customer_id') THEN
        ALTER TABLE users ADD COLUMN stripe_customer_id VARCHAR(255) UNIQUE;
        ALTER TABLE users ADD COLUMN subscription_tier VARCHAR(50) DEFAULT 'free';
        CREATE INDEX idx_users_stripe_customer ON users(stripe_customer_id);
    END IF;
END $$;

-- Create subscriptions table
CREATE TABLE IF NOT EXISTS subscriptions (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  stripe_subscription_id VARCHAR(255) UNIQUE NOT NULL,
  stripe_customer_id VARCHAR(255) NOT NULL,
  status VARCHAR(50) NOT NULL,
  price_id VARCHAR(255),
  quantity INTEGER DEFAULT 1,
  trial_end TIMESTAMP,
  current_period_start TIMESTAMP,
  current_period_end TIMESTAMP,
  cancel_at_period_end BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Create webhook events log
CREATE TABLE IF NOT EXISTS webhook_events (
  id SERIAL PRIMARY KEY,
  stripe_event_id VARCHAR(255) UNIQUE NOT NULL,
  event_type VARCHAR(100) NOT NULL,
  processed_at TIMESTAMP DEFAULT NOW(),
  processing_time_ms INTEGER,
  success BOOLEAN DEFAULT TRUE,
  error_message TEXT,
  raw_data JSONB
);

-- Create payment failures tracking
CREATE TABLE IF NOT EXISTS payment_failures (
  id SERIAL PRIMARY KEY,
  stripe_invoice_id VARCHAR(255),
  stripe_customer_id VARCHAR(255),
  stripe_subscription_id VARCHAR(255),
  attempt_count INTEGER DEFAULT 1,
  failure_reason TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Verify the changes
SELECT table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name IN ('users', 'subscriptions', 'webhook_events', 'payment_failures')
ORDER BY table_name, ordinal_position;
```

---

## Environment Configuration

### Critical Environment Setup

We had to clean up conflicting Stripe configurations and add missing variables.

#### Environment File Structure

**Problem**: Multiple conflicting Stripe keys causing test/production confusion.

**Solution**: Clean environment structure:

```bash
# ❌ REMOVE these conflicting entries:
# STRIPE_SECRET_KEY=sk_live_... (mixed with test keys)
# STRIPE_WEBHOOK_SECRET=whsec_live_... (wrong environment)

# ✅ KEEP only one consistent set per environment:

# Development Environment (.env.local)
STRIPE_SECRET_KEY=sk_test_51ABC...
STRIPE_PUBLISHABLE_KEY=pk_test_51ABC...
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_51ABC...
STRIPE_WEBHOOK_SECRET=whsec_abc123...

# Production Environment (Vercel)
STRIPE_SECRET_KEY=sk_live_51XYZ...
STRIPE_PUBLISHABLE_KEY=pk_live_51XYZ...
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_live_51XYZ...
STRIPE_WEBHOOK_SECRET=whsec_xyz789...
```

#### Environment Variable Verification

Create this script to verify all required variables:

```javascript
// scripts/verify-stripe-env.js
const requiredVars = [
  "STRIPE_SECRET_KEY",
  "STRIPE_PUBLISHABLE_KEY",
  "NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY",
  "STRIPE_WEBHOOK_SECRET",
  "DATABASE_URL",
];

console.log("🔍 Checking required Stripe environment variables...\n");

const missing = [];
const present = [];

requiredVars.forEach((varName) => {
  if (process.env[varName]) {
    present.push(varName);
    console.log(`✅ ${varName}: ${process.env[varName].substring(0, 20)}...`);
  } else {
    missing.push(varName);
    console.log(`❌ ${varName}: MISSING`);
  }
});

console.log(
  `\n📊 Summary: ${present.length}/${requiredVars.length} variables present`
);

if (missing.length > 0) {
  console.log("\n🚨 Missing variables:", missing.join(", "));
  process.exit(1);
} else {
  console.log("\n🎉 All required Stripe environment variables are present!");
}
```

---

## Stripe Dashboard Configuration

### Step 1: Create Webhook Endpoint

1. Go to **Stripe Dashboard > Developers > Webhooks**
2. Click **Add endpoint**
3. Set **Endpoint URL** to: `https://yourdomain.com/api/webhooks/stripe`
4. Select these **Events to send**:
   - `checkout.session.completed`
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `invoice.payment_succeeded`
   - `invoice.payment_failed`

### Step 2: Configure Price Objects

1. Go to **Stripe Dashboard > Products**
2. Create products for each subscription tier
3. Create prices with proper metadata:

```json
{
  "tier": "basic",
  "features": "feature1,feature2",
  "max_users": "5"
}
```

### Step 3: Set Up Customer Portal

1. Go to **Stripe Dashboard > Settings > Billing > Customer portal**
2. Enable customer portal
3. Configure allowed actions:
   - Update payment methods
   - Download invoices
   - Cancel subscriptions
   - Update billing information

---

## Webhook Implementation

### Step 1: Create Webhook Handler

```typescript
// pages/api/webhooks/stripe.ts
import { buffer } from "micro";
import { NextApiRequest, NextApiResponse } from "next";
import Stripe from "stripe";
import {
  logWebhookEvent,
  processWebhookEvent,
} from "../../../lib/stripe/webhook-processor";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: "2023-10-16",
});

const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET!;
const WEBHOOK_TIMEOUT = 4500; // Leave 500ms buffer under Stripe's 5s limit

export const config = {
  api: {
    bodyParser: false, // Critical: Disable body parsing for signature verification
  },
};

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  if (req.method !== "POST") {
    res.setHeader("Allow", "POST");
    return res.status(405).end("Method Not Allowed");
  }

  const buf = await buffer(req);
  const sig = req.headers["stripe-signature"] as string;

  if (!sig) {
    console.error("Missing stripe-signature header");
    return res.status(400).json({ error: "Missing stripe-signature header" });
  }

  let event: Stripe.Event;

  try {
    // Critical: Verify webhook signature
    event = stripe.webhooks.constructEvent(buf, sig, webhookSecret);
  } catch (err) {
    console.error(`Webhook signature verification failed:`, err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  // Log the received event
  await logWebhookEvent(event.id, event.type, event.data.object);
  console.log(`Processing webhook: ${event.type} (${event.id})`);

  // Set up timeout protection
  const timeoutPromise = new Promise((_, reject) => {
    setTimeout(() => {
      reject(new Error("Webhook processing timeout"));
    }, WEBHOOK_TIMEOUT);
  });

  try {
    // Process with timeout protection
    await Promise.race([processWebhookEvent(event), timeoutPromise]);

    console.log(`Successfully processed webhook: ${event.type}`);
    return res.status(200).json({ received: true });
  } catch (error) {
    console.error(`Webhook processing failed for ${event.type}:`, error);

    // Log the failure but still return 200 to prevent Stripe retries
    await logWebhookEvent(
      event.id,
      event.type,
      event.data.object,
      error.message
    );
    return res.status(200).json({
      received: true,
      error: "Processing failed but acknowledged",
    });
  }
}
```

### Step 2: Create Webhook Processor

```typescript
// lib/stripe/webhook-processor.ts
import Stripe from "stripe";
import { query } from "../db";

export async function processWebhookEvent(event: Stripe.Event) {
  switch (event.type) {
    case "checkout.session.completed":
      await handleCheckoutCompleted(
        event.data.object as Stripe.Checkout.Session
      );
      break;

    case "customer.subscription.created":
    case "customer.subscription.updated":
      await handleSubscriptionChange(event.data.object as Stripe.Subscription);
      break;

    case "customer.subscription.deleted":
      await handleSubscriptionDeleted(event.data.object as Stripe.Subscription);
      break;

    case "invoice.payment_succeeded":
      await handlePaymentSucceeded(event.data.object as Stripe.Invoice);
      break;

    case "invoice.payment_failed":
      await handlePaymentFailed(event.data.object as Stripe.Invoice);
      break;

    default:
      console.log(`Unhandled event type: ${event.type}`);
  }
}

async function handleCheckoutCompleted(session: Stripe.Checkout.Session) {
  console.log("Processing checkout completion:", session.id);

  // Get customer and subscription details
  const customerId = session.customer as string;
  const subscriptionId = session.subscription as string;

  if (!customerId || !subscriptionId) {
    throw new Error("Missing customer or subscription ID in checkout session");
  }

  // Update user with Stripe customer ID
  await query("UPDATE users SET stripe_customer_id = $1 WHERE email = $2", [
    customerId,
    session.customer_details?.email,
  ]);

  console.log(`Updated user with Stripe customer ID: ${customerId}`);
}

async function handleSubscriptionChange(subscription: Stripe.Subscription) {
  console.log("Processing subscription change:", subscription.id);

  const customerId = subscription.customer as string;
  const subscriptionData = {
    stripe_subscription_id: subscription.id,
    stripe_customer_id: customerId,
    status: subscription.status,
    price_id: subscription.items.data[0]?.price.id,
    quantity: subscription.items.data[0]?.quantity || 1,
    trial_end: subscription.trial_end
      ? new Date(subscription.trial_end * 1000)
      : null,
    current_period_start: new Date(subscription.current_period_start * 1000),
    current_period_end: new Date(subscription.current_period_end * 1000),
    cancel_at_period_end: subscription.cancel_at_period_end,
  };

  // Use upsert to handle both creates and updates
  await query(
    `
    INSERT INTO subscriptions (
      user_id, stripe_subscription_id, stripe_customer_id, status, 
      price_id, quantity, trial_end, current_period_start, 
      current_period_end, cancel_at_period_end, updated_at
    ) 
    VALUES (
      (SELECT id FROM users WHERE stripe_customer_id = $2),
      $1, $2, $3, $4, $5, $6, $7, $8, $9, NOW()
    )
    ON CONFLICT (stripe_subscription_id) 
    DO UPDATE SET
      status = EXCLUDED.status,
      price_id = EXCLUDED.price_id,
      quantity = EXCLUDED.quantity,
      trial_end = EXCLUDED.trial_end,
      current_period_start = EXCLUDED.current_period_start,
      current_period_end = EXCLUDED.current_period_end,
      cancel_at_period_end = EXCLUDED.cancel_at_period_end,
      updated_at = NOW()
  `,
    [
      subscriptionData.stripe_subscription_id,
      subscriptionData.stripe_customer_id,
      subscriptionData.status,
      subscriptionData.price_id,
      subscriptionData.quantity,
      subscriptionData.trial_end,
      subscriptionData.current_period_start,
      subscriptionData.current_period_end,
      subscriptionData.cancel_at_period_end,
    ]
  );

  // Update user subscription tier
  const tier = getPlanTierFromPriceId(subscriptionData.price_id);
  await query(
    "UPDATE users SET subscription_tier = $1 WHERE stripe_customer_id = $2",
    [tier, customerId]
  );

  console.log(
    `Updated subscription ${subscription.id} to status: ${subscription.status}`
  );
}

async function handleSubscriptionDeleted(subscription: Stripe.Subscription) {
  console.log("Processing subscription deletion:", subscription.id);

  const customerId = subscription.customer as string;

  // Update subscription status to cancelled
  await query(
    "UPDATE subscriptions SET status = $1, updated_at = NOW() WHERE stripe_subscription_id = $2",
    ["cancelled", subscription.id]
  );

  // Reset user to free tier
  await query(
    "UPDATE users SET subscription_tier = $1 WHERE stripe_customer_id = $2",
    ["free", customerId]
  );

  console.log(
    `Cancelled subscription ${subscription.id} and reset user to free tier`
  );
}

async function handlePaymentSucceeded(invoice: Stripe.Invoice) {
  console.log("Processing successful payment:", invoice.id);

  const subscriptionId = invoice.subscription as string;
  const customerId = invoice.customer as string;

  if (subscriptionId) {
    // Update subscription status to active
    await query(
      "UPDATE subscriptions SET status = $1, updated_at = NOW() WHERE stripe_subscription_id = $2",
      ["active", subscriptionId]
    );

    // Clear any payment failure records
    await query(
      "DELETE FROM payment_failures WHERE stripe_subscription_id = $1",
      [subscriptionId]
    );

    console.log(
      `Activated subscription ${subscriptionId} after successful payment`
    );
  }
}

async function handlePaymentFailed(invoice: Stripe.Invoice) {
  console.log("Processing failed payment:", invoice.id);

  const subscriptionId = invoice.subscription as string;
  const customerId = invoice.customer as string;
  const attemptCount = invoice.attempt_count || 1;

  // Log the payment failure
  await query(
    `
    INSERT INTO payment_failures (
      stripe_invoice_id, stripe_customer_id, stripe_subscription_id,
      attempt_count, failure_reason, created_at
    ) VALUES ($1, $2, $3, $4, $5, NOW())
  `,
    [
      invoice.id,
      customerId,
      subscriptionId,
      attemptCount,
      invoice.last_finalization_error?.message || "Payment failed",
    ]
  );

  // If this is the 3rd failed attempt, mark subscription as past_due
  if (attemptCount >= 3 && subscriptionId) {
    await query(
      "UPDATE subscriptions SET status = $1, updated_at = NOW() WHERE stripe_subscription_id = $2",
      ["past_due", subscriptionId]
    );

    // Update user to limited access
    await query(
      "UPDATE users SET subscription_tier = $1 WHERE stripe_customer_id = $2",
      ["limited", customerId]
    );

    console.log(
      `Limited access for subscription ${subscriptionId} after 3 failed payment attempts`
    );
  }
}

export async function logWebhookEvent(
  eventId: string,
  eventType: string,
  eventData: any,
  errorMessage?: string
) {
  const startTime = Date.now();

  try {
    await query(
      `
      INSERT INTO webhook_events (
        stripe_event_id, event_type, processed_at, 
        success, error_message, raw_data
      ) VALUES ($1, $2, NOW(), $3, $4, $5)
      ON CONFLICT (stripe_event_id) DO NOTHING
    `,
      [
        eventId,
        eventType,
        !errorMessage,
        errorMessage || null,
        JSON.stringify(eventData),
      ]
    );

    const processingTime = Date.now() - startTime;
    console.log(`Logged webhook event ${eventId} (${processingTime}ms)`);
  } catch (error) {
    console.error("Failed to log webhook event:", error);
  }
}

function getPlanTierFromPriceId(priceId?: string): string {
  const priceToTierMap: Record<string, string> = {
    [process.env.STRIPE_PRICE_ID_BASIC!]: "basic",
    [process.env.STRIPE_PRICE_ID_PRO!]: "pro",
    [process.env.STRIPE_PRICE_ID_BUSINESS!]: "business",
  };

  return priceToTierMap[priceId || ""] || "free";
}
```

---

## Database Synchronization Patterns

### Idempotent Processing

**Problem**: Webhooks can be delivered multiple times, causing duplicate database entries.

**Solution**: Implement idempotent processing:

```typescript
// lib/stripe/idempotent-processor.ts
export async function processIdempotently<T>(
  eventId: string,
  processor: () => Promise<T>
): Promise<T> {
  // Check if we've already processed this event
  const existingEvent = await query(
    "SELECT * FROM webhook_events WHERE stripe_event_id = $1",
    [eventId]
  );

  if (existingEvent.rows.length > 0) {
    console.log(`Event ${eventId} already processed, skipping`);
    return;
  }

  // Process the event within a transaction
  return await withTransaction(async (client) => {
    // Mark event as being processed
    await client.query(
      `
      INSERT INTO webhook_events (stripe_event_id, event_type, processed_at)
      VALUES ($1, 'processing', NOW())
    `,
      [eventId]
    );

    // Process the actual event
    const result = await processor();

    // Mark as completed
    await client.query(
      `
      UPDATE webhook_events 
      SET success = true, processing_time_ms = EXTRACT(EPOCH FROM (NOW() - processed_at)) * 1000
      WHERE stripe_event_id = $1
    `,
      [eventId]
    );

    return result;
  });
}

async function withTransaction<T>(
  callback: (client: any) => Promise<T>
): Promise<T> {
  const client = await db.getClient();

  try {
    await client.query("BEGIN");
    const result = await callback(client);
    await client.query("COMMIT");
    return result;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}
```

---

## Common Issues and Debugging

### Critical Issues We Discovered

#### Issue 1: Body Parser Breaks Webhook Signatures

**Problem**: Webhook signature verification failing intermittently.

**Symptoms**:

- "Webhook signature verification failed" errors
- Works locally but fails in production
- No clear pattern to failures

**Root Cause**: Next.js body parser modifies the request body, invalidating Stripe signatures.

**Solution**:

```typescript
// ❌ WRONG - This breaks signature verification
export default async function handler(req, res) {
  const event = req.body; // Already parsed by Next.js
  const sig = req.headers["stripe-signature"];
  // This will fail because body was modified
  stripe.webhooks.constructEvent(req.body, sig, secret);
}

// ✅ CORRECT - Disable body parser and use raw buffer
export const config = {
  api: {
    bodyParser: false, // Critical for webhook signatures
  },
};

export default async function handler(req, res) {
  const buf = await buffer(req); // Get raw buffer
  const sig = req.headers["stripe-signature"];
  const event = stripe.webhooks.constructEvent(buf, sig, secret);
}
```

#### Issue 2: Database Connection Pool Exhaustion

**Problem**: Webhook processing causing database connection timeouts.

**Symptoms**:

- "Connection pool exhausted" errors
- Webhook processing slowing down over time
- Database becoming unresponsive

**Root Cause**: Not properly releasing database connections in webhook handlers.

**Solution**: Use connection pooling with proper cleanup:

```typescript
// lib/db.ts - Proper connection management
import { Pool } from "pg";

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 20, // Maximum connections in pool
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

export async function query(text: string, params?: any[]) {
  const client = await pool.connect();
  try {
    const result = await client.query(text, params);
    return result;
  } catch (error) {
    console.error("Database query error:", error);
    throw error;
  } finally {
    client.release(); // Critical: Always release connections
  }
}

// For transaction handling
export async function withTransaction<T>(
  callback: (client: any) => Promise<T>
): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const result = await callback(client);
    await client.query("COMMIT");
    return result;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release(); // Critical: Always release even on error
  }
}
```

#### Issue 3: Webhook Event Ordering Problems

**Problem**: Webhook events arriving out of order causing inconsistent state.

**Symptoms**:

- Subscription updates being overwritten by older events
- Database state not matching Stripe state
- Users losing access unexpectedly

**Root Cause**: Stripe webhooks can arrive out of order, especially during high volume.

**Solution**: Implement event ordering and validation:

```typescript
async function handleSubscriptionChange(subscription: Stripe.Subscription) {
  // Check if we have a newer version already processed
  const existingSubscription = await query(
    "SELECT * FROM subscriptions WHERE stripe_subscription_id = $1",
    [subscription.id]
  );

  if (existingSubscription.rows.length > 0) {
    const existing = existingSubscription.rows[0];
    const existingTimestamp = new Date(existing.updated_at).getTime();
    const newTimestamp = subscription.created * 1000; // Stripe uses seconds

    if (existingTimestamp > newTimestamp) {
      console.log(`Ignoring older subscription event for ${subscription.id}`);
      return; // Skip processing older events
    }
  }

  // Process the update...
}
```

---

## Testing and Verification

### Local Testing with Stripe CLI

1. **Install Stripe CLI**:

```bash
brew install stripe/stripe-cli/stripe
stripe login
```

2. **Start webhook forwarding**:

```bash
stripe listen --forward-to localhost:3000/api/webhooks/stripe
```

3. **Trigger test events**:

```bash
stripe trigger customer.subscription.created
stripe trigger invoice.payment_succeeded
stripe trigger invoice.payment_failed
```

### Test Event Processing

Create test script to verify webhook processing:

```javascript
// scripts/test-webhook-processing.js
const stripe = require("stripe")(process.env.STRIPE_SECRET_KEY);

async function testWebhookProcessing() {
  console.log("Testing webhook processing...");

  try {
    // Create a test customer
    const customer = await stripe.customers.create({
      email: "test@example.com",
      name: "Test Customer",
    });

    console.log(`Created test customer: ${customer.id}`);

    // Create a test subscription
    const subscription = await stripe.subscriptions.create({
      customer: customer.id,
      items: [{ price: process.env.STRIPE_PRICE_ID_BASIC }],
    });

    console.log(`Created test subscription: ${subscription.id}`);

    // Wait for webhooks to process
    await new Promise((resolve) => setTimeout(resolve, 5000));

    // Verify database was updated
    const dbResult = await query(
      "SELECT * FROM subscriptions WHERE stripe_subscription_id = $1",
      [subscription.id]
    );

    if (dbResult.rows.length > 0) {
      console.log("✅ Webhook processing successful - database updated");
    } else {
      console.log("❌ Webhook processing failed - no database update");
    }

    // Cleanup
    await stripe.subscriptions.cancel(subscription.id);
    await stripe.customers.del(customer.id);
  } catch (error) {
    console.error("Test failed:", error);
  }
}

testWebhookProcessing();
```

---

## Production Deployment Checklist

### Pre-Deployment

- [ ] **Environment Variables**: All Stripe keys and secrets configured for production
- [ ] **Database Migrations**: All schema changes applied to production database
- [ ] **Webhook URL**: Updated in Stripe Dashboard to production endpoint
- [ ] **SSL Certificate**: HTTPS enabled for webhook endpoint
- [ ] **Error Monitoring**: Logging and monitoring configured for webhook failures

### Post-Deployment Verification

- [ ] **Test Webhook Processing**: Use Stripe Dashboard to send test webhooks
- [ ] **Database Sync**: Verify webhook events are creating/updating database records
- [ ] **Performance**: Check webhook response times are under 5 seconds
- [ ] **Error Handling**: Verify failed webhooks are logged properly
- [ ] **Customer Portal**: Test that customer portal links work correctly

### Monitoring Setup

1. **Webhook Monitoring Dashboard**:

```sql
-- Query to monitor webhook processing
SELECT
  event_type,
  DATE(processed_at) as date,
  COUNT(*) as total_events,
  COUNT(*) FILTER (WHERE success = true) as successful,
  COUNT(*) FILTER (WHERE success = false) as failed,
  AVG(processing_time_ms) as avg_processing_time
FROM webhook_events
WHERE processed_at >= NOW() - INTERVAL '7 days'
GROUP BY event_type, DATE(processed_at)
ORDER BY date DESC, event_type;
```

2. **Subscription Health Check**:

```sql
-- Query to check subscription sync status
SELECT
  s.status,
  COUNT(*) as count,
  COUNT(*) FILTER (WHERE s.updated_at < NOW() - INTERVAL '1 hour') as potentially_stale
FROM subscriptions s
GROUP BY s.status;
```

### Alert Setup

Configure alerts for:

- Webhook processing failures > 5% in 15 minutes
- Webhook response time > 3 seconds average
- Database connection pool > 80% utilization
- Payment failure rate > 10% in 1 hour

---

## Final Notes

This integration provides:

- ✅ **Reliable webhook processing** with signature verification
- ✅ **Idempotent event handling** to prevent duplicate processing
- ✅ **Proper database synchronization** with Stripe state
- ✅ **Comprehensive error handling** and recovery
- ✅ **Production-ready monitoring** and alerting
- ✅ **Transaction safety** for all database operations

### Critical Lessons Learned

1. **Body Parser Rule**: Always disable Next.js body parser for webhook endpoints
2. **Connection Management**: Properly release database connections to prevent pool exhaustion
3. **Event Ordering**: Handle out-of-order webhook events with timestamp validation
4. **Timeout Protection**: Keep webhook processing under 5 seconds with timeout guards
5. **Idempotency**: Always check for duplicate events before processing
6. **Error Recovery**: Return 200 status even for processing errors to prevent retries

The most critical lesson: **A single missing `bodyParser: false` configuration can break the entire payment system silently**. Always verify webhook signature processing in a production-like environment before deployment.
