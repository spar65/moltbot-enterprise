# Authentication Provider Migration Guide

## Introduction

This guide provides a structured approach to migrating between authentication providers or versions. It complements the `100-auth-provider-migration.mdc` rule with practical implementation details and best practices.

## Table of Contents

1. [Migration Planning](#migration-planning)
2. [Architecture Patterns](#architecture-patterns)
3. [Implementation Strategy](#implementation-strategy)
4. [Handling Edge Cases](#handling-edge-cases)
5. [Testing](#testing)
6. [Rollout Strategy](#rollout-strategy)
7. [Monitoring and Rollback](#monitoring-and-rollback)
8. [Case Studies](#case-studies)

## Migration Planning

### Assessment Checklist

Before starting a migration, complete this assessment:

- [ ] **Current Auth Provider Documentation**

  - Document the current auth provider implementation
  - List all dependencies and versions
  - Map all integration points (API routes, middleware, components)

- [ ] **Target Auth Provider Research**

  - Research target auth provider features
  - Compare implementation patterns
  - Identify breaking changes and differences

- [ ] **Dependency Audit**

  - Audit all auth-related dependencies
  - Check for compatibility issues
  - Identify transitive dependencies

- [ ] **Impact Analysis**
  - Determine impact on existing features
  - Identify affected components and pages
  - Assess security implications

### Sample Migration Plan Template

```markdown
# Auth Migration Plan: [Current] to [Target]

## Overview

- **Current Provider**: [Name/Version]
- **Target Provider**: [Name/Version]
- **Motivation**: [Reasons for migration]
- **Timeline**: [Start and end dates]

## Scope

- **Affected Components**: [List of components]
- **Affected API Routes**: [List of routes]
- **User Impact**: [Description of user-facing changes]

## Migration Phases

1. **Research & Planning** (Week 1-2)

   - Complete assessment checklist
   - Document current implementation
   - Create compatibility layer design

2. **Development** (Week 3-5)

   - Implement compatibility layer
   - Create parallel authentication system
   - Develop feature flag infrastructure

3. **Testing** (Week 6-7)

   - Implement test suite for both systems
   - Conduct security testing
   - Perform load testing

4. **Rollout** (Week 8-10)
   - Phase 1: Internal testing (Week 8)
   - Phase 2: Beta users (Week 9)
   - Phase 3: Full rollout (Week 10)

## Rollback Plan

- **Trigger Conditions**: [Conditions that would trigger rollback]
- **Rollback Process**: [Step-by-step rollback procedure]
- **Validation Steps**: [How to verify successful rollback]

## Success Criteria

- [List measurable criteria for successful migration]
```

## Architecture Patterns

### Compatibility Layer Pattern

The compatibility layer pattern allows you to abstract away differences between auth providers:

```typescript
// src/lib/auth/types.ts
export interface AuthUser {
  id: string;
  email: string;
  name?: string;
  picture?: string;
  email_verified?: boolean;
  [key: string]: any; // For provider-specific fields
}

// src/lib/auth/compatibility.ts
export function normalizeUser(user: any): AuthUser {
  // Handle different auth provider formats
  if (user.sub) {
    // Auth0-style user
    return {
      id: user.sub,
      email: user.email,
      name: user.name,
      picture: user.picture,
      email_verified: user.email_verified,
    };
  } else if (user.uid) {
    // Firebase-style user
    return {
      id: user.uid,
      email: user.email,
      name: user.displayName,
      picture: user.photoURL,
      email_verified: user.emailVerified,
    };
  } else if (user.id) {
    // Clerk-style user
    return {
      id: user.id,
      email: user.primaryEmailAddress?.emailAddress,
      name: `${user.firstName} ${user.lastName}`.trim(),
      picture: user.imageUrl,
      email_verified:
        user.primaryEmailAddress?.verification?.status === "verified",
    };
  }

  // Unknown format
  throw new Error("Unknown auth provider user format");
}
```

### Feature Flag Pattern

Use feature flags to control the rollout of the new auth system:

```typescript
// src/lib/feature-flags.ts
type FeatureFlag = "useNewAuth" | "useNewAuthAPI" | "useNewAuthUI";

// Simple in-memory implementation
const FEATURE_FLAGS: Record<FeatureFlag, boolean> = {
  useNewAuth: process.env.NEXT_PUBLIC_USE_NEW_AUTH === "true",
  useNewAuthAPI: process.env.NEXT_PUBLIC_USE_NEW_AUTH_API === "true",
  useNewAuthUI: process.env.NEXT_PUBLIC_USE_NEW_AUTH_UI === "true",
};

// For server-side
export function getFeatureFlag(flag: FeatureFlag): boolean {
  return FEATURE_FLAGS[flag];
}

// For client-side with hooks
export function useFeatureFlag(flag: FeatureFlag): boolean {
  // Could fetch from API or use Context
  return FEATURE_FLAGS[flag];
}
```

### Adapter Pattern

Use the adapter pattern to maintain a consistent interface regardless of auth provider:

```typescript
// src/lib/auth/adapter.ts
import { AuthUser } from "./types";

// Interface that all auth adapters must implement
export interface AuthAdapter {
  getUser(): Promise<AuthUser | null>;
  signIn(options?: any): Promise<AuthUser>;
  signOut(): Promise<void>;
  isAuthenticated(): Promise<boolean>;
}

// Auth0 adapter implementation
export class Auth0Adapter implements AuthAdapter {
  private auth0: any; // Auth0 client

  constructor(auth0Client: any) {
    this.auth0 = auth0Client;
  }

  async getUser(): Promise<AuthUser | null> {
    try {
      const user = await this.auth0.getUser();
      return user ? normalizeUser(user) : null;
    } catch (error) {
      console.error("Auth0 getUser error:", error);
      return null;
    }
  }

  // Implement other methods...
}

// Create similar adapters for other auth providers
export class FirebaseAdapter implements AuthAdapter {
  // Implementation
}

export class ClerkAdapter implements AuthAdapter {
  // Implementation
}
```

## Implementation Strategy

### Phased Implementation Approach

Implement the migration in phases to minimize risk:

1. **Phase 1: Preparation**

   - Create compatibility layer
   - Implement feature flags
   - Set up monitoring

2. **Phase 2: Parallel Systems**

   - Implement new auth provider alongside existing one
   - Make both systems work with abstraction layer
   - Test with internal users

3. **Phase 3: Gradual Rollout**

   - Enable new auth for a small percentage of users
   - Monitor for issues
   - Gradually increase percentage

4. **Phase 4: Deprecation**
   - Once stable, mark old system as deprecated
   - Migrate remaining users
   - Remove old system

### Implementation Timeline Example

| Phase            | Timeframe   | Activities                               | Success Criteria                      |
| ---------------- | ----------- | ---------------------------------------- | ------------------------------------- |
| Preparation      | Weeks 1-2   | Setup compatibility layer, feature flags | All abstraction layers pass tests     |
| Parallel Systems | Weeks 3-4   | Implement new auth alongside old         | Both systems functioning in isolation |
| Internal Testing | Weeks 5-6   | Test with team members                   | No critical issues reported           |
| Beta Rollout     | Weeks 7-8   | 10% of users on new system               | Error rate below 0.1%                 |
| Gradual Rollout  | Weeks 9-12  | Increase to 100%                         | All users migrated successfully       |
| Cleanup          | Weeks 13-14 | Remove old system                        | No dependencies on old system         |

## Handling Edge Cases

### Session Persistence

When migrating, handle existing sessions carefully:

```typescript
// src/lib/auth/session-migration.ts
export async function attemptSessionMigration(
  req: any,
  res: any
): Promise<boolean> {
  try {
    // Check for legacy session
    const legacySession = getLegacySession(req);

    if (legacySession && legacySession.user) {
      // Create session in new system
      await createNewSession(req, res, legacySession.user);

      // Optionally clear old session
      clearLegacySession(req, res);

      return true;
    }

    return false;
  } catch (error) {
    console.error("Session migration failed:", error);
    return false;
  }
}
```

### Token Migration

Handle token migration between systems:

```typescript
// src/lib/auth/token-migration.ts
export async function migrateAuthTokens(
  legacyTokens: { accessToken: string; refreshToken?: string },
  userData: any
): Promise<{ accessToken: string; refreshToken?: string }> {
  try {
    // This implementation depends on your auth providers
    // You might need to exchange tokens or create new ones

    // Example: Create new token using user data from old token
    const newTokens = await createNewTokens({
      userId: userData.id,
      email: userData.email,
    });

    return newTokens;
  } catch (error) {
    console.error("Token migration failed:", error);
    throw new Error("Failed to migrate authentication tokens");
  }
}
```

### Handling In-Flight Requests

During migration, handle requests that might occur during the transition:

```typescript
// src/middleware.ts
export async function middleware(req: any, res: any) {
  // Get feature flags
  const useNewAuth = getFeatureFlag("useNewAuth");

  // Check for migration in progress
  const migrationInProgress = getFeatureFlag("authMigrationInProgress");

  if (migrationInProgress) {
    // During migration, try both auth systems
    try {
      // Try new auth first if enabled
      if (useNewAuth) {
        const newAuthResult = await checkNewAuth(req, res);
        if (newAuthResult.authenticated) {
          return nextWithUser(req, res, newAuthResult.user);
        }

        // Fall back to legacy auth
        const legacyAuthResult = await checkLegacyAuth(req, res);
        if (legacyAuthResult.authenticated) {
          // Opportunistically migrate session
          attemptSessionMigration(req, res);
          return nextWithUser(req, res, legacyAuthResult.user);
        }
      } else {
        // Try legacy auth first
        // Similar implementation as above but reversed
      }

      // Neither auth system authenticated the user
      return redirectToLogin(req, res);
    } catch (error) {
      console.error("Auth check failed during migration:", error);
      return redirectToLogin(req, res);
    }
  } else {
    // Not in migration, use the configured auth system
    return useNewAuth ? handleNewAuth(req, res) : handleLegacyAuth(req, res);
  }
}
```

## Testing

### Test Matrix

Create a comprehensive test matrix covering both auth systems:

| Feature             | Legacy Auth | New Auth | Mixed Mode |
| ------------------- | ----------- | -------- | ---------- |
| Login               | ✓           | ✓        | ✓          |
| Logout              | ✓           | ✓        | ✓          |
| Session Persistence | ✓           | ✓        | ✓          |
| Protected Routes    | ✓           | ✓        | ✓          |
| API Authorization   | ✓           | ✓        | ✓          |
| Token Refresh       | ✓           | ✓        | ✓          |
| Error Handling      | ✓           | ✓        | ✓          |

### Integration Tests

Create tests that verify both systems work:

```typescript
// tests/auth-integration.test.ts
describe("Auth Integration", () => {
  describe("Legacy Auth", () => {
    beforeEach(() => {
      // Setup legacy auth
      mockLegacyAuth();
    });

    testAuthFeatures();
  });

  describe("New Auth", () => {
    beforeEach(() => {
      // Setup new auth
      mockNewAuth();
    });

    testAuthFeatures();
  });

  describe("Migration Mode", () => {
    beforeEach(() => {
      // Setup both systems
      mockLegacyAuth();
      mockNewAuth();
      mockFeatureFlag("authMigrationInProgress", true);
    });

    testMigrationScenarios();
  });
});

function testAuthFeatures() {
  test("login works", async () => {
    // Test login
  });

  test("logout works", async () => {
    // Test logout
  });

  // Other tests...
}

function testMigrationScenarios() {
  test("session migration works", async () => {
    // Test session migration
  });

  test("handles legacy session during migration", async () => {
    // Test legacy session handling
  });

  // Other migration-specific tests...
}
```

## Rollout Strategy

### Feature Flag Configuration

Configure feature flags for controlled rollout:

```json
// Feature flag configuration (could be in database or config file)
{
  "flags": {
    "useNewAuth": {
      "defaultValue": false,
      "description": "Use new auth provider",
      "rollout": {
        "percentage": 0,
        "enabledFor": ["internal", "beta-testers"],
        "disabledFor": []
      }
    },
    "useNewAuthAPI": {
      "defaultValue": false,
      "description": "Use new auth provider for API routes",
      "rollout": {
        "percentage": 0,
        "enabledFor": ["internal"],
        "disabledFor": []
      }
    }
  }
}
```

### Gradual Rollout Plan

| Stage        | Audience         | Percentage | Duration | Success Criteria     |
| ------------ | ---------------- | ---------- | -------- | -------------------- |
| Alpha        | Development team | 100%       | 1 week   | No blocking issues   |
| Beta         | Internal users   | 100%       | 2 weeks  | < 5 reported issues  |
| Limited      | Beta testers     | 100%       | 2 weeks  | < 10 reported issues |
| Canary       | 5% of users      | 5%         | 1 week   | Error rate < 0.5%    |
| Expanded     | 25% of users     | 25%        | 1 week   | Error rate < 0.2%    |
| Full Rollout | All users        | 100%       | 2 weeks  | Error rate < 0.1%    |

## Monitoring and Rollback

### Monitoring Metrics

Monitor these key metrics during migration:

1. **Authentication Success Rate**

   - Successful vs. failed authentication attempts
   - Compare legacy vs. new system

2. **Performance Metrics**

   - Authentication latency
   - Token validation time

3. **Error Rates**

   - Authentication errors
   - Token validation errors
   - Session-related errors

4. **User Impact**
   - Session terminations
   - Forced re-authentication events

### Rollback Triggers

Define clear conditions that would trigger a rollback:

- Authentication success rate drops below 99.5%
- Authentication latency increases by more than 100ms
- Critical security vulnerability discovered
- More than 10 user-reported auth issues in 24 hours

### Rollback Procedure

1. **Disable Feature Flags**

   - Set all new auth feature flags to `false`
   - Update flag configuration in real-time

2. **Verify Legacy System**

   - Ensure legacy auth system is still operational
   - Verify all credentials and configuration

3. **Communicate Status**

   - Notify team of rollback
   - Update status page if public-facing

4. **Monitor Recovery**

   - Verify authentication success returns to normal
   - Track any lingering issues

5. **Root Cause Analysis**
   - Investigate what went wrong
   - Develop fix before re-attempting migration

## Case Studies

### Auth0 v3 to v4 Migration

**Context**: Migration from Auth0 SDK v3 to v4 with significant API changes

**Challenges**:

- Session handling changed significantly
- API route authentication approach completely different
- No direct upgrade path

**Solution**:

- Created compatibility layer between v3 and v4 APIs
- Implemented feature flags for gradual rollout
- Used middleware-based approach that worked with both versions
- Migrated sessions progressively

**Outcome**:

- Successful migration with minimal user impact
- Performance improvements from new SDK
- Better security with more modern approach

### Firebase to Clerk Migration

**Context**: Migrating from Firebase Authentication to Clerk

**Challenges**:

- Different user identifier formats
- Different session management approaches
- Custom claims handling differences

**Solution**:

- Implemented adapter pattern for auth providers
- Created user mapping between Firebase UID and Clerk ID
- Maintained parallel auth systems during migration
- Migrated user data incrementally

**Outcome**:

- Improved user management capabilities
- Reduced authentication complexity
- Better security posture

## Conclusion

Authentication provider migrations are complex but manageable with proper planning and implementation. By following this guide and the associated rule, you can ensure a smooth transition between auth providers while maintaining security and user experience.

Remember these key principles:

- Always implement a compatibility layer
- Use feature flags for controlled rollout
- Test thoroughly in all scenarios
- Monitor closely during migration
- Have a clear rollback plan

For specific questions or assistance with your migration, consult with your security team or authentication provider's support resources.
