# Auth0 v4.6.0+ Implementation Guide

This guide provides step-by-step instructions for implementing Auth0 v4.6.0+ authentication in a Next.js application using the Pages Router.

## Important: Auth0 Architecture Changes

> ⚠️ **CRITICAL**: Auth0 v4.0.0 completely changed its architecture from earlier versions!
>
> - **v3**: Used API routes at `/api/auth/[...auth0].ts`
> - **v4+**: Uses middleware to auto-mount routes at `/auth/*`
>
> **NEVER** mix these patterns - it will cause authentication failures.

## Table of Contents

1. [Installation](#1-installation)
2. [Environment Variables](#2-environment-variables)
3. [Auth0 Client Configuration](#3-auth0-client-configuration)
4. [Middleware Setup](#4-middleware-setup)
5. [Protected Pages](#5-protected-pages)
6. [Protected API Routes](#6-protected-api-routes)
7. [Troubleshooting](#7-troubleshooting)
8. [Migration from v3](#8-migration-from-v3)

## 1. Installation

Install the Auth0 Next.js SDK v4.6.0 or later:

```bash
npm install @auth0/nextjs-auth0@4.6.0
```

**Important**: Pin the version in your package.json to prevent accidental upgrades:

```json
"dependencies": {
  "@auth0/nextjs-auth0": "4.6.0",
  // Other dependencies...
}
```

## 2. Environment Variables

Create a `.env.local` file with the following variables:

```bash
# Required environment variables - exact names matter!
AUTH0_SECRET=your-32-byte-secret-here
AUTH0_ISSUER_BASE_URL=your-tenant.us.auth0.com  # No https:// prefix
AUTH0_BASE_URL=http://localhost:3000
AUTH0_CLIENT_ID=your-client-id
AUTH0_CLIENT_SECRET=your-client-secret

# Optional environment variables
AUTH0_AUDIENCE=https://api.example.com  # If using API authorization
AUTH0_SCOPE="openid profile email"  # Default scopes
```

For production, generate a strong secret:

```bash
openssl rand -hex 32
```

## 3. Auth0 Client Configuration

Create a minimal Auth0 client instance:

```typescript
// src/lib/auth0.ts
import { Auth0Client } from "@auth0/nextjs-auth0/server";

// Client configuration comes from environment variables
export const auth0 = new Auth0Client();
```

## 4. Middleware Setup

Create a middleware file in your project root:

```typescript
// middleware.ts (in project root, NOT in src/)
import type { NextRequest } from "next/server";
import { auth0 } from "./src/lib/auth0"; // Adjust path as needed

export async function middleware(request: NextRequest) {
  return await auth0.middleware(request);
}

export const config = {
  matcher: [
    /*
     * Match all request paths except for the ones starting with:
     * - _next/static (static files)
     * - _next/image (image optimization files)
     * - favicon.ico, sitemap.xml, robots.txt (metadata files)
     */
    "/((?!_next/static|_next/image|favicon.ico|sitemap.xml|robots.txt).*)",
  ],
};
```

## 5. Protected Pages

### Client-Side User Data

To access user data on the client side:

```typescript
// components/Profile.tsx
"use client";
import { useUser } from "@auth0/nextjs-auth0/client"; // Note /client suffix

export default function Profile() {
  const { user, error, isLoading } = useUser();

  if (isLoading) return <div>Loading...</div>;
  if (error) return <div>{error.message}</div>;
  if (!user) return <div>Not logged in</div>;

  return (
    <div>
      <h1>Profile</h1>
      <img src={user.picture} alt={user.name} />
      <p>Name: {user.name}</p>
      <p>Email: {user.email}</p>
    </div>
  );
}
```

### Server-Side Authentication Check

For server-rendered pages:

```typescript
// pages/dashboard.tsx
import { auth0 } from "../lib/auth0";
import { GetServerSideProps } from "next";

export default function Dashboard({ user }) {
  return (
    <div>
      <h1>Dashboard</h1>
      <pre>{JSON.stringify(user, null, 2)}</pre>
    </div>
  );
}

export const getServerSideProps: GetServerSideProps = async (context) => {
  const session = await auth0.getSession(context.req);

  if (!session) {
    return {
      redirect: {
        destination: "/auth/login",
        permanent: false,
      },
    };
  }

  return {
    props: {
      user: session.user,
    },
  };
};
```

### Login/Logout Buttons

```typescript
// components/AuthButtons.tsx
export function LoginButton() {
  return <a href="/auth/login">Log in</a>; // Note: /auth/, NOT /api/auth/
}

export function LogoutButton() {
  return <a href="/auth/logout">Log out</a>; // Note: /auth/, NOT /api/auth/
}
```

## 6. Protected API Routes

### Basic Authentication Check

```typescript
// pages/api/protected-data.ts
import { NextApiRequest, NextApiResponse } from "next";
import { auth0 } from "../../lib/auth0";

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const session = await auth0.getSession(req);

  if (!session) {
    return res.status(401).json({ error: "Unauthorized" });
  }

  // Handle authenticated request
  res.status(200).json({
    message: "This is protected data",
    user: session.user,
  });
}
```

### Utility for Protected Routes

Create a utility to protect API routes more cleanly:

```typescript
// src/lib/protectedRoute.ts
import { NextApiRequest, NextApiResponse, NextApiHandler } from "next";
import { auth0 } from "./auth0";

export function withAuth(handler: NextApiHandler) {
  return async (req: NextApiRequest, res: NextApiResponse) => {
    const session = await auth0.getSession(req);

    if (!session) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    // Add user to the request for easy access
    req.user = session.user;

    // Call the original handler
    return handler(req, res);
  };
}
```

Then use it in your API routes:

```typescript
// pages/api/user-data.ts
import { NextApiRequest, NextApiResponse } from "next";
import { withAuth } from "../../lib/protectedRoute";

async function handler(req: NextApiRequest, res: NextApiResponse) {
  // req.user is available from the withAuth wrapper
  res.status(200).json({ user: req.user });
}

export default withAuth(handler);
```

## 7. Troubleshooting

### Common Issues and Solutions

#### Authentication Not Working

**Issue**: Users can't log in or routes aren't protected.

**Solutions**:

- Ensure Auth0 SDK version is 4.6.0+
- Verify middleware.ts is in the correct location (project root)
- Check environment variables are correctly set
- Confirm Auth0 Dashboard application settings match your routes
- Verify correct import paths with proper suffixes (`/client`, `/server`)

#### "Cannot find Auth0 configuration" Error

**Issue**: Error message about missing Auth0 configuration.

**Solutions**:

- Double-check all required environment variables
- Ensure AUTH0_BASE_URL matches your actual application URL
- Restart your development server after changing environment variables

#### Incorrect Redirect After Login/Logout

**Issue**: Users redirected to wrong URL after authentication actions.

**Solutions**:

- Check AUTH0_BASE_URL is set correctly
- Configure returnTo parameters in login/logout URLs
- Update callback URLs in Auth0 Dashboard application settings

#### "Error: The middleware can't be compiled"

**Issue**: Middleware compilation error.

**Solutions**:

- Move middleware.ts to project root (not in src/ or pages/)
- Fix any TypeScript errors in the middleware
- Ensure imports in middleware.ts use relative paths from root

#### Session Not Persisting

**Issue**: Users have to log in again frequently.

**Solutions**:

- Check AUTH0_SECRET is properly set (and is 32+ bytes)
- Verify session cookie settings in Auth0 configuration
- Ensure your application isn't clearing cookies

## 8. Migration from v3

If you're migrating from Auth0 v3, follow these steps:

1. **Update Dependencies**:

   ```bash
   npm install @auth0/nextjs-auth0@4.6.0
   ```

2. **Remove v3 Files**:

   ```bash
   rm pages/api/auth/[...auth0].ts
   ```

3. **Create Auth0 Client**:

   ```typescript
   // src/lib/auth0.ts
   import { Auth0Client } from "@auth0/nextjs-auth0/server";
   export const auth0 = new Auth0Client();
   ```

4. **Add Middleware**:

   ```typescript
   // middleware.ts
   import { auth0 } from "./src/lib/auth0";
   export async function middleware(request) {
     return await auth0.middleware(request);
   }
   export const config = {
     /* ... */
   };
   ```

5. **Update Route References**:

   - Change all `/api/auth/login` to `/auth/login`
   - Change all `/api/auth/logout` to `/auth/logout`
   - Change all `/api/auth/callback` to `/auth/callback`

6. **Update Session Access**:

   - Replace `getSession(req, res)` with `auth0.getSession(req)`
   - Replace `withApiAuthRequired` with custom authentication middleware

7. **Update Dashboard Settings**:

   - Update callback URLs in Auth0 Dashboard
   - Update allowed logout URLs in Auth0 Dashboard

8. **Test Thoroughly**:
   - Test login flow
   - Test logout flow
   - Test protected routes
   - Test session persistence

## Conclusion

Auth0 v4.6.0+ uses a completely different architecture than earlier versions, relying on middleware instead of API routes. This allows for a cleaner implementation but requires careful attention to the correct patterns.

Always document your Auth0 version and implementation details in your project, and never mix patterns from different versions.

## Documentation Links

- [Auth0 Next.js SDK v4.6.0 Docs](https://auth0.github.io/nextjs-auth0/v4.6.0/)
- [Auth0 v3 to v4 Migration Guide](https://auth0.github.io/nextjs-auth0/v4.6.0/changes)
- [Auth0 Dashboard](https://manage.auth0.com/)
- [Next.js Middleware Documentation](https://nextjs.org/docs/app/building-your-application/routing/middleware)
- [Auth0 Quick Reference Card](AUTH0_QUICK_REFERENCE.md)
