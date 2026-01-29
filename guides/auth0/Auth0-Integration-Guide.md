# Auth0 SDK 4.6.0 Integration Guide

> **⚠️ DEPRECATED: This guide has been replaced by our new comprehensive Auth0 guide suite at [/docs/guides/auth0/](./auth0/). Please use the new guides for the most up-to-date and complete information.**

## Introduction

This guide provides detailed instructions for integrating Auth0 SDK 4.6.0 with Next.js applications. It addresses common pitfalls, explains configuration requirements, and offers solutions to production deployment issues that are often encountered during integration.

## Table of Contents

1. [Critical Configuration Changes in SDK 4.6.0](#critical-configuration-changes-in-sdk-460)
2. [Environment Variable Setup](#environment-variable-setup)
3. [Auth0 Dashboard Configuration](#auth0-dashboard-configuration)
4. [Code Implementation](#code-implementation)
5. [Middleware Configuration](#middleware-configuration)
6. [Common Errors and Solutions](#common-errors-and-solutions)
7. [Diagnostic Tools](#diagnostic-tools)
8. [Emergency Recovery Procedures](#emergency-recovery-procedures)

## Critical Configuration Changes in SDK 4.6.0

### Route Path Changes

Auth0 SDK 4.6.0 introduces a significant change in route paths compared to previous versions:

- ❌ **Old path (pre-4.6.0)**: `/api/auth/[...auth0].ts`
- ✅ **New path (4.6.0+)**: `/auth/[...auth0].ts`

This change affects how you configure both your Next.js application and your Auth0 dashboard settings. Overlooking this change is the most common cause of authentication failures in production.

### Domain Configuration

Auth0 SDK 4.6.0 requires precise domain formatting:

- ❌ **Incorrect**: `your-tenant.auth0.com`
- ✅ **Correct**: `your-tenant.us.auth0.com` (including the regional suffix)

The regional suffix (`.us`, `.eu`, etc.) is critical for proper operation. You can verify your domain by visiting:

```
https://your-exact-domain/.well-known/openid-configuration
```

## Environment Variable Setup

### Required Environment Variables

```bash
# All of these are REQUIRED in Vercel production environment:
AUTH0_SECRET=32-character-random-string-generated-with-openssl-rand-hex-32
AUTH0_BASE_URL=https://your-production-domain.com
AUTH0_ISSUER_BASE_URL=https://your-exact-tenant.us.auth0.com
AUTH0_CLIENT_ID=your-client-id-from-auth0-dashboard
AUTH0_CLIENT_SECRET=your-client-secret-from-auth0-dashboard
AUTH0_DOMAIN=your-exact-tenant.us.auth0.com
APP_BASE_URL=https://your-production-domain.com
```

### Generating a Secure Secret

For the `AUTH0_SECRET` variable, generate a secure random string:

```bash
openssl rand -hex 32
```

### Environment Variable Security

Following our [Environment Variable Security Rule](/.cursor/rules/011-env-var-security.mdc):

- **Server-side only**: These variables should never be exposed to the client
- **Production scope**: Ensure all variables are set to "Production" scope in Vercel
- **Verification**: Use the diagnostic tools to verify environment variables before deploying

## Auth0 Dashboard Configuration

### Application URLs

In your Auth0 Dashboard → Applications → Your App → Settings:

```
# Application Login URI:
https://your-production-domain.com/auth/login

# Allowed Callback URLs:
https://your-production-domain.com/auth/callback

# Allowed Logout URLs:
https://your-production-domain.com

# Allowed Web Origins:
https://your-production-domain.com

# Back-Channel Logout URI:
https://your-production-domain.com/auth/backchannel-logout
```

### Application Settings

- **Application Type**: Regular Web Application
- **Token Endpoint Authentication Method**: Post
- **JSON Web Token (JWT) Signature Algorithm**: RS256
- **OIDC Conformant**: Enabled

## Code Implementation

### Auth0 Client Configuration

Create `src/lib/auth0.ts` with robust error handling:

```typescript
import { Auth0Client } from "@auth0/nextjs-auth0/server";

// Helper function to ensure valid URLs
const getValidUrl = (url?: string): string => {
  if (!url) return "";
  try {
    // Test if it's already a valid URL
    new URL(url);
    return url;
  } catch (err) {
    // If not, try adding https:// prefix
    try {
      const urlWithProtocol = `https://${url}`;
      new URL(urlWithProtocol);
      return urlWithProtocol;
    } catch (err) {
      // If still invalid, return empty string
      return "";
    }
  }
};

// Extract domain from issuer URL if needed
const extractDomainFromIssuerUrl = (issuerUrl?: string): string => {
  if (!issuerUrl) return "";
  try {
    const url = new URL(issuerUrl);
    return url.hostname;
  } catch (err) {
    try {
      const url = new URL(`https://${issuerUrl}`);
      return url.hostname;
    } catch (err) {
      return "";
    }
  }
};

// Get a valid base URL with multiple fallbacks
const appBaseUrl = getValidUrl(
  process.env.AUTH0_BASE_URL ||
    process.env.APP_BASE_URL ||
    (process.env.VERCEL_URL ? `https://${process.env.VERCEL_URL}` : "")
);

// Get domain with fallback to extracted domain from issuer URL
const domain =
  process.env.AUTH0_DOMAIN ||
  extractDomainFromIssuerUrl(process.env.AUTH0_ISSUER_BASE_URL) ||
  "";

// Create Auth0 client with validated parameters
export const auth0 = new Auth0Client({
  domain,
  clientId: process.env.AUTH0_CLIENT_ID,
  clientSecret: process.env.AUTH0_CLIENT_SECRET,
  appBaseUrl,
  secret: process.env.AUTH0_SECRET,
});

export default auth0;
```

### Auth0 Route Handler

Create `src/pages/auth/[...auth0].ts`:

```typescript
import { auth0 } from "../../lib/auth0";

// Dynamic API route handler that Auth0 SDK uses for authentication flows
export default auth0.handleAuth();
```

## Middleware Configuration

### Robust Middleware Implementation

Create `middleware.ts` in your project root:

```typescript
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { auth0 } from "./src/lib/auth0";

// Extract base URL from request headers (fallback for URL construction errors)
const extractBaseUrl = (request: NextRequest): string => {
  const headers = request.headers;
  const origin = headers.get("origin");
  if (origin) return origin;

  const host = headers.get("host");
  if (!host) return "";

  const protocol = headers.get("x-forwarded-proto") || "https";
  return `${protocol}://${host}`;
};

export async function middleware(request: NextRequest) {
  try {
    // Try Auth0 middleware with error handling
    return await auth0.middleware(request);
  } catch (err: any) {
    const error = err instanceof Error ? err : new Error(String(err));
    console.error(`Auth0 middleware error:`, error.message);

    // Handle URL construction errors
    if (error.message?.includes("Invalid URL")) {
      const pathname = request.nextUrl.pathname;
      const baseUrl = extractBaseUrl(request);

      // For login route, redirect to login with fallback URL
      if (pathname === "/auth/login") {
        return NextResponse.redirect(`${baseUrl}/auth/login`);
      }
    }

    // Always fall back to allowing the request through
    return NextResponse.next();
  }
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|sitemap.xml|robots.txt).*)",
  ],
};
```

## Common Errors and Solutions

### Error: MIDDLEWARE_INVOCATION_FAILED

**Symptoms**:

- Auth0 middleware fails in production but works in development
- Error appears in Vercel logs: `MIDDLEWARE_INVOCATION_FAILED`
- Users can't log in or access protected pages

**Causes**:

1. URL construction errors in Auth0 SDK
2. Missing or incorrect environment variables
3. Using old route paths (`/api/auth/` instead of `/auth/`)
4. Missing regional suffix in Auth0 domain

**Solutions**:

1. Implement the robust Auth0 client with URL validation
2. Verify all required environment variables are set
3. Ensure routes are at `/auth/[...auth0].ts` not `/api/auth/[...auth0].ts`
4. Check Auth0 domain format (e.g., `tenant.us.auth0.com`)

### Error: Invalid URL

**Symptoms**:

- `TypeError: Invalid URL` appears in logs
- Occurs during Auth0's URL construction

**Causes**:

1. Malformed URLs in environment variables
2. Missing protocol (https://) in URLs
3. Edge Runtime limitations in Vercel

**Solutions**:

1. Add URL validation in Auth0 client initialization
2. Ensure all URLs include `https://` prefix
3. Implement fallback URL construction in middleware

### Error: Callback Not Working

**Symptoms**:

- Authentication starts but users get errors after logging in
- Redirect fails after authentication

**Causes**:

1. Mismatched callback URLs between code and Auth0 Dashboard
2. Using `/api/auth/callback` instead of `/auth/callback`

**Solutions**:

1. Update Auth0 Dashboard with correct callback URL
2. Ensure your callback URL is configured as `/auth/callback`

## Diagnostic Tools

We've created a set of diagnostic tools to help troubleshoot Auth0 integration issues:

### 1. Environment Variables Test

Create `/pages/test-env.tsx` using our diagnostic tool to check if environment variables are properly set.

### 2. URL Construction Test

Create `/pages/api/test-auth0-urls.ts` to test Auth0 URL construction and identify potential issues.

### 3. Basic Middleware Test

A simplified middleware that logs environment variables and request information without actually authenticating.

### 4. Discovery Endpoint Checker

A shell script to verify your Auth0 domain configuration.

## Emergency Recovery Procedures

If Auth0 authentication completely fails in production:

### Quick Recovery Option 1: Bypass Auth0 Middleware

1. Deploy a minimal middleware that bypasses Auth0 for critical paths:

```typescript
export function middleware(request: NextRequest) {
  // Allow all requests through without Auth0 processing
  return NextResponse.next();
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"],
};
```

### Quick Recovery Option 2: Disable Authentication for Specific Routes

```typescript
export function middleware(request: NextRequest) {
  const url = request.nextUrl;

  // Skip authentication for critical user paths
  if (url.pathname.startsWith("/critical-feature")) {
    return NextResponse.next();
  }

  try {
    return await auth0.middleware(request);
  } catch (err) {
    // Log error and allow request through
    console.error("Auth0 error:", err);
    return NextResponse.next();
  }
}
```

### Long-term Recovery Plan

1. Use diagnostic tools to identify the specific issue
2. Fix environment variables or configuration as needed
3. Deploy a targeted fix for the specific issue
4. Re-enable full authentication once fixed

## Conclusion

Following this guide will help you successfully integrate Auth0 SDK 4.6.0 with your Next.js application and avoid common pitfalls. Remember to use the diagnostic tools to identify issues early and implement the robust error handling patterns shown here to ensure a resilient authentication system.

## Additional Resources

- [Auth0 Next.js SDK Documentation](https://auth0.github.io/nextjs-auth0/)
- [Auth0 Dashboard](https://manage.auth0.com/)
- [Next.js Documentation](https://nextjs.org/docs)
- [Diagnostic Tools Repository](../../tools/auth0-diagnostics/)
