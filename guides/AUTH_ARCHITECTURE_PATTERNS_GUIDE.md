# Authentication Architecture Patterns Guide

## Introduction

This guide provides practical implementation strategies for authentication architecture in modern web applications, focusing on choosing between server-side and client-side authentication approaches. It complements the `120-auth-architecture-patterns.mdc` rule with concrete examples and implementation patterns.

## Authentication Approaches

### Server-Side Authentication

**Characteristics:**

- Authentication happens on the server before rendering pages
- Session data typically stored in secure HTTP-only cookies
- Pages rendered with knowledge of user's authentication state

**Best for:**

- SEO-critical applications
- High-security requirements
- Server-rendered applications

**Implementation:**

```typescript
// Get user on server
async function getServerUser(req, res) {
  const session = await getSession(req, res);
  return session?.user || null;
}

// Protect page with auth
export const getServerSideProps = withPageAuth(async ({ req, res }) => {
  const data = await fetchData(req);
  return { props: { data } };
});
```

### Client-Side Authentication

**Characteristics:**

- Authentication happens in browser after page load
- Tokens managed by JavaScript
- State maintained in memory or secure cookies

**Best for:**

- Single-page applications (SPAs)
- Client-heavy applications
- Smooth UI transitions

**Implementation:**

```typescript
function useAuth() {
  const [user, setUser] = useState(null);

  useEffect(() => {
    // Fetch user from auth API
    fetch("/api/auth/me")
      .then((res) => res.json())
      .then((user) => setUser(user));
  }, []);

  return { user, isAuthenticated: !!user };
}
```

### Hybrid Authentication

**Characteristics:**

- Initial auth state from server
- Client-side auth for subsequent actions
- Combines benefits of both approaches

**Best for:**

- Next.js applications
- Applications needing both SEO and SPA experience
- Complex authentication requirements

**Implementation:**

```typescript
// Server-side auth that passes user to client
export const getServerSideProps = async ({ req, res }) => {
  const user = await getServerUser(req, res);
  if (!user) {
    return { redirect: { destination: "/login" } };
  }
  return { props: { user } };
};

// Client component using server-provided user
function Dashboard({ user }) {
  // Use user data directly, no additional fetching needed
  return <h1>Welcome, {user.name}</h1>;
}
```

## Comprehensive Hybrid Authentication Implementation

Here's a more detailed implementation of the hybrid approach:

```typescript
// src/lib/auth/hybrid.ts
import { GetServerSideProps, GetServerSidePropsContext } from "next";
import { getServerUser } from "./server";
import { createContext, useContext, useState } from "react";
import { User } from "./types";

// Create auth context
interface AuthContextType {
  user: User | null;
  isAuthenticated: boolean;
  hasPermission: (permission: string) => boolean;
  refreshUser: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

// Server-side auth wrapper
export function withHybridAuth<P extends { user: User }>(
  getServerSidePropsFunc?: (
    context: GetServerSidePropsContext,
    user: User
  ) => Promise<{ props: Omit<P, "user"> }>
): GetServerSideProps<P> {
  return async (context) => {
    const { req, res } = context;

    // Get user on server
    const user = await getServerUser(req, res);

    // Redirect to login if not authenticated
    if (!user) {
      return {
        redirect: {
          destination: `/login?returnTo=${encodeURIComponent(
            context.resolvedUrl
          )}`,
          permanent: false,
        },
      };
    }

    // Get additional props if provided
    let additionalProps = {};
    if (getServerSidePropsFunc) {
      additionalProps = (await getServerSidePropsFunc(context, user)).props;
    }

    // Return all props including user
    return {
      props: {
        ...additionalProps,
        user,
      } as P,
    };
  };
}

// Client-side auth provider that uses server-provided user
export function AuthProvider({
  children,
  initialUser,
}: {
  children: React.ReactNode;
  initialUser: User | null;
}) {
  const [user, setUser] = useState<User | null>(initialUser);

  // Refresh user data from API
  const refreshUser = async () => {
    try {
      const res = await fetch("/api/auth/me");
      if (res.ok) {
        const updatedUser = await res.json();
        setUser(updatedUser);
      }
    } catch (error) {
      console.error("Failed to refresh user:", error);
    }
  };

  // Check if user has permission
  const hasPermission = (permission: string) => {
    if (!user || !user.permissions) return false;
    return user.permissions.includes(permission);
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        isAuthenticated: !!user,
        hasPermission,
        refreshUser,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

// Hook to use auth context
export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
}

// Example usage in _app.tsx
function MyApp({ Component, pageProps }) {
  return (
    <AuthProvider initialUser={pageProps.user}>
      <Component {...pageProps} />
    </AuthProvider>
  );
}
```

## Role-Based Access Control (RBAC)

Implementing role-based access control is crucial for managing permissions:

