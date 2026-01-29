# Environment-Specific Auth0 Implementation Guides

> This guide provides detailed instructions for implementing Auth0 SDK 4.6.0 in different Next.js environments and router types.

## Table of Contents

1. [Environment-Specific Considerations](#environment-specific-considerations)
2. [Next.js Pages Router Implementation](#nextjs-pages-router-implementation)
3. [Next.js App Router Implementation](#nextjs-app-router-implementation)
4. [Managing Multiple Environments](#managing-multiple-environments)
5. [Edge Runtime Considerations](#edge-runtime-considerations)
6. [Version Compatibility Matrix](#version-compatibility-matrix)

## Environment-Specific Considerations

Auth0 implementation varies significantly depending on:

- Next.js router type (Pages Router vs App Router)
- Next.js version (13.x vs 14.x+)
- Deployment environment (Vercel vs self-hosted)
- Runtime environment (Node.js vs Edge)

This guide provides specific instructions for each combination.

## Next.js Pages Router Implementation

### Pages Router with Auth0 SDK 4.6.0

#### Step 1: Install dependencies

```bash
npm install @auth0/nextjs-auth0@4.6.0
```

#### Step 2: Create Auth0 client

Create `src/lib/auth0.ts`:

```typescript
import { Auth0Client } from "@auth0/nextjs-auth0/server";

// Helper for URL validation
const getValidUrl = (url?: string): string => {
  if (!url) return "";
  try {
    new URL(url);
    return url;
  } catch (err) {
    try {
      const urlWithProtocol = `https://${url}`;
      new URL(urlWithProtocol);
      return urlWithProtocol;
    } catch (err) {
      return "";
    }
  }
};

// Get domain with fallback extraction
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

// Prepare validated parameters
const appBaseUrl = getValidUrl(
  process.env.AUTH0_BASE_URL ||
    process.env.APP_BASE_URL ||
    (process.env.VERCEL_URL ? `https://${process.env.VERCEL_URL}` : "")
);

const domain =
  process.env.AUTH0_DOMAIN ||
  extractDomainFromIssuerUrl(process.env.AUTH0_ISSUER_BASE_URL) ||
  "";

// Create Auth0 client
export const auth0 = new Auth0Client({
  domain,
  clientId: process.env.AUTH0_CLIENT_ID,
  clientSecret: process.env.AUTH0_CLIENT_SECRET,
  appBaseUrl,
  secret: process.env.AUTH0_SECRET,
});

export default auth0;
```

#### Step 3: Set up Auth0 API routes

Create `src/pages/auth/[...auth0].ts`:

```typescript
import { auth0 } from "../../lib/auth0";

// This handles login, callback, logout, etc.
export default auth0.handleAuth();
```

#### Step 4: Configure middleware

Create `middleware.ts` in your project root:

```typescript
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { auth0 } from "./src/lib/auth0";

// Extract base URL from request headers
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
    return await auth0.middleware(request);
  } catch (err: any) {
    const error = err instanceof Error ? err : new Error(String(err));
    console.error(`Auth0 middleware error:`, error.message);

    // Handle URL construction errors
    if (error.message?.includes("Invalid URL")) {
      const pathname = request.nextUrl.pathname;
      const baseUrl = extractBaseUrl(request);

      if (pathname === "/auth/login") {
        return NextResponse.redirect(`${baseUrl}/auth/login`);
      }
    }

    // Allow request to proceed as fallback
    return NextResponse.next();
  }
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|sitemap.xml|robots.txt).*)",
  ],
};
```

#### Step 5: Use Auth0 in components

```tsx
// pages/profile.tsx
import { getSession, withPageAuthRequired } from "@auth0/nextjs-auth0";
import { GetServerSideProps } from "next";

export default function ProfilePage({ user }) {
  return (
    <div>
      <h1>Profile</h1>
      <pre>{JSON.stringify(user, null, 2)}</pre>
    </div>
  );
}

export const getServerSideProps: GetServerSideProps = withPageAuthRequired();
```

## Next.js App Router Implementation

### App Router with Auth0 SDK 4.6.0

#### Step 1: Install dependencies

```bash
npm install @auth0/nextjs-auth0@4.6.0
```

#### Step 2: Create Auth0 client

Create `src/lib/auth0.ts` with the same content as in the Pages Router example.

#### Step 3: Set up Auth0 API routes

With App Router, you'll need to create a route handler:

Create `src/app/auth/[...auth0]/route.ts`:

```typescript
import { auth0 } from "@/lib/auth0";

// Handle all Auth0 routes
export const GET = auth0.handleAuth();
export const POST = auth0.handleAuth();
```

#### Step 4: Configure middleware

Create `middleware.ts` in your project root with the same content as in the Pages Router example.

#### Step 5: Use Auth0 in components

For server components:

```tsx
// app/profile/page.tsx
import { auth0 } from "@/lib/auth0";
import { redirect } from "next/navigation";

