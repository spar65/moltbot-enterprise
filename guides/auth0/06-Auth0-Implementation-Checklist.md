# Auth0 Implementation Checklist

> A comprehensive checklist for implementing Auth0 authentication in Next.js applications

## Initial Setup

- [ ] Create Auth0 tenant
- [ ] Create Auth0 application (Regular Web App)
- [ ] Configure application settings
  - [ ] Set Allowed Callback URLs
  - [ ] Set Allowed Logout URLs
  - [ ] Set Allowed Web Origins
  - [ ] Configure Advanced Settings (JWT Algorithm, Grant Types)
- [ ] Set up test users
- [ ] Configure brute force protection
- [ ] Enable MFA (recommended)
- [ ] Set up email verification (recommended)

## Environment Configuration

- [ ] Generate AUTH0_SECRET using openssl
  ```bash
  openssl rand -hex 32
  ```
- [ ] Configure environment variables for development
  ```
  AUTH0_SECRET=your-generated-secret
  AUTH0_BASE_URL=http://localhost:3000
  AUTH0_ISSUER_BASE_URL=https://your-dev-tenant.us.auth0.com
  AUTH0_CLIENT_ID=your-dev-client-id
  AUTH0_CLIENT_SECRET=your-dev-client-secret
  AUTH0_DOMAIN=your-dev-tenant.us.auth0.com
  APP_BASE_URL=http://localhost:3000
  ```
- [ ] Set up environment variables in Vercel for staging
- [ ] Set up environment variables in Vercel for production
- [ ] Configure callback URLs for all environments
- [ ] Verify environment variables with diagnostic tools

## Validation and Diagnostic Tools