```typescript
// src/lib/auth/rbac.ts
import { User } from "./types";

// Define roles and their hierarchy
export const ROLES = {
  GUEST: "guest",
  USER: "user",
  EDITOR: "editor",
  ADMIN: "admin",
};

// Role hierarchy (higher roles inherit permissions from lower roles)
export const ROLE_HIERARCHY = [
  ROLES.GUEST,
  ROLES.USER,
  ROLES.EDITOR,
  ROLES.ADMIN,
];

// Permissions by role
export const ROLE_PERMISSIONS: Record<string, string[]> = {
  [ROLES.GUEST]: ["read:public"],
  [ROLES.USER]: ["read:own", "write:own"],
  [ROLES.EDITOR]: ["read:any", "write:any", "publish:any"],
  [ROLES.ADMIN]: ["manage:users", "manage:content", "manage:settings"],
};

// Check if user has permission
export function hasPermission(user: User | null, permission: string): boolean {
  if (!user || !user.roles || user.roles.length === 0) {
    return false;
  }

  // Check if any of the user's roles has the required permission
  return user.roles.some((role) => {
    // Get role's position in hierarchy
    const roleIndex = ROLE_HIERARCHY.indexOf(role);
    if (roleIndex === -1) return false;

    // Check current role and all higher roles
    for (let i = 0; i <= roleIndex; i++) {
      const currentRole = ROLE_HIERARCHY[i];
      if (ROLE_PERMISSIONS[currentRole]?.includes(permission)) {
        return true;
      }
    }

    return false;
  });
}

// React component for permission-based rendering
export function PermissionGate({
  permission,
  user,
  fallback = null,
  children,
}: {
  permission: string;
  user: User | null;
  fallback?: React.ReactNode;
  children: React.ReactNode;
}) {
  if (!hasPermission(user, permission)) {
    return <>{fallback}</>;
  }

  return <>{children}</>;
}

// HOC for protecting components with permissions
export function withPermission(
  Component: React.ComponentType<any>,
  permission: string,
  FallbackComponent: React.ComponentType = () => null
) {
  return function ProtectedComponent(props: any) {
    const { user } = useAuth();

    if (!hasPermission(user, permission)) {
      return <FallbackComponent {...props} />;
    }

    return <Component {...props} />;
  };
}
```

## Token Handling Best Practices

### ❌ Never store tokens in localStorage/sessionStorage

- Vulnerable to XSS attacks
- Accessible to any JavaScript

### ✅ Use HTTP-only cookies

- Not accessible to JavaScript
- Can be secured with flags:
  ```
  Set-Cookie: token=value; HttpOnly; Secure; SameSite=Lax
  ```

### ✅ Use short-lived access tokens

- Limit damage if compromised
- Use refresh tokens for persistence

## Token Refresh Implementation

Here's how to implement secure token refresh:

```typescript
// src/lib/auth/token-refresh.ts

// Token refresh mechanism
export async function refreshAccessToken(refreshToken: string) {
  try {
    const response = await fetch("/api/auth/refresh", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ refreshToken }),
    });

    if (!response.ok) {
      throw new Error("Failed to refresh token");
    }

    const data = await response.json();

    return {
      accessToken: data.accessToken,
      refreshToken: data.refreshToken || refreshToken, // Some implementations rotate refresh tokens
      expiresAt: Date.now() + data.expiresIn * 1000,
    };
  } catch (error) {
    console.error("Token refresh failed:", error);
    // Force re-login
    window.location.href = `/login?error=session_expired&returnTo=${encodeURIComponent(
      window.location.pathname
    )}`;
    throw error;
  }
}

// Auto-refresh implementation
export function setupTokenRefresh(expiresAt: number, refreshToken: string) {
  // Calculate time until expiry (with 5-minute buffer)
  const timeUntilExpiry = expiresAt - Date.now() - 5 * 60 * 1000;

  if (timeUntilExpiry <= 0) {
    // Token already expired or about to expire
    return refreshAccessToken(refreshToken);
  }

  // Set up refresh before expiration
  const refreshTimeout = setTimeout(async () => {
    try {
      const tokenData = await refreshAccessToken(refreshToken);
      // Set up the next refresh
      setupTokenRefresh(tokenData.expiresAt, tokenData.refreshToken);
    } catch (error) {
      console.error("Failed to refresh token:", error);
    }
  }, timeUntilExpiry);

  // Return cleanup function
  return () => clearTimeout(refreshTimeout);
}
```

## Provider-Specific Configuration

Each authentication provider requires specific configuration:

### Auth0 Configuration

