# Auth0 v4.6.0 Quick Reference Card

This is a concise reference for Auth0 v4.6.0 implementation in Next.js with Pages Router.

## Version Lock

```json
// package.json
"dependencies": {
  "@auth0/nextjs-auth0": "4.6.0"  // Exactly this version
}
```

## Core Patterns

- **Routes:** `/auth/*` (NOT `/api/auth/*`)
- **Session Access:** `auth0.getSession(req)` (NOT `getSession(req, res)`)
- **Middleware File:** `middleware.ts` (in root directory, NOT in src/ or pages/)
- **No API Routes:** Do NOT create `pages/api/auth/[...auth0].ts`

## Correct Imports

```typescript
// Server-side (for middleware, API routes, getServerSideProps)
import { Auth0Client } from "@auth0/nextjs-auth0/server";

// Client-side (for React components)
import { useUser } from "@auth0/nextjs-auth0/client";
```

## Environment Variables

```bash
# Required variables - exact names matter!
AUTH0_SECRET=your-32-byte-secret-here
AUTH0_ISSUER_BASE_URL=your-tenant.us.auth0.com  # No https://
AUTH0_BASE_URL=http://localhost:3000
AUTH0_CLIENT_ID=your-client-id
AUTH0_CLIENT_SECRET=your-client-secret
```

## Key Files

1. **Auth0 Client:**

```typescript
// src/lib/auth0.ts
import { Auth0Client } from "@auth0/nextjs-auth0/server";
export const auth0 = new Auth0Client();
```

2. **Middleware:**

```typescript
// middleware.ts (root directory)
import { NextRequest } from "next/server";
import { auth0 } from "./src/lib/auth0";

export async function middleware(request: NextRequest) {
  return await auth0.middleware(request);
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"],
};
```

3. **Protected API Route:**

```typescript
// pages/api/protected.ts
import { NextApiRequest, NextApiResponse } from "next";
import { auth0 } from "../../lib/auth0";

export default async function handler(req, res) {
  const session = await auth0.getSession(req);
  if (!session) return res.status(401).json({ error: "Unauthorized" });

  // Your protected logic here
}
```

4. **Auth Buttons:**

```tsx
// components/AuthButtons.tsx
export function LoginButton() {
  return <a href="/auth/login">Log in</a>; // Note: /auth/ NOT /api/auth/
}

export function LogoutButton() {
  return <a href="/auth/logout">Log out</a>; // Note: /auth/ NOT /api/auth/
}
```

## Common Errors

| Error                                 | Likely Cause                  | Solution                         |
| ------------------------------------- | ----------------------------- | -------------------------------- |
| "Cannot find Auth0 configuration"     | Missing environment variables | Check all required env vars      |
| Auth loop or redirect issues          | Wrong route paths             | Use `/auth/*` not `/api/auth/*`  |
| "auth0.middleware is not a function"  | Import from wrong module      | Use `@auth0/nextjs-auth0/server` |
| "req.user is undefined"               | Wrong session access          | Use `auth0.getSession(req)`      |
| Login works but protected routes fail | Mixed v3/v4 patterns          | Follow v4 patterns consistently  |

## Dashboard Configuration

In your Auth0 Dashboard, set:

- **Allowed Callback URLs:** `http://localhost:3000/auth/callback`
- **Allowed Logout URLs:** `http://localhost:3000`
- **Allowed Web Origins:** `http://localhost:3000`

## Documentation Links

- [Full Auth0 Implementation Guide](AUTH0_V4_IMPLEMENTATION_GUIDE.md)
- [Auth0 Do's and Don'ts](AUTH0_DOS_AND_DONTS.md)
- [Current Implementation Details](AUTH0_CURRENT_IMPLEMENTATION.md)
- [Manual Testing Procedure](../README-Auth0-Manual-Testing.md)
