# Auth0 Troubleshooting Guide

## Introduction

This guide provides solutions to common Auth0 integration issues based on production experience. It follows a decision-tree approach to help diagnose and resolve authentication problems efficiently.

## Debugging Decision Tree (Based on Production Issues)

### Authentication Not Working

#### Middleware Not Working

1. **Check matcher patterns**

   - Ensure static assets are excluded
   - Verify public routes are properly excluded

   ```javascript
   // Correct matcher configuration
   export const config = {
     matcher: [
       "/((?!api/public|api/auth|_next/static|_next/image|favicon.ico|public/).*)",
     ],
   };
   ```

2. **Verify environment variables**

   - Check all Auth0 environment variables are correctly set
   - Verify AUTH0_BASE_URL matches the deployment environment
   - Ensure AUTH0_SECRET is set and secure

3. **Test redirect URL preservation**

   - Confirm returnTo parameter is properly set
   - Check URL encoding for complex paths

4. **Inspect Auth0 logs**
   - Check Auth0 dashboard for login attempts
   - Look for authorization errors or rate limiting

#### Login Not Working

1. **Verify callback URLs**

   - Ensure callback URL is configured in Auth0 dashboard
   - Check for URL mismatches between configuration and code

2. **Check CORS settings**

   - Verify allowed origins in Auth0 dashboard
   - Test with explicit origin setting

3. **Validate user credentials**

   - Check if user exists in Auth0 dashboard
   - Verify user is not blocked

4. **Clear browser cache and cookies**
   - Try incognito/private browsing mode
   - Clear application storage and cookies

### Tests Failing After Auth0 Update

1. **Check mock implementations**

   - Update mocks to match new SDK API signatures
   - Verify mock return values match expected format

2. **Update test assertions**

   - Adjust assertions to accommodate SDK changes
   - Use more resilient, behavior-based assertions
   - Verify redirect status codes (302 vs 307)

3. **Inspect API changes**

   - Read Auth0 SDK changelog for breaking changes
   - Update implementation code to match API changes

4. **Reset testing environment**
   - Clear test cache between runs
   - Ensure mocks are reset between tests

### Role-Based Access Not Working

1. **Verify token contents**

   - Check if roles are included in the token
   - Inspect token format and structure

2. **Check Auth0 configuration**

   - Verify roles are assigned to users
   - Check rule configuration for adding roles to tokens

3. **Test role extraction**
   - Debug role extraction logic
   - Check for case sensitivity issues

## Session State Troubleshooting

### Session Loss During Navigation

1. **Check for client-side routing issues**

   - Verify Next.js router is not clearing auth state during navigation
   - Ensure useUser hook is consistently used across components

2. **Verify cookie configuration**

   - Check cookie sameSite and secure settings
   - Verify cookie domain configuration matches deployment environment

3. **Test session expiration handling**
   - Implement proper refresh token logic
   - Add graceful session recovery mechanisms

### Common Session Error Patterns

#### "User is undefined" Errors

**Cause**: Session not available or not properly loaded before component render
**Solution**: Implement proper loading states and error boundaries

```javascript
// Proper session handling pattern
function ProfilePage() {
  const { user, isLoading, error } = useUser();

  // Handle loading state
  if (isLoading) return <LoadingSpinner />;

  // Handle error state
  if (error) return <AuthErrorFallback error={error} />;

  // Handle no session state
  if (!user) return <RedirectToLogin />;

  // Render authenticated content
  return <ProfileContent user={user} />;
}
```

## Authentication Performance Optimization

### Reducing Auth Latency

1. **Optimize token validation**

   - Use caching strategies for token validation
   - Implement stale-while-revalidate pattern for auth state

2. **Minimize redundant auth checks**

   - Centralize authentication state management
   - Use React Query or similar for auth state caching

3. **Implement auth state prefetching**
   - Prefetch authentication state on app initialization
   - Use optimistic UI updates for auth-dependent actions

### Performance Monitoring

1. **Track authentication timing metrics**

   - Measure time spent in auth operations
   - Identify bottlenecks in authentication flow

2. **Implement performance budgets**
   - Set maximum acceptable time for auth operations
   - Alert when auth operations exceed budget

## SDK Version Mismatch Issues

### Identifying Version Mismatch Problems

1. **API Signature Changes**

   - Look for errors like `getSession requires 1-2 arguments but got 0`
   - Check for changes in function signatures between versions

2. **Redirect Status Code Changes**

   - Auth0 v3 uses 302 redirects
   - Auth0 v4.6.0 uses 307 redirects
   - Tests may fail if asserting specific status codes

3. **Environment Variable Differences**

   - Check for mismatches between expected and actual env var names
   - Variables like `AUTH0_DOMAIN` vs `AUTH0_ISSUER_BASE_URL`

### Resolving Version Mismatch Problems

1. **Update all Auth0 imports**

   - Ensure consistent version usage throughout the application
   - Check for mixed imports from different Auth0 packages

2. **Review environment variables**

   - Update variable names to match SDK version
   - Consider supporting both naming patterns during transition

3. **Update test assertions**
   - Make redirect tests version-agnostic
   - Assert on redirect behavior, not specific status codes

## Common Error Codes and Solutions

### Error: invalid_request

**Cause**: Missing or invalid parameters
**Solution**: Check required parameters are included and correctly formatted

### Error: access_denied

**Cause**: User denied consent or authentication failed
**Solution**: Check user permissions, credentials, and consent prompts

### Error: invalid_client

**Cause**: Client authentication failed
**Solution**: Verify client ID and secret are correct

### Error: invalid_grant

**Cause**: Invalid, expired, or revoked token
**Solution**: Refresh authentication token or re-authenticate

### Error: server_error

**Cause**: Auth0 server error
**Solution**: Check Auth0 status page, retry later, contact support if persistent

## Logging and Debugging Tips

### Enable Enhanced Debugging

```javascript
// Next.js config
module.exports = {
  env: {
    AUTH0_DEBUG: "true",
  },
};
```

### Implement Proper Error Logging

```javascript
// Custom error handler
import { captureException } from "@sentry/nextjs";

function handleAuthError(error) {
  console.error("Auth error:", error);
  captureException(error);

  return {
    error: {
      message: "Authentication failed",
      details:
        process.env.NODE_ENV === "development" ? error.message : undefined,
    },
  };
}
```

### Use Network Inspection

1. Use browser DevTools to inspect authentication requests
2. Check for proper headers and response codes
3. Verify redirect chains are functioning correctly

## Note on Troubleshooting Flowcharts

For complex authentication flows, we recommend creating visual decision tree flowcharts to assist in troubleshooting. These can be especially valuable for:

1. Login failure diagnosis
2. Session management issues
3. Token validation problems
4. Role-based access troubleshooting

The development team should create these flowcharts based on production experiences and update them as new issues are discovered and resolved.
