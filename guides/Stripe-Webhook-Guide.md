# Stripe Webhook Integration Guide

This guide focuses on implementing and managing Stripe webhooks, covering best practices for secure, reliable webhook processing.

## Table of Contents

1. [Introduction to Webhooks](#introduction-to-webhooks)
2. [Webhook Endpoint Setup](#webhook-endpoint-setup)
3. [Event Types and Handling](#event-types-and-handling)
4. [Signature Verification](#signature-verification)
5. [Idempotent Event Processing](#idempotent-event-processing)
6. [Testing with Stripe CLI](#testing-with-stripe-cli)
7. [Event Ordering and Duplicates](#event-ordering-and-duplicates)
8. [Handling API Versions](#handling-api-versions)
9. [Event Replay and Debugging](#event-replay-and-debugging)
10. [Error Handling](#error-handling)

## Introduction to Webhooks

Webhooks are HTTP callbacks that Stripe sends to your application when events occur in your account, such as successful payments, subscription updates, or failed charges.

**Why Webhooks Matter:**

- Real-time notifications of account events
- Reliable event delivery with retries
- Asynchronous processing of payment events
- Support for subscription lifecycle management
- Integration with business logic and other systems

**Critical Webhook Events:**

- `payment_intent.succeeded` - Confirms successful payment
- `payment_intent.payment_failed` - Indicates payment failure
- `customer.subscription.created` - New subscription created
- `customer.subscription.updated` - Subscription details changed
- `customer.subscription.deleted` - Subscription canceled or ended
- `invoice.payment_succeeded` - Invoice paid successfully
- `invoice.payment_failed` - Failed payment on invoice

## Webhook Endpoint Setup

### Creating a Webhook Endpoint

In a Next.js application, create a dedicated API route for webhook handling:

```typescript
// pages/api/webhooks/stripe.ts
import { NextApiRequest, NextApiResponse } from "next";
import { buffer } from "micro";
import Stripe from "stripe";
import { stripe } from "@/lib/stripe";
import { processStripeEvent } from "@/services/webhook-service";
import { logger } from "@/lib/logger";

// Disable body parsing, need raw body for signature verification
export const config = {
  api: {
    bodyParser: false,
  },
};

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  // Get Stripe signature from headers
  const signature = req.headers["stripe-signature"] as string;
  if (!signature) {
    return res.status(400).json({ error: "Missing stripe-signature header" });
  }

  try {
    // Get raw request body for signature verification
    const rawBody = await buffer(req);

    // Verify event signature
    const event = stripe.webhooks.constructEvent(
      rawBody,
      signature,
      process.env.STRIPE_WEBHOOK_SECRET!
    );

    // Process the event
    await processStripeEvent(event);

    // Return a 200 success response
    return res.status(200).json({ received: true });
  } catch (err) {
    const error = err as Error;
    logger.error("Webhook error:", error.message);
    return res.status(400).json({ error: `Webhook Error: ${error.message}` });
  }
}
```

### Configuring Stripe Webhooks

1. **Register webhook endpoint in Stripe Dashboard:**

   - Go to the [Stripe Dashboard](https://dashboard.stripe.com/webhooks)
   - Click "Add endpoint"
   - Enter your webhook URL (e.g., `https://your-domain.com/api/webhooks/stripe`)
   - Select the events you want to receive
   - Save and retrieve your webhook signing secret

2. **Configure environment variables:**

```
# .env.local
STRIPE_WEBHOOK_SECRET=whsec_...
```

## Event Types and Handling

Create a dedicated service for processing webhook events:

```typescript
// services/webhook-service.ts
import Stripe from "stripe";
import { db } from "@/lib/db";
import { logger } from "@/lib/logger";

export async function processStripeEvent(event: Stripe.Event): Promise<void> {
  // Check if we've processed this event before
  const isProcessed = await checkEventProcessed(event.id);
  if (isProcessed) {
    logger.info(`Webhook event already processed: ${event.id}`);
    return;
  }

  // Process based on event type
  try {
    switch (event.type) {
      // Payment Intent events
      case "payment_intent.succeeded":
        await handlePaymentIntentSucceeded(
          event.data.object as Stripe.PaymentIntent
        );
        break;
      case "payment_intent.payment_failed":
        await handlePaymentIntentFailed(
          event.data.object as Stripe.PaymentIntent
        );
        break;

      // Subscription events
      case "customer.subscription.created":
        await handleSubscriptionCreated(
          event.data.object as Stripe.Subscription
        );
        break;
      case "customer.subscription.updated":
        await handleSubscriptionUpdated(
          event.data.object as Stripe.Subscription
        );
        break;
      case "customer.subscription.deleted":
        await handleSubscriptionDeleted(
          event.data.object as Stripe.Subscription
        );
        break;

      // Invoice events
      case "invoice.payment_succeeded":
        await handleInvoicePaymentSucceeded(
          event.data.object as Stripe.Invoice
        );
        break;
      case "invoice.payment_failed":
        await handleInvoicePaymentFailed(event.data.object as Stripe.Invoice);
        break;

      // Other events
      default:
        logger.info(`Unhandled event type: ${event.type}`);
    }

    // Mark event as processed
    await markEventProcessed(event.id);
  } catch (error) {
    logger.error(`Error processing webhook event ${event.id}:`, error);
    throw error; // Rethrow to trigger Stripe retry
  }
}

// Event handler implementations
async function handlePaymentIntentSucceeded(
  paymentIntent: Stripe.PaymentIntent
): Promise<void> {
  logger.info(`Payment succeeded: ${paymentIntent.id}`);

  // Extract metadata
  const { userId, orderId } = paymentIntent.metadata;

  if (orderId) {
    // Update order status
    await db.order.update({
      where: { id: orderId },
      data: { status: "PAID", paymentIntentId: paymentIntent.id },
    });
  }

  // Additional business logic
  // ...
}

async function handlePaymentIntentFailed(
  paymentIntent: Stripe.PaymentIntent
): Promise<void> {
  logger.info(`Payment failed: ${paymentIntent.id}`);

  const { userId, orderId } = paymentIntent.metadata;

  if (orderId) {
    // Update order status
    await db.order.update({
      where: { id: orderId },
      data: { status: "PAYMENT_FAILED" },
    });

    // Notify user of payment failure
    // ...
  }
}

// Implement additional event handlers
// ...

// Idempotency helpers
async function checkEventProcessed(eventId: string): Promise<boolean> {
  const existingEvent = await db.stripeEvent.findUnique({
    where: { id: eventId },
  });

  return !!existingEvent;
}

async function markEventProcessed(eventId: string): Promise<void> {
  await db.stripeEvent.create({
    data: {
      id: eventId,
      processedAt: new Date(),
    },
  });
}
```

## Signature Verification

Stripe signs webhook events with a secret key to ensure they come from Stripe and haven't been tampered with.

```typescript
// lib/webhook-verification.ts
import Stripe from "stripe";
import { stripe } from "./stripe";
import { logger } from "./logger";

export function verifyStripeSignature(
  payload: Buffer,
  signature: string,
  webhookSecret: string
): Stripe.Event {
  try {
    // Verify the event using the webhook secret
    return stripe.webhooks.constructEvent(payload, signature, webhookSecret);
  } catch (err) {
    const error = err as Error;
    logger.error("Webhook signature verification failed:", error.message);
    throw new Error(`Webhook signature verification failed: ${error.message}`);
  }
}

// Check timestamp tolerance
export function isWithinTimestampTolerance(
  timestamp: number,
  tolerance: number = 300 // 5 minutes in seconds
): boolean {
  const now = Math.floor(Date.now() / 1000);
  return Math.abs(now - timestamp) <= tolerance;
}
```

## Idempotent Event Processing

Implement idempotent event processing to handle webhook retries and duplicate events:

```typescript
// models/webhook-event.ts
import { prisma } from "@/lib/prisma";

// Database model for tracking processed events
// In your Prisma schema:
//
// model StripeEvent {
//   id          String   @id
//   processedAt DateTime
//   eventType   String
//   objectId    String
//   metadata    Json?
// }

// Check if an event has already been processed
export async function isEventProcessed(eventId: string): Promise<boolean> {
  const event = await prisma.stripeEvent.findUnique({
    where: { id: eventId },
  });

  return !!event;
}

// Mark an event as processed
export async function recordProcessedEvent(
  eventId: string,
  eventType: string,
  objectId: string,
  metadata: Record<string, any> = {}
): Promise<void> {
  await prisma.stripeEvent.create({
    data: {
      id: eventId,
      processedAt: new Date(),
      eventType,
      objectId,
      metadata,
    },
  });
}

// Advanced: Check for duplicate events with different IDs but same underlying action
export async function isDuplicateAction(
  eventType: string,
  objectId: string,
  timeWindowSeconds: number = 60
): Promise<boolean> {
  const timeThreshold = new Date();
  timeThreshold.setSeconds(timeThreshold.getSeconds() - timeWindowSeconds);

  const count = await prisma.stripeEvent.count({
    where: {
      eventType,
      objectId,
      processedAt: {
        gte: timeThreshold,
      },
    },
  });

  return count > 0;
}
```

## Testing with Stripe CLI

The Stripe CLI allows you to test webhooks locally by forwarding events to your local development environment.

### Setting Up the Stripe CLI

1. **Install the Stripe CLI:**

   - Follow instructions at [https://stripe.com/docs/stripe-cli](https://stripe.com/docs/stripe-cli)

2. **Login to your Stripe account:**

   ```bash
   stripe login
   ```

3. **Forward webhooks to your local server:**

   ```bash
   stripe listen --forward-to localhost:3000/api/webhooks/stripe
   ```

   The CLI will display a webhook signing secret to use in your local environment.

### Testing Webhook Events

Trigger test webhook events using the CLI:

```bash
# Trigger a specific event
stripe trigger payment_intent.succeeded

# Trigger with custom data
stripe trigger payment_intent.succeeded --data '{"amount": 2000, "currency": "usd"}'
```

## Event Ordering and Duplicates

Stripe does not guarantee events will arrive in order or that they won't be duplicated. Implement the following strategies:

### Handling Out-of-Order Events

```typescript
// services/webhook-event-ordering.ts
import { prisma } from "@/lib/prisma";
import { logger } from "@/lib/logger";

// Check if a newer version of this event has already been processed
export async function isNewerEventProcessed(
  objectId: string,
  objectType: string,
  timestamp: number
): Promise<boolean> {
  const latestEvent = await prisma.stripeEvent.findFirst({
    where: {
      objectId,
      eventType: {
        startsWith: `${objectType}.`,
      },
    },
    orderBy: {
      processedAt: "desc",
    },
  });

  if (!latestEvent) {
    return false;
  }

  // Get the event timestamp from metadata
  const latestTimestamp = latestEvent.metadata?.timestamp as number;

  // If we have a timestamp and it's newer than the current event, this is an out-of-order event
  return !!latestTimestamp && latestTimestamp > timestamp;
}

// State-based processing for subscriptions
export async function processSubscriptionUpdate(
  subscription: any
): Promise<void> {
  // Get current subscription state from database
  const dbSubscription = await prisma.subscription.findUnique({
    where: { stripeId: subscription.id },
  });

  if (!dbSubscription) {
    // New subscription, create it
    await prisma.subscription.create({
      data: {
        stripeId: subscription.id,
        status: subscription.status,
        currentPeriodEnd: new Date(subscription.current_period_end * 1000),
        // Other fields...
      },
    });
    return;
  }

  // Compare states and update only if needed
  if (
    dbSubscription.status !== subscription.status ||
    dbSubscription.currentPeriodEnd.getTime() !==
      new Date(subscription.current_period_end * 1000).getTime()
  ) {
    // State change detected, update the record
    await prisma.subscription.update({
      where: { id: dbSubscription.id },
      data: {
        status: subscription.status,
        currentPeriodEnd: new Date(subscription.current_period_end * 1000),
        // Update other fields as needed
      },
    });

    // Log the state change
    logger.info(
      `Subscription ${subscription.id} updated: ${dbSubscription.status} -> ${subscription.status}`
    );
  } else {
    logger.info(`No changes detected for subscription ${subscription.id}`);
  }
}
```

## Handling API Versions

Stripe API objects may change structure between versions. Implement version handling:

```typescript
// lib/stripe-versioning.ts
import { logger } from "./logger";

// Known Stripe API versions and their compatibility
const SUPPORTED_VERSIONS = ["2023-10-16", "2023-08-16", "2023-05-31"];
const CURRENT_VERSION = "2023-10-16";

// Check if an event's API version is supported
export function isVersionSupported(version: string): boolean {
  return SUPPORTED_VERSIONS.includes(version);
}

// Handle version-specific object differences
export function normalizeEventObject(object: any, version: string): any {
  // If current version, no normalization needed
  if (version === CURRENT_VERSION) {
    return object;
  }

  // Clone the object to avoid modifying the original
  const normalized = { ...object };

  // Example: In older versions, some field might have a different name
  if (version === "2023-05-31" && object.type === "subscription") {
    // Map fields from old version to current structure
    if ("trial_end" in normalized && !("trial_end_at" in normalized)) {
      normalized.trial_end_at = normalized.trial_end;
    }
  }

  // Log version differences
  if (version !== CURRENT_VERSION) {
    logger.info(
      `Normalized event from version ${version} to ${CURRENT_VERSION}`
    );
  }

  return normalized;
}
```

## Event Replay and Debugging

Implement tools for event replay and debugging:

```typescript
// services/webhook-replay.ts
import Stripe from "stripe";
import { stripe } from "@/lib/stripe";
import { logger } from "@/lib/logger";
import { processStripeEvent } from "./webhook-service";

// Replay a specific event by ID
export async function replayEvent(eventId: string): Promise<void> {
  try {
    // Retrieve the event from Stripe
    const event = await stripe.events.retrieve(eventId);

    logger.info(`Replaying event ${eventId} (${event.type})`);

    // Process the event
    await processStripeEvent(event);

    logger.info(`Successfully replayed event ${eventId}`);
  } catch (error) {
    logger.error(`Failed to replay event ${eventId}:`, error);
    throw error;
  }
}

// Replay a batch of events for a specific object
export async function replayEventsForObject(
  objectId: string,
  objectType: string,
  startTimestamp?: number
): Promise<void> {
  try {
    // Build query parameters
    const params: Stripe.EventListParams = {
      limit: 100,
      type: `${objectType}.*`,
    };

    // If we have a start timestamp, add it to the query
    if (startTimestamp) {
      params.created = {
        gte: startTimestamp,
      };
    }

    // Get events from Stripe
    const events = await stripe.events.list(params);

    // Filter for events related to our object
    const relevantEvents = events.data.filter((event) => {
      const object = event.data.object as any;
      return object && object.id === objectId;
    });

    // Sort events by created timestamp to process in order
    relevantEvents.sort((a, b) => a.created - b.created);

    logger.info(
      `Replaying ${relevantEvents.length} events for ${objectType} ${objectId}`
    );

    // Process each event
    for (const event of relevantEvents) {
      await processStripeEvent(event);
      logger.info(`Replayed event ${event.id} (${event.type})`);
    }

    logger.info(`Finished replaying events for ${objectType} ${objectId}`);
  } catch (error) {
    logger.error(
      `Failed to replay events for ${objectType} ${objectId}:`,
      error
    );
    throw error;
  }
}
```

## Error Handling

Implement robust error handling for webhook processing:

```typescript
// services/webhook-error-handling.ts
import Stripe from "stripe";
import { logger } from "@/lib/logger";
import { prisma } from "@/lib/prisma";

// Database model for tracking failed events
// In your Prisma schema:
//
// model FailedWebhookEvent {
//   id            String   @id
//   eventType     String
//   eventData     Json
//   errorMessage  String
//   errorStack    String?
//   attempts      Int      @default(1)
//   lastAttempt   DateTime @default(now())
//   createdAt     DateTime @default(now())
// }

// Record a failed webhook event
export async function recordFailedEvent(
  event: Stripe.Event,
  error: Error
): Promise<void> {
  try {
    // Store the failed event in the database
    await prisma.failedWebhookEvent.upsert({
      where: { id: event.id },
      update: {
        attempts: { increment: 1 },
        lastAttempt: new Date(),
        errorMessage: error.message,
        errorStack: error.stack,
      },
      create: {
        id: event.id,
        eventType: event.type,
        eventData: event as any,
        errorMessage: error.message,
        errorStack: error.stack,
        lastAttempt: new Date(),
      },
    });

    // Log the failure
    logger.error(`Webhook event ${event.id} processing failed:`, {
      eventType: event.type,
      error: error.message,
      objectId: (event.data.object as any).id,
    });

    // Alert for critical events
    if (isCriticalEvent(event.type)) {
      // Send alert to operations team
      // ...
    }
  } catch (dbError) {
    // If we can't even record the failure, log it critically
    logger.critical(
      `Failed to record webhook failure for ${event.id}:`,
      dbError
    );
  }
}

// Determine if an event is critical
function isCriticalEvent(eventType: string): boolean {
  const criticalEvents = [
    "payment_intent.succeeded",
    "invoice.payment_succeeded",
    "customer.subscription.deleted",
    // Add other business-critical events
  ];

  return criticalEvents.includes(eventType);
}

// Retry processing failed events
export async function retryFailedEvents(
  maxAttempts: number = 3,
  ageHours: number = 24
): Promise<void> {
  const cutoffDate = new Date();
  cutoffDate.setHours(cutoffDate.getHours() - ageHours);

  // Find failed events that we can retry
  const failedEvents = await prisma.failedWebhookEvent.findMany({
    where: {
      attempts: { lt: maxAttempts },
      lastAttempt: { gte: cutoffDate },
    },
    orderBy: {
      lastAttempt: "asc", // Process oldest first
    },
  });

  logger.info(`Retrying ${failedEvents.length} failed webhook events`);

  for (const failedEvent of failedEvents) {
    try {
      // Process the event
      const event = failedEvent.eventData as unknown as Stripe.Event;

      // Process the event (implement your event processing here)
      // await processStripeEvent(event);

      // If successful, remove from failed events
      await prisma.failedWebhookEvent.delete({
        where: { id: failedEvent.id },
      });

      logger.info(`Successfully reprocessed event ${failedEvent.id}`);
    } catch (error) {
      // Update the failed event record
      await prisma.failedWebhookEvent.update({
        where: { id: failedEvent.id },
        data: {
          attempts: { increment: 1 },
          lastAttempt: new Date(),
          errorMessage: (error as Error).message,
          errorStack: (error as Error).stack,
        },
      });

      logger.error(`Failed to reprocess event ${failedEvent.id}:`, error);
    }
  }
}
```
