# Stripe Integration Guide

This comprehensive guide covers implementing Stripe payments in the VibeCoder platform, focusing on best practices for API client setup, payment flows, and subscription management.

## Table of Contents

1. [API Client Setup](#api-client-setup)
2. [Authentication and API Keys](#authentication-and-api-keys)
3. [Common API Operations](#common-api-operations)
4. [Error Handling](#error-handling)
5. [Environment Configuration](#environment-configuration)
6. [API Versioning](#api-versioning)
7. [Currency Handling](#currency-handling)
8. [Proration and Mid-cycle Changes](#proration-and-mid-cycle-changes)
9. [Payment Retry Logic](#payment-retry-logic)
10. [Customer Portal Integration](#customer-portal-integration)

## API Client Setup

### Creating a Centralized Client

Always use a centralized Stripe client to ensure consistent configuration and error handling:

```typescript
// lib/stripe.ts
import Stripe from "stripe";
import { logger } from "./logger";

// Constants
const REQUIRED_API_VERSION = "2023-10-16";
const MAX_NETWORK_RETRIES = 3;

// Validate configuration
function validateStripeConfig() {
  const secretKey = process.env.STRIPE_SECRET_KEY;
  if (!secretKey) {
    throw new Error("STRIPE_SECRET_KEY environment variable is not defined");
  }
  return secretKey;
}

// Create and export the Stripe client instance
export const stripe = new Stripe(validateStripeConfig(), {
  apiVersion: REQUIRED_API_VERSION as any,
  maxNetworkRetries: MAX_NETWORK_RETRIES,
  appInfo: {
    name: "VibeCoder",
    version: process.env.APP_VERSION || "1.0.0",
  },
  typescript: true,
});

// Export a method to check API health
export async function checkStripeApiHealth(): Promise<boolean> {
  try {
    // Perform a lightweight API call to check if Stripe is reachable
    await stripe.balance.retrieve();
    return true;
  } catch (error) {
    logger.error("Stripe API health check failed", { error });
    return false;
  }
}

// Utility to safely handle Stripe API operations
export async function safeStripeOperation<T>(
  operation: () => Promise<T>,
  operationName: string
): Promise<T> {
  try {
    return await operation();
  } catch (error) {
    logger.error(`Stripe ${operationName} operation failed`, { error });
    throw error;
  }
}
```

## Authentication and API Keys

### API Key Management

- Store API keys in environment variables, never in code
- Use different API keys for different environments
- Rotate keys periodically and after team member departures
- Use restricted API keys with minimal permissions when possible

### Environment Variable Configuration

```
# .env.local (Never commit this file)
STRIPE_SECRET_KEY=sk_test_...
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...

# Production keys should be set in deployment environment
```

### Accessing Keys in Code

Always access keys through environment variables:

```typescript
// Server-side (API routes, etc.)
const stripeSecretKey = process.env.STRIPE_SECRET_KEY;

// Client-side (only publishable key)
const stripePublishableKey = process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY;
```

## Common API Operations

### Creating a Customer

```typescript
// services/stripe-customer.ts
import { stripe, safeStripeOperation } from "@/lib/stripe";
import { User } from "@/types";

export async function createStripeCustomer(user: User) {
  return safeStripeOperation(
    () =>
      stripe.customers.create({
        email: user.email,
        name: user.name,
        metadata: {
          userId: user.id,
          createdAt: new Date().toISOString(),
        },
      }),
    "createCustomer"
  );
}

export async function getOrCreateCustomer(user: User) {
  // First check if customer exists
  const existingCustomers = await stripe.customers.list({
    email: user.email,
    limit: 1,
  });

  if (existingCustomers.data.length > 0) {
    return existingCustomers.data[0];
  }

  // Create new customer if none exists
  return createStripeCustomer(user);
}
```

### Creating a Payment Intent

```typescript
// services/stripe-payment.ts
import { stripe, safeStripeOperation } from "@/lib/stripe";
import { getOrCreateCustomer } from "./stripe-customer";
import { User } from "@/types";

export async function createPaymentIntent(
  user: User,
  amount: number,
  currency: string,
  metadata: Record<string, string> = {}
) {
  // Get or create customer
  const customer = await getOrCreateCustomer(user);

  // Enhanced metadata
  const enhancedMetadata = {
    userId: user.id,
    userEmail: user.email,
    ...metadata,
  };

  return safeStripeOperation(
    () =>
      stripe.paymentIntents.create({
        amount,
        currency,
        customer: customer.id,
        metadata: enhancedMetadata,
        automatic_payment_methods: {
          enabled: true,
        },
      }),
    "createPaymentIntent"
  );
}
```

### Creating a Subscription

```typescript
// services/stripe-subscription.ts
import { stripe, safeStripeOperation } from "@/lib/stripe";
import { getOrCreateCustomer } from "./stripe-customer";
import { User, SubscriptionPlan } from "@/types";

export async function createSubscription(
  user: User,
  priceId: string,
  paymentMethodId?: string,
  trialDays?: number
) {
  // Get or create customer
  const customer = await getOrCreateCustomer(user);

  // If payment method provided, attach it to the customer
  if (paymentMethodId) {
    await stripe.paymentMethods.attach(paymentMethodId, {
      customer: customer.id,
    });

    // Set as default payment method
    await stripe.customers.update(customer.id, {
      invoice_settings: {
        default_payment_method: paymentMethodId,
      },
    });
  }

  // Subscription parameters
  const subscriptionParams: Stripe.SubscriptionCreateParams = {
    customer: customer.id,
    items: [{ price: priceId }],
    expand: ["latest_invoice.payment_intent"],
    metadata: {
      userId: user.id,
    },
  };

  // Add trial period if specified
  if (trialDays && trialDays > 0) {
    const trialEnd = Math.floor(Date.now() / 1000) + trialDays * 24 * 60 * 60;
    subscriptionParams.trial_end = trialEnd;
  }

  return safeStripeOperation(
    () => stripe.subscriptions.create(subscriptionParams),
    "createSubscription"
  );
}
```

## Error Handling

### Error Categorization

Implement consistent error handling for Stripe operations:

```typescript
// lib/stripe-errors.ts
import Stripe from "stripe";

export enum PaymentErrorType {
  CARD_ERROR = "card_error",
  AUTHENTICATION_ERROR = "authentication_error",
  RATE_LIMIT_ERROR = "rate_limit_error",
  API_ERROR = "api_error",
  IDEMPOTENCY_ERROR = "idempotency_error",
  INVALID_REQUEST_ERROR = "invalid_request_error",
  UNKNOWN_ERROR = "unknown_error",
}

export interface FormattedStripeError {
  type: PaymentErrorType;
  code: string | null;
  message: string;
  param: string | null;
  detail: string | null;
  isRetryable: boolean;
  userMessage: string;
}

export function formatStripeError(error: any): FormattedStripeError {
  // Default error structure
  const formattedError: FormattedStripeError = {
    type: PaymentErrorType.UNKNOWN_ERROR,
    code: null,
    message: "An unknown error occurred",
    param: null,
    detail: null,
    isRetryable: false,
    userMessage:
      "An error occurred while processing your payment. Please try again.",
  };

  // Not a Stripe error
  if (!(error instanceof Stripe.errors.StripeError)) {
    return formattedError;
  }

  // Map Stripe error type
  switch (error.type) {
    case "StripeCardError":
      formattedError.type = PaymentErrorType.CARD_ERROR;
      formattedError.isRetryable = true;
      break;
    case "StripeRateLimitError":
      formattedError.type = PaymentErrorType.RATE_LIMIT_ERROR;
      formattedError.isRetryable = true;
      break;
    case "StripeInvalidRequestError":
      formattedError.type = PaymentErrorType.INVALID_REQUEST_ERROR;
      formattedError.isRetryable = false;
      break;
    case "StripeAPIError":
      formattedError.type = PaymentErrorType.API_ERROR;
      formattedError.isRetryable = true;
      break;
    case "StripeAuthenticationError":
      formattedError.type = PaymentErrorType.AUTHENTICATION_ERROR;
      formattedError.isRetryable = false;
      break;
    case "StripeIdempotencyError":
      formattedError.type = PaymentErrorType.IDEMPOTENCY_ERROR;
      formattedError.isRetryable = false;
      break;
    default:
      formattedError.type = PaymentErrorType.UNKNOWN_ERROR;
      formattedError.isRetryable = false;
  }

  // Add specific error details
  formattedError.code = error.code || null;
  formattedError.message = error.message || "Unknown error";
  formattedError.param = error.param || null;
  formattedError.detail = error.detail || null;

  // Create user-friendly message based on error code
  if (error.code) {
    switch (error.code) {
      case "card_declined":
        formattedError.userMessage =
          "Your card was declined. Please try a different payment method.";
        break;
      case "expired_card":
        formattedError.userMessage =
          "Your card has expired. Please update your card information.";
        break;
      case "incorrect_cvc":
        formattedError.userMessage =
          "Your card's security code is incorrect. Please check and try again.";
        break;
      case "processing_error":
        formattedError.userMessage =
          "An error occurred while processing your card. Please try again later.";
        break;
      case "rate_limit":
        formattedError.userMessage =
          "Too many requests. Please try again later.";
        break;
      default:
        formattedError.userMessage =
          "An error occurred while processing your payment. Please try again.";
    }
  }

  return formattedError;
}

// Usage example
export function handleStripeError(error: any) {
  const formattedError = formatStripeError(error);

  // Log the error for monitoring
  console.error("Stripe error:", {
    type: formattedError.type,
    code: formattedError.code,
    message: formattedError.message,
    isRetryable: formattedError.isRetryable,
  });

  // Return user-friendly message
  return formattedError.userMessage;
}
```

## Environment Configuration

### Multi-environment Setup

Configure your application to handle multiple environments:

```typescript
// config/stripe.ts
export const stripeConfig = {
  development: {
    publishableKey: process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY!,
    prices: {
      basic: "price_1234_dev",
      pro: "price_5678_dev",
      enterprise: "price_9012_dev",
    },
    webhookSecret: process.env.STRIPE_WEBHOOK_SECRET!,
  },
  test: {
    publishableKey: process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY!,
    prices: {
      basic: "price_1234_test",
      pro: "price_5678_test",
      enterprise: "price_9012_test",
    },
    webhookSecret: process.env.STRIPE_WEBHOOK_SECRET!,
  },
  production: {
    publishableKey: process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY!,
    prices: {
      basic: "price_1234_prod",
      pro: "price_5678_prod",
      enterprise: "price_9012_prod",
    },
    webhookSecret: process.env.STRIPE_WEBHOOK_SECRET!,
  },
};

// Get config based on environment
export function getStripeConfig() {
  const env = process.env.NODE_ENV || "development";
  return (
    stripeConfig[env as keyof typeof stripeConfig] || stripeConfig.development
  );
}

// Get price ID for the current environment
export function getPriceId(planName: "basic" | "pro" | "enterprise") {
  const config = getStripeConfig();
  return config.prices[planName];
}
```

## API Versioning

### Handling API Version Compatibility

```typescript
// lib/stripe-version.ts
import { stripe } from "./stripe";
import { logger } from "./logger";

// Supported API versions
const SUPPORTED_VERSIONS = ["2023-10-16", "2023-08-16"];
const CURRENT_VERSION = "2023-10-16";

export async function checkApiVersionCompatibility(): Promise<boolean> {
  try {
    // Get current Stripe API version
    const account = await stripe.account.retrieve();
    const currentVersion =
      account.settings?.dashboard?.display_timezone || CURRENT_VERSION;

    // Check if version is supported
    const isSupported = SUPPORTED_VERSIONS.includes(currentVersion);

    if (!isSupported) {
      logger.warn(`Unsupported Stripe API version: ${currentVersion}`, {
        supportedVersions: SUPPORTED_VERSIONS,
      });
    }

    return isSupported;
  } catch (error) {
    logger.error("Error checking Stripe API version", { error });
    return false;
  }
}
```

## Currency Handling

### Multi-currency Support

```typescript
// utils/currency.ts
import { stripeClient } from "@/lib/stripe";

// Format amount with currency symbol
export function formatCurrency(amount: number, currency: string): string {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: currency.toUpperCase(),
  }).format(amount / 100);
}

// Format amount based on user locale
export function formatCurrencyForLocale(
  amount: number,
  currency: string,
  locale: string = "en-US"
): string {
  return new Intl.NumberFormat(locale, {
    style: "currency",
    currency: currency.toUpperCase(),
  }).format(amount / 100);
}

// Zero-decimal currencies don't need to be divided by 100
const zeroDecimalCurrencies = [
  "jpy",
  "krw",
  "vnd",
  "bif",
  "clp",
  "djf",
  "gnf",
  "kmf",
  "mga",
  "pyg",
  "rwf",
  "ugx",
  "vuv",
  "xaf",
  "xof",
  "xpf",
];

// Convert amount for display based on currency
export function convertAmountForDisplay(
  amount: number,
  currency: string
): number {
  const lowerCurrency = currency.toLowerCase();
  if (zeroDecimalCurrencies.includes(lowerCurrency)) {
    return amount;
  }
  return amount / 100;
}

// Convert amount for Stripe API based on currency
export function convertAmountForStripe(
  amount: number,
  currency: string
): number {
  const lowerCurrency = currency.toLowerCase();
  if (zeroDecimalCurrencies.includes(lowerCurrency)) {
    return Math.round(amount);
  }
  return Math.round(amount * 100);
}
```

## Proration and Mid-cycle Changes

### Handling Subscription Changes

```typescript
// services/subscription-changes.ts
import { stripe, safeStripeOperation } from "@/lib/stripe";

// Calculate proration for subscription upgrade/downgrade
export async function calculateProrationAmount(
  subscriptionId: string,
  newPriceId: string
): Promise<number> {
  // Create a preview of the updated subscription
  const preview = await safeStripeOperation(
    () => stripe.subscriptions.retrieve(subscriptionId),
    "retrieveSubscription"
  );

  // Get the current subscription item to update
  const subscriptionItemId = preview.items.data[0]?.id;

  if (!subscriptionItemId) {
    throw new Error("No subscription item found");
  }

  // Calculate proration
  const invoice = await safeStripeOperation(
    () =>
      stripe.invoices.retrieveUpcoming({
        subscription: subscriptionId,
        subscription_items: [
          {
            id: subscriptionItemId,
            price: newPriceId,
          },
        ],
      }),
    "calculateProration"
  );

  // Return the prorated amount
  return invoice.amount_due;
}

// Update subscription with proration
export async function updateSubscription(
  subscriptionId: string,
  newPriceId: string,
  prorate: boolean = true
): Promise<Stripe.Subscription> {
  // Get current subscription
  const subscription = await safeStripeOperation(
    () => stripe.subscriptions.retrieve(subscriptionId),
    "retrieveSubscription"
  );

  // Get the subscription item to update
  const subscriptionItemId = subscription.items.data[0]?.id;

  if (!subscriptionItemId) {
    throw new Error("No subscription item found");
  }

  // Update the subscription
  return safeStripeOperation(
    () =>
      stripe.subscriptions.update(subscriptionId, {
        proration_behavior: prorate ? "create_prorations" : "none",
        items: [
          {
            id: subscriptionItemId,
            price: newPriceId,
          },
        ],
      }),
    "updateSubscription"
  );
}
```

## Payment Retry Logic

### Implementing Retry Logic

```typescript
// services/payment-retry.ts
import { stripe, safeStripeOperation } from "@/lib/stripe";
import { logger } from "@/lib/logger";

// Retry a failed payment with exponential backoff
export async function retryFailedPayment(
  invoiceId: string,
  maxRetries: number = 3
): Promise<boolean> {
  let attempts = 0;
  let success = false;

  // Get the invoice
  const invoice = await safeStripeOperation(
    () => stripe.invoices.retrieve(invoiceId),
    "retrieveInvoice"
  );

  // Only retry if the invoice is open and has a payment intent
  if (invoice.status !== "open" || !invoice.payment_intent) {
    logger.warn("Cannot retry payment for invoice", {
      invoiceId,
      status: invoice.status,
      hasPaymentIntent: !!invoice.payment_intent,
    });
    return false;
  }

  // Retry payment with exponential backoff
  while (attempts < maxRetries && !success) {
    attempts++;

    try {
      // Retry the payment
      await safeStripeOperation(
        () => stripe.invoices.pay(invoiceId),
        "retryPayment"
      );

      success = true;
      logger.info("Payment retry succeeded", {
        invoiceId,
        attempt: attempts,
      });
    } catch (error) {
      // Calculate backoff time
      const backoffMs = Math.pow(2, attempts) * 1000;

      logger.warn("Payment retry failed, will retry", {
        invoiceId,
        attempt: attempts,
        nextRetryMs: backoffMs,
        error,
      });

      // Wait before retrying
      await new Promise((resolve) => setTimeout(resolve, backoffMs));
    }
  }

  return success;
}

// Determine if a payment failure is recoverable
export function isRecoverablePaymentFailure(error: any): boolean {
  if (!error.code) return false;

  // List of error codes that are potentially recoverable
  const recoverableCodes = [
    "card_declined",
    "processing_error",
    "authentication_required",
    "insufficient_funds",
    "resource_missing",
    "rate_limit",
  ];

  return recoverableCodes.includes(error.code);
}
```

## Customer Portal Integration

### Setting Up Customer Portal

```typescript
// services/customer-portal.ts
import { stripe, safeStripeOperation } from "@/lib/stripe";
import { User } from "@/types";
import { getOrCreateCustomer } from "./stripe-customer";

// Create a customer portal session
export async function createCustomerPortalSession(
  user: User,
  returnUrl: string
): Promise<string> {
  // Get or create customer
  const customer = await getOrCreateCustomer(user);

  // Create a portal session
  const session = await safeStripeOperation(
    () =>
      stripe.billingPortal.sessions.create({
        customer: customer.id,
        return_url: returnUrl,
      }),
    "createPortalSession"
  );

  return session.url;
}

// Configure the customer portal
export async function configureCustomerPortal(): Promise<void> {
  // This is typically done once through the Stripe Dashboard,
  // but can also be done programmatically

  await safeStripeOperation(
    () =>
      stripe.billingPortal.configurations.create({
        business_profile: {
          headline: "VibeCoder Subscription Management",
        },
        features: {
          subscription_cancel: {
            enabled: true,
            cancellation_reason: {
              enabled: true,
            },
          },
          subscription_update: {
            enabled: true,
            default_allowed_updates: ["price"],
            proration_behavior: "create_prorations",
          },
          customer_update: {
            enabled: true,
            allowed_updates: ["email", "address", "shipping", "phone"],
          },
          payment_method_update: {
            enabled: true,
          },
          invoice_history: {
            enabled: true,
          },
        },
      }),
    "configurePortal"
  );
}
```

## Best Practices Summary

1. **Centralized Client**: Use a single Stripe client instance with consistent configuration
2. **Error Handling**: Implement comprehensive error categorization and user-friendly messages
3. **API Keys**: Store securely in environment variables and rotate regularly
4. **Idempotency**: Use idempotency keys for critical operations to prevent duplicates
5. **Testing**: Use Stripe test mode and test cards for all development and testing
6. **Webhooks**: Implement secure webhook handling with signature verification
7. **Logging**: Log appropriate payment information for debugging and audit purposes
8. **Currency**: Handle currency formatting and conversion correctly
9. **Monitoring**: Set up monitoring for payment success rates and API health
10. **Retry Logic**: Implement intelligent retry mechanisms for recoverable failures

By following these best practices, you'll create a robust, secure, and maintainable Stripe integration for the VibeCoder platform.

---
