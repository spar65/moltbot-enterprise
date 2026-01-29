# Stripe Fraud Prevention Guide

This guide focuses on implementing effective fraud prevention measures for Stripe payments to protect revenue while maintaining a positive customer experience.

## Table of Contents

1. [Introduction](#introduction)
2. [Configuring Stripe Radar](#configuring-stripe-radar)
3. [Custom Fraud Rules](#custom-fraud-rules)
4. [Risk Assessment Implementation](#risk-assessment-implementation)
5. [Manual Review Workflows](#manual-review-workflows)
6. [Balancing Fraud Prevention and User Experience](#balancing-fraud-prevention-and-user-experience)
7. [Monitoring and Improving Detection](#monitoring-and-improving-detection)
8. [Handling Disputes and Chargebacks](#handling-disputes-and-chargebacks)
9. [3D Secure Authentication](#3d-secure-authentication)
10. [Measuring Effectiveness](#measuring-effectiveness)

## Introduction

Fraud prevention is a critical component of any payment system. Effective fraud prevention can:

- Protect revenue by preventing fraudulent transactions
- Reduce chargeback fees and penalties
- Maintain good standing with payment processors
- Protect legitimate customers from fraud
- Maintain a positive customer experience

This guide covers both using Stripe's built-in tools and implementing custom measures to prevent fraud in your application.

## Configuring Stripe Radar

Stripe Radar is Stripe's built-in fraud prevention tool that uses machine learning to identify and block fraudulent transactions.

### Enabling and Configuring Radar

1. **Enable Radar in the Stripe Dashboard:**

   - Go to Radar > Settings in the Stripe Dashboard
   - Enable Radar for your account
   - Configure block and review thresholds

2. **Standard Rules:**
   - CVC verification: Block payments with failed CVC checks
   - ZIP/Postal code verification: Block payments with failed postal code verification
   - International block list: Block payments from high-risk countries
   - Block anonymous proxies and VPNs
   - Verification requirements for high-risk payments

### Implementation in Code

```typescript
// Example: Set radar_options when creating a Payment Intent
import Stripe from "stripe";
import { stripe } from "@/lib/stripe";

async function createPaymentIntent(
  amount: number,
  currency: string,
  customerId: string,
  metadata: Record<string, string> = {}
): Promise<Stripe.PaymentIntent> {
  return await stripe.paymentIntents.create({
    amount,
    currency,
    customer: customerId,
    metadata,
    // Set Radar options
    radar_options: {
      session: {
        // Link this payment to a specific user session for better fraud detection
        session_id: metadata.sessionId,
        // Include additional data points Radar can use
        referrer: metadata.referrer,
        ip: metadata.ip,
        user_agent: metadata.userAgent,
      },
    },
  });
}
```

## Custom Fraud Rules

### Creating Rules in Dashboard

1. Navigate to Radar > Rules in the Stripe Dashboard
2. Create custom rules using Stripe's rule language
3. Set actions (block, review, allow) for each rule

### Example Rules

```
# Block transactions with high-value first-time purchases
Rule name: Block high-value first purchases
If: :charge_amount: > 100000 AND :customer_account_age: < 1d
Then: Block

# Require 3D Secure for suspicious transactions
Rule name: Require 3DS for suspicious transactions
If: :risk_score: > 50 AND :charge_amount: > 50000
Then: Require authentication
```

### Custom Rules via API

```typescript
// Custom fraud rules need to be managed via Stripe Dashboard
// You can't create rules via API, but you can add data points
// that your rules can use

// When creating a customer, add relevant metadata
await stripe.customers.create({
  email: user.email,
  name: user.name,
  metadata: {
    user_id: user.id,
    account_created_at: user.createdAt.toISOString(),
    verified: user.emailVerified ? "true" : "false",
    purchase_count: "0",
    // Add other relevant data points
  },
});

// Update metadata when user behavior changes
await stripe.customers.update(stripeCustomerId, {
  metadata: {
    purchase_count: (parseInt(customer.metadata.purchase_count) + 1).toString(),
    last_purchase_date: new Date().toISOString(),
  },
});
```

## Risk Assessment Implementation

Implement custom risk scoring for transactions:

```typescript
// services/risk-assessment.ts
import { stripe } from "@/lib/stripe";
import { prisma } from "@/lib/prisma";
import { logger } from "@/lib/logger";

interface RiskAssessment {
  score: number;
  factors: string[];
  requiresReview: boolean;
  requiresAdditionalVerification: boolean;
}

export async function assessTransactionRisk(
  paymentIntentId: string,
  userId: string,
  sessionData: {
    ip: string;
    userAgent: string;
    referrer?: string;
  }
): Promise<RiskAssessment> {
  // Retrieve the payment intent
  const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);

  // Get customer information
  const customer = await stripe.customers.retrieve(
    paymentIntent.customer as string
  );

  // Get user data from database
  const user = await prisma.user.findUnique({
    where: { id: userId },
    include: {
      orders: true,
      paymentMethods: true,
    },
  });

  if (!user) {
    throw new Error(`User not found: ${userId}`);
  }

  let riskScore = 0;
  const riskFactors: string[] = [];

  // Factor 1: New customer with high-value transaction
  if (
    customer.created > Date.now() / 1000 - 7 * 24 * 60 * 60 && // Less than 7 days old
    paymentIntent.amount > 50000 // More than $500
  ) {
    riskScore += 25;
    riskFactors.push("new_customer_high_value");
  }

  // Factor 2: Multiple payment methods added recently
  const paymentMethods = await stripe.paymentMethods.list({
    customer: customer.id,
    type: "card",
  });

  if (paymentMethods.data.length >= 3) {
    riskScore += 15;
    riskFactors.push("multiple_payment_methods");
  }

  // Factor 3: Mismatched billing/shipping country
  if (
    paymentIntent.shipping &&
    customer.address &&
    paymentIntent.shipping.address.country !== customer.address.country
  ) {
    riskScore += 20;
    riskFactors.push("country_mismatch");
  }

  // Factor 4: Previous payment failures
  const recentCharges = await stripe.charges.list({
    customer: customer.id,
    created: { gte: Math.floor(Date.now() / 1000) - 30 * 24 * 60 * 60 }, // Last 30 days
  });

  const failedCharges = recentCharges.data.filter((charge) => !charge.paid);
  if (failedCharges.length >= 2) {
    riskScore += 20;
    riskFactors.push("previous_failures");
  }

  // Factor 5: Velocity check - too many purchases in short time
  const recentOrders = user.orders.filter(
    (order) =>
      new Date(order.createdAt) > new Date(Date.now() - 24 * 60 * 60 * 1000)
  );

  if (recentOrders.length >= 3) {
    riskScore += 20;
    riskFactors.push("velocity_check_failed");
  }

  // Calculate final risk assessment
  const requiresReview = riskScore >= 50;
  const requiresAdditionalVerification = riskScore >= 30;

  // Log the risk assessment
  logger.info(`Risk assessment for payment ${paymentIntentId}:`, {
    score: riskScore,
    factors: riskFactors,
    requiresReview,
    requiresAdditionalVerification,
  });

  // Store the risk assessment
  await prisma.riskAssessment.create({
    data: {
      paymentIntentId,
      userId,
      score: riskScore,
      factors: riskFactors,
      requiresReview,
      requiresAdditionalVerification,
      ipAddress: sessionData.ip,
      userAgent: sessionData.userAgent,
      assessedAt: new Date(),
    },
  });

  return {
    score: riskScore,
    factors: riskFactors,
    requiresReview,
    requiresAdditionalVerification,
  };
}
```

## Manual Review Workflows

For suspicious transactions that require human review:

```typescript
// services/review-workflow.ts
import { prisma } from "@/lib/prisma";
import { stripe } from "@/lib/stripe";
import { logger } from "@/lib/logger";
import { sendNotification } from "@/lib/notifications";

// Review statuses
export enum ReviewStatus {
  PENDING = "PENDING",
  APPROVED = "APPROVED",
  REJECTED = "REJECTED",
  ADDITIONAL_INFO_REQUIRED = "ADDITIONAL_INFO_REQUIRED",
}

// Create a payment review
export async function createPaymentReview(
  paymentIntentId: string,
  riskScore: number,
  riskFactors: string[]
): Promise<void> {
  // Get payment intent details
  const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);

  // Create a review record
  await prisma.paymentReview.create({
    data: {
      paymentIntentId,
      customerId: paymentIntent.customer as string,
      amount: paymentIntent.amount,
      currency: paymentIntent.currency,
      riskScore,
      riskFactors,
      status: ReviewStatus.PENDING,
      createdAt: new Date(),
    },
  });

  // Notify fraud review team
  await sendNotification({
    type: "FRAUD_REVIEW",
    message: `New payment review needed for ${paymentIntentId} (Risk: ${riskScore})`,
    data: {
      paymentIntentId,
      riskScore,
      riskFactors,
      amount: formatCurrency(paymentIntent.amount, paymentIntent.currency),
    },
  });

  logger.info(`Created payment review for ${paymentIntentId}`);
}

// Approve a payment after review
export async function approvePaymentReview(
  reviewId: string,
  reviewerId: string,
  notes: string
): Promise<void> {
  // Get the review
  const review = await prisma.paymentReview.findUnique({
    where: { id: reviewId },
  });

  if (!review) {
    throw new Error(`Review not found: ${reviewId}`);
  }

  // Update the review status
  await prisma.paymentReview.update({
    where: { id: reviewId },
    data: {
      status: ReviewStatus.APPROVED,
      reviewerId,
      reviewedAt: new Date(),
      notes,
    },
  });

  // Capture the payment if it was previously uncaptured
  if (review.paymentIntentId) {
    const paymentIntent = await stripe.paymentIntents.retrieve(
      review.paymentIntentId
    );

    if (paymentIntent.status === "requires_capture") {
      await stripe.paymentIntents.capture(review.paymentIntentId);
    }
  }

  // Notify relevant teams
  await sendNotification({
    type: "PAYMENT_REVIEW_COMPLETED",
    message: `Payment review ${reviewId} approved by ${reviewerId}`,
    data: { reviewId, status: "APPROVED", notes },
  });

  logger.info(`Approved payment review ${reviewId}`);
}

// Reject a payment after review
export async function rejectPaymentReview(
  reviewId: string,
  reviewerId: string,
  notes: string,
  refundIfPossible: boolean = true
): Promise<void> {
  // Get the review
  const review = await prisma.paymentReview.findUnique({
    where: { id: reviewId },
  });

  if (!review) {
    throw new Error(`Review not found: ${reviewId}`);
  }

  // Update the review status
  await prisma.paymentReview.update({
    where: { id: reviewId },
    data: {
      status: ReviewStatus.REJECTED,
      reviewerId,
      reviewedAt: new Date(),
      notes,
    },
  });

  // If payment has been captured and refund is requested
  if (refundIfPossible && review.paymentIntentId) {
    const paymentIntent = await stripe.paymentIntents.retrieve(
      review.paymentIntentId
    );

    if (paymentIntent.status === "succeeded") {
      // Find the charge
      const charges = await stripe.charges.list({
        payment_intent: paymentIntent.id,
      });

      if (charges.data.length > 0) {
        // Refund the payment
        await stripe.refunds.create({
          charge: charges.data[0].id,
          reason: "fraudulent",
        });
      }
    } else if (paymentIntent.status === "requires_capture") {
      // Cancel instead of capturing
      await stripe.paymentIntents.cancel(paymentIntent.id, {
        cancellation_reason: "fraudulent",
      });
    }
  }

  // Notify relevant teams
  await sendNotification({
    type: "PAYMENT_REVIEW_COMPLETED",
    message: `Payment review ${reviewId} rejected by ${reviewerId}`,
    data: { reviewId, status: "REJECTED", notes },
  });

  logger.info(`Rejected payment review ${reviewId}`);
}
```

## Balancing Fraud Prevention and User Experience

```typescript
// hooks/usePaymentFlow.ts
import { useState, useEffect } from "react";
import { assessTransactionRisk } from "@/services/risk-assessment";
import { useSession } from "next-auth/react";

export function usePaymentFlow(paymentIntentId: string | null) {
  const [verification, setVerification] = useState<{
    required: boolean;
    type: "none" | "3ds" | "email" | "phone";
  }>({
    required: false,
    type: "none",
  });

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const { data: session } = useSession();

  useEffect(() => {
    async function checkRisk() {
      if (!paymentIntentId || !session?.user?.id) return;

      setLoading(true);

      try {
        // Get session data
        const sessionData = {
          ip: window.clientInformation?.ip || "",
          userAgent: navigator.userAgent,
          referrer: document.referrer,
        };

        // Assess transaction risk
        const risk = await assessTransactionRisk(
          paymentIntentId,
          session.user.id,
          sessionData
        );

        // Determine verification requirements
        if (risk.requiresAdditionalVerification) {
          if (risk.score >= 50) {
            // Higher risk - require 3DS
            setVerification({
              required: true,
              type: "3ds",
            });
          } else if (risk.score >= 30) {
            // Medium risk - require email verification
            setVerification({
              required: true,
              type: "email",
            });
          }
        }
      } catch (err) {
        setError((err as Error).message);
      } finally {
        setLoading(false);
      }
    }

    checkRisk();
  }, [paymentIntentId, session?.user?.id]);

  // Return the verification requirements
  return {
    verification,
    loading,
    error,
  };
}
```

## Monitoring and Improving Detection

### Metrics to Track

- False positive rate
- False negative rate
- Review queue length and time
- Chargeback rate
- Transaction decline rate
- Average risk score

### Implementing a Feedback Loop

```typescript
// services/fraud-feedback.ts
import { prisma } from "@/lib/prisma";
import { logger } from "@/lib/logger";

// Record fraud feedback for a transaction
export async function recordFraudFeedback(
  paymentIntentId: string,
  outcome: "legitimate" | "fraudulent",
  source: "chargeback" | "customer_service" | "manual_review",
  notes: string = ""
): Promise<void> {
  // Find the risk assessment
  const riskAssessment = await prisma.riskAssessment.findFirst({
    where: { paymentIntentId },
  });

  // Record the feedback
  await prisma.fraudFeedback.create({
    data: {
      paymentIntentId,
      riskAssessmentId: riskAssessment?.id,
      outcome,
      source,
      notes,
      recordedAt: new Date(),
    },
  });

  // Log the feedback
  logger.info(`Fraud feedback for ${paymentIntentId}: ${outcome}`, {
    paymentIntentId,
    outcome,
    source,
    riskScore: riskAssessment?.score,
  });
}

// Get feedback statistics to evaluate the fraud system
export async function getFraudDetectionStats(
  startDate: Date,
  endDate: Date
): Promise<any> {
  // Get all feedback in date range
  const feedback = await prisma.fraudFeedback.findMany({
    where: {
      recordedAt: {
        gte: startDate,
        lte: endDate,
      },
    },
    include: {
      riskAssessment: true,
    },
  });

  // Calculate statistics
  const total = feedback.length;
  const legitimate = feedback.filter((f) => f.outcome === "legitimate").length;
  const fraudulent = total - legitimate;

  // False positives: marked as high risk but was legitimate
  const falsePositives = feedback.filter(
    (f) => f.outcome === "legitimate" && f.riskAssessment?.score >= 50
  ).length;

  // False negatives: marked as low risk but was fraudulent
  const falseNegatives = feedback.filter(
    (f) => f.outcome === "fraudulent" && f.riskAssessment?.score < 30
  ).length;

  // Calculate rates
  const falsePositiveRate = total > 0 ? falsePositives / total : 0;
  const falseNegativeRate = total > 0 ? falseNegatives / total : 0;
  const accuracy =
    total > 0 ? (total - falsePositives - falseNegatives) / total : 0;

  return {
    period: {
      start: startDate,
      end: endDate,
    },
    counts: {
      total,
      legitimate,
      fraudulent,
      falsePositives,
      falseNegatives,
    },
    rates: {
      falsePositiveRate,
      falseNegativeRate,
      accuracy,
    },
  };
}
```

## Handling Disputes and Chargebacks

### Webhook Handling for Disputes

```typescript
// services/dispute-handler.ts
import Stripe from "stripe";
import { stripe } from "@/lib/stripe";
import { prisma } from "@/lib/prisma";
import { logger } from "@/lib/logger";
import { sendNotification } from "@/lib/notifications";

// Handle dispute.created webhook event
export async function handleDisputeCreated(
  dispute: Stripe.Dispute
): Promise<void> {
  logger.warn(`Dispute created: ${dispute.id}`, {
    amount: dispute.amount,
    reason: dispute.reason,
    status: dispute.status,
    chargeId: dispute.charge,
  });

  // Find the related order
  const payment = await prisma.payment.findFirst({
    where: { stripeChargeId: dispute.charge as string },
    include: {
      order: {
        include: {
          user: true,
        },
      },
    },
  });

  // Create a dispute record
  await prisma.dispute.create({
    data: {
      stripeDisputeId: dispute.id,
      stripeChargeId: dispute.charge as string,
      orderId: payment?.order?.id,
      userId: payment?.order?.user?.id,
      amount: dispute.amount,
      currency: dispute.currency,
      reason: dispute.reason,
      status: dispute.status,
      evidenceDueBy: dispute.evidence_details?.due_by
        ? new Date(dispute.evidence_details.due_by * 1000)
        : null,
      createdAt: new Date(dispute.created * 1000),
    },
  });

  // Send notification to the team
  await sendNotification({
    type: "DISPUTE_CREATED",
    message: `New dispute ${dispute.id} for ${formatCurrency(
      dispute.amount,
      dispute.currency
    )}`,
    data: {
      disputeId: dispute.id,
      amount: dispute.amount,
      reason: dispute.reason,
      order: payment?.order?.id,
      user: payment?.order?.user?.id,
      dueBy: dispute.evidence_details?.due_by,
    },
  });

  // Record fraud feedback
  if (payment?.stripePaymentIntentId) {
    await recordFraudFeedback(
      payment.stripePaymentIntentId,
      "fraudulent",
      "chargeback",
      `Dispute reason: ${dispute.reason}`
    );
  }
}

// Submit evidence for a dispute
export async function submitDisputeEvidence(
  disputeId: string,
  evidence: {
    customerName?: string;
    customerEmail?: string;
    customerPurchaseIp?: string;
    productDescription?: string;
    customerSignature?: string;
    billingAddress?: string;
    receipt?: string;
    customerCommunication?: string;
    serviceDate?: string;
    serviceDocumentation?: string;
    duplicateChargeId?: string;
    duplicateChargeDocumentation?: string;
    duplicateChargeExplanation?: string;
    refundPolicy?: string;
    refundPolicyDisclosure?: string;
    cancellationPolicy?: string;
    cancellationPolicyDisclosure?: string;
    accessActivityLogs?: string;
    shippingAddress?: string;
    shippingDate?: string;
    shippingCarrier?: string;
    shippingTrackingNumber?: string;
    shippingDocumentation?: string;
    uncategorizedText?: string;
    uncategorizedFile?: string;
  }
): Promise<void> {
  // Update the dispute with the evidence
  await stripe.disputes.update(disputeId, {
    evidence: evidence,
  });

  // Submit the evidence
  await stripe.disputes.submit(disputeId);

  // Update the dispute record
  await prisma.dispute.update({
    where: { stripeDisputeId: disputeId },
    data: {
      evidenceSubmittedAt: new Date(),
      status: "submitted_evidence",
    },
  });

  logger.info(`Evidence submitted for dispute ${disputeId}`);
}
```

## 3D Secure Authentication

### Implementing 3D Secure

```typescript
// components/PaymentForm.tsx
import { useState } from "react";
import { CardElement, useStripe, useElements } from "@stripe/react-stripe-js";
import { usePaymentFlow } from "@/hooks/usePaymentFlow";

export function PaymentForm({ clientSecret, amount, currency }) {
  const stripe = useStripe();
  const elements = useElements();
  const [error, setError] = useState(null);
  const [processing, setProcessing] = useState(false);

  const { verification } = usePaymentFlow(clientSecret?.split("_secret_")[0]);

  const handleSubmit = async (event) => {
    event.preventDefault();

    if (!stripe || !elements) {
      return;
    }

    setProcessing(true);

    try {
      // Get card element
      const cardElement = elements.getElement(CardElement);

      // Confirm the payment with 3D Secure if required
      const { error, paymentIntent } = await stripe.confirmCardPayment(
        clientSecret,
        {
          payment_method: {
            card: cardElement,
            billing_details: {
              // Include billing details
            },
          },
        }
      );

      if (error) {
        setError(error.message);
      } else if (paymentIntent.status === "succeeded") {
        // Payment successful
        window.location.href = "/payment/success";
      } else if (paymentIntent.status === "requires_action") {
        // 3D Secure authentication required
        const { error, paymentIntent: updatedIntent } =
          await stripe.confirmCardPayment(clientSecret);

        if (error) {
          setError(error.message);
        } else if (updatedIntent.status === "succeeded") {
          // Payment successful after 3D Secure
          window.location.href = "/payment/success";
        }
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setProcessing(false);
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      <div className="mb-4">
        <label className="block text-sm font-medium text-gray-700">
          Card details
        </label>
        <div className="mt-1">
          <CardElement className="p-3 border rounded-md shadow-sm" />
        </div>
      </div>

      {verification.required && verification.type === "3ds" && (
        <div className="mb-4 p-3 bg-blue-50 text-blue-700 rounded-md">
          <p className="text-sm">
            For your security, this payment may require additional verification.
            You might be redirected to your bank's website to complete
            authentication.
          </p>
        </div>
      )}

      {error && (
        <div className="mb-4 p-3 bg-red-50 text-red-700 rounded-md">
          {error}
        </div>
      )}

      <button
        type="submit"
        disabled={!stripe || processing}
        className="w-full py-2 px-4 border border-transparent rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50"
      >
        {processing
          ? "Processing..."
          : `Pay ${new Intl.NumberFormat("en-US", {
              style: "currency",
              currency: currency,
            }).format(amount / 100)}`}
      </button>
    </form>
  );
}
```

## Measuring Effectiveness

### Fraud Dashboard Implementation

```typescript
// pages/admin/fraud-dashboard.tsx
import { useState, useEffect } from "react";
import { getFraudDetectionStats } from "@/services/fraud-feedback";
import { LineChart, BarChart } from "@/components/Charts";
import { DateRangePicker } from "@/components/DateRangePicker";

export default function FraudDashboard() {
  const [dateRange, setDateRange] = useState({
    start: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000), // 30 days ago
    end: new Date(),
  });

  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function loadStats() {
      setLoading(true);
      try {
        const data = await getFraudDetectionStats(
          dateRange.start,
          dateRange.end
        );
        setStats(data);
      } catch (error) {
        console.error("Failed to load fraud stats:", error);
      } finally {
        setLoading(false);
      }
    }

    loadStats();
  }, [dateRange]);

  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-2xl font-bold mb-4">Fraud Detection Dashboard</h1>

      <DateRangePicker
        startDate={dateRange.start}
        endDate={dateRange.end}
        onChange={setDateRange}
        className="mb-6"
      />

      {loading ? (
        <div className="text-center py-12">Loading...</div>
      ) : stats ? (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="bg-white p-6 rounded-lg shadow">
            <h2 className="text-lg font-semibold mb-4">
              Fraud Detection Accuracy
            </h2>
            <div className="grid grid-cols-3 gap-4 mb-6">
              <div className="text-center">
                <div className="text-3xl font-bold text-green-600">
                  {(stats.rates.accuracy * 100).toFixed(1)}%
                </div>
                <div className="text-sm text-gray-500">Accuracy</div>
              </div>
              <div className="text-center">
                <div className="text-3xl font-bold text-yellow-600">
                  {(stats.rates.falsePositiveRate * 100).toFixed(1)}%
                </div>
                <div className="text-sm text-gray-500">False Positives</div>
              </div>
              <div className="text-center">
                <div className="text-3xl font-bold text-red-600">
                  {(stats.rates.falseNegativeRate * 100).toFixed(1)}%
                </div>
                <div className="text-sm text-gray-500">False Negatives</div>
              </div>
            </div>

            <BarChart
              data={[
                {
                  name: "Accuracy",
                  value: stats.rates.accuracy * 100,
                  color: "green",
                },
                {
                  name: "False Positives",
                  value: stats.rates.falsePositiveRate * 100,
                  color: "yellow",
                },
                {
                  name: "False Negatives",
                  value: stats.rates.falseNegativeRate * 100,
                  color: "red",
                },
              ]}
            />
          </div>

          <div className="bg-white p-6 rounded-lg shadow">
            <h2 className="text-lg font-semibold mb-4">
              Fraud Detection Counts
            </h2>
            <div className="grid grid-cols-3 gap-4 mb-6">
              <div className="text-center">
                <div className="text-3xl font-bold">{stats.counts.total}</div>
                <div className="text-sm text-gray-500">Total Transactions</div>
              </div>
              <div className="text-center">
                <div className="text-3xl font-bold text-green-600">
                  {stats.counts.legitimate}
                </div>
                <div className="text-sm text-gray-500">Legitimate</div>
              </div>
              <div className="text-center">
                <div className="text-3xl font-bold text-red-600">
                  {stats.counts.fraudulent}
                </div>
                <div className="text-sm text-gray-500">Fraudulent</div>
              </div>
            </div>

            <BarChart
              data={[
                {
                  name: "Legitimate",
                  value: stats.counts.legitimate,
                  color: "green",
                },
                {
                  name: "Fraudulent",
                  value: stats.counts.fraudulent,
                  color: "red",
                },
              ]}
            />
          </div>

          {/* Additional charts and metrics */}
        </div>
      ) : (
        <div className="text-center py-12">No data available</div>
      )}
    </div>
  );
}
```

## Conclusion

Implementing a robust fraud prevention system requires a combination of Stripe's built-in tools and custom logic. By carefully balancing fraud prevention with user experience, you can minimize fraud while maximizing legitimate conversions.

Key takeaways:

1. Use Stripe Radar as your first line of defense
2. Implement custom risk assessment for additional protection
3. Create manual review workflows for edge cases
4. Monitor and improve your fraud detection system over time
5. Balance security with user experience
6. Be prepared to handle disputes and chargebacks
7. Use 3D Secure authentication strategically

Following these practices will help protect your business from fraud while providing a smooth experience for legitimate customers.
