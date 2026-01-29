# Auth0 Management API Integration - Complete Implementation and Debugging Guide

## Overview

This guide provides a complete walkthrough for integrating Auth0 Management API with role-based authentication, including common issues and their solutions. This is based on real debugging experience where we solved critical session parameter mismatches.

## Table of Contents

1. [Initial Setup](#initial-setup)
2. [Database Schema Fixes](#database-schema-fixes)
3. [Environment Configuration](#environment-configuration)
4. [Auth0 Configuration](#auth0-configuration)
5. [Implementation Steps](#implementation-steps)
6. [API Response Structure Fixes](#api-response-structure-fixes)
7. [Complete Working Implementations](#complete-working-implementations)
8. [Common Issues and Debugging](#common-issues-and-debugging)
9. [The Critical Bug We Discovered](#the-critical-bug-we-discovered)
10. [Testing and Verification](#testing-and-verification)
11. [Production Checklist](#production-checklist)

---

## Initial Setup

### Prerequisites

- Auth0 account with management permissions
- Next.js application with Auth0 SDK
- Environment variables configured

### Required Environment Variables

```bash
# Basic Auth0 Configuration
AUTH0_SECRET=your-32-character-secret
AUTH0_BASE_URL=http://localhost:3000
AUTH0_ISSUER_BASE_URL=https://your-domain.auth0.com
AUTH0_CLIENT_ID=your-client-id
AUTH0_CLIENT_SECRET=your-client-secret

# Management API Configuration
AUTH0_MGMT_CLIENT_ID=your-machine-to-machine-client-id
AUTH0_MGMT_CLIENT_SECRET=your-machine-to-machine-secret
AUTH0_AUDIENCE=https://api.yourdomain.com
AUTH0_DOMAIN=your-domain.auth0.com
```

---

## Database Schema Fixes

### Issues We Encountered

During implementation, we discovered several database schema issues that had to be resolved:

#### 1. Missing auth0_id Column

**Problem**: The users table was missing the `auth0_id` column needed for Auth0 synchronization.

**Solution**: Add the column with proper constraints:

```sql
-- Add auth0_id column to users table
ALTER TABLE users ADD COLUMN auth0_id VARCHAR(255) UNIQUE;

-- Add index for performance
CREATE INDEX idx_users_auth0_id ON users(auth0_id);
```

#### 2. Auto-increment ID Column Issue

**Problem**: The users table ID column wasn't properly auto-incrementing.

**Solution**: Fix the sequence and set it as default:

```sql
-- Create sequence if it doesn't exist
CREATE SEQUENCE IF NOT EXISTS users_id_seq;

-- Set the column default to use the sequence
ALTER TABLE users ALTER COLUMN id SET DEFAULT nextval('users_id_seq');

-- Set the sequence ownership
ALTER SEQUENCE users_id_seq OWNED BY users.id;

-- Set the sequence to current max value + 1
SELECT setval('users_id_seq', (SELECT COALESCE(MAX(id), 0) + 1 FROM users));
```

#### 3. Role Column References

**Problem**: Database queries were referencing a non-existent "role" column.

**Solution**: Remove or update queries that reference the role column:

```typescript
// ❌ WRONG - Role column doesn't exist
const query = "SELECT id, email, role FROM users WHERE auth0_id = $1";

// ✅ CORRECT - Use existing columns
const query = "SELECT id, email, created_at FROM users WHERE auth0_id = $1";
```

### Database Migration Script

Create this migration file to apply all fixes:

```sql
-- migrations/002_auth0_integration_fixes.sql

-- Add auth0_id column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'users' AND column_name = 'auth0_id') THEN
        ALTER TABLE users ADD COLUMN auth0_id VARCHAR(255) UNIQUE;
        CREATE INDEX idx_users_auth0_id ON users(auth0_id);
    END IF;
END $$;

-- Fix auto-increment for ID column
CREATE SEQUENCE IF NOT EXISTS users_id_seq;
ALTER TABLE users ALTER COLUMN id SET DEFAULT nextval('users_id_seq');
ALTER SEQUENCE users_id_seq OWNED BY users.id;
SELECT setval('users_id_seq', (SELECT COALESCE(MAX(id), 0) + 1 FROM users));

-- Verify the changes
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'users'
ORDER BY ordinal_position;
```

### Database Connection Setup

Since our endpoints reference a database connection, here's the complete setup:

```typescript
// src/lib/db.ts - Database connection setup
import { Pool } from "pg";

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl:
    process.env.NODE_ENV === "production"
      ? { rejectUnauthorized: false }
      : false,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

export async function query(text: string, params?: any[]) {
  const client = await pool.connect();
  try {
    const result = await client.query(text, params);
    return result;
  } catch (error) {
    console.error("Database query error:", error);
    throw error;
  } finally {
    client.release();
  }
}

// For Neon Database specifically (if using Neon)
// Alternative implementation:
/*
import { Pool } from '@neondatabase/serverless';

const pool = new Pool({ 
  connectionString: process.env.DATABASE_URL,
  ssl: true
});

export async function query(text: string, params?: any[]) {
  const client = await pool.connect();
  try {
    const result = await client.query(text, params);
    return result;
  } catch (error) {
    console.error('Neon database query error:', error);
    throw error;
  } finally {
    client.release();
  }
}
*/
```

---

## Environment Configuration

### Critical Environment Setup

We had to clean up conflicting Auth0 configurations and add missing variables.

#### Environment File Cleanup

**Problem**: Multiple Auth0 domains in `.env.local` causing conflicts.

**Solution**: Clean up and use only one consistent tenant:

```bash
# ❌ REMOVE these conflicting entries:
# AUTH0_ISSUER_BASE_URL=https://dev-xyz.us.auth0.com
# AUTH0_ISSUER_BASE_URL=https://prod-abc.us.auth0.com

# ✅ KEEP only one consistent set:
AUTH0_SECRET=your-32-character-secret
AUTH0_BASE_URL=http://localhost:3000
AUTH0_ISSUER_BASE_URL=https://dev-s2idqivfjwfrvd1i.us.auth0.com
AUTH0_CLIENT_ID=your-client-id
AUTH0_CLIENT_SECRET=your-client-secret

# Management API (ADD these if missing)
AUTH0_MGMT_CLIENT_ID=your-m2m-client-id
AUTH0_MGMT_CLIENT_SECRET=your-m2m-client-secret
AUTH0_DOMAIN=dev-s2idqivfjwfrvd1i.us.auth0.com

# Custom API Audience (CRITICAL)
AUTH0_AUDIENCE=https://api.vibecoder.com
```

#### Environment Variable Verification

Create this script to verify all required variables:

```javascript
// scripts/verify-env.js
const requiredVars = [
  "AUTH0_SECRET",
  "AUTH0_BASE_URL",
  "AUTH0_ISSUER_BASE_URL",
  "AUTH0_CLIENT_ID",
  "AUTH0_CLIENT_SECRET",
  "AUTH0_MGMT_CLIENT_ID",
  "AUTH0_MGMT_CLIENT_SECRET",
  "AUTH0_DOMAIN",
  "AUTH0_AUDIENCE",
];

console.log("🔍 Checking required Auth0 environment variables...\n");

const missing = [];
const present = [];

requiredVars.forEach((varName) => {
  if (process.env[varName]) {
    present.push(varName);
    console.log(`✅ ${varName}: ${process.env[varName].substring(0, 20)}...`);
  } else {
    missing.push(varName);
    console.log(`❌ ${varName}: MISSING`);
  }
});

console.log(
  `\n📊 Summary: ${present.length}/${requiredVars.length} variables present`
);

if (missing.length > 0) {
  console.log("\n🚨 Missing variables:", missing.join(", "));
  process.exit(1);
} else {
  console.log("\n🎉 All required environment variables are present!");
}
```

---

## Auth0 Configuration

### Step 1: Create Machine-to-Machine Application

1. Go to **Auth0 Dashboard > Applications**
2. Click **Create Application**
3. Choose **Machine to Machine Applications**
4. Select **Auth0 Management API**
5. Grant the following scopes:
   - `read:users`
   - `update:users`
   - `create:users`
   - `delete:users`
   - `read:user_idp_tokens`

### Step 2: Create Custom API (for Audience)

1. Go to **Auth0 Dashboard > APIs**
2. Click **Create API**
3. Set **Identifier** to: `https://api.yourdomain.com`
4. Leave **Signing Algorithm** as RS256

### Step 3: Create Auth0 Action for Custom Claims

1. Go to **Auth0 Dashboard > Actions > Library**
2. Click **Create Action > Login / Post Login**
3. Name it "Include App Metadata"
4. Use this code:

```javascript
exports.onExecutePostLogin = async (event, api) => {
  const namespace = "https://vibecoder.com/";

  if (event.user.app_metadata && event.user.app_metadata.roles) {
    console.log(
      "Adding custom claims for roles:",
      event.user.app_metadata.roles
    );

    // Add to both tokens for compatibility
    api.accessToken.setCustomClaim(
      `${namespace}roles`,
      event.user.app_metadata.roles
    );
    api.accessToken.setCustomClaim(
      `${namespace}app_metadata`,
      event.user.app_metadata
    );

    api.idToken.setCustomClaim(
      `${namespace}roles`,
      event.user.app_metadata.roles
    );
    api.idToken.setCustomClaim(
      `${namespace}app_metadata`,
      event.user.app_metadata
    );

    console.log("Custom claims added to both tokens");
  } else {
    console.log("No app_metadata.roles found for user");
  }
};
```

5. **Deploy** the Action
6. Go to **Actions > Flows > Login**
7. **Drag the Action** into the flow between Start and Complete
8. Click **Apply**

### Step 4: Set User App Metadata

1. Go to **Auth0 Dashboard > User Management > Users**
2. Find your admin user
3. Edit **app_metadata**:

```json
{
  "roles": ["admin"]
}
```

---

## Implementation Steps

### Step 1: Create Auth0 Management Client

```typescript
// src/lib/auth0-management.ts
import { ManagementClient } from "auth0";

export default async function getAuth0ManagementClient() {
  const management = new ManagementClient({
    domain: process.env.AUTH0_DOMAIN!,
    clientId: process.env.AUTH0_MGMT_CLIENT_ID!,
    clientSecret: process.env.AUTH0_MGMT_CLIENT_SECRET!,
    scope: "read:users update:users create:users delete:users",
  });

  return management;
}
```

### Step 2: Create Admin Auth Functions

```typescript
// src/lib/admin-auth.ts
export const isUserAdmin = (user: any, session?: any): boolean => {
  // First try to get custom claims from decoded tokens if session is provided
  if (session && session.tokenSet && session.tokenSet.idToken) {
    try {
      const parts = session.tokenSet.idToken.split(".");
      if (parts.length === 3) {
        const payload = JSON.parse(Buffer.from(parts[1], "base64").toString());
        const namespace = "https://vibecoder.com/";

        // Check for roles in the decoded token
        if (
          payload[`${namespace}roles`] &&
          Array.isArray(payload[`${namespace}roles`])
        ) {
          if (payload[`${namespace}roles`].includes("admin")) {
            console.log(
              "Admin access granted via decoded token roles for:",
              user.email
            );
            return true;
          }
        }
      }
    } catch (error) {
      console.log("Could not decode token for admin check:", error);
    }
  }

  // Additional fallback methods...
  return false;
};

export const logUserSession = (user: any, session?: any): void => {
  const newNamespace = "https://vibecoder.com/";
  let decodedClaims = {};

  // Try to decode token claims if session is provided
  if (session && session.tokenSet && session.tokenSet.idToken) {
    try {
      const parts = session.tokenSet.idToken.split(".");
      if (parts.length === 3) {
        const payload = JSON.parse(Buffer.from(parts[1], "base64").toString());
        decodedClaims = {
          new_namespace_roles: payload[`${newNamespace}roles`],
          new_namespace_app_metadata: payload[`${newNamespace}app_metadata`],
        };
      }
    } catch (error) {
      console.log("Could not decode token for logging:", error);
    }
  }

  console.log("User session:", {
    email: user.email,
    decoded_token_claims: decodedClaims,
  });
};
```

### Step 3: Create Admin API Endpoints

```typescript
// pages/api/admin/auth0/auth0-users.ts
export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  try {
    const session = await auth0.getSession(req);

    if (!session?.user) {
      return res.status(401).json({ error: "Not authenticated" });
    }

    // ✅ CRITICAL: Pass both user AND session
    logUserSession(session.user, session);

    if (!isUserAdmin(session.user, session)) {
      return res
        .status(403)
        .json({ error: "Forbidden: Admin access required" });
    }

    // Management API calls...
    const management = await getAuth0ManagementClient();
    const users = await management.users.getAll();

    res.status(200).json({ users });
  } catch (error) {
    console.error("Error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
}
```

---

## API Response Structure Fixes

### Critical Auth0 Management API Response Issue

**Problem**: Our API endpoints were failing because Auth0 Management API response structure was different than expected.

**Symptoms**:

- Admin pages showing "An unexpected error occurred while loading Auth0 users"
- 500 errors in console logs
- Cannot read property 'length' of undefined errors

**Root Cause**: Auth0 Management API returns `response.data.users`, not `response.users`.

### The Fix

#### Before (Broken):

```typescript
// ❌ WRONG - This causes "Cannot read property 'length' of undefined"
export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  try {
    const management = await getAuth0ManagementClient();
    const response = await management.users.getAll();

    // This fails because response.users is undefined
    const users = response.users || [];

    res.status(200).json({ users });
  } catch (error) {
    res.status(500).json({ error: "Internal server error" });
  }
}
```

#### After (Working):

```typescript
// ✅ CORRECT - Access response.data.users or use response directly
export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  try {
    const management = await getAuth0ManagementClient();
    const response = await management.users.getAll();

    // Auth0 Management API returns users directly in response
    const users = response || [];
    // OR if it's nested: const users = response.data?.users || [];

    res.status(200).json({ users });
  } catch (error) {
    console.error("Auth0 Management API Error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
}
```

### Fixed Endpoints

#### 1. Auth0 Users Endpoint

```typescript
// pages/api/admin/auth0/auth0-users.ts - WORKING VERSION
import { NextApiRequest, NextApiResponse } from "next";
import { auth0 } from "../../../../src/lib/auth0";
import { isUserAdmin, logUserSession } from "../../../../src/lib/admin-auth";
import getAuth0ManagementClient from "../../../../src/lib/auth0-management";

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  try {
    const session = await auth0.getSession(req);

    if (!session?.user) {
      return res.status(401).json({ error: "Not authenticated" });
    }

    // ✅ CRITICAL: Pass both user AND session
    logUserSession(session.user, session);

    if (!isUserAdmin(session.user, session)) {
      return res
        .status(403)
        .json({ error: "Forbidden: Admin access required" });
    }

    console.log("🔍 Fetching Auth0 users...");
    const management = await getAuth0ManagementClient();
    const response = await management.users.getAll();

    // ✅ FIXED: Handle response structure correctly
    const users = response || [];

    console.log(`✅ Successfully fetched ${users.length} Auth0 users`);
    res.status(200).json({ users });
  } catch (error) {
    console.error("❌ Error fetching Auth0 users:", error);
    res.status(500).json({
      error: "Internal server error",
      details:
        process.env.NODE_ENV === "development" ? error.message : undefined,
    });
  }
}
```

#### 2. Database Sync Endpoint

```typescript
// pages/api/admin/auth0/sync.ts - WORKING VERSION
import { NextApiRequest, NextApiResponse } from "next";
import { auth0 } from "../../../../src/lib/auth0";
import { isUserAdmin, logUserSession } from "../../../../src/lib/admin-auth";
import getAuth0ManagementClient from "../../../../src/lib/auth0-management";
import { query } from "../../../../src/lib/db";

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  try {
    const session = await auth0.getSession(req);

    if (!session?.user) {
      return res.status(401).json({ error: "Not authenticated" });
    }

    // ✅ CRITICAL: Pass both user AND session
    logUserSession(session.user, session);

    if (!isUserAdmin(session.user, session)) {
      return res
        .status(403)
        .json({ error: "Forbidden: Admin access required" });
    }

    console.log("🔍 Starting Auth0 to database sync...");
    const management = await getAuth0ManagementClient();
    const response = await management.users.getAll();

    // ✅ FIXED: Handle response structure correctly
    const auth0Users = response || [];

    console.log(`📥 Found ${auth0Users.length} users in Auth0`);

    let syncResults = {
      created: 0,
      updated: 0,
      errors: [],
    };

    for (const user of auth0Users) {
      try {
        // Check if user exists in database
        const existingUser = await query(
          "SELECT id, email FROM users WHERE auth0_id = $1",
          [user.user_id]
        );

        if (existingUser.rows.length === 0) {
          // Check for email conflicts before creating
          const emailConflict = await query(
            "SELECT id, auth0_id FROM users WHERE email = $1",
            [user.email]
          );

          if (emailConflict.rows.length > 0) {
            // Email exists with different auth0_id - log conflict
            console.warn(
              `⚠️ Email conflict: ${user.email} exists with different auth0_id`
            );
            syncResults.errors.push(
              `${user.email}: Email exists with different auth0_id`
            );
            continue;
          }

          // Create new user
          await query(
            "INSERT INTO users (auth0_id, email, name, created_at, updated_at) VALUES ($1, $2, $3, NOW(), NOW())",
            [user.user_id, user.email, user.name || user.email]
          );
          syncResults.created++;
          console.log(`✅ Created user: ${user.email}`);
        } else {
          // Update existing user
          await query(
            "UPDATE users SET email = $1, name = $2, updated_at = NOW() WHERE auth0_id = $3",
            [user.email, user.name || user.email, user.user_id]
          );
          syncResults.updated++;
          console.log(`📝 Updated user: ${user.email}`);
        }
      } catch (userError) {
        console.error(`❌ Error syncing user ${user.email}:`, userError);
        syncResults.errors.push(`${user.email}: ${userError.message}`);
      }
    }

    console.log("✅ Sync completed:", syncResults);
    res.status(200).json({
      message: "Sync completed successfully",
      results: syncResults,
    });
  } catch (error) {
    console.error("❌ Error during sync:", error);
    res.status(500).json({
      error: "Internal server error",
      details:
        process.env.NODE_ENV === "development" ? error.message : undefined,
    });
  }
}
```

---

## Complete Working Implementations

### Final Admin Auth Functions

Here's the complete, working implementation of the admin authentication functions:

```typescript
// src/lib/admin-auth.ts - FINAL WORKING VERSION
import jwt from "jsonwebtoken";

export const isUserAdmin = (user: any, session?: any): boolean => {
  console.log("isUserAdmin called with:", {
    hasUser: !!user,
    hasSession: !!session,
    userEmail: user?.email,
    sessionKeys: session ? Object.keys(session) : [],
  });

  // Method 1: Try to get custom claims from decoded tokens if session is provided
  if (session && session.tokenSet && session.tokenSet.idToken) {
    try {
      console.log("🔍 Attempting to decode ID token...");
      const parts = session.tokenSet.idToken.split(".");
      if (parts.length === 3) {
        const payload = JSON.parse(Buffer.from(parts[1], "base64").toString());
        console.log("🔍 Decoded token payload keys:", Object.keys(payload));

        // Check both possible namespaces
        const namespaces = [
          `${process.env.AUTH0_AUDIENCE}/`,
          "https://api.vibecoder.com/",
          "https://vibecoder.com/",
        ];

        for (const namespace of namespaces) {
          const roles = payload[`${namespace}roles`];
          if (roles && Array.isArray(roles) && roles.includes("admin")) {
            console.log(
              `✅ Admin access granted via token roles (${namespace}) for:`,
              user.email
            );
            return true;
          }
        }

        // Also check app_metadata
        for (const namespace of namespaces) {
          const appMetadata = payload[`${namespace}app_metadata`];
          if (
            appMetadata?.roles &&
            Array.isArray(appMetadata.roles) &&
            appMetadata.roles.includes("admin")
          ) {
            console.log(
              `✅ Admin access granted via token app_metadata (${namespace}) for:`,
              user.email
            );
            return true;
          }
        }
      }
    } catch (error) {
      console.log("❌ Could not decode token for admin check:", error);
    }
  }

  // Method 2: Check for namespace roles directly in user object (fallback)
  const namespacedRoles =
    user[`${process.env.AUTH0_AUDIENCE}/roles`] ||
    user["https://api.vibecoder.com/roles"] ||
    user["https://vibecoder.com/roles"];
  if (namespacedRoles && Array.isArray(namespacedRoles)) {
    if (namespacedRoles.includes("admin")) {
      console.log(
        "✅ Admin access granted via user namespace roles for:",
        user.email
      );
      return true;
    }
  }

  // Method 3: Check for namespace app_metadata directly in user object
  const namespacedAppMetadata =
    user[`${process.env.AUTH0_AUDIENCE}/app_metadata`] ||
    user["https://api.vibecoder.com/app_metadata"] ||
    user["https://vibecoder.com/app_metadata"];
  if (
    namespacedAppMetadata?.roles &&
    Array.isArray(namespacedAppMetadata.roles)
  ) {
    if (namespacedAppMetadata.roles.includes("admin")) {
      console.log(
        "✅ Admin access granted via user namespace app_metadata for:",
        user.email
      );
      return true;
    }
  }

  // Method 4: Email fallback (temporary - should be removed in production)
  const adminEmails = [
    "your-admin@example.com", // Replace with actual admin emails
  ];

  if (adminEmails.includes(user?.email)) {
    console.log("⚠️ Admin access granted via email fallback for:", user.email);
    return true;
  }

  console.log("❌ Admin access denied for:", user.email);
  return false;
};

export const logUserSession = (user: any, session?: any): void => {
  let decodedClaims = {};

  // Try to decode token claims if session is provided
  if (session && session.tokenSet && session.tokenSet.idToken) {
    try {
      const parts = session.tokenSet.idToken.split(".");
      if (parts.length === 3) {
        const payload = JSON.parse(Buffer.from(parts[1], "base64").toString());

        // Check all possible namespaces
        const namespaces = [
          `${process.env.AUTH0_AUDIENCE}/`,
          "https://api.vibecoder.com/",
          "https://vibecoder.com/",
        ];

        namespaces.forEach((namespace) => {
          if (
            payload[`${namespace}roles`] ||
            payload[`${namespace}app_metadata`]
          ) {
            decodedClaims[`${namespace}roles`] = payload[`${namespace}roles`];
            decodedClaims[`${namespace}app_metadata`] =
              payload[`${namespace}app_metadata`];
          }
        });
      }
    } catch (error) {
      console.log("❌ Could not decode token for logging:", error);
    }
  } else {
    console.log("🔍 Session/tokenSet/idToken not available for decoding");
  }

  console.log("User session:", {
    email: user.email,
    decoded_token_claims: decodedClaims,
    session_available: !!session,
    tokenSet_available: !!session?.tokenSet,
    idToken_available: !!session?.tokenSet?.idToken,
  });
};
```

### Auth0 SDK Configuration

```typescript
// src/lib/auth0.ts - UPDATED WITH AUDIENCE
import { initAuth0 } from "@auth0/nextjs-auth0";

const auth0Instance = initAuth0({
  secret: process.env.AUTH0_SECRET!,
  issuerBaseURL: process.env.AUTH0_ISSUER_BASE_URL!,
  baseURL: process.env.AUTH0_BASE_URL!,
  clientID: process.env.AUTH0_CLIENT_ID!,
  clientSecret: process.env.AUTH0_CLIENT_SECRET!,
  authorizationParams: {
    // ✅ CRITICAL: Include audience for custom claims
    audience: process.env.AUTH0_AUDIENCE,
    scope: "openid profile email",
  },
});

export const auth0 = auth0Instance;
```

### Database Users Endpoint

```typescript
// pages/api/admin/auth0/db-users.ts - WORKING VERSION
import { NextApiRequest, NextApiResponse } from "next";
import { auth0 } from "../../../../src/lib/auth0";
import { isUserAdmin, logUserSession } from "../../../../src/lib/admin-auth";
import { query } from "../../../../src/lib/db";

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  try {
    const session = await auth0.getSession(req);

    if (!session?.user) {
      return res.status(401).json({ error: "Not authenticated" });
    }

    // ✅ CRITICAL: Pass both user AND session
    logUserSession(session.user, session);

    if (!isUserAdmin(session.user, session)) {
      return res
        .status(403)
        .json({ error: "Forbidden: Admin access required" });
    }

    console.log("🔍 Fetching database users...");

    // ✅ FIXED: Use existing columns only
    const result = await query(
      "SELECT id, auth0_id, email, name, created_at, updated_at FROM users ORDER BY created_at DESC"
    );

    const users = result.rows;
    console.log(`✅ Successfully fetched ${users.length} database users`);

    res.status(200).json({ users });
  } catch (error) {
    console.error("❌ Error fetching database users:", error);
    res.status(500).json({
      error: "Internal server error",
      details:
        process.env.NODE_ENV === "development" ? error.message : undefined,
    });
  }
}
```

---

## Common Issues and Debugging

### Issue 1: "Forbidden: Admin access required"

**Symptoms:**

- Admin page shows access denied
- Console shows "An unexpected error occurred while loading Auth0 users"

**Common Causes:**

1. Auth0 Action not deployed
2. Auth0 Action not in login flow
3. User missing app_metadata
4. Environment variables incorrect

**Debugging Steps:**

1. Check Auth0 Dashboard > Actions > Library (should show "DEPLOYED")
2. Check Auth0 Dashboard > Actions > Flows > Login (Action should be visible)
3. Check user's app_metadata in Auth0 Dashboard
4. Verify environment variables

### Issue 2: Missing Custom Claims

**Symptoms:**

- Auth0 Action appears to be working
- Logs show `decoded_token_claims: {}`
- User has correct app_metadata

**Debugging Steps:**

Create this debug endpoint:

```typescript
// pages/api/debug-session-structure.ts
export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const session = await auth0.getSession(req);

  if (!session?.user) {
    return res.status(401).json({ error: "Not authenticated" });
  }

  // Deep inspection of session structure
  const sessionInspection = {
    session_exists: !!session,
    tokenSet_exists: !!session.tokenSet,
    idToken_exists: !!(session.tokenSet && session.tokenSet.idToken),
    idToken_length:
      session.tokenSet && session.tokenSet.idToken
        ? session.tokenSet.idToken.length
        : 0,
  };

  // Try token decoding with detailed error handling
  let tokenDecodeResult = null;
  if (session && session.tokenSet && session.tokenSet.idToken) {
    try {
      console.log("🔍 DEBUG: Attempting token decode...");
      console.log("🔍 DEBUG: Token length:", session.tokenSet.idToken.length);

      const parts = session.tokenSet.idToken.split(".");
      console.log("🔍 DEBUG: Token parts:", parts.length);

      if (parts.length === 3) {
        const payload = JSON.parse(Buffer.from(parts[1], "base64").toString());
        console.log("🔍 DEBUG: Payload keys:", Object.keys(payload));

        tokenDecodeResult = {
          success: true,
          payload_keys: Object.keys(payload),
          vibecoder_roles: payload["https://vibecoder.com/roles"],
          vibecoder_app_metadata: payload["https://vibecoder.com/app_metadata"],
        };
      }
    } catch (error) {
      tokenDecodeResult = { success: false, error: error.message };
    }
  }

  return res.status(200).json({
    session_inspection: sessionInspection,
    token_decode_result: tokenDecodeResult,
  });
}
```

---

## The Critical Bug We Discovered

### The Problem

We discovered a critical bug where admin endpoints would show:

```
🔍 Session/tokenSet/idToken not available for decoding
Admin access granted via email fallback for: user@example.com
```

While test endpoints showed:

```
decoded_token_claims: {
  new_namespace_roles: ['admin'],
  new_namespace_app_metadata: { roles: ['admin'] }
}
Admin access granted via decoded token roles for: user@example.com
```

### The Root Cause

**Function parameter mismatch!** Admin endpoints were calling:

```typescript
// ❌ WRONG - Missing session parameter
logUserSession(session.user);
isUserAdmin(session.user, session); // Inconsistent!
```

But the function signatures expected:

```typescript
export const logUserSession = (user: any, session?: any): void => {};
export const isUserAdmin = (user: any, session?: any): boolean => {};
```

### The Solution

**Always pass both parameters consistently:**

```typescript
// ✅ CORRECT - Consistent parameter passing
logUserSession(session.user, session);
isUserAdmin(session.user, session);
```

### How to Find This Bug

1. **Check function signatures** vs actual calls:

```bash
grep -r "logUserSession(" --include="*.ts" pages/api/admin/
grep -r "isUserAdmin(" --include="*.ts" pages/api/admin/
```

2. **Compare working vs non-working endpoints** side by side

3. **Create debug endpoints** that mirror the problematic ones

4. **Look for inconsistent logging** between similar endpoints

---

## Testing and Verification

### Debug Endpoints to Create

```typescript
// 1. Test admin authentication
// pages/api/test-admin-auth.ts
export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const session = await auth0.getSession(req);

  if (!session?.user) {
    return res.status(401).json({ error: "Not authenticated" });
  }

  logUserSession(session.user, session);

  const isAdminWithSession = isUserAdmin(session.user, session);
  const isAdminWithoutSession = isUserAdmin(session.user);

  return res.status(200).json({
    message: "Admin Auth Test",
    user_email: session.user.email,
    admin_check_results: {
      with_session: isAdminWithSession,
      without_session: isAdminWithoutSession,
    },
    success: isAdminWithSession,
  });
}
```

```typescript
// 2. Debug raw token structure
// pages/api/debug-tokenset.ts
export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const session = await auth0.getSession(req);

  if (!session?.user) {
    return res.status(401).json({ error: "Not authenticated" });
  }

  const tokenSet = session.tokenSet;
  let decodedIdToken = null;

  if (tokenSet?.idToken) {
    try {
      const parts = tokenSet.idToken.split(".");
      if (parts.length === 3) {
        const payload = JSON.parse(Buffer.from(parts[1], "base64").toString());
        decodedIdToken = payload;
      }
    } catch (e) {
      console.log("Error decoding ID token:", e);
    }
  }

  const customClaims = {};
  if (decodedIdToken) {
    Object.keys(decodedIdToken).forEach((key) => {
      if (
        key.includes("vibecoder") ||
        key.includes("roles") ||
        key.includes("app_metadata")
      ) {
        customClaims[key] = decodedIdToken[key];
      }
    });
  }

  return res.status(200).json({
    message: "TokenSet Debug",
    tokenSet_info: {
      has_id_token: !!tokenSet?.idToken,
      has_access_token: !!tokenSet?.accessToken,
      id_token_length: tokenSet?.idToken?.length || 0,
      access_token_length: tokenSet?.accessToken?.length || 0,
    },
    decoded_tokens: {
      id_token_payload: decodedIdToken,
    },
    custom_claims_found: customClaims,
  });
}
```

### Expected Results After Fix

**Admin endpoints should show:**

```
User session: {
  email: 'user@example.com',
  decoded_token_claims: {
    new_namespace_roles: ['admin'],
    new_namespace_app_metadata: { roles: ['admin'] }
  }
}
Admin access granted via decoded token roles for: user@example.com
```

**Test endpoint should show:**

```json
{
  "admin_check_results": {
    "with_session": true,
    "without_session": false
  },
  "success": true
}
```

### Additional Debug Endpoints That Helped Us

These debug endpoints were critical in discovering the session parameter bug:

#### 1. Session Structure Debug

```typescript
// pages/api/debug-session-structure.ts
import { NextApiRequest, NextApiResponse } from "next";
import { auth0 } from "../src/lib/auth0";

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const session = await auth0.getSession(req);

  if (!session?.user) {
    return res.status(401).json({ error: "Not authenticated" });
  }

  // Deep inspection of session structure
  const sessionInspection = {
    session_exists: !!session,
    session_keys: session ? Object.keys(session) : [],
    tokenSet_exists: !!session.tokenSet,
    tokenSet_keys: session.tokenSet ? Object.keys(session.tokenSet) : [],
    idToken_exists: !!(session.tokenSet && session.tokenSet.idToken),
    idToken_length:
      session.tokenSet && session.tokenSet.idToken
        ? session.tokenSet.idToken.length
        : 0,
    accessToken_exists: !!(session.tokenSet && session.tokenSet.accessToken),
    accessToken_length:
      session.tokenSet && session.tokenSet.accessToken
        ? session.tokenSet.accessToken.length
        : 0,
  };

  // Try token decoding with detailed error handling
  let tokenDecodeResult = null;
  if (session && session.tokenSet && session.tokenSet.idToken) {
    try {
      const parts = session.tokenSet.idToken.split(".");
      if (parts.length === 3) {
        const payload = JSON.parse(Buffer.from(parts[1], "base64").toString());

        // Look for custom claims
        const customClaims = {};
        Object.keys(payload).forEach((key) => {
          if (
            key.includes("vibecoder") ||
            key.includes("roles") ||
            key.includes("app_metadata")
          ) {
            customClaims[key] = payload[key];
          }
        });

        tokenDecodeResult = {
          success: true,
          payload_keys: Object.keys(payload),
          custom_claims: customClaims,
          all_claims: payload,
        };
      }
    } catch (error) {
      tokenDecodeResult = { success: false, error: error.message };
    }
  }

  return res.status(200).json({
    message: "Session Structure Debug",
    user_email: session.user.email,
    session_inspection: sessionInspection,
    token_decode_result: tokenDecodeResult,
  });
}
```

#### 2. Admin Auth Comparison Test

```typescript
// pages/api/test-admin-auth.ts
import { NextApiRequest, NextApiResponse } from "next";
import { auth0 } from "../src/lib/auth0";
import { isUserAdmin, logUserSession } from "../src/lib/admin-auth";

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const session = await auth0.getSession(req);

  if (!session?.user) {
    return res.status(401).json({ error: "Not authenticated" });
  }

  console.log("\n=== ADMIN AUTH COMPARISON TEST ===");

  // Test with session parameter
  console.log("\n1. Testing WITH session parameter:");
  logUserSession(session.user, session);
  const isAdminWithSession = isUserAdmin(session.user, session);

  // Test without session parameter
  console.log("\n2. Testing WITHOUT session parameter:");
  logUserSession(session.user);
  const isAdminWithoutSession = isUserAdmin(session.user);

  console.log("\n=== COMPARISON RESULTS ===");
  console.log("With session:", isAdminWithSession);
  console.log("Without session:", isAdminWithoutSession);

  return res.status(200).json({
    message: "Admin Auth Comparison Test",
    user_email: session.user.email,
    admin_check_results: {
      with_session: isAdminWithSession,
      without_session: isAdminWithoutSession,
      difference: isAdminWithSession !== isAdminWithoutSession,
    },
    success: isAdminWithSession,
  });
}
```

#### 3. Token Deep Inspection

```typescript
// pages/api/debug-token-deep.ts
import { NextApiRequest, NextApiResponse } from "next";
import { auth0 } from "../src/lib/auth0";

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const session = await auth0.getSession(req);

  if (!session?.user) {
    return res.status(401).json({ error: "Not authenticated" });
  }

  const response = {
    message: "Deep Token Inspection",
    user_email: session.user.email,
    session_structure: {
      has_session: !!session,
      has_tokenSet: !!session.tokenSet,
      has_idToken: !!session.tokenSet?.idToken,
      has_accessToken: !!session.tokenSet?.accessToken,
    },
    tokens: {},
  };

  // Decode ID Token
  if (session.tokenSet?.idToken) {
    try {
      const parts = session.tokenSet.idToken.split(".");
      const header = JSON.parse(Buffer.from(parts[0], "base64").toString());
      const payload = JSON.parse(Buffer.from(parts[1], "base64").toString());

      response.tokens.idToken = {
        header,
        payload,
        custom_claims: Object.keys(payload)
          .filter(
            (key) =>
              key.includes("vibecoder") ||
              key.includes("roles") ||
              key.includes("app_metadata")
          )
          .reduce((acc, key) => {
            acc[key] = payload[key];
            return acc;
          }, {}),
      };
    } catch (error) {
      response.tokens.idToken = { error: error.message };
    }
  }

  // Decode Access Token
  if (session.tokenSet?.accessToken) {
    try {
      const parts = session.tokenSet.accessToken.split(".");
      const header = JSON.parse(Buffer.from(parts[0], "base64").toString());
      const payload = JSON.parse(Buffer.from(parts[1], "base64").toString());

      response.tokens.accessToken = {
        header,
        payload,
        custom_claims: Object.keys(payload)
          .filter(
            (key) =>
              key.includes("vibecoder") ||
              key.includes("roles") ||
              key.includes("app_metadata")
          )
          .reduce((acc, key) => {
            acc[key] = payload[key];
            return acc;
          }, {}),
      };
    } catch (error) {
      response.tokens.accessToken = { error: error.message };
    }
  }

  return res.status(200).json(response);
}
```

#### How These Debug Endpoints Revealed The Bug

1. **Session Structure Debug** showed that both working and broken endpoints had identical session structures
2. **Admin Auth Comparison** revealed that `isUserAdmin(user, session)` returned `true` while `isUserAdmin(user)` returned `false`
3. **Token Deep Inspection** confirmed that custom claims were present in tokens
4. **Side-by-side logging comparison** showed:
   - Working endpoints: "Admin access granted via decoded token roles"
   - Broken endpoints: "Admin access granted via email fallback"

This led us to discover that the broken endpoints were missing the session parameter in their function calls!

---

## UI Integration and Frontend Setup

### Frontend Component Integration

Your admin dashboard frontend needs to call the correct endpoints and handle the response data properly.

#### Example Admin Dashboard Component

```typescript
// components/admin/AuthIntegrationHub.tsx
import { useEffect, useState } from "react";

interface User {
  id: number;
  email: string;
  name: string;
  created_at: string;
  updated_at: string;
  auth0_id?: string;
}

interface SyncStatus {
  inSync: boolean;
  message: string;
  lastSync?: string;
}

export default function AuthIntegrationHub() {
  const [auth0Users, setAuth0Users] = useState<User[]>([]);
  const [dbUsers, setDbUsers] = useState<User[]>([]);
  const [syncStatus, setSyncStatus] = useState<SyncStatus>({
    inSync: false,
    message: "Checking...",
  });
  const [loading, setLoading] = useState(true);
  const [syncing, setSyncing] = useState(false);

  const fetchAuth0Users = async () => {
    try {
      const response = await fetch("/api/admin/auth0/auth0-users");
      if (!response.ok) throw new Error("Failed to fetch Auth0 users");
      const data = await response.json();
      setAuth0Users(data.users || []);
    } catch (error) {
      console.error("Error fetching Auth0 users:", error);
    }
  };

  const fetchDbUsers = async () => {
    try {
      const response = await fetch("/api/admin/auth0/db-users");
      if (!response.ok) throw new Error("Failed to fetch database users");
      const data = await response.json();
      setDbUsers(data.users || []);
    } catch (error) {
      console.error("Error fetching database users:", error);
    }
  };

  const performSync = async () => {
    setSyncing(true);
    try {
      const response = await fetch("/api/admin/auth0/sync", { method: "POST" });
      if (!response.ok) throw new Error("Sync failed");

      const result = await response.json();
      console.log("Sync completed:", result);

      // Refresh data after sync
      await Promise.all([fetchAuth0Users(), fetchDbUsers()]);

      setSyncStatus({
        inSync: true,
        message: `Sync completed: ${result.results.created} created, ${result.results.updated} updated`,
        lastSync: new Date().toISOString(),
      });
    } catch (error) {
      console.error("Sync error:", error);
      setSyncStatus({
        inSync: false,
        message: "Sync failed: " + error.message,
      });
    } finally {
      setSyncing(false);
    }
  };

  useEffect(() => {
    const loadData = async () => {
      setLoading(true);
      await Promise.all([fetchAuth0Users(), fetchDbUsers()]);

      // Check sync status
      const auth0Count = auth0Users.length;
      const dbCount = dbUsers.length;
      setSyncStatus({
        inSync: auth0Count === dbCount,
        message:
          auth0Count === dbCount
            ? "Auth0 users are synchronized with your database"
            : `Sync needed: ${auth0Count} Auth0 users, ${dbCount} database users`,
      });

      setLoading(false);
    };

    loadData();
  }, []);

  if (loading) {
    return <div>Loading Auth0 integration data...</div>;
  }

  return (
    <div className="auth-integration-hub">
      <h2>Auth0 Integration Hub</h2>

      {/* Sync Status */}
      <div
        className={`sync-status ${syncStatus.inSync ? "success" : "warning"}`}
      >
        <p>{syncStatus.message}</p>
        {syncStatus.lastSync && (
          <p>Last sync: {new Date(syncStatus.lastSync).toLocaleString()}</p>
        )}
      </div>

      {/* Sync Button */}
      <button onClick={performSync} disabled={syncing}>
        {syncing ? "Syncing..." : "Sync Now"}
      </button>

      {/* User Counts */}
      <div className="user-counts">
        <div>Auth0 Users: {auth0Users.length}</div>
        <div>Database Users: {dbUsers.length}</div>
      </div>

      {/* Users Table */}
      <div className="users-table">
        <h3>Auth0 Users</h3>
        <table>
          <thead>
            <tr>
              <th>Email</th>
              <th>Name</th>
              <th>Auth0 ID</th>
              <th>Created</th>
            </tr>
          </thead>
          <tbody>
            {auth0Users.map((user) => (
              <tr key={user.id}>
                <td>{user.email}</td>
                <td>{user.name}</td>
                <td>{user.auth0_id}</td>
                <td>{new Date(user.created_at).toLocaleDateString()}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
```

### Frontend Integration Checklist

- [ ] Frontend calls `/api/admin/auth0/auth0-users` for Auth0 user data
- [ ] Frontend calls `/api/admin/auth0/db-users` for database user data
- [ ] Frontend calls `/api/admin/auth0/sync` (POST) to trigger synchronization
- [ ] UI updates user counts after successful sync
- [ ] Error handling displays meaningful messages to admin users
- [ ] Loading states prevent multiple simultaneous sync operations

---

## Security Considerations

### Production Security Requirements

#### 1. Remove Email Fallback Authentication

**CRITICAL**: The email fallback in `isUserAdmin()` must be removed in production:

```typescript
// ❌ REMOVE THIS IN PRODUCTION
const adminEmails = ["your-admin@example.com"];

if (adminEmails.includes(user?.email)) {
  console.log("⚠️ Admin access granted via email fallback for:", user.email);
  return true;
}
```

**Replacement**: Use only role-based authentication via Auth0 tokens.

#### 2. Secure or Remove Debug Endpoints

Debug endpoints should be secured or removed in production:

```typescript
// Option 1: Remove debug endpoints entirely
// Delete these files in production:
// - pages/api/debug-session-structure.ts
// - pages/api/debug-tokenset.ts
// - pages/api/debug-token-deep.ts
// - pages/api/test-admin-auth.ts

// Option 2: Secure debug endpoints (require admin access)
export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  // Add this to all debug endpoints
  if (process.env.NODE_ENV === "production") {
    return res.status(404).json({ error: "Not found" });
  }

  const session = await auth0.getSession(req);
  if (!session?.user) {
    return res.status(401).json({ error: "Not authenticated" });
  }

  if (!isUserAdmin(session.user, session)) {
    return res.status(403).json({ error: "Forbidden: Admin access required" });
  }

  // Debug functionality here...
}
```

#### 3. Rate Limiting Implementation

Add rate limiting to prevent abuse:

```typescript
// src/lib/rate-limit.ts
interface RateLimitEntry {
  count: number;
  resetTime: number;
}

const rateLimitMap = new Map<string, RateLimitEntry>();

export function checkRateLimit(
  identifier: string,
  maxRequests = 10,
  windowMs = 60000
): boolean {
  const now = Date.now();
  const key = identifier;

  const entry = rateLimitMap.get(key);

  if (!entry || now > entry.resetTime) {
    rateLimitMap.set(key, { count: 1, resetTime: now + windowMs });
    return true;
  }

  if (entry.count >= maxRequests) {
    return false;
  }

  entry.count++;
  return true;
}

// Usage in API endpoints:
export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const clientIp =
    req.headers["x-forwarded-for"] || req.connection.remoteAddress;

  if (!checkRateLimit(`admin-${clientIp}`)) {
    return res.status(429).json({ error: "Rate limit exceeded" });
  }

  // Rest of endpoint logic...
}
```

#### 4. Environment Security

```bash
# Production environment security
AUTH0_SECRET=<32-character-random-string>  # Generate new for production
AUTH0_MGMT_CLIENT_SECRET=<secure-secret>   # Keep secret secure
DATABASE_URL=<connection-string-with-ssl>  # Use SSL in production

# Remove development URLs
# AUTH0_BASE_URL=http://localhost:3000     # Remove this
AUTH0_BASE_URL=https://yourdomain.com      # Use production URL
```

---

## Token Lifetime and Session Management

### Token Refresh Considerations

The Auth0 Next.js SDK automatically handles token refresh, but consider these points:

#### 1. Token Expiration Testing

```typescript
// Test token expiration and refresh
// Add this to your testing checklist:

// 1. Set short token lifetime in Auth0 Dashboard (e.g., 5 minutes)
// 2. Login and wait for token to expire
// 3. Verify that API calls still work (SDK should refresh automatically)
// 4. Check that custom claims are still present after refresh

// Debug endpoint to check token expiration:
export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const session = await auth0.getSession(req);

  if (!session?.tokenSet?.idToken) {
    return res.status(401).json({ error: "No token available" });
  }

  try {
    const decoded = jwt.decode(session.tokenSet.idToken, { complete: true });
    const now = Math.floor(Date.now() / 1000);

    return res.json({
      issued_at: decoded.payload.iat,
      expires_at: decoded.payload.exp,
      current_time: now,
      expires_in_seconds: decoded.payload.exp - now,
      is_expired: decoded.payload.exp < now,
    });
  } catch (error) {
    return res.status(500).json({ error: "Token decode failed" });
  }
}
```

#### 2. Long-Running Sessions

For admin users who may have long-running sessions:

- Set appropriate token lifetimes (e.g., 8 hours for admin tokens)
- Consider implementing session activity tracking
- Provide clear feedback when re-authentication is needed

#### 3. Session Storage Security

```typescript
// Consider session storage security in production
const auth0Instance = initAuth0({
  // ... other config
  session: {
    cookie: {
      secure: process.env.NODE_ENV === "production", // HTTPS only in production
      sameSite: "lax",
      httpOnly: true,
      maxAge: 8 * 60 * 60, // 8 hours
    },
  },
});
```

---

## Production Checklist

### Database Schema Verification

- [ ] `auth0_id` column exists in users table with UNIQUE constraint
- [ ] ID column auto-increment sequence is properly configured
- [ ] No references to non-existent "role" column in queries
- [ ] Database migration scripts tested and documented

### Auth0 Dashboard Verification

- [ ] Machine-to-Machine app created with Management API access
- [ ] Custom API created with correct audience (`https://api.yourdomain.com`)
- [ ] Auth0 Action deployed and shows "DEPLOYED" status in Library
- [ ] Auth0 Action added to Login flow (visible in Actions > Flows > Login)
- [ ] Admin users have app_metadata with `{"roles": ["admin"]}`
- [ ] Test login shows Action executing in Auth0 logs

### Environment Variables

- [ ] All required variables set in production environment
- [ ] `AUTH0_AUDIENCE` matches custom API identifier exactly
- [ ] Management API credentials are for correct tenant (DEV/PROD)
- [ ] No conflicting Auth0 domains in environment file
- [ ] Environment verification script passes

### Code Implementation

- [ ] **CRITICAL**: All admin function calls include session parameter
- [ ] API endpoints handle `response` vs `response.data.users` correctly
- [ ] Token decoding handles errors gracefully with try/catch
- [ ] Logging shows "decoded token roles" not "email fallback" for admin access
- [ ] Debug endpoints removed or properly secured for production

### Function Parameter Audit

Run these commands to verify all calls are correct:

```bash
# Check all admin function calls
grep -r "logUserSession(" --include="*.ts" pages/api/admin/
grep -r "isUserAdmin(" --include="*.ts" pages/api/admin/

# Look for missing session parameters:
# ❌ BAD: logUserSession(session.user)
# ❌ BAD: isUserAdmin(session.user)
# ✅ GOOD: logUserSession(session.user, session)
# ✅ GOOD: isUserAdmin(session.user, session)
```

### Testing Steps

1. **Database verification**:

   - Run schema verification queries
   - Test user creation/sync functionality
   - Verify no "role column" errors

2. **Fresh login** after Auth0 changes:

   - Logout completely from application
   - Clear browser cache/cookies
   - Login again to get fresh tokens

3. **Admin access verification**:

   - Check admin pages load without errors
   - Verify logging shows "decoded token roles" not "email fallback"
   - Test Auth0 user management functions

4. **Token verification**:

   - Use debug endpoints to verify custom claims present
   - Check both ID and access tokens contain namespace claims
   - Verify Auth0 Action logs show claims being added

5. **API response verification**:
   - Test Auth0 users endpoint returns data correctly
   - Test sync functionality works without errors
   - Verify proper error handling for API failures

### Critical Bug Prevention

- [ ] **Session Parameter Rule**: Every call to `isUserAdmin()` and `logUserSession()` includes session parameter
- [ ] **Response Structure**: All Auth0 Management API calls handle response structure correctly
- [ ] **Environment Conflicts**: Only one Auth0 tenant configuration in environment
- [ ] **Database Schema**: All required columns exist and no invalid column references

### Security and Production Readiness

- [ ] **Email Fallback Removed**: No hardcoded admin emails in production code
- [ ] **Debug Endpoints**: Secured or removed in production environment
- [ ] **Rate Limiting**: Implemented for admin API endpoints
- [ ] **Environment Security**: Production secrets properly configured
- [ ] **Token Refresh**: Tested with short token lifetimes
- [ ] **Session Security**: Secure cookies enabled for production
- [ ] **HTTPS Only**: All production URLs use HTTPS
- [ ] **Database SSL**: Production database connections use SSL

### Frontend Integration

- [ ] **API Endpoints**: Frontend correctly calls all Auth0 admin endpoints
- [ ] **Error Handling**: UI displays meaningful error messages
- [ ] **Loading States**: Prevents multiple simultaneous operations
- [ ] **Real-time Updates**: UI refreshes after sync operations
- [ ] **User Feedback**: Clear indication of sync status and results

### Error Handling and Monitoring

- [ ] **Sync Conflicts**: Email conflicts properly detected and logged
- [ ] **Database Errors**: Connection issues handled gracefully
- [ ] **Auth0 API Errors**: Management API failures properly caught
- [ ] **Token Decode Errors**: Invalid tokens handled without crashes
- [ ] **Production Logging**: Appropriate log levels for production

---

## Troubleshooting Quick Reference

| Symptom                                  | Likely Cause                  | Solution                         |
| ---------------------------------------- | ----------------------------- | -------------------------------- |
| "Forbidden: Admin access required"       | Action not deployed/in flow   | Check Auth0 Dashboard Actions    |
| `decoded_token_claims: {}`               | Missing session parameter     | Add session to function calls    |
| "Session/tokenSet/idToken not available" | Function parameter mismatch   | Check all auth function calls    |
| Custom claims missing                    | Action not adding to ID token | Update Action to set both tokens |
| Inconsistent behavior                    | Session caching/timing        | Restart dev server, fresh login  |

---

## Final Notes

This integration provides:

- ✅ **Scalable admin management** via Auth0 Dashboard
- ✅ **No hardcoded email lists** in code
- ✅ **Role-based access control** with JWT tokens
- ✅ **Production-ready authentication** system
- ✅ **Proper database synchronization** with Auth0 users
- ✅ **Robust error handling** and debugging capabilities

### Critical Lessons Learned

1. **Session Parameter Rule**: **Always ensure function signatures match their usage**, especially with optional parameters. A single missing session parameter can break the entire token decoding pipeline while appearing to work correctly.

2. **API Response Structure**: Auth0 Management API response structure can vary - always handle both `response` and `response.data` patterns appropriately.

3. **Database Schema**: Ensure all required columns exist and avoid references to non-existent columns. The `auth0_id` column is critical for synchronization.

4. **Environment Cleanup**: Conflicting Auth0 configurations can cause subtle issues. Keep only one consistent tenant configuration.

5. **Debug-First Approach**: Create comprehensive debug endpoints early - they're invaluable for discovering parameter mismatches and configuration issues.

### Success Metrics

After implementing all fixes, you should see:

- ✅ Auth0 Management API endpoints returning 200 status codes
- ✅ Admin logs showing "decoded token roles" not "email fallback"
- ✅ Database sync working without errors
- ✅ Custom claims present in decoded tokens
- ✅ No "Cannot read property" errors in console

### Maintenance

- **Regular testing**: Test admin access after any Auth0 configuration changes
- **Token monitoring**: Periodically verify custom claims are being added correctly
- **Function audits**: Regularly check that all admin function calls include session parameters
- **Database integrity**: Monitor sync operations and verify schema consistency

This guide represents real-world debugging experience and should prevent the most common Auth0 integration pitfalls.

---

## Common Production Issues and Solutions

### Issue: "Cannot connect to database" in Production

**Symptoms:**

- Database connections fail in production
- Works locally but fails when deployed

**Common Causes:**

- Missing SSL configuration
- Incorrect connection string format
- Database provider differences (local vs. production)

**Solution:**

```typescript
// Ensure SSL is properly configured for production
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl:
    process.env.NODE_ENV === "production"
      ? { rejectUnauthorized: false }
      : false,
  // For Neon specifically:
  // ssl: true
});
```

### Issue: Auth0 Action Not Adding Claims in Production

**Symptoms:**

- Custom claims work in development
- Missing in production after deployment

**Debugging Steps:**

1. Check Auth0 Dashboard > Actions > Library - Action should show "DEPLOYED"
2. Check Auth0 Dashboard > Actions > Flows > Login - Action should be in the flow
3. Check Auth0 logs for Action execution
4. Verify production user has correct app_metadata

**Solution:**

- Redeploy the Action in Auth0 Dashboard
- Ensure Action is added to the correct tenant (DEV vs PROD)
- Test with a fresh login to get new tokens

### Issue: "Email exists with different auth0_id" During Sync

**Symptoms:**

- Sync fails for some users
- Error logs show email conflicts

**Root Cause:**

- User changed email in Auth0
- User exists in database with old email mapping

**Solution:**

```sql
-- Manual resolution of email conflicts
-- Option 1: Update the database record to match Auth0
UPDATE users
SET auth0_id = 'auth0|new_user_id'
WHERE email = 'conflicting@email.com' AND auth0_id IS NULL;

-- Option 2: Remove the conflicting database record
DELETE FROM users
WHERE email = 'conflicting@email.com' AND auth0_id != 'auth0|correct_user_id';
```

### Issue: Admin Access Lost After Deployment

**Symptoms:**

- Admin access works locally
- Fails in production

**Common Causes:**

- Environment variables missing
- Auth0 audience mismatch
- Debug endpoints removed but still referenced

**Solution:**

1. Verify all environment variables are set in production
2. Check that `AUTH0_AUDIENCE` matches exactly
3. Test with debug endpoint to verify custom claims
4. Ensure email fallback is still present during transition

### Issue: High Memory Usage from Rate Limiting

**Symptoms:**

- Memory usage grows over time
- Rate limiting Map never clears

**Solution:**

```typescript
// Add cleanup to rate limiting
export function cleanupRateLimit() {
  const now = Date.now();
  for (const [key, entry] of rateLimitMap.entries()) {
    if (now > entry.resetTime) {
      rateLimitMap.delete(key);
    }
  }
}

// Call cleanup periodically
setInterval(cleanupRateLimit, 5 * 60 * 1000); // Every 5 minutes
```

### Issue: Session Cookies Not Working in Production

**Symptoms:**

- Authentication fails silently
- Users can't stay logged in

**Solution:**

```typescript
// Ensure proper cookie configuration
const auth0Instance = initAuth0({
  session: {
    cookie: {
      domain:
        process.env.NODE_ENV === "production" ? ".yourdomain.com" : undefined,
      secure: process.env.NODE_ENV === "production",
      sameSite: "lax",
      httpOnly: true,
    },
  },
});
```

### Quick Production Diagnostic Commands

```bash
# Check environment variables
node -e "console.log(Object.keys(process.env).filter(k => k.includes('AUTH0')))"

# Test database connection
node -e "
const { Pool } = require('pg');
const pool = new Pool({ connectionString: process.env.DATABASE_URL });
pool.query('SELECT NOW()', (err, res) => {
  console.log(err ? 'Error:' + err : 'Connected at: ' + res.rows[0].now);
  process.exit();
});
"

# Verify API endpoints respond
curl -s https://yourdomain.com/api/auth/me | jq .
```

This guide represents real-world debugging experience and should prevent the most common Auth0 integration pitfalls.

Additional considerations:

The guide is now very robust, but a few minor points could still be refined or clarified:

Rate Limiting Implementation Details:
The checkRateLimit function is great, but it’s not yet integrated into the API endpoints (e.g., auth0-users.ts, sync.ts). While the example shows usage, consider adding it to at least one endpoint in the "Complete Working Implementations" section for clarity.
Suggestion: Update pages/api/admin/auth0/auth0-users.ts with rate limiting:
typescript

Collapse

Wrap

Run

Copy
import { checkRateLimit } from "../../../../src/lib/rate-limit";
// ...
export default async function handler(req: NextApiRequest, res: NextApiResponse) {
const clientIp = req.headers["x-forwarded-for"] || req.connection.remoteAddress;
if (!checkRateLimit(`auth0-users-${clientIp}`)) {
return res.status(429).json({ error: "Rate limit exceeded" });
}
// Rest of the code...
}
Token Refresh Testing Specificity:
The token expiration testing endpoint is useful, but it could specify how to handle cases where refresh fails (e.g., redirect to login). This might be overkill unless you’ve encountered it.
Suggestion: Add a note:
"If refresh fails, the SDK should redirect to /api/auth/login. Test this by disabling the Auth0 client secret temporarily."
Frontend Error Handling Enhancement:
The AuthIntegrationHub component handles errors with console.error, but it doesn’t display them to the user. Consider adding a UI feedback mechanism.
Suggestion: Update the component:
typescript

Collapse

Wrap

Run

Copy
const [error, setError] = useState<string | null>(null);
// In catch blocks: setError(`Error: ${error.message}`);
// In JSX: {error && <div className="error">{error}</div>}
Production Diagnostic Commands:
The commands are helpful, but the database connection test assumes a pg client. If using Neon, ensure the correct package (@neondatabase/serverless) is tested.
Suggestion: Update the command comment:
"Test database connection (use pg or @neondatabase/serverless based on your setup)."
Documentation of Backfill Script:
The guide mentions backfilling auth0_id if null (from my earlier response), but no script is provided. This might be optional, but it’s useful for initial data migration.
Suggestion: Add to "Database Schema Fixes":
sql

Collapse

Wrap

Copy
-- Backfill auth0_id based on email match
UPDATE users u
SET auth0_id = au.user_id
FROM auth0_users au
WHERE u.email = au.email AND u.auth0_id IS NULL;
