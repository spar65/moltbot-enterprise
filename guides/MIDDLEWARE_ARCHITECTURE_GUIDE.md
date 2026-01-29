# Next.js Middleware Architecture Guide

## Introduction

This guide provides practical implementation details and best practices for designing a robust middleware architecture in Next.js applications. It complements the `110-middleware-architecture.mdc` rule with real-world examples and solutions to common challenges.

## Table of Contents

1. [Understanding Next.js Middleware](#understanding-nextjs-middleware)
2. [Common Middleware Challenges](#common-middleware-challenges)
3. [Architecture Patterns](#architecture-patterns)
4. [Implementation Guide](#implementation-guide)
5. [Authentication Middleware](#authentication-middleware)
6. [Handling Edge Cases](#handling-edge-cases)
7. [Middleware Conflict Resolution](#middleware-conflict-resolution)
8. [Testing Middleware](#testing-middleware)
9. [Performance Considerations](#performance-considerations)
10. [Best Practices](#best-practices)
11. [Troubleshooting](#troubleshooting)

## Understanding Next.js Middleware

### What is Next.js Middleware?

Next.js middleware runs before a request is completed, allowing you to modify the response by:

- Rewriting, redirecting, or modifying request/response headers
- Intercepting and modifying the response
- Implementing authentication, logging, or analytics

Middleware runs on the Edge Runtime, making it highly performant and able to execute before the cache and rendering.

### Middleware Execution Flow

1. Browser makes request to your Next.js application
2. Middleware executes before the request reaches your pages or API routes
3. Middleware can modify the request or response, or terminate the request early
4. If middleware doesn't terminate the request, it continues to your Next.js pages or API routes

### Middleware vs. API Routes vs. getServerSideProps

| Feature            | Middleware            | API Routes     | getServerSideProps |
| ------------------ | --------------------- | -------------- | ------------------ |
| Execution Timing   | Before page/API route | On API request | During SSR         |
| Can Redirect       | Yes                   | Yes            | Yes                |
| Can Modify Headers | Yes                   | Yes            | Limited            |
| Runtime            | Edge                  | Node.js        | Node.js            |
| Access to Database | Limited               | Yes            | Yes                |
| Client-side Access | No                    | Yes (fetch)    | No                 |
| Page Rendering     | No                    | No             | Yes                |

## Common Middleware Challenges

### 1. Nested Middleware Execution

**Problem**: Next.js can execute middleware multiple times for a single request due to how it handles rewrites and redirects.

**Example Scenario**:

- Middleware redirects `/dashboard` to `/dashboard/overview`
- Middleware runs again for `/dashboard/overview`
- Auth checks and other operations are duplicated

**Solution**: Implement a middleware execution guard that prevents the same middleware from running multiple times on related requests.

### 2. Managing Multiple Middleware Concerns

**Problem**: As applications grow, middleware often needs to handle multiple concerns like authentication, rate limiting, logging, etc.

**Solution**: Implement a composable middleware architecture that allows you to:

- Create specialized middleware components
- Compose them into a processing pipeline
- Execute them in a specified order

### 3. Configuration Complexity

**Problem**: Hard-coding middleware behavior makes it difficult to maintain and change.

**Solution**: Create a configuration-driven approach with:

- Path matchers for determining which routes a middleware applies to
- Feature flags for enabling/disabling middleware
- Centralized configuration for middleware parameters

### 4. Performance Overhead

**Problem**: Poorly implemented middleware can add significant latency to requests.

**Solution**:

- Optimize middleware execution with caching
- Conditionally run middleware only on relevant paths
- Use the Edge Runtime for performance-critical middleware

## Architecture Patterns

### Middleware Factory Pattern

Create middleware using factory functions to allow configuration:

```typescript
// src/lib/middleware/createRateLimitMiddleware.ts
import { NextRequest, NextResponse } from "next/server";
import { MiddlewareFunction } from "./types";

export function createRateLimitMiddleware(options: {
  limit?: number;
  windowMs?: number;
  keyGenerator?: (req: NextRequest) => string;
}): MiddlewareFunction {
  const {
    limit = 60,
    windowMs = 60 * 1000,
    keyGenerator = (req) => req.ip || "",
  } = options;

  // Store request counts (in a real app, use Redis or similar)
  const requests = new Map<string, { count: number; resetTime: number }>();

  return async function rateLimitMiddleware(req: NextRequest) {
    const key = keyGenerator(req);
    const now = Date.now();

    // Initialize or reset if window has passed
    if (!requests.has(key) || requests.get(key)!.resetTime < now) {
      requests.set(key, { count: 1, resetTime: now + windowMs });
      return null; // Continue to next middleware
    }

    // Increment count
    const data = requests.get(key)!;
    data.count++;

    // Check if over limit
    if (data.count > limit) {
      const resetTime = data.resetTime;
      const retryAfter = Math.ceil((resetTime - now) / 1000);

      // Return rate limit response
      return NextResponse.json(
        { error: "Too many requests", retryAfter },
        {
          status: 429,
          headers: {
            "Retry-After": String(retryAfter),
            "X-RateLimit-Limit": String(limit),
            "X-RateLimit-Remaining": "0",
            "X-RateLimit-Reset": String(Math.ceil(resetTime / 1000)),
          },
        }
      );
    }

    // Update the map
    requests.set(key, data);

    // Continue to next middleware
    return null;
  };
}
```

### Middleware Composition Pattern

Compose multiple middleware functions into a single middleware pipeline:

```typescript
// src/lib/middleware/compose.ts
import { NextRequest, NextResponse } from "next/server";
import { MiddlewareFunction } from "./types";

export function composeMiddleware(
  ...middlewares: MiddlewareFunction[]
): MiddlewareFunction {
  return async function composedMiddleware(req: NextRequest) {
    let response: NextResponse | null = null;

    for (const middleware of middlewares) {
      try {
        // Execute middleware
        const result = await middleware(req);

        // If middleware returns a response, use it and break the chain
        if (result) {
          response = result;
          break;
        }
      } catch (error) {
        console.error("Middleware error:", error);
        // Return 500 error
        return NextResponse.json(
          { error: "Internal Server Error" },
          { status: 500 }
        );
      }
    }

    // If no middleware returned a response, continue
    return response || NextResponse.next();
  };
}
```

### Configuration-Driven Pattern

Make middleware behavior configurable:

```typescript
// middleware.config.ts
export interface MiddlewareConfig {
  enabled: boolean;
  paths: {
    include: string[];
    exclude: string[];
  };
  options: Record<string, any>;
}

export const middlewareConfig: Record<string, MiddlewareConfig> = {
  auth: {
    enabled: true,
    paths: {
      include: ["/dashboard", "/account", "/api/private"],
      exclude: ["/api/public", "/login", "/register"],
    },
    options: {
      loginUrl: "/login",
      cookieName: "auth_token",
    },
  },
  rateLimit: {
    enabled: true,
    paths: {
      include: ["/api"],
      exclude: ["/api/health"],
    },
    options: {
      limit: 60,
      windowMs: 60 * 1000,
    },
  },
};
```

## Implementation Guide

### Step 1: Create Middleware Types

```typescript
// src/lib/middleware/types.ts
import { NextRequest, NextResponse } from "next/server";

export type MiddlewareFunction = (
  request: NextRequest,
  response?: NextResponse
) => Promise<NextResponse | undefined | null> | NextResponse | undefined | null;

export interface MiddlewareConfig {
  enabled?: boolean;
  matcher?: string | string[];
  paths?: {
    include?: string[];
    exclude?: string[];
  };
}
```

### Step 2: Create Path Matcher Utility

```typescript
// src/lib/middleware/matcher.ts
import { NextRequest } from "next/server";

export function shouldProcessPath(
  req: NextRequest,
  config: {
    include?: string[];
    exclude?: string[];
  } = {}
): boolean {
  const { pathname } = req.nextUrl;
  const { include = [], exclude = [] } = config;

  // Common static assets that should be excluded by default
  const defaultExclude = ["/_next/", "/static/", "/favicon.ico", "/robots.txt"];

  // Check exclusions first
  const allExclusions = [...defaultExclude, ...exclude];
  if (allExclusions.some((path) => pathname.startsWith(path))) {
    return false;
  }

  // If includes are specified, path must match at least one
  if (include.length > 0) {
    return include.some((path) => pathname.startsWith(path));
  }

  // If no includes are specified, process all non-excluded paths
  return true;
}
```

### Step 3: Create Middleware Components

Create individual middleware components for each concern:

```typescript
// src/lib/middleware/auth.ts
// Authentication middleware implementation

// src/lib/middleware/rate-limit.ts
// Rate limiting middleware implementation

// src/lib/middleware/metrics.ts
// Metrics collection middleware implementation

// src/lib/middleware/security.ts
// Security headers middleware implementation
```

### Step 4: Create Nested Middleware Guard

```typescript
// src/lib/middleware/nested.ts
import { NextRequest, NextResponse } from "next/server";

export function createNestedMiddlewareGuard() {
  // Create a token to identify middleware execution
  const executionToken = `mw_${Date.now()}_${Math.random()
    .toString(36)
    .substring(2, 15)}`;

  return function nestedMiddlewareGuard(req: NextRequest) {
    // Check if middleware has already executed for this request
    const previousExecution = req.headers.get("x-middleware-execution");

    if (previousExecution === executionToken) {
      // Middleware has already run, skip
      return NextResponse.next();
    }

    // Mark request as processed
    const response = NextResponse.next();
    response.headers.set("x-middleware-execution", executionToken);

    return response;
  };
}
```

### Step 5: Implement Root Middleware

```typescript
// src/middleware.ts
import { NextRequest, NextResponse } from "next/server";
import { composeMiddleware } from "./lib/middleware/compose";
import { shouldProcessPath } from "./lib/middleware/matcher";
import { createAuthMiddleware } from "./lib/middleware/auth";
import { createRateLimitMiddleware } from "./lib/middleware/rate-limit";
import { createSecurityMiddleware } from "./lib/middleware/security";
import { createNestedMiddlewareGuard } from "./lib/middleware/nested";
import { middlewareConfig } from "../middleware.config";

// Initialize middleware
const nestedGuard = createNestedMiddlewareGuard();
const authMiddleware = createAuthMiddleware(middlewareConfig.auth.options);
const rateLimitMiddleware = createRateLimitMiddleware(
  middlewareConfig.rateLimit.options
);
const securityMiddleware = createSecurityMiddleware(
  middlewareConfig.security.options
);

// Main middleware handler
export async function middleware(req: NextRequest) {
  // Prevent nested middleware execution
  const guardResult = nestedGuard(req);
  if (!guardResult.headers.has("x-middleware-execution")) {
    // Already processed by this middleware, just pass through
    return guardResult;
  }

  // Create the middleware pipeline
  const pipeline = composeMiddleware(
    // Security headers for all routes
    async (req) => {
      if (
        middlewareConfig.security.enabled &&
        shouldProcessPath(req, middlewareConfig.security.paths)
      ) {
        return securityMiddleware(req);
      }
      return null;
    },

    // Rate limiting for API routes
    async (req) => {
      if (
        middlewareConfig.rateLimit.enabled &&
        shouldProcessPath(req, middlewareConfig.rateLimit.paths)
      ) {
        return rateLimitMiddleware(req);
      }
      return null;
    },

    // Authentication for protected routes
    async (req) => {
      if (
        middlewareConfig.auth.enabled &&
        shouldProcessPath(req, middlewareConfig.auth.paths)
      ) {
        return authMiddleware(req);
      }
      return null;
    }
  );

  // Execute the pipeline
  return pipeline(req);
}

// Configure middleware matcher
export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"],
};
```

## Authentication Middleware

### Implementation Example

```typescript
// src/lib/middleware/auth.ts
import { NextRequest, NextResponse } from "next/server";
import { verifyAuthToken } from "../auth/token";
import { MiddlewareFunction } from "./types";

export function createAuthMiddleware(options: {
  loginUrl?: string;
  cookieName?: string;
  headerName?: string;
}): MiddlewareFunction {
  const {
    loginUrl = "/login",
    cookieName = "auth_token",
    headerName = "Authorization",
  } = options;

  return async function authMiddleware(req: NextRequest) {
    try {
      // Skip authentication for public routes
      if (
        req.nextUrl.pathname.startsWith(loginUrl) ||
        req.nextUrl.pathname.startsWith("/api/auth")
      ) {
        return null;
      }

      // Get token from cookie or authorization header
      const token =
        req.cookies.get(cookieName)?.value ||
        req.headers.get(headerName)?.replace("Bearer ", "");

      // No token found, redirect to login
      if (!token) {
        const url = new URL(loginUrl, req.url);
        url.searchParams.set(
          "returnTo",
          req.nextUrl.pathname + req.nextUrl.search
        );
        return NextResponse.redirect(url);
      }

      // Verify token
      const user = await verifyAuthToken(token);

      if (!user) {
        // Invalid token, redirect to login
        const url = new URL(loginUrl, req.url);
        url.searchParams.set(
          "returnTo",
          req.nextUrl.pathname + req.nextUrl.search
        );
        return NextResponse.redirect(url);
      }

      // Token is valid, add user to request headers
      const response = NextResponse.next();
      response.headers.set("x-user-id", user.id);
      response.headers.set("x-user-email", user.email);
      response.headers.set("x-user-roles", JSON.stringify(user.roles || []));

      return response;
    } catch (error) {
      console.error("Authentication middleware error:", error);

      // Redirect to login on error
      const url = new URL(loginUrl, req.url);
      url.searchParams.set(
        "returnTo",
        req.nextUrl.pathname + req.nextUrl.search
      );
      return NextResponse.redirect(url);
    }
  };
}
```

### Provider-Agnostic Token Verification

```typescript
// src/lib/auth/token.ts
import { jwtVerify } from "jose";
import { getAuth0PublicKey } from "./auth0";
import { getFirebasePublicKey } from "./firebase";
import { getClerkPublicKey } from "./clerk";

// User type
export interface User {
  id: string;
  email: string;
  name?: string;
  roles?: string[];
  [key: string]: any;
}

/**
 * Verify an auth token regardless of provider
 */
export async function verifyAuthToken(token: string): Promise<User | null> {
  try {
    // Determine token type
    const tokenType = detectTokenType(token);

    switch (tokenType) {
      case "auth0":
        return await verifyAuth0Token(token);
      case "firebase":
        return await verifyFirebaseToken(token);
      case "clerk":
        return await verifyClerkToken(token);
      default:
        throw new Error("Unknown token type");
    }
  } catch (error) {
    console.error("Token verification error:", error);
    return null;
  }
}

/**
 * Detect token type based on structure or claims
 */
function detectTokenType(
  token: string
): "auth0" | "firebase" | "clerk" | "unknown" {
  try {
    // Simple heuristic: decode the token and check for identifying claims
    const decoded = JSON.parse(
      Buffer.from(token.split(".")[1], "base64").toString()
    );

    if (decoded.iss?.includes("auth0.com")) {
      return "auth0";
    }

    if (decoded.iss?.includes("securetoken.google.com")) {
      return "firebase";
    }

    if (decoded.iss?.includes("clerk.")) {
      return "clerk";
    }

    return "unknown";
  } catch (error) {
    return "unknown";
  }
}

// Implement provider-specific verification functions
async function verifyAuth0Token(token: string): Promise<User | null> {
  // Implementation
}

async function verifyFirebaseToken(token: string): Promise<User | null> {
  // Implementation
}

async function verifyClerkToken(token: string): Promise<User | null> {
  // Implementation
}
```

## Handling Edge Cases

### Multi-Domain Applications

When working with applications spanning multiple domains or subdomains:

```typescript
// src/lib/middleware/multi-domain.ts
import { NextRequest, NextResponse } from "next/server";
import { MiddlewareFunction } from "./types";

export function createMultiDomainMiddleware(options: {
  domains: Record<string, { loginUrl: string }>;
  defaultDomain: string;
}): MiddlewareFunction {
  const { domains, defaultDomain } = options;

  return function multiDomainMiddleware(req: NextRequest) {
    // Get the hostname
    const hostname = req.headers.get("host") || defaultDomain;

    // Find the domain configuration
    const domainConfig = Object.entries(domains).find(([domain]) =>
      hostname.includes(domain)
    );

    if (domainConfig) {
      // Clone the response
      const response = NextResponse.next();

      // Add domain-specific information to headers
      response.headers.set("x-domain", domainConfig[0]);
      response.headers.set("x-login-url", domainConfig[1].loginUrl);

      return response;
    }

    // Use default domain configuration
    const response = NextResponse.next();
    response.headers.set("x-domain", defaultDomain);
    response.headers.set("x-login-url", domains[defaultDomain].loginUrl);

    return response;
  };
}
```

### Handling Redirects from Middleware

When redirecting from middleware, maintain query parameters and handle relative paths:

```typescript
// src/lib/middleware/redirect.ts
import { NextRequest, NextResponse } from "next/server";

export function safeRedirect(
  req: NextRequest,
  destination: string
): NextResponse {
  // Create a URL object from the destination
  const url = destination.startsWith("/")
    ? new URL(destination, req.url) // Relative path
    : new URL(destination); // Absolute URL

  // Add returnTo parameter for authentication redirects
  if (destination.includes("/login") || destination.includes("/auth")) {
    const returnTo = req.nextUrl.pathname + req.nextUrl.search;
    url.searchParams.set("returnTo", returnTo);
  }

  // Create the redirect response
  return NextResponse.redirect(url);
}
```

### Handling File Uploads and Large Requests

Middleware runs on the Edge Runtime, which has limitations for large requests:

```typescript
// src/lib/middleware/uploads.ts
import { NextRequest, NextResponse } from "next/server";
import { MiddlewareFunction } from "./types";

export function createUploadBypassMiddleware(): MiddlewareFunction {
  return function uploadBypassMiddleware(req: NextRequest) {
    // Check if this is an upload request (content-type or path-based detection)
    const isUpload =
      req.headers.get("content-type")?.includes("multipart/form-data") ||
      req.nextUrl.pathname.startsWith("/api/upload");

    if (isUpload) {
      // Skip middleware processing for upload requests
      const response = NextResponse.next();
      response.headers.set("x-middleware-bypassed", "true");
      return response;
    }

    return null;
  };
}
```

## Middleware Conflict Resolution

Middleware conflicts occur when multiple middleware components attempt to modify the same request or response properties, or when they produce contradictory outcomes. Here's how to effectively manage and resolve these conflicts:

### Common Conflict Scenarios

1. **Header Conflicts**: Multiple middleware components setting the same header to different values
2. **Redirect Conflicts**: Different middleware attempting to redirect to different URLs
3. **Auth vs. Rate Limiting**: Authentication middleware allowing a request that rate limiting should block
4. **Response Transformation Conflicts**: Multiple middleware trying to transform the response body
5. **Cache Control Conflicts**: Different cache directives being set by security and performance middleware

### Prioritization Strategy

Implement a clear prioritization strategy to resolve conflicts:

```typescript
// src/lib/middleware/priority.ts
export enum MiddlewarePriority {
  CRITICAL = 0, // Security-critical middleware (runs first)
  HIGH = 1, // Authentication, rate limiting
  MEDIUM = 2, // Logging, metrics
  LOW = 3, // Convenience, non-essential transforms
}

export interface PrioritizedMiddleware {
  middleware: MiddlewareFunction;
  priority: MiddlewarePriority;
  name: string;
}

// Sort middleware by priority
export function sortMiddlewareByPriority(
  middlewareList: PrioritizedMiddleware[]
): MiddlewareFunction[] {
  // Sort by priority (lower number = higher priority)
  const sorted = [...middlewareList].sort((a, b) => a.priority - b.priority);
  return sorted.map((item) => item.middleware);
}
```

### Conflict Resolution Implementation

Create a conflict resolution system:

```typescript
// src/lib/middleware/resolve-conflicts.ts
import { NextResponse } from "next/server";

// Resolve header conflicts
export function resolveHeaderConflicts(
  headers: Headers,
  conflictStrategy: "first-wins" | "last-wins" | "merge" = "last-wins"
): Headers {
  // Track original and final header values
  const headerLog: Record<string, string[]> = {};
  const finalHeaders = new Headers();

  // Collect all header entries
  for (const [key, value] of headers.entries()) {
    if (!headerLog[key]) {
      headerLog[key] = [];
    }
    headerLog[key].push(value);
  }

  // Resolve conflicts based on strategy
  for (const [key, values] of Object.entries(headerLog)) {
    if (values.length === 1) {
      // No conflict
      finalHeaders.set(key, values[0]);
    } else {
      // Conflict resolution
      switch (conflictStrategy) {
        case "first-wins":
          finalHeaders.set(key, values[0]);
          break;
        case "last-wins":
          finalHeaders.set(key, values[values.length - 1]);
          break;
        case "merge":
          // Only works for certain headers like Set-Cookie
          values.forEach((value) => finalHeaders.append(key, value));
          break;
      }

      // Log conflict in development
      if (process.env.NODE_ENV === "development") {
        console.warn(`Middleware header conflict for "${key}":`, values);
        console.warn(`Resolved to: ${finalHeaders.get(key)}`);
      }
    }
  }

  return finalHeaders;
}

// Enhanced NextResponse with conflict resolution
export function createConflictAwareResponse(
  baseResponse: NextResponse,
  conflictStrategy: "first-wins" | "last-wins" | "merge" = "last-wins"
): NextResponse {
  // Create new response with same status
  const newResponse = new NextResponse(null, {
    status: baseResponse.status,
    statusText: baseResponse.statusText,
  });

  // Resolve header conflicts
  const resolvedHeaders = resolveHeaderConflicts(
    baseResponse.headers,
    conflictStrategy
  );

  // Apply resolved headers
  for (const [key, value] of resolvedHeaders.entries()) {
    newResponse.headers.set(key, value);
  }

  return newResponse;
}
```

### Handling Redirect Conflicts

When multiple middleware components attempt to redirect:

```typescript
// src/lib/middleware/redirect-resolver.ts
import { NextRequest, NextResponse } from "next/server";

export interface RedirectIntent {
  url: URL;
  priority: number;
  reason: string;
}

// Manage multiple potential redirects
export class RedirectResolver {
  private redirects: RedirectIntent[] = [];

  // Add a potential redirect
  addRedirect(redirect: RedirectIntent): void {
    this.redirects.push(redirect);
  }

  // Get the highest priority redirect
  resolveRedirect(): URL | null {
    if (this.redirects.length === 0) {
      return null;
    }

    // Sort by priority (higher number = higher priority)
    this.redirects.sort((a, b) => b.priority - a.priority);

    // Log conflicts in development
    if (this.redirects.length > 1 && process.env.NODE_ENV === "development") {
      console.warn(
        "Middleware redirect conflict:",
        this.redirects.map((r) => ({
          url: r.url.toString(),
          priority: r.priority,
          reason: r.reason,
        }))
      );
      console.warn(`Resolved to: ${this.redirects[0].url.toString()}`);
    }

    return this.redirects[0].url;
  }

  // Clear all redirects
  clear(): void {
    this.redirects = [];
  }
}

// Usage in middleware
export function createRedirectMiddleware(redirectResolver: RedirectResolver) {
  return async function redirectMiddleware(req: NextRequest) {
    // Process the request and get the highest priority redirect
    const redirectUrl = redirectResolver.resolveRedirect();

    if (redirectUrl) {
      // Perform the redirect
      return NextResponse.redirect(redirectUrl);
    }

    // No redirect needed
    return null;
  };
}
```

### Authentication and Rate Limiting Conflict

When combining authentication and rate limiting:

```typescript
// src/lib/middleware/auth-rate-limit.ts
import { NextRequest, NextResponse } from "next/server";

export function createAuthAwareRateLimiter(options: {
  authenticated: {
    limit: number;
    windowMs: number;
  };
  anonymous: {
    limit: number;
    windowMs: number;
  };
}) {
  // Separate rate limiters for authenticated and anonymous users
  const authenticatedLimiter = createRateLimitMiddleware({
    limit: options.authenticated.limit,
    windowMs: options.authenticated.windowMs,
    keyGenerator: (req) => {
      // Use user ID from auth middleware
      const userId = req.headers.get("x-user-id");
      return userId || "anonymous";
    },
  });

  const anonymousLimiter = createRateLimitMiddleware({
    limit: options.anonymous.limit,
    windowMs: options.anonymous.windowMs,
    keyGenerator: (req) => req.ip || "",
  });

  // Combined middleware that applies different rate limits
  return async function authAwareRateLimiter(req: NextRequest) {
    // Check if user is authenticated by looking for header set by auth middleware
    const isAuthenticated = !!req.headers.get("x-user-id");

    // Apply appropriate rate limiter
    if (isAuthenticated) {
      return authenticatedLimiter(req);
    } else {
      return anonymousLimiter(req);
    }
  };
}
```

### Conflict-Aware Middleware Composition

Modify the middleware composition function to handle conflicts:

```typescript
// src/lib/middleware/compose-with-conflict-resolution.ts
import { NextRequest, NextResponse } from "next/server";
import { MiddlewareFunction } from "./types";
import { createConflictAwareResponse } from "./resolve-conflicts";
import { RedirectResolver } from "./redirect-resolver";

export function composeMiddlewareWithConflictResolution(
  ...middlewares: MiddlewareFunction[]
): MiddlewareFunction {
  return async function composedMiddleware(req: NextRequest) {
    // Create redirect resolver
    const redirectResolver = new RedirectResolver();

    // Track headers set by each middleware
    let response = NextResponse.next();

    // Execute each middleware
    for (const middleware of middlewares) {
      try {
        const result = await middleware(req);

        // Check if middleware returned a redirect
        if (result?.headers.has("Location")) {
          // Store redirect intent instead of returning immediately
          redirectResolver.addRedirect({
            url: new URL(result.headers.get("Location") || "", req.url),
            priority: middlewares.indexOf(middleware), // Earlier middleware = higher priority
            reason: `Middleware at index ${middlewares.indexOf(middleware)}`,
          });
          continue;
        }

        // If middleware returned a response, update our accumulated response
        if (result) {
          // Merge headers from result into our response
          for (const [key, value] of result.headers.entries()) {
            response.headers.set(key, value);
          }

          // Update status if it was changed
          if (result.status !== 200) {
            response = new NextResponse(null, {
              status: result.status,
              statusText: result.statusText,
              headers: response.headers,
            });
          }
        }
      } catch (error) {
        console.error("Middleware error:", error);
        return NextResponse.json(
          { error: "Internal Server Error" },
          { status: 500 }
        );
      }
    }

    // Check if we need to redirect
    const redirectUrl = redirectResolver.resolveRedirect();
    if (redirectUrl) {
      return NextResponse.redirect(redirectUrl);
    }

    // Resolve any header conflicts
    return createConflictAwareResponse(response);
  };
}
```

## Testing Middleware

### Unit Testing Individual Middleware

```typescript
// __tests__/middleware/auth.test.ts
import { NextRequest, NextResponse } from "next/server";
import { createAuthMiddleware } from "../../src/lib/middleware/auth";
import {
  createMockRequest,
  runMiddleware,
} from "../../src/lib/middleware/testing";
import * as tokenUtils from "../../src/lib/auth/token";

// Mock the token verification function
jest.mock("../../src/lib/auth/token");

describe("Auth Middleware", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test("redirects to login when no token is present", async () => {
    // Create middleware
    const authMiddleware = createAuthMiddleware({
      loginUrl: "/auth/login",
    });

    // Create mock request
    const req = createMockRequest({
      url: "/dashboard",
    });

    // Run middleware
    const response = await runMiddleware(authMiddleware, req);

    // Assert redirect
    expect(response.status).toBe(307); // Temporary redirect
    expect(response.headers.get("location")).toContain("/auth/login");
    expect(response.headers.get("location")).toContain("returnTo=/dashboard");
  });

  test("continues with valid token", async () => {
    // Mock token verification
    (tokenUtils.verifyAuthToken as jest.Mock).mockResolvedValue({
      id: "user-123",
      email: "user@example.com",
      roles: ["user"],
    });

    // Create middleware
    const authMiddleware = createAuthMiddleware({
      loginUrl: "/auth/login",
    });

    // Create mock request with token
    const req = createMockRequest({
      url: "/dashboard",
      cookies: {
        auth_token: "valid-token",
      },
    });

    // Run middleware
    const response = await runMiddleware(authMiddleware, req);

    // Assert continuation
    expect(response.status).toBe(200);
    expect(response.headers.get("x-user-id")).toBe("user-123");
    expect(response.headers.get("x-user-email")).toBe("user@example.com");
    expect(response.headers.get("x-user-roles")).toBe('["user"]');
  });
});
```

### Integration Testing Middleware Pipeline

```typescript
// __tests__/middleware/pipeline.test.ts
import { NextRequest, NextResponse } from "next/server";
import { middleware } from "../../src/middleware";
import { createMockRequest } from "../../src/lib/middleware/testing";
import * as tokenUtils from "../../src/lib/auth/token";

// Mock the token verification function
jest.mock("../../src/lib/auth/token");

describe("Middleware Pipeline", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test("applies security headers to all routes", async () => {
    // Create mock request
    const req = createMockRequest({
      url: "/",
    });

    // Run middleware
    const response = await middleware(req);

    // Assert security headers
    expect(response.headers.get("X-Content-Type-Options")).toBe("nosniff");
    expect(response.headers.get("X-Frame-Options")).toBe("DENY");
    expect(response.headers.get("X-XSS-Protection")).toBe("1; mode=block");
  });

  test("applies rate limiting to API routes", async () => {
    // Create many requests to trigger rate limit
    const requests = Array(70)
      .fill(null)
      .map(() =>
        createMockRequest({
          url: "/api/data",
          headers: {
            "x-forwarded-for": "127.0.0.1",
          },
        })
      );

    // Run middleware for each request
    let lastResponse;
    for (const req of requests) {
      lastResponse = await middleware(req);
    }

    // Assert rate limit response
    expect(lastResponse.status).toBe(429);
    expect(lastResponse.headers.get("Retry-After")).toBeTruthy();
  });

  test("authentication takes precedence over other middleware", async () => {
    // Create mock request for protected route
    const req = createMockRequest({
      url: "/dashboard",
    });

    // Run middleware
    const response = await middleware(req);

    // Assert redirect to login (auth middleware ran first)
    expect(response.status).toBe(307);
    expect(response.headers.get("location")).toContain("/login");
  });
});
```

## Performance Considerations

### Middleware Performance Optimization

1. **Minimize Bundle Size**

   - Keep middleware code small and focused
   - Avoid large dependencies in middleware

2. **Use Conditional Execution**

   - Only run middleware on relevant paths
   - Short-circuit when possible

3. **Leverage Caching**

   - Cache expensive operations
   - Use Incremental Static Regeneration (ISR) for pages

4. **Efficient Token Verification**
   - Use JWKs caching for token verification
   - Implement token claim validation efficiently

### Performance Monitoring

Add instrumentation to measure middleware performance:

```typescript
// src/lib/middleware/performance-monitor.ts
import { NextRequest, NextResponse } from "next/server";
import { MiddlewareFunction } from "./types";

export function createPerformanceMonitorMiddleware(): MiddlewareFunction {
  return function performanceMonitorMiddleware(req: NextRequest) {
    // Start timing
    const start = Date.now();

    // Add timing header to response
    const response = NextResponse.next();

    // Calculate duration
    const duration = Date.now() - start;

    // Add timing information
    response.headers.set("Server-Timing", `middleware;dur=${duration}`);

    // In a real app, you might send this to your monitoring system
    if (duration > 50) {
      // More than 50ms is slow
      console.warn(
        `Slow middleware execution: ${duration}ms for ${req.nextUrl.pathname}`
      );
    }

    return response;
  };
}
```

## Best Practices

### 1. Keep Middleware Focused

Each middleware function should have a single responsibility:

- Authentication
- Rate limiting
- Logging
- Security headers
- etc.

### 2. Use Factory Functions

Always use factory functions to create middleware:

- Allows configuration
- Enables reuse
- Makes testing easier

### 3. Handle Errors Gracefully

Always include error handling in middleware:

- Catch and log errors
- Provide appropriate fallbacks
- Avoid exposing sensitive information

### 4. Test Thoroughly

Create comprehensive tests for middleware:

- Unit tests for individual middleware
- Integration tests for middleware pipelines
- Edge case testing

### 5. Document Middleware Behavior

Document your middleware architecture:

- What each middleware does
- Order of execution
- Configuration options
- Path matching rules

### 6. Use TypeScript

Use TypeScript for type safety:

- Define interfaces for middleware functions
- Type configuration objects
- Ensure consistent return types

### 7. Configure Matcher Patterns

Use specific matcher patterns to optimize performance:

- Only run middleware on relevant paths
- Exclude static assets
- Use regex patterns for complex matching

## Troubleshooting

### Common Middleware Issues

#### 1. Infinite Redirect Loops

**Problem**: Middleware redirects to a path that triggers the same middleware.

**Solution**:

- Implement a redirect counter in a cookie
- Add path exclusions for redirect targets
- Use the nested middleware guard

#### 2. Middleware Not Running

**Problem**: Middleware doesn't seem to execute for certain paths.

**Solution**:

- Check your matcher configuration
- Verify that the path isn't excluded
- Ensure you're not accidentally short-circuiting the middleware

#### 3. Headers Not Being Set

**Problem**: Headers set in middleware aren't visible in API routes or components.

**Solution**:

- Use x-prefix for custom headers
- Use cookies for persistent data
- Remember that headers from middleware to page components are filtered

#### 4. Middleware Execution Order Issues

**Problem**: Middleware components execute in unexpected order.

**Solution**:

- Use explicit ordering in your composition function
- Add logging to trace middleware execution
- Create a proper middleware pipeline

#### 5. Performance Issues

**Problem**: Middleware adds significant latency to requests.

**Solution**:

- Implement caching for expensive operations
- Use conditional execution based on paths
- Optimize token verification and other slow operations

### Debugging Middleware

Add debug logging to middleware:

```typescript
// src/lib/middleware/debug.ts
import { NextRequest, NextResponse } from "next/server";
import { MiddlewareFunction } from "./types";

export function createDebugMiddleware(): MiddlewareFunction {
  return function debugMiddleware(req: NextRequest) {
    // Only enable in development
    if (process.env.NODE_ENV !== "development") {
      return null;
    }

    // Log request details
    console.log("-------- MIDDLEWARE DEBUG --------");
    console.log(`URL: ${req.nextUrl.pathname}${req.nextUrl.search}`);
    console.log(`Method: ${req.method}`);
    console.log("Headers:", Object.fromEntries(req.headers.entries()));
    console.log(
      "Cookies:",
      Object.fromEntries(req.cookies.getAll().map((c) => [c.name, c.value]))
    );
    console.log("----------------------------------");

    // Continue to next middleware
    return null;
  };
}
```

## Conclusion

A well-designed middleware architecture is crucial for scalable Next.js applications. By following the patterns and best practices in this guide, you can create a modular, maintainable, and performant middleware system that handles authentication, security, and other cross-cutting concerns elegantly.

Remember these key principles:

- Keep middleware focused on a single responsibility
- Use composition to build complex pipelines
- Make middleware behavior configurable
- Test thoroughly
- Optimize for performance
- Implement robust conflict resolution strategies

For specific questions or assistance with your middleware implementation, refer to the [Next.js middleware documentation](https://nextjs.org/docs/advanced-features/middleware) or the `110-middleware-architecture.mdc` rule in your project.
