# Auth0 Implementation Do's and Don'ts

This guide provides clear guidelines to prevent common Auth0 implementation mistakes, especially around version-specific patterns.

## Version Selection

### ✅ DO:

- **Pin your Auth0 SDK version** in package.json to prevent accidental upgrades
- **Document which Auth0 version** you're using in your project README
- **Follow version-specific patterns** consistently throughout your codebase
- **Refer to official Auth0 documentation** for your specific version

### ❌ DON'T:

- **Don't mix Auth0 SDK versions** in the same project
- **Don't upgrade Auth0 SDK** without a complete migration plan
- **Don't copy code examples** without checking which Auth0 version they use

## Auth0 v4+ (Latest) Implementation

### ✅ DO:

- **Use middleware-based authentication** with middleware.ts in the root directory
- **Create an Auth0Client** from "@auth0/nextjs-auth0/server"
- **Use `/auth/*` routes** for login, logout, and callback
- **Use auth0.getSession(req)** to validate sessions in API routes
- **Import from "/client" suffix** for client components: `@auth0/nextjs-auth0/client`

### ❌ DON'T:

- **Don't create `/api/auth/[...auth0].ts`** files (this is v3 pattern)
- **Don't use getSession(req, res)** (this is v3 pattern)
- **Don't link to `/api/auth/login`** in your UI (use `/auth/login` instead)
- **Don't place middleware.ts** in src/ or pages/ directories (must be in root)

## Auth0 v3 Implementation (Legacy)

### ✅ DO:

- **Use API routes pattern** with pages/api/auth/[...auth0].ts
- **Call handleAuth()** to setup route handlers
- **Use `/api/auth/*` paths** for login, logout, and callback
- **Import from root package**: `@auth0/nextjs-auth0`
- **Use withApiAuthRequired** for protected API routes

### ❌ DON'T:

- **Don't create middleware.ts** for Auth0 (this is v4+ pattern)
- **Don't link to `/auth/login`** in your UI (use `/api/auth/login` for v3)
- **Don't try to customize Auth0 v3 routes** with middleware

## Migration Between Versions

### ✅ DO:

- **Read the official migration guide** thoroughly
- **Complete the migration in one go**
- **Test thoroughly** after migration
- **Update all authentication-related code**
- **Update Auth0 Dashboard configuration** to match your new routes

### ❌ DON'T:

- **Don't attempt partial migrations** between major versions
- **Don't keep old authentication code** around "just in case"

## Environment Variables

### ✅ DO:

- **Set all required Auth0 environment variables**
- **Generate a secure AUTH0_SECRET** for production
- **Keep environment variables in .env.local** (don't commit to version control)
- **Validate environment variables** at startup

### ❌ DON'T:

- **Don't expose Auth0 client secrets** in client-side code
- **Don't use the same AUTH0_SECRET** in development and production
- **Don't forget to update environment variables** when deploying

## Auth0 Dashboard Configuration

### ✅ DO:

- **Configure correct callback URLs** in Auth0 Dashboard
- **Set allowed logout URLs** in Auth0 Dashboard
- **Use different Auth0 applications** for development and production
- **Regularly review security settings** in Auth0 Dashboard

### ❌ DON'T:

- **Don't use production Auth0 application** for development
- **Don't use insecure settings** in production

## Common Mistakes to Avoid

### Mistake 1: Mixed Authentication Patterns

```typescript
// ❌ BAD: Mixing v3 and v4 patterns
// pages/api/auth/[...auth0].ts (v3 pattern)
import { handleAuth } from "@auth0/nextjs-auth0";
export default handleAuth();

// middleware.ts (v4 pattern)
import { auth0 } from "./lib/auth0";
export async function middleware(request) {
  return await auth0.middleware(request);
}
// This mixed approach will break authentication!
```

### Mistake 2: Wrong Route References

```jsx
// ❌ BAD: Using v3 route with v4 implementation
// When using Auth0 v4+
<a href="/api/auth/login">Login</a> // Wrong!

// ✅ GOOD: Correct route for v4+
<a href="/auth/login">Login</a>
```

### Mistake 3: Incorrect Session Access

```typescript
// ❌ BAD: Using v3 pattern with v4 implementation
// When using Auth0 v4+
import { getSession } from "@auth0/nextjs-auth0";

export default async function handler(req, res) {
  // Wrong approach for v4+
  const session = await getSession(req, res);
}

// ✅ GOOD: Correct session access for v4+
import { auth0 } from "../../lib/auth0";

export default async function handler(req, res) {
  // Correct approach for v4+
  const session = await auth0.getSession(req);
}
```

### Mistake 4: Middleware in Wrong Location

```typescript
// ❌ BAD: Middleware in wrong location
// src/middleware.ts or pages/middleware.ts

// ✅ GOOD: Middleware in correct location
// middleware.ts (in project root)
```

## Troubleshooting Indicators

If you see these errors, you might be mixing Auth0 versions:

1. **"Cannot find Auth0 configuration"** - Check environment variables match your version
2. **"handleAuth is not a function"** - You might be using v3 imports with v4
3. **"auth0.middleware is not a function"** - You might be using v4 imports with v3
4. **Authentication redirects in loops** - Check for route path conflicts
5. **Login works but protected pages don't** - Check session validation methods

## Conclusion

Following these do's and don'ts will help you avoid the most common Auth0 implementation issues. Remember that Auth0 v3 and v4+ use fundamentally different approaches, and mixing them will inevitably cause authentication problems.

When in doubt, refer to the official Auth0 documentation for your specific version:

- [Auth0 Next.js SDK v4.6.0 Docs](https://auth0.github.io/nextjs-auth0/v4.6.0/)
- [Auth0 Next.js SDK v3 Docs](https://auth0.github.io/nextjs-auth0/v3/)
