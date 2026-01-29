# Developer Guide: Implementing Subscription Access Controls

This guide explains how to implement subscription-based access controls in the VibeCoder application using our 5-tier subscription model.

## Table of Contents

- [Understanding the Tier System](#understanding-the-tier-system)
- [UI Implementation](#ui-implementation)
- [API Implementation](#api-implementation)
- [Testing Your Implementation](#testing-your-implementation)
- [Common Patterns](#common-patterns)
- [Troubleshooting](#troubleshooting)

## Understanding the Tier System

VibeCoder uses a 5-tier subscription model:

| Tier    | Description         | Target Users          | Monthly Price |
| ------- | ------------------- | --------------------- | ------------- |
| free    | Basic access        | New users, evaluators | $0            |
| basic   | Essential features  | Individual users      | $5            |
| sync    | Team collaboration  | Small teams           | $15           |
| cleanup | Advanced analysis   | Professional users    | $45           |
| elite   | Enterprise features | Organizations         | $100          |

The tier hierarchy is strictly: `free → basic → sync → cleanup → elite`

Access is cumulative, meaning higher tiers have access to all features of lower tiers. For example, a user with a "cleanup" subscription can access all features available to "free", "basic", and "sync" users.

### Key Types and Functions

```typescript
// Import these from src/lib/database.ts
import {
  SubscriptionTier,
  hasSufficientTier,
  TIER_LEVELS,
  getTierLevel,
} from "../lib/database";

// SubscriptionTier type
type SubscriptionTier = "free" | "basic" | "sync" | "cleanup" | "elite";

// Check if a user's tier meets or exceeds a required tier
function hasSufficientTier(
  userTier: SubscriptionTier,
  requiredTier: SubscriptionTier
): boolean;

// Get numeric level of a tier (for custom comparisons)
function getTierLevel(tier: SubscriptionTier): number;

// Tier levels as a record (for reference)
const TIER_LEVELS: Record<SubscriptionTier, number> = {
  free: 0,
  basic: 1,
  sync: 2,
  cleanup: 3,
  elite: 4,
};
```

## UI Implementation

### Using the ProtectedContent Component

The easiest way to implement subscription-based UI is to use the `ProtectedContent` component:

```tsx
import { ProtectedContent } from "../components/ProtectedContent";

function FeaturePage() {
  return (
    <div className="feature-container">
      {/* Everyone can see this */}
      <h1>Feature Dashboard</h1>

      {/* Only basic tier and above can see this */}
      <ProtectedContent requiredTier="basic">
        <div className="premium-feature">
          <h2>Basic Analytics</h2>
          <AnalyticsComponent />
        </div>
      </ProtectedContent>

      {/* Only elite tier can see this */}
      <ProtectedContent requiredTier="elite">
        <div className="elite-feature">
          <h2>Custom Rules Engine</h2>
          <RulesEngine />
        </div>
      </ProtectedContent>
    </div>
  );
}
```

### ProtectedContent Props

| Prop         | Type             | Description                                                     |
| ------------ | ---------------- | --------------------------------------------------------------- |
| requiredTier | SubscriptionTier | The minimum tier required to view the content                   |
| children     | ReactNode        | The content to display if the user has access                   |
| fallback     | ReactNode?       | Optional custom content to show if the user doesn't have access |
| showPreview  | boolean?         | Whether to show a blurred preview (default: true)               |

### Using the Subscription Context Directly

For more complex scenarios, you can use the subscription context directly:

```tsx
import { useSubscription } from "../contexts/SubscriptionContext";

function ComplexFeature() {
  const { tier, hasAccess, isLoading } = useSubscription();

  if (isLoading) {
    return <LoadingSpinner />;
  }

  return (
    <div>
      <h2>Feature Dashboard</h2>

      {/* Basic tier features */}
      {hasAccess("basic") && (
        <section>
          <h3>Basic Analytics</h3>
          <BasicAnalytics />
        </section>
      )}

      {/* Conditional rendering based on tier */}
      <section>
        <h3>Data Processing</h3>
        {hasAccess("cleanup") ? <AdvancedProcessing /> : <BasicProcessing />}
      </section>

      {/* Show different upgrade buttons based on current tier */}
      {tier === "free" && <UpgradeToBasicButton />}
      {tier === "basic" && <UpgradeToSyncButton />}
      {tier === "sync" && <UpgradeToCleanupButton />}
      {tier === "cleanup" && <UpgradeToEliteButton />}
    </div>
  );
}
```

## API Implementation

### Using the Subscription Middleware

Protect API routes using the subscription middleware:

```typescript
// pages/api/tools/advanced-analysis.ts
import { NextApiRequest, NextApiResponse } from "next";
import { withSubscriptionCheck } from "../../../middleware/subscription";

async function handler(req: NextApiRequest, res: NextApiResponse) {
  // This code only runs if the user has sufficient tier
  const result = await performAdvancedAnalysis(req.body);
  return res.status(200).json(result);
}

// Protect this endpoint - requires "cleanup" tier or higher
export default withSubscriptionCheck(handler, "cleanup");
```

### Custom API Protection

For more complex scenarios:

```typescript
import { NextApiRequest, NextApiResponse } from "next";
import { auth0 } from "../../../lib/auth0";
import { getUserSubscription, hasSufficientTier } from "../../../lib/database";

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  try {
    // Get the user's session
    const session = await auth0.getSession(req);
    if (!session?.user) {
      return res.status(401).json({ error: "Not authenticated" });
    }

    // Get the user's subscription
    const userId = session.user.sub;
    const subscription = await getUserSubscription(userId);
    const userTier = subscription?.tier || "free";

    // Determine required tier based on request parameters
    let requiredTier: SubscriptionTier = "basic";
    if (req.body.advancedFeatures) {
      requiredTier = "cleanup";
    }
    if (req.body.customRules) {
      requiredTier = "elite";
    }

    // Check if user has access
    if (!hasSufficientTier(userTier, requiredTier)) {
      return res.status(403).json({
        error: `This operation requires ${requiredTier} tier or higher`,
        currentTier: userTier,
        requiredTier: requiredTier,
        upgradeUrl: "/subscribe",
      });
    }

    // Process the request
    const result = await processRequest(req.body);
    return res.status(200).json(result);
  } catch (error) {
    console.error("API error:", error);
    return res.status(500).json({ error: "Internal server error" });
  }
}
```

## Testing Your Implementation

### Testing UI Components

```tsx
import { render, screen } from "@testing-library/react";
import { SubscriptionProvider } from "../contexts/SubscriptionContext";
import { ProtectedContent } from "../components/ProtectedContent";

// Mock the useUser hook
jest.mock("@auth0/nextjs-auth0", () => ({
  useUser: () => ({
    user: { sub: "user123" },
    isLoading: false,
  }),
}));

// Mock fetch for subscription data
global.fetch = jest.fn(() =>
  Promise.resolve({
    ok: true,
    json: () =>
      Promise.resolve({
        subscription: { tier: "basic", status: "active" },
      }),
  })
) as jest.Mock;

describe("ProtectedContent", () => {
  it("shows content when user has sufficient tier", async () => {
    render(
      <SubscriptionProvider>
        <ProtectedContent requiredTier="basic">
          <div>Premium Content</div>
        </ProtectedContent>
      </SubscriptionProvider>
    );

    expect(await screen.findByText("Premium Content")).toBeInTheDocument();
  });

  it("shows upgrade prompt when user has insufficient tier", async () => {
    render(
      <SubscriptionProvider>
        <ProtectedContent requiredTier="elite">
          <div>Elite Content</div>
        </ProtectedContent>
      </SubscriptionProvider>
    );

    expect(await screen.findByText("Upgrade Required")).toBeInTheDocument();
    expect(await screen.findByText("Upgrade Now")).toBeInTheDocument();
  });
});
```

### Testing API Protection

```typescript
import { createMocks } from "node-mocks-http";
import handler from "../pages/api/protected-endpoint";

// Mock auth0 and database functions
jest.mock("../lib/auth0", () => ({
  auth0: {
    getSession: jest.fn(),
  },
}));

jest.mock("../lib/database", () => ({
  getUserSubscription: jest.fn(),
  hasSufficientTier: jest.fn(),
}));

describe("Protected API Endpoint", () => {
  it("returns 403 when user has insufficient tier", async () => {
    // Setup mocks
    const { auth0 } = require("../lib/auth0");
    const {
      getUserSubscription,
      hasSufficientTier,
    } = require("../lib/database");

    auth0.getSession.mockResolvedValue({
      user: { sub: "user123" },
    });

    getUserSubscription.mockResolvedValue({
      tier: "basic",
      status: "active",
    });

    hasSufficientTier.mockReturnValue(false);

    // Create mock request/response
    const { req, res } = createMocks({
      method: "POST",
      body: { data: "test" },
    });

    // Call the handler
    await handler(req, res);

    // Verify response
    expect(res._getStatusCode()).toBe(403);
    expect(JSON.parse(res._getData())).toHaveProperty("error");
  });
});
```

## Common Patterns

### Feature Flags with Tier Requirements

```typescript
// Define feature flags with tier requirements
const FEATURES: Record<
  string,
  {
    enabled: boolean;
    requiredTier: SubscriptionTier;
    description: string;
  }
> = {
  "advanced-analytics": {
    enabled: true,
    requiredTier: "sync",
    description: "Advanced analytics and reporting",
  },
  "custom-rules": {
    enabled: true,
    requiredTier: "elite",
    description: "Custom rules engine",
  },
  "team-collaboration": {
    enabled: true,
    requiredTier: "sync",
    description: "Team collaboration features",
  },
};

// Usage
function canUseFeature(featureId: string, userTier: SubscriptionTier): boolean {
  const feature = FEATURES[featureId];
  if (!feature || !feature.enabled) {
    return false;
  }

  return hasSufficientTier(userTier, feature.requiredTier);
}
```

### Tiered Feature Sets

```typescript
// Define features available at each tier
const TIER_FEATURES: Record<SubscriptionTier, string[]> = {
  free: ["basic-search", "public-templates"],
  basic: ["saved-searches", "basic-analytics"],
  sync: ["team-sharing", "collaboration", "integrations"],
  cleanup: ["advanced-analytics", "bulk-operations"],
  elite: ["custom-rules", "priority-support", "white-labeling"],
};

// Get all features available to a tier (including lower tiers)
function getAvailableFeatures(userTier: SubscriptionTier): string[] {
  const userLevel = getTierLevel(userTier);
  const allFeatures: string[] = [];

  Object.entries(TIER_FEATURES).forEach(([tier, features]) => {
    if (getTierLevel(tier as SubscriptionTier) <= userLevel) {
      allFeatures.push(...features);
    }
  });

  return allFeatures;
}
```

## Troubleshooting

### Common Issues

1. **Subscription Not Loading**

   - Check that the `SubscriptionProvider` is properly set up in `_app.tsx`
   - Verify the API endpoint `/api/user/subscription` is working
   - Check browser console for errors

2. **Protected Content Always Shows Upgrade Prompt**

   - Verify the user's subscription tier in the database
   - Check that `requiredTier` is spelled correctly (must be one of: "free", "basic", "sync", "cleanup", "elite")
   - Ensure the subscription is marked as "active" in the database

3. **API Returns 403 Even for Subscribed Users**

   - Check that the middleware is using the correct tier requirement
   - Verify the user's subscription in the database
   - Look for typos in tier names

4. **Stripe Webhook Not Updating Subscription**
   - Verify Stripe price IDs in `.env.local` match those in the Stripe dashboard
   - Check webhook logs for errors
   - Test webhook handling with the Stripe CLI

### Debugging Tips

Add debug logging to the subscription context:

```tsx
// Add to SubscriptionContext.tsx
useEffect(() => {
  if (process.env.NODE_ENV === "development") {
    console.log("Subscription loaded:", {
      tier,
      subscription,
      isLoading,
    });
  }
}, [tier, subscription, isLoading]);
```

## Need Help?

If you're stuck implementing subscription access controls:

1. Check the [026-subscription-access-control.mdc](mdc:026-subscription-access-control.mdc) rule
2. Review the implementation in `components/ProtectedContent.tsx`
3. Look at the test page in `pages/test-protection.tsx` for examples
4. Reach out to the team on Slack in the #subscription-system channel
