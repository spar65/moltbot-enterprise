# Admin Subscription Management Guide

## Overview

This guide documents the implementation of VibeCoder's admin subscription management features, capturing our approach, technical decisions, and lessons learned. The admin subscription management system enables administrators to:

1. View and manage user subscriptions
2. Track subscription metrics and analytics
3. Troubleshoot subscription-related issues
4. Apply subscription tier changes manually when needed

## Architecture

### Core Components

The admin subscription management system consists of these key components:

1. **Admin Subscription Dashboard**

   - Route: `/admin/subscriptions`
   - Shows subscription metrics and tier distribution
   - Provides filtering and search capabilities

2. **User Subscription Management**

   - Route: `/admin/users/{userId}`
   - Shows detailed subscription history for specific users
   - Allows manual subscription tier changes
   - Shows payment and billing history

3. **Subscription API Endpoints**
   - `/api/admin/subscriptions` - Subscription metrics and listing
   - `/api/admin/users/{userId}/subscription` - User-specific subscription data
   - `/api/admin/subscription/update` - Manual subscription updates

### Data Model

The subscription data model is built around these primary entities:

1. **User**

   - Contains core user identity from Auth0
   - Links to subscription records

2. **Subscription**

   - Status (active, canceled, past_due, etc.)
   - Current tier (basic, pro, premium, etc.)
   - Start and end dates
   - Payment method information

3. **Subscription Tier**

   - Feature entitlements
   - Pricing information
   - Usage limits

4. **Transaction Records**
   - Payment history
   - Invoice data
   - Refund information

## Implementation

### Admin Authorization

Admin routes are protected using a multi-layered approach:

1. **Auth0 Role-Based Access Control**

   - Admin users are assigned the "admin" role in Auth0
   - Role information is included in the user session
   - Server-side validation of the admin role on all admin routes

2. **AdminGuard Component**
   - React component that wraps admin UI components
   - Redirects non-admin users to an unauthorized page
   - Shows loading state while checking admin status

Example implementation:

```tsx
// src/components/AdminGuard.tsx
import { useUser } from "@auth0/nextjs-auth0";
import { useRouter } from "next/router";

export function AdminGuard({ children }: { children: React.ReactNode }) {
  const { user, isLoading } = useUser();
  const router = useRouter();
  const isAdmin = user?.["https://vibecoder.com/roles"]?.includes("admin");

  if (isLoading) {
    return <AdminLoadingScreen />;
  }

  if (!isAdmin) {
    router.push("/unauthorized");
    return null;
  }

  return <>{children}</>;
}
```

### Admin API Protection

All admin API endpoints use middleware to validate admin access:

```typescript
// src/middleware/admin.ts
import { getSession } from "@auth0/nextjs-auth0";
import { NextApiRequest, NextApiResponse } from "next";

export async function adminMiddleware(
  req: NextApiRequest,
  res: NextApiResponse,
  next: () => Promise<void>
) {
  try {
    const session = await getSession(req, res);

    if (!session?.user) {
      return res.status(401).json({ error: "Not authenticated" });
    }

    const roles = session.user["https://vibecoder.com/roles"] || [];
    const isAdmin = roles.includes("admin");

    if (!isAdmin) {
      return res.status(403).json({ error: "Not authorized" });
    }

    // User is an admin, proceed to the handler
    return await next();
  } catch (error) {
    console.error("Admin middleware error:", error);
    return res.status(500).json({ error: "Internal server error" });
  }
}
```

### Subscription Data Fetching

The subscription data is fetched using a combination of database queries and Stripe API calls:

```typescript
// src/lib/subscription-admin.ts
import Stripe from "stripe";
import { sql } from "./database";

export async function getSubscriptionMetrics() {
  const results = await sql`
    SELECT 
      subscription_tier, 
      COUNT(*) as count,
      SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) as active_count,
      SUM(CASE WHEN status = 'past_due' THEN 1 ELSE 0 END) as past_due_count,
      SUM(CASE WHEN status = 'canceled' THEN 1 ELSE 0 END) as canceled_count
    FROM subscriptions
    GROUP BY subscription_tier
  `;

  return results;
}

export async function getUserSubscriptionDetails(userId: string) {
  // Get user details from database
  const user = await sql`
    SELECT * FROM users WHERE id = ${userId}
  `;

  if (!user.length) {
    throw new Error("User not found");
  }

  // Get subscription details from database
  const subscriptions = await sql`
    SELECT * FROM subscriptions WHERE user_id = ${userId}
    ORDER BY created_at DESC
  `;

  // Get additional details from Stripe if needed
  if (user[0].stripe_customer_id && subscriptions[0]?.stripe_subscription_id) {
    const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
      apiVersion: "2022-11-15",
    });

    const stripeSubscription = await stripe.subscriptions.retrieve(
      subscriptions[0].stripe_subscription_id
    );

    // Enrich subscription with Stripe data
    return {
      user: user[0],
      subscription: {
        ...subscriptions[0],
        stripeDetails: stripeSubscription,
      },
    };
  }

  return {
    user: user[0],
    subscription: subscriptions[0] || null,
  };
}
```

