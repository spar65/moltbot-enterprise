# Multi-Environment Authentication Configuration Guide

This guide provides practical implementation strategies for configuring authentication across multiple environments while maintaining security and consistency.

## Introduction

Managing authentication across different environments (development, staging, production) presents unique challenges. This guide extends the `500-multi-env-auth.mdc` rule with concrete examples and implementation patterns.

## Table of Contents

1. [Environment Architecture Overview](#environment-architecture-overview)
2. [Auth0 Tenant Configuration](#auth0-tenant-configuration)
3. [Environment-Specific Configuration](#environment-specific-configuration)
4. [Implementing Environment-Aware Authentication](#implementing-environment-aware-authentication)
5. [Local Development Setup](#local-development-setup)
6. [Testing Across Environments](#testing-across-environments)
7. [Environment Transition Process](#environment-transition-process)
8. [Security Considerations](#security-considerations)
9. [Troubleshooting Cross-Environment Issues](#troubleshooting-cross-environment-issues)
10. [Best Practices](#best-practices)

## Environment Architecture Overview

A proper multi-environment architecture for authentication should include:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  DEVELOPMENT    │    │     STAGING     │    │   PRODUCTION    │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │  Auth0 Dev  │ │    │ │ Auth0 Stage │ │    │ │ Auth0 Prod  │ │
│ │   Tenant    │ │    │ │   Tenant    │ │    │ │   Tenant    │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │   Dev App   │ │    │ │  Stage App  │ │    │ │  Prod App   │ │
│ │   Config    │ │    │ │   Config    │ │    │ │   Config    │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │   Dev DB    │ │    │ │  Stage DB   │ │    │ │   Prod DB   │ │
│ │  (Users)    │ │    │ │  (Users)    │ │    │ │  (Users)    │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Auth0 Tenant Configuration

### Creating Separate Auth0 Tenants

For each environment, create a separate Auth0 tenant:

1. **Development Tenant**: Used for local development

   - Naming convention: `company-dev`
   - More permissive settings for easier development
   - Test users with predictable credentials

2. **Staging Tenant**: Used for testing deployments

   - Naming convention: `company-staging`
   - Settings mirror production but with additional logging
   - Test data that simulates production patterns

3. **Production Tenant**: Used for live application
   - Naming convention: `company` or `company-prod`
   - Strict security settings
   - No test users or data

### Configuring Application Settings

For each tenant, create matching application configurations:

```javascript
// Auth0 Development Application Settings
{
  "name": "My App (Development)",
  "callbacks": [
    "http://localhost:3000/auth/callback",
    "https://dev.myapp.com/auth/callback"
  ],
  "allowed_logout_urls": [
    "http://localhost:3000",
    "https://dev.myapp.com"
  ],
  "web_origins": [
    "http://localhost:3000",
    "https://dev.myapp.com"
  ],
  "grant_types": [
    "authorization_code",
    "refresh_token"
  ],
  "token_endpoint_auth_method": "none"
}
```

```javascript
// Auth0 Production Application Settings
{
  "name": "My App (Production)",
  "callbacks": [
    "https://app.myapp.com/auth/callback"
  ],
  "allowed_logout_urls": [
    "https://app.myapp.com"
  ],
  "web_origins": [
    "https://app.myapp.com"
  ],
  "grant_types": [
    "authorization_code",
    "refresh_token"
  ],
  "token_endpoint_auth_method": "none"
}
```

### Tenant-Level Settings

Configure these settings for each tenant:

| Setting                | Development | Staging  | Production           |
| ---------------------- | ----------- | -------- | -------------------- |
| User Registration      | Enabled     | Enabled  | Enabled              |
| Social Connections     | Disabled    | Enabled  | Enabled              |
| MFA                    | Optional    | Optional | Required (for admin) |
| Brute Force Protection | Basic       | Strict   | Strict               |
| Suspicious Login       | Disabled    | Enabled  | Enabled              |
| Logging                | Verbose     | Enhanced | Standard             |

## Environment-Specific Configuration

### Environment Variable Structure

Use a structured approach to environment variables:

```bash
# .env.development
AUTH0_DOMAIN=company-dev.us.auth0.com
AUTH0_CLIENT_ID=dev-client-id
AUTH0_CLIENT_SECRET=dev-client-secret
AUTH0_AUDIENCE=https://api.dev.company.com
AUTH0_SCOPE="openid profile email"
AUTH0_ISSUER_BASE_URL=https://company-dev.us.auth0.com
AUTH0_BASE_URL=http://localhost:3000
AUTH0_SECRET=development-signing-secret
API_BASE_URL=http://localhost:3001

# .env.staging
AUTH0_DOMAIN=company-staging.us.auth0.com
AUTH0_CLIENT_ID=staging-client-id
AUTH0_CLIENT_SECRET=staging-client-secret
AUTH0_AUDIENCE=https://api.staging.company.com
AUTH0_SCOPE="openid profile email"
AUTH0_ISSUER_BASE_URL=https://company-staging.us.auth0.com
AUTH0_BASE_URL=https://staging.company.com
AUTH0_SECRET=staging-signing-secret
API_BASE_URL=https://api.staging.company.com

# .env.production
AUTH0_DOMAIN=company.us.auth0.com
AUTH0_CLIENT_ID=production-client-id
AUTH0_CLIENT_SECRET=production-client-secret
AUTH0_AUDIENCE=https://api.company.com
AUTH0_SCOPE="openid profile email"
AUTH0_ISSUER_BASE_URL=https://company.us.auth0.com
AUTH0_BASE_URL=https://app.company.com
AUTH0_SECRET=production-signing-secret
API_BASE_URL=https://api.company.com
```

### Configuration Management

Create a centralized configuration module:

```typescript
// src/config/auth.ts
import { z } from "zod";

// Define schema for auth configuration
const authConfigSchema = z.object({
  domain: z.string().min(1),
  clientId: z.string().min(1),
  clientSecret: z.string().min(1),
  audience: z.string().url(),
  scope: z.string().default("openid profile email"),
  issuerBaseUrl: z.string().url(),
  baseUrl: z.string().url(),
  secret: z.string().min(32),
  environment: z.enum(["development", "staging", "production"]),
});

// Create type from schema
type AuthConfig = z.infer<typeof authConfigSchema>;

// Load environment variables based on NODE_ENV
function loadAuthConfig(): AuthConfig {
  const env = process.env.NODE_ENV || "development";

  try {
    // Extract and validate config
    const config = {
      domain: process.env.AUTH0_DOMAIN!,
      clientId: process.env.AUTH0_CLIENT_ID!,
      clientSecret: process.env.AUTH0_CLIENT_SECRET!,
      audience: process.env.AUTH0_AUDIENCE!,
      scope: process.env.AUTH0_SCOPE || "openid profile email",
      issuerBaseUrl: process.env.AUTH0_ISSUER_BASE_URL!,
      baseUrl: process.env.AUTH0_BASE_URL!,
      secret: process.env.AUTH0_SECRET!,
      environment: env as "development" | "staging" | "production",
    };

    // Validate against schema
    return authConfigSchema.parse(config);
  } catch (error) {
    console.error("Auth configuration error:", error);
    throw new Error("Invalid auth configuration");
  }
}

// Export validated config
export const authConfig = loadAuthConfig();

// Helper functions
export function isDevelopment() {
  return authConfig.environment === "development";
}

export function isProduction() {
  return authConfig.environment === "production";
}

export function isStaging() {
  return authConfig.environment === "staging";
}
```

## Implementing Environment-Aware Authentication

### Next.js Auth0 Configuration

```typescript
// src/lib/auth0.ts
import { Auth0Client } from "@auth0/nextjs-auth0/server";
import { authConfig } from "../config/auth";

// Create Auth0 client with environment-specific config
export const auth0 = new Auth0Client({
  baseURL: authConfig.baseUrl,
  secretKey: authConfig.secret,
  authConfig: {
    issuer: authConfig.issuerBaseUrl,
    clientID: authConfig.clientId,
    clientSecret: authConfig.clientSecret,
    scope: authConfig.scope,
    audience: authConfig.audience,
    skipHostedLoginPageLink: authConfig.environment === "development",
    routes: {
      callback: "/auth/callback",
      login: "/auth/login",
      logout: "/auth/logout",
    },
  },
});
```

### Environment-Specific Auth UI Customization

```typescript
// src/components/LoginForm.tsx
import { useAuth } from "../hooks/useAuth";
import { authConfig, isDevelopment } from "../config/auth";

export function LoginForm() {
  const { login } = useAuth();

  return (
    <div className="login-form">
      {isDevelopment() && (
        <div className="dev-banner">DEVELOPMENT ENVIRONMENT</div>
      )}

      <h1>
        Log In to{" "}
        {authConfig.environment === "production"
          ? "MyApp"
          : `MyApp (${authConfig.environment})`}
      </h1>

      <button onClick={() => login()}>Log In with Auth0</button>

      {isDevelopment() && (
        <div className="test-accounts">
          <h4>Test Accounts</h4>
          <p>user@example.com / Password123!</p>
          <p>admin@example.com / Password123!</p>
        </div>
      )}
    </div>
  );
}
```

## Local Development Setup

### Environment Switching in Development

Create a script to easily switch between environments:

```javascript
// scripts/switch-env.js
const fs = require("fs");
const path = require("path");
const readline = require("readline");

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

// Available environments
const environments = ["development", "staging", "production"];

console.log("Select environment to use for local development:");
environments.forEach((env, index) => {
  console.log(`${index + 1}. ${env}`);
});

rl.question("Enter number: ", (answer) => {
  const selection = parseInt(answer, 10);

  if (selection >= 1 && selection <= environments.length) {
    const selectedEnv = environments[selection - 1];

    // Copy the selected .env file to .env.local
    const source = path.join(process.cwd(), `.env.${selectedEnv}`);
    const destination = path.join(process.cwd(), ".env.local");

    fs.copyFileSync(source, destination);
    console.log(`\nSwitched to ${selectedEnv} environment!`);
    console.log(`Copied ${source} to ${destination}\n`);
  } else {
    console.log("Invalid selection");
  }

  rl.close();
});
```

### Auth0 Local Development Configuration

Enable proper localhost usage with Auth0:

```typescript
// next.config.js
module.exports = {
  publicRuntimeConfig: {
    auth0: {
      domain: process.env.AUTH0_DOMAIN,
      clientId: process.env.AUTH0_CLIENT_ID,
      audience: process.env.AUTH0_AUDIENCE,
    },
  },
  async rewrites() {
    // Only apply in development for localhost callback handling
    if (process.env.NODE_ENV === "development") {
      return [
        {
          source: "/auth/:path*",
          destination: "/api/auth/:path*",
        },
      ];
    }
    return [];
  },
};
```

### Mock Authentication Option

For offline development, provide a mock authentication option:

```typescript
// src/mocks/auth.ts
export const mockUsers = {
  admin: {
    sub: "mock|admin123",
    name: "Admin User",
    email: "admin@example.com",
    picture: "https://via.placeholder.com/150",
    roles: ["admin"],
    permissions: ["read:any", "write:any"],
  },
  user: {
    sub: "mock|user123",
    name: "Regular User",
    email: "user@example.com",
    picture: "https://via.placeholder.com/150",
    roles: ["user"],
    permissions: ["read:own", "write:own"],
  },
};

// Create mock token for development
export function createMockToken(user = mockUsers.user) {
  // This is NOT a real JWT - just a mock for development
  return `mock_${btoa(JSON.stringify(user))}`;
}

// Parse mock token
export function parseMockToken(token) {
  if (!token.startsWith("mock_")) return null;
  try {
    return JSON.parse(atob(token.replace("mock_", "")));
  } catch (e) {
    return null;
  }
}
```

## Testing Across Environments

### Environment-Specific Test Suites

Configure Jest to support multiple environments:

```javascript
// jest.config.js
module.exports = {
  setupFilesAfterEnv: ["<rootDir>/jest.setup.js"],
  testEnvironment: "jsdom",
  testPathIgnorePatterns: ["/node_modules/", "/.next/"],
  transformIgnorePatterns: ["/node_modules/"],
  moduleNameMapper: {
    "^@/(.*)$": "<rootDir>/src/$1",
  },
  // Environment-specific test setups
  projects: [
    {
      displayName: "development",
      testEnvironment: "jsdom",
      setupFiles: ["<rootDir>/test/setup/development.js"],
      testMatch: ["<rootDir>/**/*.test.ts?(x)"],
    },
    {
      displayName: "staging",
      testEnvironment: "jsdom",
      setupFiles: ["<rootDir>/test/setup/staging.js"],
      testMatch: ["<rootDir>/**/*.test.ts?(x)"],
    },
    {
      displayName: "production",
      testEnvironment: "jsdom",
      setupFiles: ["<rootDir>/test/setup/production.js"],
      testMatch: ["<rootDir>/**/*.test.ts?(x)"],
    },
  ],
};
```

### Environment Setup for Tests

```javascript
// test/setup/development.js
process.env.NODE_ENV = "development";
process.env.AUTH0_DOMAIN = "company-dev.us.auth0.com";
process.env.AUTH0_CLIENT_ID = "test-client-id";
process.env.AUTH0_CLIENT_SECRET = "test-client-secret";
process.env.AUTH0_AUDIENCE = "https://api.dev.company.com";
process.env.AUTH0_BASE_URL = "http://localhost:3000";
process.env.AUTH0_SECRET = "test-secret-at-least-32-characters-long";
```

### Environment-Aware Test Helpers

```typescript
// test/helpers/auth.ts
import { mockUsers } from "../../src/mocks/auth";
import { isProduction, isDevelopment } from "../../src/config/auth";

export function getTestUser(role = "user") {
  // In production tests, use different test accounts
  if (isProduction()) {
    return {
      sub: role === "admin" ? "prod-test|admin" : "prod-test|user",
      name: role === "admin" ? "Production Admin" : "Production User",
      // Other properties...
    };
  }

  // Use standard mock users for dev/staging
  return role === "admin" ? mockUsers.admin : mockUsers.user;
}

export function getAuthHeaders(user = getTestUser()) {
  // Production and staging require proper JWT format for tests
  if (!isDevelopment()) {
    // Use test tokens from Auth0 test client
    return {
      Authorization: `Bearer ${getEnvTestToken(user.sub.includes("admin"))}`,
    };
  }

  // Development can use simpler mock tokens
  return {
    Authorization: `Bearer mock_${btoa(JSON.stringify(user))}`,
  };
}

// Get environment-specific test tokens (these would be pre-generated)
function getEnvTestToken(isAdmin = false) {
  const envTokens = {
    development: {
      admin: "dev-admin-test-token",
      user: "dev-user-test-token",
    },
    staging: {
      admin: "staging-admin-test-token",
      user: "staging-user-test-token",
    },
    production: {
      admin: "prod-admin-test-token",
      user: "prod-user-test-token",
    },
  };

  const env = process.env.NODE_ENV || "development";
  const role = isAdmin ? "admin" : "user";

  return envTokens[env][role];
}
```

## Environment Transition Process

### Promoting Auth Configuration

Create a checklist for promoting auth configuration between environments:

```markdown
# Auth0 Configuration Promotion Checklist

## Pre-Promotion Tasks

- [ ] Verify all required Auth0 Rules exist in target environment
- [ ] Compare Auth0 settings between environments
- [ ] Verify callback URLs in target environment
- [ ] Ensure API permissions are consistent
- [ ] Check for environment-specific variables in Rules/Actions

## Environment Variables Update

- [ ] Update auth environment variables in deployment system
- [ ] Verify secret rotation if needed
- [ ] Update any additional environment-specific settings

## Post-Promotion Verification

- [ ] Test login flow in target environment
- [ ] Test logout flow in target environment
- [ ] Test protected API calls with new tokens
- [ ] Verify token claims and permissions
- [ ] Test social connections if applicable

## Rollback Plan

- [ ] Document previous configuration values
- [ ] Define triggers for rollback decision
- [ ] Assign rollback decision owner
- [ ] Create rollback command/script
```

### Configuration Comparison Tool

Create a tool to compare Auth0 configuration between environments:

```javascript
// scripts/compare-auth0-config.js
const fs = require("fs");
const path = require("path");
const { ManagementClient } = require("auth0");

async function getAuth0Config(domain, clientId, clientSecret) {
  const auth0 = new ManagementClient({
    domain,
    clientId,
    clientSecret,
    scope: "read:clients read:rules read:resource_servers",
  });

  // Get clients (applications)
  const clients = await auth0.clients.getAll();

  // Get rules
  const rules = await auth0.rules.getAll();

  // Get API configuration
  const apis = await auth0.resourceServers.getAll();

  return {
    clients: clients.map((c) => ({
      name: c.name,
      client_id: c.client_id,
      callbacks: c.callbacks,
      allowed_logout_urls: c.allowed_logout_urls,
      web_origins: c.web_origins,
    })),
    rules: rules.map((r) => ({
      name: r.name,
      enabled: r.enabled,
      script_size: r.script.length,
    })),
    apis: apis.map((a) => ({
      name: a.name,
      identifier: a.identifier,
      scopes_count: a.scopes.length,
    })),
  };
}

async function compareEnvironments() {
  const envs = {
    development: {
      domain: process.env.DEV_AUTH0_DOMAIN,
      clientId: process.env.DEV_AUTH0_CLIENT_ID,
      clientSecret: process.env.DEV_AUTH0_CLIENT_SECRET,
    },
    staging: {
      domain: process.env.STAGING_AUTH0_DOMAIN,
      clientId: process.env.STAGING_AUTH0_CLIENT_ID,
      clientSecret: process.env.STAGING_AUTH0_CLIENT_SECRET,
    },
    production: {
      domain: process.env.PROD_AUTH0_DOMAIN,
      clientId: process.env.PROD_AUTH0_CLIENT_ID,
      clientSecret: process.env.PROD_AUTH0_CLIENT_SECRET,
    },
  };

  const configs = {};

  // Get configurations
  for (const [env, config] of Object.entries(envs)) {
    console.log(`Fetching ${env} configuration...`);
    configs[env] = await getAuth0Config(
      config.domain,
      config.clientId,
      config.clientSecret
    );
    console.log(`Done fetching ${env} configuration.`);
  }

  // Compare configs
  console.log("\nEnvironment Comparison Summary:");

  for (const env of Object.keys(configs)) {
    if (env === "production") continue; // Don't compare production to itself

    console.log(`\n${env.toUpperCase()} vs PRODUCTION:`);

    // Compare client counts
    console.log(
      `- Applications: ${configs[env].clients.length} vs ${configs.production.clients.length}`
    );

    // Compare rule counts
    console.log(
      `- Rules: ${configs[env].rules.length} vs ${configs.production.rules.length}`
    );

    // Compare API counts
    console.log(
      `- APIs: ${configs[env].apis.length} vs ${configs.production.apis.length}`
    );

    // Find missing rules in this environment that exist in production
    const prodRuleNames = configs.production.rules.map((r) => r.name);
    const envRuleNames = configs[env].rules.map((r) => r.name);
    const missingRules = prodRuleNames.filter((r) => !envRuleNames.includes(r));

    if (missingRules.length > 0) {
      console.log("- Missing rules:");
      missingRules.forEach((r) => console.log(`  - ${r}`));
    }
  }

  // Save full report
  fs.writeFileSync(
    path.join(process.cwd(), "auth0-config-report.json"),
    JSON.stringify(configs, null, 2)
  );

  console.log("\nFull report saved to auth0-config-report.json");
}

compareEnvironments().catch((err) => {
  console.error("Error comparing environments:", err);
  process.exit(1);
});
```

## Security Considerations

### Environment Isolation

Ensure proper security boundaries between environments:

1. **No Shared Secrets**: Never use the same client secrets, signing keys, or encryption keys across environments

2. **No Production Data in Lower Environments**: Never copy real user data to development or staging

3. **No Bidirectional Trust**: Production should never trust development or staging environments

4. **Access Control Separation**: Use different access control and admin accounts for each environment

### Environment-Specific Security Settings

```typescript
// src/config/security.ts
import { authConfig, isProduction, isDevelopment } from "./auth";

export const securityConfig = {
  // JWT validation settings
  tokenValidation: {
    // More strict caching in production
    cacheMaxAge: isProduction() ? 3600 : 60,
    // Stricter leeway in production
    leeway: isProduction() ? 0 : 60,
    // Required in production, optional in dev
    requireEmailVerification: isProduction(),
  },

  // Session settings
  session: {
    // Shorter session in production
    maxAge: isProduction() ? 3600 * 8 : 3600 * 24,
    // Always secure in production, flexible in dev
    secure: isProduction() ? true : authConfig.baseUrl.startsWith("https"),
    // Use stricter same-site policy in production
    sameSite: isProduction() ? "strict" : "lax",
  },

  // Rate limiting
  rateLimit: {
    // More permissive in development
    loginAttempts: isDevelopment() ? 20 : 5,
    windowMs: isDevelopment() ? 60 * 1000 : 15 * 60 * 1000,
  },
};
```

## Troubleshooting Cross-Environment Issues

### Common Multi-Environment Auth Problems

#### 1. Token Validation Failures

**Problem**: Tokens from one environment being validated against another environment's configuration.

**Solution**:

```typescript
// src/middleware/auth.ts
import { auth0 } from "../lib/auth0";
import { authConfig } from "../config/auth";

export async function validateToken(token) {
  try {
    // Always validate against current environment issuer
    const result = await auth0.verifyToken(token, {
      issuer: authConfig.issuerBaseUrl,
    });
    return result;
  } catch (error) {
    console.error(`Token validation error: ${error.message}`);
    // Check for common cross-environment issues
    if (error.message.includes("issuer")) {
      console.error(
        "Possible cross-environment token. Check that token is from the correct Auth0 tenant."
      );
    }
    throw error;
  }
}
```

#### 2. Callback URL Mismatches

**Problem**: Redirect URIs configured for one environment being used in another.

**Solution**:

```typescript
// src/pages/api/auth/login.ts
import { authConfig } from "../../../config/auth";

export default async function login(req, res) {
  // Environment-specific callback URL
  const callbackUrl = new URL("/auth/callback", authConfig.baseUrl).toString();

  // Log the callback URL in non-production environments
  if (authConfig.environment !== "production") {
    console.log(`Using callback URL: ${callbackUrl}`);
  }

  try {
    // Redirect to Auth0 login
    res.redirect(
      `${
        authConfig.issuerBaseUrl
      }/authorize?...&redirect_uri=${encodeURIComponent(callbackUrl)}`
    );
  } catch (error) {
    console.error("Login error:", error);
    res.status(500).send("Login error");
  }
}
```

#### 3. Environment Leakage

**Problem**: Development configuration or credentials leaking into production.

**Solution**:

```typescript
// src/lib/auth0-guard.ts
import { isProduction, authConfig } from "../config/auth";

// Function to prevent accidental env leakage
export function enforceEnvironmentSafety() {
  if (isProduction()) {
    // Verify not using development tenant in production
    if (
      authConfig.domain.includes("-dev") ||
      authConfig.domain.includes("-staging")
    ) {
      throw new Error(
        "CRITICAL: Development Auth0 tenant used in production environment"
      );
    }

    // Verify not using localhost in production
    if (authConfig.baseUrl.includes("localhost")) {
      throw new Error("CRITICAL: localhost URL used in production environment");
    }
  }
}

// Call this in your app initialization
enforceEnvironmentSafety();
```

## Best Practices

### 1. Environment Markers

Always include visual indicators of the current environment:

```tsx
// src/components/EnvironmentIndicator.tsx
import React from "react";
import { authConfig, isDevelopment, isStaging } from "../config/auth";

export function EnvironmentIndicator() {
  // Only show in non-production environments
  if (authConfig.environment === "production") {
    return null;
  }

  const bgColor = isDevelopment()
    ? "bg-blue-500"
    : isStaging()
    ? "bg-yellow-500"
    : null;

  return bgColor ? (
    <div
      className={`fixed top-0 left-0 right-0 ${bgColor} text-white text-center py-1 text-sm font-bold z-50`}
    >
      {authConfig.environment.toUpperCase()} ENVIRONMENT
    </div>
  ) : null;
}
```

### 2. Configuration Validation

Validate configuration at startup to catch misconfigurations early:

```typescript
// src/lib/validate-config.ts
import { authConfig } from "../config/auth";

export function validateAuthConfig() {
  const { environment, domain, baseUrl } = authConfig;

  // Check for environment/domain mismatches
  if (environment === "development" && !domain.includes("-dev")) {
    console.warn(
      "Warning: Development environment using non-development Auth0 domain"
    );
  }

  if (environment === "staging" && !domain.includes("-staging")) {
    console.warn("Warning: Staging environment using non-staging Auth0 domain");
  }

  if (
    environment === "production" &&
    (domain.includes("-dev") || domain.includes("-staging"))
  ) {
    throw new Error(
      "CRITICAL: Production environment using non-production Auth0 domain"
    );
  }

  // Check for URL/environment mismatches
  if (
    environment === "development" &&
    !baseUrl.includes("localhost") &&
    !baseUrl.includes("dev.")
  ) {
    console.warn("Warning: Development environment using non-development URL");
  }

  if (
    environment === "staging" &&
    !baseUrl.includes("staging.") &&
    !baseUrl.includes("test.")
  ) {
    console.warn("Warning: Staging environment using non-staging URL");
  }

  if (
    environment === "production" &&
    (baseUrl.includes("localhost") ||
      baseUrl.includes("dev.") ||
      baseUrl.includes("staging."))
  ) {
    throw new Error(
      "CRITICAL: Production environment using non-production URL"
    );
  }

  console.log(`Auth configuration validated for ${environment} environment`);
}
```

### 3. Documentation

Create a comprehensive environment configuration document:

```markdown
# Authentication Environment Configuration

## Overview

This document describes the authentication configuration for all environments in our application.

## Environment Details

### Development

- **Auth0 Tenant:** company-dev.us.auth0.com
- **Application:** My App (Development)
- **Application ID:** dev-client-id
- **Callback URLs:** http://localhost:3000/auth/callback, https://dev.company.com/auth/callback
- **User Registration:** Enabled
- **Test Accounts:**
  - user@example.com / Password123!
  - admin@example.com / Password123!

### Staging

- **Auth0 Tenant:** company-staging.us.auth0.com
- **Application:** My App (Staging)
- **Application ID:** staging-client-id
- **Callback URLs:** https://staging.company.com/auth/callback
- **User Registration:** Enabled
- **Test Accounts:**
  - staging-user@company.com / StagingPassword123!
  - staging-admin@company.com / StagingPassword123!

### Production

- **Auth0 Tenant:** company.us.auth0.com
- **Application:** My App
- **Application ID:** production-client-id
- **Callback URLs:** https://app.company.com/auth/callback
- **User Registration:** Enabled
- **Social Connections:** Google, GitHub, Microsoft

## Environment Transition Process

See the [Auth0 Configuration Promotion Checklist](./auth0-promotion-checklist.md) for the process to follow when promoting configuration between environments.
```

## Conclusion

Implementing a solid multi-environment authentication architecture is essential for secure and maintainable applications. By following the patterns in this guide, you can ensure consistency across environments while maintaining appropriate security isolation.

For more details on multi-environment auth configuration requirements, refer to the `500-multi-env-auth.mdc` rule.

## Resources

- [Auth0 Multi-Tenant Architecture](https://auth0.com/docs/get-started/auth0-overview/create-tenants)
- [Next.js Environment Variables](https://nextjs.org/docs/basic-features/environment-variables)
- [Auth0 Environment Setup](https://auth0.com/docs/get-started/auth0-overview/set-up-multiple-environments)
- [Secure SDLC Environment Management](https://owasp.org/www-project-secure-software-development-lifecycle-project/)