- [ ] Create Auth0 configuration validation script

  ```javascript
  // scripts/validate-auth0-config.js
  #!/usr/bin/env node

  console.log('🔍 Validating Auth0 Configuration...\n');

  // Check environment variables
  const requiredEnvVars = [
    'AUTH0_SECRET',
    'AUTH0_BASE_URL',
    'AUTH0_ISSUER_BASE_URL',
    'AUTH0_CLIENT_ID',
    'AUTH0_CLIENT_SECRET',
    'AUTH0_DOMAIN'
  ];

  let hasErrors = false;

  // Check for missing variables
  const missingVars = requiredEnvVars.filter(varName => !process.env[varName]);
  if (missingVars.length > 0) {
    console.error(`❌ Missing environment variables: ${missingVars.join(', ')}`);
    hasErrors = true;
  }

  // Validate AUTH0_SECRET length (must be exactly 32 characters)
  if (process.env.AUTH0_SECRET && process.env.AUTH0_SECRET.length !== 32) {
    console.error(`❌ AUTH0_SECRET must be exactly 32 characters, got ${process.env.AUTH0_SECRET.length}`);
    hasErrors = true;
  }

  // Validate URL formats
  const urlVars = ['AUTH0_BASE_URL', 'AUTH0_ISSUER_BASE_URL'];
  for (const varName of urlVars) {
    const url = process.env[varName];
    if (url && !url.startsWith('http')) {
      console.error(`❌ ${varName} should start with http(s)://, got: ${url}`);
      hasErrors = true;
    }
  }

  // Check file structure
  // Check middleware.ts location (should be in root for Auth0 SDK 4.6.0)
  // Check auth0.ts location
  // Check for Auth0 route handler

  // Test Auth0 domain connectivity
  const domain = process.env.AUTH0_ISSUER_BASE_URL || `https://${process.env.AUTH0_DOMAIN}`;
  const discoveryUrl = `${domain}/.well-known/openid-configuration`;
  ```

- [ ] Create Auth0 connection test script

  ```javascript
  // scripts/test-auth0-connection.js
  #!/usr/bin/env node

  import fetch from 'node-fetch';

  // Get Auth0 domain from environment variables
  const domain = process.env.AUTH0_ISSUER_BASE_URL || `https://${process.env.AUTH0_DOMAIN}`;

  // Test the discovery endpoint
  const discoveryUrl = `${domain}/.well-known/openid-configuration`;
  console.log(`Testing connection to: ${discoveryUrl}`);

  try {
    const response = await fetch(discoveryUrl);

    if (response.ok) {
      const data = await response.json();
      console.log('✅ Successfully connected to Auth0');
      console.log(`✅ Issuer: ${data.issuer}`);
      console.log(`✅ Authorization endpoint: ${data.authorization_endpoint}`);
    } else {
      console.error(`❌ Failed to connect to Auth0: ${response.status}`);
    }
  } catch (error) {
    console.error('❌ Error connecting to Auth0:', error.message);
  }
  ```

- [ ] Add validation scripts to package.json
  ```json
  {
    "scripts": {
      "dev": "npm run auth0:check && next dev",
      "build": "npm run auth0:check && next build",
      "auth0:check": "node scripts/validate-auth0-config.js",
      "auth0:test": "node --env-file=.env.local scripts/test-auth0-connection.js",
      "auth0:generate-secret": "node -e \"console.log(crypto.randomBytes(16).toString('hex'))\""
    }
  }
  ```

## Code Implementation

- [ ] Install Auth0 SDK
  ```bash
  npm install @auth0/nextjs-auth0@4.6.0
  ```
- [ ] Create Auth0 client with robust error handling

  ```typescript
  // src/lib/auth0.ts
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
        console.warn(`Invalid URL provided: ${url}`);
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
        console.warn(`Could not extract domain from: ${issuerUrl}`);
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

  // Validate required environment variables
  const requiredEnvVars = [
    "AUTH0_CLIENT_ID",
    "AUTH0_CLIENT_SECRET",
    "AUTH0_SECRET",
  ];

  const missingVars = requiredEnvVars.filter(
    (varName) => !process.env[varName]
  );
  if (missingVars.length > 0) {
    console.error(
      `❌ Missing Auth0 environment variables: ${missingVars.join(", ")}`
    );
  }

  // Validate AUTH0_SECRET length
  if (process.env.AUTH0_SECRET && process.env.AUTH0_SECRET.length !== 32) {
    console.error(
      `❌ AUTH0_SECRET must be exactly 32 characters, got ${process.env.AUTH0_SECRET.length}`
    );
  }

  // Create Auth0 client
  export const auth0 = new Auth0Client({
    domain,
    clientId: process.env.AUTH0_CLIENT_ID,
    clientSecret: process.env.AUTH0_CLIENT_SECRET,
    appBaseUrl,
    secret: process.env.AUTH0_SECRET,
    authorizationParameters: {
      scope: "openid profile email",
    },
  });

  export default auth0;
  ```

- [ ] Set up Auth0 route handler

  - For Pages Router (v4.6.0+):

    ```typescript
    // pages/auth/[...auth0].ts
    import { NextApiRequest, NextApiResponse } from "next";
    import { auth0 } from "../../src/lib/auth0";

    // Create a handler that will delegate to Auth0
    export default async function handler(
      req: NextApiRequest,
      res: NextApiResponse
    ) {
      try {
        // Let Auth0 handle the authentication routes
        // This is a placeholder - the actual handling is done by middleware
        return res.status(200).end();
      } catch (error) {
        console.error("Auth route error:", error);
        return res.status(500).end("Internal Server Error");
      }
    }
    ```

  - For App Router:
    ```typescript
    // app/auth/[...auth0]/route.ts
    import { auth0 } from "@/lib/auth0";
    export const GET = auth0.handleAuth();
    export const POST = auth0.handleAuth();
    ```

- [ ] Configure middleware with robust error handling

  ```typescript
  // middleware.ts
  import { NextResponse } from "next/server";
  import type { NextRequest } from "next/server";
  import { auth0 } from "./src/lib/auth0";

  export async function middleware(request: NextRequest) {
    console.log("🔍 MIDDLEWARE - Processing:", request.nextUrl.pathname);

    // Handle auth routes
    if (request.nextUrl.pathname.startsWith("/auth/")) {
      console.log("🔑 AUTH ROUTE DETECTED:", request.nextUrl.pathname);

      try {
        const authResult = await auth0.middleware(request);
        console.log("✅ Auth0 result:", authResult?.status || "no response");

        if (authResult) {
          return authResult;
        }

        // Fallback manual handling if needed
        const authPath = request.nextUrl.pathname.split("/auth/")[1];
        console.log("🔄 Manual auth handling for:", authPath);

        switch (authPath) {
          case "login":
            const loginUrl =
              `https://${process.env.AUTH0_ISSUER_BASE_URL}/authorize?` +
              `client_id=${process.env.AUTH0_CLIENT_ID}&` +
              `redirect_uri=${encodeURIComponent(
                `${process.env.AUTH0_BASE_URL}/auth/callback`
              )}&` +
              `response_type=code&` +
              `scope=openid%20profile%20email`;

            console.log("🔗 Redirecting to Auth0 login");
            return NextResponse.redirect(loginUrl);

          case "logout":
            const logoutUrl =
              `https://${process.env.AUTH0_ISSUER_BASE_URL}/v2/logout?` +
              `client_id=${process.env.AUTH0_CLIENT_ID}&` +
              `returnTo=${encodeURIComponent(
                process.env.AUTH0_BASE_URL || ""
              )}`;

            console.log("🔗 Redirecting to Auth0 logout");
            return NextResponse.redirect(logoutUrl);

          default:
            console.log("❌ Unknown auth route:", authPath);
            return new NextResponse("Not Found", { status: 404 });
        }
      } catch (error) {
        console.error("❌ Auth middleware error:", error);
        return new NextResponse("Auth Error", { status: 500 });
      }
    }

    // For non-auth routes, continue normally
    return NextResponse.next();
  }

  export const config = {
    matcher: [
      "/((?!_next/static|_next/image|favicon.ico|sitemap.xml|robots.txt|api/webhooks|api/cron).*)",
    ],
  };
  ```

- [ ] Implement login/logout UI

  ```tsx
  // components/AuthButtons.tsx
  export function LoginButton() {
    return (
      <a href="/auth/login" className="login-button">
        Log In
      </a>
    );
  }

  export function LogoutButton() {
    return (
      <a href="/auth/logout" className="logout-button">
        Log Out
      </a>
    );
  }
  ```

- [ ] Set up protected routes

  - For Pages Router:

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

  - For App Router:

    ```typescript
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

