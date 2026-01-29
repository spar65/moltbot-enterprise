# Auth0 Implementation Version Documentation

> **IMPORTANT**: This document should be created in your project to clearly document the Auth0 implementation details.
> Copy this template and fill in the details for your project.

## Auth0 SDK Version

**Current Version:** [Enter Auth0 SDK version, e.g., 4.6.0]

**Implementation Pattern:** [Middleware-based (v4+) OR API Routes-based (v3)]

**Last Updated:** [Date of last Auth0 implementation update]

## Implementation Details

### Key Files

- **Auth0 Client:** [Path to Auth0 client file, e.g., src/lib/auth0.ts]
- **Middleware:** [Path to middleware file, if using v4+]
- **API Routes:** [List any Auth0-specific API routes]
- **Protected Page Examples:** [List example protected pages]
- **Protected API Examples:** [List example protected API endpoints]

### Authentication Routes

- **Login:** [/auth/login (v4+) or /api/auth/login (v3)]
- **Logout:** [/auth/logout (v4+) or /api/auth/logout (v3)]
- **Callback:** [/auth/callback (v4+) or /api/auth/callback (v3)]

### Session Validation Method

```typescript
// How session validation is performed in this project
// Example for v4+:
const session = await auth0.getSession(req);

// Example for v3:
const session = await getSession(req, res);
```

## Auth0 Dashboard Configuration

### Application Settings

- **Application Type:** [Regular Web Application]
- **Allowed Callback URLs:** [List configured callback URLs]
- **Allowed Logout URLs:** [List configured logout URLs]
- **Allowed Web Origins:** [List configured web origins]

### JWT Configuration

- **JWT Signing Algorithm:** [e.g., RS256]
- **JWKS URI:** [If applicable]
- **Audience:** [If applicable]

## Environment Variables

```
# Required environment variables (DO NOT INCLUDE ACTUAL VALUES HERE)
AUTH0_SECRET=***************
AUTH0_BASE_URL=***************
AUTH0_ISSUER_BASE_URL=***************
AUTH0_CLIENT_ID=***************
AUTH0_CLIENT_SECRET=***************

# Optional environment variables
AUTH0_AUDIENCE=***************
AUTH0_SCOPE=***************
```

## Important Notes

- [Add any important notes about the implementation]
- [Document any customizations or non-standard configurations]
- [Note any known issues or limitations]

## Don'ts

- DO NOT downgrade the Auth0 SDK version without a complete migration plan
- DO NOT mix v3 and v4+ implementation patterns
- DO NOT create API routes at `/api/auth/[...auth0].ts` when using v4+
- DO NOT create middleware when using v3

## Migration History

| Date   | Previous Version | New Version   | Changes Made                   | Developer |
| ------ | ---------------- | ------------- | ------------------------------ | --------- |
| [Date] | [e.g., 3.x.x]    | [e.g., 4.6.0] | [Brief description of changes] | [Name]    |

## Reference Documentation

- [Auth0 Next.js SDK Documentation](https://auth0.github.io/nextjs-auth0)
- [Auth0 Dashboard](https://manage.auth0.com/)
- [Internal Auth0 Implementation Guide](./guides/AUTH0_V4_IMPLEMENTATION_GUIDE.md)
- [Auth0 Do's and Don'ts](./guides/AUTH0_DOS_AND_DONTS.md)