### Admin UI Implementation

The admin UI is built with reusable components focusing on:

1. **Consistent Layout** - All admin pages use the same layout and navigation
2. **Responsive Design** - Works well on different screen sizes
3. **Error Handling** - Graceful error states and user feedback
4. **Loading States** - Clear loading indicators for async operations

Example of the Subscription Dashboard component:

```tsx
// pages/admin/subscriptions/index.tsx
import { useEffect, useState } from "react";
import { AdminLayout } from "../../../src/components/Layout/AdminLayout";
import { AdminGuard } from "../../../src/components/AdminGuard";
import { SubscriptionMetricsChart } from "../../../src/components/Subscription/SubscriptionMetricsChart";
import { SubscriptionTable } from "../../../src/components/Subscription/SubscriptionTable";
import { fetchSubscriptionMetrics } from "../../../src/lib/api-client";

export default function SubscriptionDashboard() {
  const [metrics, setMetrics] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    async function loadMetrics() {
      try {
        setLoading(true);
        const data = await fetchSubscriptionMetrics();
        setMetrics(data);
      } catch (err) {
        setError(err.message || "Failed to load subscription metrics");
      } finally {
        setLoading(false);
      }
    }

    loadMetrics();
  }, []);

  return (
    <AdminGuard>
      <AdminLayout title="Subscription Dashboard" section="subscriptions">
        {loading ? (
          <div className="loading-spinner">Loading metrics...</div>
        ) : error ? (
          <div className="error-message">{error}</div>
        ) : (
          <>
            <div className="metrics-summary">
              <SubscriptionMetricsChart data={metrics.byTier} />
            </div>
            <div className="subscription-table-container">
              <SubscriptionTable subscriptions={metrics.recentSubscriptions} />
            </div>
          </>
        )}
      </AdminLayout>
    </AdminGuard>
  );
}
```

## Testing Approach

We implemented a comprehensive testing strategy for subscription management:

### Unit Tests

- Testing subscription calculation logic
- Testing database query functions
- Testing API endpoint handlers

Example test for subscription tier access:

```typescript
// tests/api/admin-subscription-tiers.test.ts
import { createMocks } from "node-mocks-http";
import {
  setupAuth0Mock,
  createMockAdminSession,
} from "../utils/auth0-test-utils";
import handler from "../../pages/api/admin/subscription-tiers";

describe("/api/admin/subscription-tiers", () => {
  let mockAuth0;
  const mockSql = require("../../src/lib/database").sql;

  beforeEach(() => {
    jest.clearAllMocks();
    process.env.AUTH0_SECRET = "test-secret";
    process.env.AUTH0_DOMAIN = "test.auth0.com";

    // Mock database response
    mockSql.mockResolvedValue([
      { id: "basic", name: "Basic Plan", price: 9.99 },
      { id: "pro", name: "Pro Plan", price: 19.99 },
      { id: "enterprise", name: "Enterprise", price: 49.99 },
    ]);
  });

  afterEach(() => {
    jest.resetModules();
  });

  it("should return subscription tiers for admin users", async () => {
    // Setup admin session
    mockAuth0 = setupAuth0Mock(createMockAdminSession());

    const { req, res } = createMocks({
      method: "GET",
    });

    await handler(req, res);

    expect(res._getStatusCode()).toBe(200);
    const data = JSON.parse(res._getData());
    expect(data.tiers).toHaveLength(3);
    expect(data.tiers[0].id).toBe("basic");
  });

  it("should block non-admin users", async () => {
    // Setup regular user session
    mockAuth0 = setupAuth0Mock({
      user: {
        sub: "auth0|user123",
        email: "user@example.com",
      },
    });

    const { req, res } = createMocks({
      method: "GET",
    });

    await handler(req, res);

    expect(res._getStatusCode()).toBe(403);
  });
});
```