## Testing

- [ ] Run local environment variable tests
  ```bash
  npm run auth0:check
  ```
- [ ] Test Auth0 connectivity
  ```bash
  npm run auth0:test
  ```
- [ ] Verify discovery endpoint
  ```bash
  curl https://your-tenant.us.auth0.com/.well-known/openid-configuration
  ```
- [ ] Test login flow
- [ ] Test logout flow
- [ ] Test session persistence
- [ ] Test error scenarios
  - [ ] Invalid credentials
  - [ ] Expired sessions
  - [ ] Network errors
- [ ] Test with multiple browsers
- [ ] Test with incognito/private browsing
- [ ] Verify redirect URLs after login/logout

## Deployment

- [ ] Deploy to staging environment
- [ ] Verify all Auth0 functionality in staging
- [ ] Run diagnostic tools in staging
- [ ] Test performance and load
- [ ] Deploy to production
- [ ] Verify all Auth0 functionality in production
- [ ] Monitor authentication logs
- [ ] Set up alerts for authentication failures

## Security Verification

- [ ] Verify JWT token signature validation
- [ ] Check secure cookie settings
- [ ] Ensure HTTP-only cookies for tokens
- [ ] Validate CSRF protection
- [ ] Review security headers
- [ ] Test for open redirects
- [ ] Verify proper error handling
- [ ] Ensure sensitive logs are not exposed

## Documentation

- [ ] Document authentication flow
- [ ] Create user guide for authentication
- [ ] Document environment variables
- [ ] Document debugging procedures
- [ ] Create onboarding guide for new developers
- [ ] Document emergency recovery procedures

## Maintenance Plan

- [ ] Schedule regular security audits
- [ ] Plan for Auth0 SDK upgrades
- [ ] Monitor Auth0 changelog for updates
- [ ] Schedule refresh token rotation
- [ ] Plan for handling Auth0 service disruptions

## Common Issues and Solutions

- **Issue**: Auth0 middleware throws "Invalid URL" errors
  **Solution**: Implement robust URL validation and fallbacks in the Auth0 client

- **Issue**: AUTH0_SECRET length issues
  **Solution**: Use the auth0:generate-secret script to create a proper 32-character secret

- **Issue**: Missing environment variables in production
  **Solution**: Run the auth0:check script before deployment to catch missing variables

- **Issue**: Callback URL mismatches
  **Solution**: Ensure callback URLs in Auth0 Dashboard match your application URLs for each environment