export default async function ProfilePage() {
  const { user } = await auth0.getSession();

  if (!user) {
    redirect("/auth/login");
  }

  return (
    <div>
      <h1>Profile</h1>
      <pre>{JSON.stringify(user, null, 2)}</pre>
    </div>
  );
}
```

For client components:

```tsx
// components/LoginButton.tsx
"use client";

export default function LoginButton() {
  return (
    <a href="/auth/login" className="login-button">
      Log In
    </a>
  );
}
```

## Managing Multiple Environments

### Environment Variable Strategy

#### Development Environment

Create `.env.development.local`:

```
AUTH0_SECRET=your-dev-secret
AUTH0_BASE_URL=http://localhost:3000
AUTH0_ISSUER_BASE_URL=https://your-dev-tenant.us.auth0.com
AUTH0_CLIENT_ID=your-dev-client-id
AUTH0_CLIENT_SECRET=your-dev-client-secret
AUTH0_DOMAIN=your-dev-tenant.us.auth0.com
APP_BASE_URL=http://localhost:3000
```

#### Staging Environment

In Vercel, add environment variables for staging:

```
AUTH0_SECRET=your-staging-secret
AUTH0_BASE_URL=https://staging.your-domain.com
AUTH0_ISSUER_BASE_URL=https://your-staging-tenant.us.auth0.com
AUTH0_CLIENT_ID=your-staging-client-id
AUTH0_CLIENT_SECRET=your-staging-client-secret
AUTH0_DOMAIN=your-staging-tenant.us.auth0.com
APP_BASE_URL=https://staging.your-domain.com
```

#### Production Environment

In Vercel, add environment variables for production:

```
AUTH0_SECRET=your-production-secret
AUTH0_BASE_URL=https://your-domain.com
AUTH0_ISSUER_BASE_URL=https://your-production-tenant.us.auth0.com
AUTH0_CLIENT_ID=your-production-client-id
AUTH0_CLIENT_SECRET=your-production-client-secret
AUTH0_DOMAIN=your-production-tenant.us.auth0.com
APP_BASE_URL=https://your-domain.com
```

### Tenant Strategy

**Recommended approach**: Use separate Auth0 tenants for each environment:

1. `your-app-dev.us.auth0.com` for development
2. `your-app-staging.us.auth0.com` for staging
3. `your-app.us.auth0.com` for production

This provides:

- Clear separation of user data
- Independent configuration for each environment
- Ability to test authentication changes safely

## Edge Runtime Considerations

### Edge Runtime Limitations

Auth0 SDK has specific considerations when running in Edge Runtime:

1. **URL Construction**: Edge Runtime is more strict with URL validation
2. **Memory Limitations**: Edge functions have memory constraints
3. **Compatibility**: Some Auth0 features may not work in Edge Runtime

### Recommended Configuration for Edge

If using Edge Runtime on Vercel:

1. Add robust error handling for URL construction
2. Use a custom error boundary component for authentication failures
3. Consider setting the config in middleware.ts to exclude authentication for static routes:

```typescript
export const config = {
  matcher: [
    "/((?!_next/static|_next/image|api/webhooks|favicon.ico|sitemap.xml|robots.txt).*)",
  ],
};
```

## Version Compatibility Matrix

| Auth0 SDK Version | Next.js Version | Router Type  | Known Issues                                      |
| ----------------- | --------------- | ------------ | ------------------------------------------------- |
| 4.6.0+            | 14.x+           | App Router   | Edge runtime URL validation errors                |
| 4.6.0+            | 14.x+           | Pages Router | Fully compatible                                  |
| 4.6.0+            | 13.x            | App Router   | Some middleware limitations                       |
| 4.6.0+            | 13.x            | Pages Router | Fully compatible                                  |
| 3.x               | 13.x and below  | Pages Router | Uses `/api/auth/` paths instead of `/auth/` paths |
| 3.x               | 14.x+           | Any          | Not recommended - use 4.x+ for Next.js 14         |
| 2.x and below     | Any             | Any          | Deprecated - migrate to newer versions            |

### Migration Notes

When upgrading:

1. Auth0 SDK 3.x → 4.x: Change route paths from `/api/auth/` to `/auth/`
2. Next.js Pages → App Router: Update API route implementation
3. Next.js 13.x → 14.x: Review middleware implementations for compatibility

## Next Steps

Now that you understand environment-specific implementations, refer to our other guides:

1. [Auth0 Setup Guide](./01-Auth0-Setup-Guide.md)
2. [Advanced Auth0 Integration](./03-Advanced-Auth0-Integration.md)
3. [Auth0 Testing Guide](./04-Auth0-Testing-Guide.md)
