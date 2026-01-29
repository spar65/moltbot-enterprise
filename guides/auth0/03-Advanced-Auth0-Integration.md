# Advanced Auth0 Integration Guide

> This guide covers advanced Auth0 integration topics including multi-tenant applications, role-based access control, silent authentication, and token refresh strategies.

## Table of Contents

1. [Authentication Flow Overview](#authentication-flow-overview)
2. [Multi-Tenant Applications](#multi-tenant-applications)
3. [Role-Based Access Control](#role-based-access-control)
4. [Token Management](#token-management)
5. [Custom Domains](#custom-domains)
6. [Silent Authentication](#silent-authentication)
7. [Advanced Error Handling](#advanced-error-handling)

## Authentication Flow Overview

### Authorization Code Flow with PKCE

Auth0 SDK 4.6.0 implements the Authorization Code Flow with PKCE, which is recommended for server-side web applications.

![Auth Code Flow with PKCE](https://auth0.com/docs/media/articles/authorization-code-grant-pkce.png)

The flow works as follows:

1. User clicks "Log In" and is redirected to Auth0 (`/auth/login`)
2. Auth0 authenticates the user and redirects back to your app (`/auth/callback`) with an authorization code
3. Your app exchanges the code for tokens at Auth0's token endpoint
4. Your app verifies the tokens and creates a session for the authenticated user
5. When the session expires, your app can use a refresh token to obtain new tokens without user interaction

### Security Benefits

This flow provides:

- Protection against CSRF attacks
- PKCE to prevent code interception attacks
- Token storage on the server, not in the browser
- No tokens exposed to browser JavaScript

## Multi-Tenant Applications

### Using Auth0 Organizations

Auth0 Organizations provide a way to represent multi-tenant applications.

#### Step 1: Create an Organization

1. In Auth0 Dashboard, go to "Organizations"
2. Click "Create Organization"
3. Provide a name and display name
4. Click "Create"

#### Step 2: Configure your application

Update your Auth0 client to use Organizations:

```typescript
// src/lib/auth0.ts
export const auth0 = new Auth0Client({
  domain,
  clientId: process.env.AUTH0_CLIENT_ID,
  clientSecret: process.env.AUTH0_CLIENT_SECRET,
  appBaseUrl,
  secret: process.env.AUTH0_SECRET,
  authorizationParams: {
    // This allows organization support
    organization: process.env.AUTH0_ORGANIZATION,
  },
});
```

#### Step 3: Use organization in login

```typescript
// components/LoginButton.tsx
export default function LoginButton({ orgId }) {
  return (
    <a href={`/auth/login?organization=${orgId}`} className="login-button">
      Log In to Organization
    </a>
  );
}
```

#### Step 4: Access organization in session

```typescript
// Get organization from session
const { user } = await auth0.getSession();
const org = user?.org_id;
```

### Organization Branding

To customize branding per organization:

1. In Auth0 Dashboard, go to your Organization
2. Click "Settings" → "Branding"
3. Configure logo, colors, and custom domain

## Role-Based Access Control

### Setting Up Roles in Auth0

1. In Auth0 Dashboard, go to "User Management" → "Roles"
2. Create roles (e.g., "admin", "user", "editor")
3. Assign permissions to roles
4. Assign roles to users

### Adding Roles to Tokens

1. In Auth0 Dashboard, go to "Actions" → "Flows"
2. Select "Login" flow
3. Add a custom action to add roles to tokens:

```javascript
// Auth0 Action
exports.onExecutePostLogin = async (event, api) => {
  if (event.authorization) {
    // Get user's roles
    const roles = event.authorization.roles || [];

    // Add roles to ID token and access token
    api.idToken.setCustomClaim("roles", roles);
    api.accessToken.setCustomClaim("roles", roles);
  }
};
```

### Using Roles in Your Application

```typescript
// middleware to check roles
import { auth0 } from "@/lib/auth0";
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

export async function middleware(request: NextRequest) {
  try {
    // Get session
    const { user } = await auth0.getSession();

    // Check if user has admin role
    const isAdmin = user?.roles?.includes("admin");

    // If trying to access admin area without admin role
    if (request.nextUrl.pathname.startsWith("/admin") && !isAdmin) {
      return NextResponse.redirect(new URL("/unauthorized", request.url));
    }

    return NextResponse.next();
  } catch (error) {
    console.error("Auth error:", error);
    return NextResponse.next();
  }
}

export const config = {
  matcher: ["/admin/:path*"],
};
```

## Token Management

### Token Storage Strategy

Auth0 SDK 4.6.0 provides different token storage options:

1. **In-memory storage** (default): Tokens are stored in memory
   - Pros: More secure, not accessible to JavaScript
   - Cons: Lost on page refresh, requires server roundtrip
2. **Cookie storage**: Tokens are stored in HTTP-only cookies
   - Pros: Persists across page refreshes, not accessible to JavaScript
   - Cons: Limited by cookie size, may have cross-domain issues

### Refresh Token Configuration

Enable refresh tokens in your Auth0 client:

1. In Auth0 Dashboard, go to your application
2. Under "Advanced Settings" → "Grant Types", enable "Refresh Token"
3. Configure SDK to use refresh tokens:

```typescript
// src/lib/auth0.ts
export const auth0 = new Auth0Client({
  domain,
  clientId: process.env.AUTH0_CLIENT_ID,
  clientSecret: process.env.AUTH0_CLIENT_SECRET,
  appBaseUrl,
  secret: process.env.AUTH0_SECRET,
  authorizationParams: {
    // Request offline_access to get refresh tokens
    scope: "openid profile email offline_access",
  },
});
```

### Handling Token Expiration

Auth0 SDK handles token expiration automatically. When a token expires:

1. If a refresh token is available, it's used to get new tokens
2. If no refresh token is available, the user is redirected to login

## Custom Domains

Auth0 allows using custom domains for a branded experience.

### Setting Up a Custom Domain

1. In Auth0 Dashboard, go to "Branding" → "Custom Domains"
2. Click "Add Custom Domain"
3. Choose between Auth0-managed certificates or your own
4. Configure your DNS settings as instructed

### Using Custom Domain in Your App

Update your environment variables to use the custom domain:

```
AUTH0_ISSUER_BASE_URL=https://auth.your-company.com
AUTH0_DOMAIN=auth.your-company.com
```

Your Auth0 client configuration remains the same, but uses these new values.

## Silent Authentication

### Implementing Cross-Tab Authentication

For a seamless experience across browser tabs:

```typescript
// utils/auth.ts
export async function checkSessionInOtherTab() {
  try {
    // Try to get a token silently
    const response = await fetch("/auth/access-token", {
      method: "GET",
      credentials: "same-origin",
    });

    if (response.ok) {
      // User is authenticated in another tab
      window.location.reload();
      return true;
    }
  } catch (error) {
    console.error("Error checking session:", error);
  }

  return false;
}
```

### Custom "Session Expired" Handler

Create a component to handle session expiration gracefully:

```tsx
// components/SessionExpiredModal.tsx
"use client";

import { useState, useEffect } from "react";

export default function SessionExpiredModal() {
  const [isVisible, setIsVisible] = useState(false);

  // Listen for auth errors
  useEffect(() => {
    const handleAuthError = (event) => {
      if (
        event.detail?.type === "auth_error" &&
        event.detail?.error === "login_required"
      ) {
        setIsVisible(true);
      }
    };

    window.addEventListener("auth-error", handleAuthError);
    return () => window.removeEventListener("auth-error", handleAuthError);
  }, []);

  if (!isVisible) return null;

  return (
    <div className="modal">
      <h2>Session Expired</h2>
      <p>Your session has expired. Please log in again to continue.</p>
      <button onClick={() => (window.location.href = "/auth/login")}>
        Log In
      </button>
    </div>
  );
}
```

## Advanced Error Handling

### Circuit Breaker Pattern

Implement a circuit breaker to prevent cascading failures:

```typescript
// lib/auth-circuit-breaker.ts
class AuthCircuitBreaker {
  private failures = 0;
  private lastFailure = 0;
  private isOpen = false;
  private readonly threshold = 5;
  private readonly resetTimeout = 60000; // 1 minute

  public async execute<T>(
    fn: () => Promise<T>,
    fallback: () => Promise<T>
  ): Promise<T> {
    // If circuit is open, use fallback
    if (this.isOpen) {
      // Check if we should reset
      if (Date.now() - this.lastFailure > this.resetTimeout) {
        this.reset();
      } else {
        return fallback();
      }
    }

    try {
      // Try the primary function
      return await fn();
    } catch (error) {
      // Record failure
      this.failures++;
      this.lastFailure = Date.now();

      // Open circuit if too many failures
      if (this.failures >= this.threshold) {
        this.isOpen = true;
        console.error("Auth circuit breaker opened due to repeated failures");
      }

      // Use fallback
      return fallback();
    }
  }

  private reset() {
    this.failures = 0;
    this.isOpen = false;
  }
}

export const authCircuitBreaker = new AuthCircuitBreaker();
```

Use it in middleware:

```typescript
export async function middleware(request: NextRequest) {
  return await authCircuitBreaker.execute(
    // Normal auth flow
    async () => await auth0.middleware(request),
    // Fallback that skips auth
    async () => NextResponse.next()
  );
}
```

### Detailed Logging Strategy

Implement structured logging for authentication events:

```typescript
// lib/auth-logger.ts
type LogLevel = "info" | "warn" | "error";

export class AuthLogger {
  log(level: LogLevel, event: string, details?: any) {
    const logEntry = {
      timestamp: new Date().toISOString(),
      level,
      event,
      details,
      // Include relevant context but no sensitive data
      context: {
        environment: process.env.NODE_ENV,
        version: process.env.NEXT_PUBLIC_VERSION,
      },
    };

    // Log to console in development
    if (process.env.NODE_ENV === "development") {
      console[level](logEntry);
    }

    // In production, send to monitoring service
    if (process.env.NODE_ENV === "production") {
      // Send to your logging service (e.g., Datadog, New Relic, etc.)
      // Example: fetch('/api/logs', { method: 'POST', body: JSON.stringify(logEntry) });
    }
  }

  info(event: string, details?: any) {
    this.log("info", event, details);
  }

  warn(event: string, details?: any) {
    this.log("warn", event, details);
  }

  error(event: string, details?: any) {
    this.log("error", event, details);
  }
}

export const authLogger = new AuthLogger();
```

## Next Steps

Now that you understand advanced Auth0 integration, refer to our other guides:

1. [Auth0 Setup Guide](./01-Auth0-Setup-Guide.md)
2. [Environment-Specific Configuration](./02-Environment-Specific-Guides.md)
3. [Auth0 Testing Guide](./04-Auth0-Testing-Guide.md)