```typescript
// src/lib/auth/providers/auth0-config.ts
export const auth0Config = {
  clientId: process.env.AUTH0_CLIENT_ID || "",
  clientSecret: process.env.AUTH0_CLIENT_SECRET || "",
  domain: process.env.AUTH0_DOMAIN || "",
  audience: process.env.AUTH0_AUDIENCE || "",
  scope: "openid profile email",
  redirectUri: process.env.AUTH0_REDIRECT_URI || "",
  logoutUrl: process.env.AUTH0_LOGOUT_URL || "",
  // Auth0-specific options
  organization: process.env.AUTH0_ORGANIZATION || "",
  connection: process.env.AUTH0_CONNECTION || "",
};

// Auth0 implementation
export function setupAuth0() {
  return {
    loginUrl:
      `https://${auth0Config.domain}/authorize?` +
      `client_id=${auth0Config.clientId}` +
      `&redirect_uri=${encodeURIComponent(auth0Config.redirectUri)}` +
      `&response_type=code` +
      `&scope=${encodeURIComponent(auth0Config.scope)}`,

    logoutUrl:
      `https://${auth0Config.domain}/v2/logout?` +
      `client_id=${auth0Config.clientId}` +
      `&returnTo=${encodeURIComponent(auth0Config.logoutUrl)}`,
  };
}
```

### Firebase Configuration

```typescript
// src/lib/auth/providers/firebase-config.ts
export const firebaseConfig = {
  apiKey: process.env.FIREBASE_API_KEY || "",
  authDomain: process.env.FIREBASE_AUTH_DOMAIN || "",
  projectId: process.env.FIREBASE_PROJECT_ID || "",
  storageBucket: process.env.FIREBASE_STORAGE_BUCKET || "",
  messagingSenderId: process.env.FIREBASE_MESSAGING_SENDER_ID || "",
  appId: process.env.FIREBASE_APP_ID || "",
};

// Firebase initialization
export function initializeFirebase() {
  if (typeof window !== "undefined" && !getApps().length) {
    return initializeApp(firebaseConfig);
  }
  return getApp();
}
```

## Multi-Provider Strategy

To support multiple authentication providers or enable migration between them:

```typescript
// src/lib/auth/multi-provider.ts
import { auth0Config, setupAuth0 } from "./providers/auth0-config";
import {
  firebaseConfig,
  initializeFirebase,
} from "./providers/firebase-config";
import { clerkConfig } from "./providers/clerk-config";

// Determine which provider to use
export function getAuthProvider() {
  // Get from environment or configuration
  const providerName = process.env.NEXT_PUBLIC_AUTH_PROVIDER || "auth0";

  switch (providerName) {
    case "firebase":
      return {
        type: "firebase",
        config: firebaseConfig,
        initialize: initializeFirebase,
      };
    case "clerk":
      return {
        type: "clerk",
        config: clerkConfig,
        initialize: () => null, // Clerk uses their provider component
      };
    case "auth0":
    default:
      return {
        type: "auth0",
        config: auth0Config,
        initialize: setupAuth0,
      };
  }
}

// Provider-agnostic user mapping
export function mapProviderUser(providerUser: any, providerType: string): User {
  switch (providerType) {
    case "firebase":
      return {
        id: providerUser.uid,
        email: providerUser.email,
        name: providerUser.displayName,
        picture: providerUser.photoURL,
        emailVerified: providerUser.emailVerified,
      };
    case "clerk":
      return {
        id: providerUser.id,
        email: providerUser.primaryEmailAddress?.emailAddress,
        name: `${providerUser.firstName} ${providerUser.lastName}`.trim(),
        picture: providerUser.imageUrl,
        emailVerified:
          providerUser.primaryEmailAddress?.verification?.status === "verified",
      };
    case "auth0":
    default:
      return {
        id: providerUser.sub,
        email: providerUser.email,
        name: providerUser.name,
        picture: providerUser.picture,
        emailVerified: providerUser.email_verified,
      };
  }
}
```

## Security Considerations

### Cross-Site Request Forgery (CSRF)

- Use SameSite cookie attribute
- Implement CSRF tokens for sensitive operations

### Cross-Site Scripting (XSS)

- Sanitize user input
- Implement Content Security Policy
- Use framework escape mechanisms

### JWT vs. Opaque Tokens

- **JWT**: Self-contained, larger, harder to revoke
- **Opaque**: Database-backed, smaller, easy to revoke

## Common Anti-Patterns

1. **Storing auth tokens in localStorage**

   - Solution: Use HTTP-only cookies

2. **Client-side-only permission checks**

   - Solution: Always verify permissions on server

3. **Mixed authentication state**

   - Solution: Create unified auth context

4. **Missing refresh token logic**
   - Solution: Implement token rotation

## Decision Matrix

| Factor         | Server-Side       | Client-Side          | Hybrid            |
| -------------- | ----------------- | -------------------- | ----------------- |
| SEO            | ✅ Excellent      | ⚠️ Poor              | ✅ Good           |
| Initial Load   | ✅ Fast with auth | ⚠️ Requires API call | ✅ Fast with auth |
| UI Transitions | ⚠️ Page reloads   | ✅ Smooth            | ✅ Smooth         |
| Security       | ✅ Most secure    | ⚠️ More exposed      | ✅ Good           |
| Complexity     | Medium            | Medium               | Higher            |

## Conclusion

Choose the approach that best fits your application's needs, prioritizing security while balancing user experience and performance requirements. This guide covers the practical implementation of the authentication patterns specified in the `120-auth-architecture-patterns.mdc` rule.

For more detailed specifications and requirements, refer to the `120-auth-architecture-patterns.mdc` rule.
