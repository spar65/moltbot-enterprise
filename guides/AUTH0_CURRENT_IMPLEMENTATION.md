# Current Auth0 Implementation Details

This document captures the current Auth0 implementation in this project, based on the recent changes made to fix the authentication issues.

## Auth0 SDK Version

**Current Version:** 4.6.0

**Implementation Pattern:** Middleware-based (v4+)

**Last Updated:** Based on recent fixes to remove nested middleware and properly implement Auth0 v4.6.0

## Implementation Details

### Key Files

- **Auth0 Client:** `src/lib/auth0.ts` - Creates an Auth0Client instance
- **Middleware:** `middleware.ts` (root directory) - Handles Auth0 authentication
- **Protected Route Utility:** `src/lib/protectedRoute.ts` - Utility for protecting API routes
- **Subscription Middleware:** `src/middleware/subscription.ts` - Handles subscription checks
- **Protected API Examples:**
  - `src/pages/api/protected-data.ts` - Basic protected endpoint
  - `src/pages/api/subscription/set-free.ts` - Protected subscription endpoint

### Authentication Routes

- **Login:** `/auth/login` (v4+)
- **Logout:** `/auth/logout` (v4+)
- **Callback:** `/auth/callback` (v4+)

### Session Validation Method

```typescript
// How session validation is performed in this project
// Auth0 v4.6.0 pattern:
import { auth0 } from "../lib/auth0";

const session = await auth0.getSession(req);
```

## Recent Changes

The recent implementation addressed several critical issues:

1. **Removed API Route Conflicts**:

   - Deleted `src/pages/api/auth/[...auth0].ts` which was causing conflicts with v4.6.0

2. **Fixed Middleware Implementation**:

   - Ensured middleware.ts is in the root directory
   - Properly configured middleware matcher

3. **Removed Nested Middleware**:

   - Deleted `src/pages/api/_middleware.ts` (not allowed in Next.js)
   - Created the `protectedRoute` utility as a cleaner alternative

4. **Corrected Session Access**:
   - Updated all API routes to use `auth0.getSession(req)` instead of `getSession(req, res)`
   - Fixed authentication checks in protected pages

## Auth0 Dashboard Configuration Requirements

For this implementation to work correctly, the Auth0 Dashboard application settings must have:

- **Allowed Callback URLs:** Including `http://localhost:3000/auth/callback` for development
- **Allowed Logout URLs:** Including `http://localhost:3000` for development
- **Allowed Web Origins:** Including `http://localhost:3000` for development

## Environment Variables

```bash
# Required environment variables - exact names matter!
AUTH0_SECRET=***************
AUTH0_ISSUER_BASE_URL=***************  # No https:// prefix
AUTH0_BASE_URL=http://localhost:3000  # For development
AUTH0_CLIENT_ID=***************
AUTH0_CLIENT_SECRET=***************

# Optional environment variables
AUTH0_AUDIENCE=***************  # If using API authorization
AUTH0_SCOPE="openid profile email"  # Default scopes
```

## Important Notes

- This implementation follows the Auth0 v4.6.0+ middleware-based pattern
- All authentication routes are at `/auth/*` NOT `/api/auth/*`
- Protected API routes use the `protectedRoute` utility or direct session checks
- The implementation no longer uses nested middleware for subscription checks
- Version should be pinned to exactly 4.6.0 in package.json to prevent accidental upgrades

## Don'ts

- DO NOT add back `pages/api/auth/[...auth0].ts` - this will conflict with the middleware approach
- DO NOT add back `pages/api/_middleware.ts` - Next.js doesn't allow nested middleware
- DO NOT mix v3 and v4 patterns in the codebase
- DO NOT use `getSession(req, res)` (v3 pattern) - use `auth0.getSession(req)` instead

## Migration History

| Date   | Previous Version     | New Version   | Changes Made                                               |
| ------ | -------------------- | ------------- | ---------------------------------------------------------- |
| Recent | Mixed v3/v4 patterns | 4.6.0 (clean) | Removed API routes, added middleware, fixed session access |

## Testing the Implementation

Follow the detailed testing procedure in [README-Auth0-Manual-Testing.md](../README-Auth0-Manual-Testing.md) to verify that the implementation is working correctly.

## Reference Documentation

- [Auth0 Next.js SDK v4.6.0 Documentation](https://auth0.github.io/nextjs-auth0/v4.6.0/)
- [Auth0 v4.6.0+ Implementation Guide](AUTH0_V4_IMPLEMENTATION_GUIDE.md)
- [Auth0 Do's and Don'ts](AUTH0_DOS_AND_DONTS.md)
- [Auth0 Quick Reference Card](AUTH0_QUICK_REFERENCE.md)
