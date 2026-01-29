# Auth0 SDK Version Compatibility Guide

> This guide provides detailed information about Auth0 SDK versions, their compatibility with different Next.js versions, and migration paths between versions.

## Table of Contents

1. [Version Comparison](#version-comparison)
2. [Breaking Changes](#breaking-changes)
3. [Migration Paths](#migration-paths)
4. [Next.js Compatibility](#nextjs-compatibility)
5. [Troubleshooting Version-Specific Issues](#troubleshooting-version-specific-issues)

## Version Comparison

### Major Auth0 SDK Versions

| Auth0 SDK Version | Release Date | Key Features                                        | Known Issues                          | Recommended For                    |
| ----------------- | ------------ | --------------------------------------------------- | ------------------------------------- | ---------------------------------- |
| 4.x (Current)     | 2024         | App Router support, Edge Runtime, improved security | URL validation errors in Edge Runtime | New projects, Next.js 13+          |
| 3.x               | 2023         | Pages Router support, modern security features      | Limited App Router support            | Existing projects on Next.js 12/13 |
| 2.x               | 2022         | Basic Next.js integration                           | Limited modern features               | Legacy projects only               |
| 1.x               | 2021         | Initial release                                     | Multiple security limitations         | Not recommended (deprecated)       |

### Feature Comparison

| Feature               | 4.x              | 3.x             | 2.x              |
| --------------------- | ---------------- | --------------- | ---------------- |
| Route Paths           | `/auth/...`      | `/api/auth/...` | `/api/auth/...`  |
| App Router Support    | ✅ Full          | ⚠️ Limited      | ❌ None          |
| Edge Runtime Support  | ✅ Yes           | ❌ No           | ❌ No            |
| Refresh Token Support | ✅ Built-in      | ✅ Built-in     | ⚠️ Limited       |
| Token Validation      | ✅ Enhanced      | ✅ Standard     | ⚠️ Basic         |
| Middleware            | ✅ Built-in      | ✅ Custom       | ❌ Not available |
| Error Handling        | ✅ Comprehensive | ⚠️ Basic        | ❌ Minimal       |
| TypeScript Support    | ✅ Full          | ✅ Full         | ⚠️ Limited       |

## Breaking Changes

### From v3.x to v4.x

#### 1. Route Path Changes

The most significant breaking change in v4.x is the change in route paths:

```
# v3.x route path
/api/auth/login
/api/auth/callback
/api/auth/logout

# v4.x route path
/auth/login
/auth/callback
/auth/logout
```

**Migration Action**: Update all Auth0 route references in your code and Auth0 Dashboard settings.

#### 2. API Changes

```typescript
// v3.x
import { handleAuth } from "@auth0/nextjs-auth0";
export default handleAuth();

// v4.x
import { auth0 } from "../../lib/auth0";
export default auth0.handleAuth();
```

**Migration Action**: Create an Auth0 client instance and use it for all Auth0 operations.

#### 3. Environment Variable Changes

v4.x requires additional environment variables:

```
# New in v4.x
AUTH0_DOMAIN=your-tenant.us.auth0.com
APP_BASE_URL=https://your-domain.com
```

**Migration Action**: Add these new environment variables to all environments.

### From v2.x to v3.x

#### 1. Configuration Structure

```typescript
// v2.x
import { initAuth0 } from "@auth0/nextjs-auth0";
export default initAuth0({
  domain: process.env.AUTH0_DOMAIN,
  clientId: process.env.AUTH0_CLIENT_ID,
  clientSecret: process.env.AUTH0_CLIENT_SECRET,
  scope: "openid profile",
  redirectUri: process.env.REDIRECT_URI,
  postLogoutRedirectUri: process.env.POST_LOGOUT_REDIRECT_URI,
  session: {
    cookieSecret: process.env.SESSION_COOKIE_SECRET,
    cookieLifetime: 60 * 60 * 8,
  },
});

// v3.x
import { handleAuth } from "@auth0/nextjs-auth0";
export default handleAuth();
```

**Migration Action**: Refactor to use the new configuration structure and environment variables.

## Migration Paths

### Migrating from v3.x to v4.x

#### Step 1: Update dependencies

```bash
npm uninstall @auth0/nextjs-auth0
npm install @auth0/nextjs-auth0@4.6.0
```

#### Step 2: Create Auth0 client

Create `src/lib/auth0.ts`:

```typescript
import { Auth0Client } from "@auth0/nextjs-auth0/server";

export const auth0 = new Auth0Client({
  domain: process.env.AUTH0_DOMAIN,
  clientId: process.env.AUTH0_CLIENT_ID,
  clientSecret: process.env.AUTH0_CLIENT_SECRET,
  appBaseUrl: process.env.AUTH0_BASE_URL,
  secret: process.env.AUTH0_SECRET,
});

export default auth0;
```

#### Step 3: Update route handlers

Change from `pages/api/auth/[...auth0].ts` to `pages/auth/[...auth0].ts`:

```typescript
import { auth0 } from "../../lib/auth0";
export default auth0.handleAuth();
```

#### Step 4: Update Auth0 Dashboard settings

Update all callback URLs in Auth0 Dashboard to use the new `/auth/` paths.

#### Step 5: Update environment variables

Add the new required environment variables.

### Migrating from v2.x to v3.x

#### Step 1: Update dependencies

```bash
npm uninstall @auth0/nextjs-auth0
npm install @auth0/nextjs-auth0@3.x
```

#### Step 2: Update API routes

Create `pages/api/auth/[...auth0].ts`:

```typescript
import { handleAuth } from "@auth0/nextjs-auth0";
export default handleAuth();
```

#### Step 3: Update environment variables

Configure the required environment variables for v3.x.

## Next.js Compatibility

### Auth0 SDK with Different Next.js Versions

| Auth0 SDK Version | Next.js 14+ (App Router) | Next.js 14+ (Pages Router) | Next.js 13 (App Router) | Next.js 13 (Pages Router) | Next.js 12 and below |
| ----------------- | ------------------------ | -------------------------- | ----------------------- | ------------------------- | -------------------- |
| 4.6.0+            | ✅ Fully Compatible      | ✅ Fully Compatible        | ⚠️ Some limitations     | ✅ Fully Compatible       | ❌ Not recommended   |
| 3.x               | ⚠️ Limited support       | ✅ Compatible              | ⚠️ Limited support      | ✅ Compatible             | ✅ Compatible        |
| 2.x               | ❌ Not compatible        | ⚠️ Limited support         | ❌ Not compatible       | ⚠️ Limited support        | ✅ Compatible        |
| 1.x               | ❌ Not compatible        | ❌ Not compatible          | ❌ Not compatible       | ❌ Not compatible         | ⚠️ Limited support   |

### Router-Specific Implementation Details

#### App Router (Next.js 13+)

For Auth0 SDK 4.6.0+ with App Router:

```typescript
// app/auth/[...auth0]/route.ts
import { auth0 } from "@/lib/auth0";

export const GET = auth0.handleAuth();
export const POST = auth0.handleAuth();
```

```typescript
// app/profile/page.tsx
import { auth0 } from "@/lib/auth0";
import { redirect } from "next/navigation";

export default async function ProfilePage() {
  const session = await auth0.getSession();

  if (!session?.user) {
    redirect("/auth/login");
  }

  return (
    <div>
      <h1>Profile</h1>
      <pre>{JSON.stringify(session.user, null, 2)}</pre>
    </div>
  );
}
```

#### Pages Router (Next.js 12+)

For Auth0 SDK 4.6.0+ with Pages Router:

```typescript
// pages/auth/[...auth0].ts
import { auth0 } from "@/lib/auth0";

export default auth0.handleAuth();
```

```typescript
// pages/profile.tsx
import { withPageAuthRequired } from "@auth0/nextjs-auth0";

export default function ProfilePage({ user }) {
  return (
    <div>
      <h1>Profile</h1>
      <pre>{JSON.stringify(user, null, 2)}</pre>
    </div>
  );
}

export const getServerSideProps = withPageAuthRequired();
```

## Troubleshooting Version-Specific Issues

### Common Issues in v4.6.0+

#### Issue: MIDDLEWARE_INVOCATION_FAILED

**Cause**: URL construction errors due to Edge Runtime's stricter validation.

**Solution**:

1. Ensure all URLs have the correct protocol (`https://`)
2. Use the robust Auth0 client from our diagnostic tools
3. Add error handling to middleware

```typescript
// Robust error handling in middleware
try {
  return await auth0.middleware(request);
} catch (error) {
  console.error("Auth0 middleware error:", error);
  return NextResponse.next();
}
```

#### Issue: Route Not Found (/api/auth/...)

**Cause**: Using old route paths with SDK 4.6.0+.

**Solution**: Update all routes to use `/auth/` instead of `/api/auth/`.

### Common Issues in v3.x

#### Issue: No session data in App Router

**Cause**: v3.x has limited App Router support.

**Solution**: Upgrade to v4.x or use the Pages Router for authentication.

#### Issue: TypeScript errors with getSession

**Cause**: Type definitions changed between versions.

**Solution**: Update type imports to match the version:

```typescript
// v3.x
import { UserProfile, getSession } from "@auth0/nextjs-auth0";

// v4.x
import { auth0 } from "@/lib/auth0";
const { user } = await auth0.getSession();
```

## Recommendation Matrix

Use this matrix to determine which Auth0 SDK version to use based on your project:

| Project Type                           | Recommended Auth0 SDK Version    |
| -------------------------------------- | -------------------------------- |
| New Next.js 14+ project (App Router)   | 4.6.0+                           |
| New Next.js 14+ project (Pages Router) | 4.6.0+                           |
| Existing Next.js 13 project            | 4.6.0+ (with caution)            |
| Legacy Next.js 12 project              | 3.x (if not upgrading Next.js)   |
| Migration from v3.x                    | Follow migration guide to 4.6.0+ |

## Next Steps

Now that you understand Auth0 SDK version compatibility, refer to our other guides:

1. [Auth0 Setup Guide](./01-Auth0-Setup-Guide.md)
2. [Environment-Specific Configuration](./02-Environment-Specific-Guides.md)
3. [Advanced Auth0 Integration](./03-Advanced-Auth0-Integration.md)
4. [Auth0 Testing Guide](./04-Auth0-Testing-Guide.md)