### Integration Tests

- Testing the admin middleware flow
- Testing user subscription management workflows
- Testing database and Stripe interactions

### End-to-End Tests

We used Cypress for E2E testing of critical admin workflows:

```typescript
// cypress/e2e/admin-subscription.cy.ts
describe("Admin Subscription Management", () => {
  beforeEach(() => {
    // Login as admin user
    cy.loginAsAdmin();
  });

  it("should display subscription dashboard with metrics", () => {
    cy.visit("/admin/subscriptions");

    // Check page loads with correct title
    cy.get("h1").should("contain", "Subscription Dashboard");

    // Check metrics are displayed
    cy.get(".metrics-summary").should("be.visible");
    cy.get(".subscription-chart").should("be.visible");

    // Check subscription table loads
    cy.get(".subscription-table").should("be.visible");
    cy.get(".subscription-table tbody tr").should("have.length.at.least", 1);
  });

  it("should allow filtering subscriptions", () => {
    cy.visit("/admin/subscriptions");

    // Filter by subscription tier
    cy.get(".filter-dropdown").click();
    cy.get(".filter-option[data-value='premium']").click();

    // Check filtered results
    cy.get(".subscription-table").should("contain", "Premium");
    cy.get(".subscription-table tbody tr").each(($row) => {
      cy.wrap($row).should("contain", "Premium");
    });

    // Clear filter
    cy.get(".clear-filters").click();
    cy.get(".subscription-table tbody tr").should("have.length.at.least", 3);
  });
});
```

## Lessons Learned

### What Worked Well

1. **Separation of Concerns**

   - Keeping API endpoints separate from UI components
   - Using middleware for authorization logic
   - Clear boundaries between subscription logic and UI presentation

2. **Centralized Auth Logic**

   - Single source of truth for admin authorization
   - Consistent application of access controls
   - Reusable AdminGuard component

3. **Comprehensive Testing**
   - Multiple layers of testing from unit to E2E
   - Test utilities for Auth0 mocking
   - Testing both success and error paths

### Challenges and Solutions

1. **Auth0 Session Mocking**

   **Challenge:** Consistent mocking of Auth0 sessions in tests was difficult

   **Solution:** Created reusable Auth0 test utilities with standard session formats

   ```typescript
   // tests/utils/auth0-test-utils.ts
   export function createMockAdminSession() {
     return {
       user: {
         sub: "auth0|admin123",
         email: "admin@example.com",
         "https://vibecoder.com/roles": ["admin"],
       },
     };
   }

   export function setupAuth0Mock(session) {
     // Consistent mocking implementation
   }
   ```

2. **Stripe and Database Integration**

   **Challenge:** Coordinating data between Stripe and our database

   **Solution:** Created synchronization service with error recovery

3. **UI Loading States**

   **Challenge:** Complex data loading created confusing UI states

   **Solution:** Implemented standardized loading indicators and skeleton screens

## Best Practices

### Admin Access Control

1. **Multi-level protection**

   - Client-side: AdminGuard component
   - Server-side: Admin middleware
   - Database: Row-level security where applicable

2. **Detailed audit logging**
   - Log all administrative actions
   - Include user ID, action type, and affected resources
   - Store timestamps for all operations

### Subscription Data Management

1. **Data consistency**

   - Regular reconciliation with Stripe data
   - Background jobs to detect and fix inconsistencies
   - Alerting for critical synchronization failures

2. **Error handling**
   - Graceful fallbacks for temporary Stripe API failures
   - Clear error messages for administrators
   - Automatic retry for transient errors

### Performance Considerations

1. **Query optimization**

   - Index subscription-related columns
   - Paginate large subscription lists
   - Cache frequently accessed subscription metrics

2. **UI responsiveness**
   - Asynchronous data loading
   - Progressive rendering of complex tables
   - Optimistic UI updates for common operations

## Conclusion

The Admin Subscription Management system provides administrators with powerful tools to manage and monitor subscriptions across the VibeCoder platform. By following the patterns and best practices outlined in this guide, we've created a maintainable, secure, and performant solution.

## Related Resources

- [Auth0 Integration Guide](./Auth0-Integration-Guide.md)
- [Stripe Integration Guide](./Stripe-Integration-Guide.md)
- [Testing Strategy Guide](./Testing-Strategy-Guide.md)
