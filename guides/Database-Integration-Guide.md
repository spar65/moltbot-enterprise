# Complete Guide to Database Integration with Auth0 and Next.js

This guide provides a comprehensive approach to integrating a database with Auth0 authentication in a Next.js application. It covers all steps from initial setup to testing and troubleshooting.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Database Setup](#database-setup)
4. [Database Utility Functions](#database-utility-functions)
5. [API Endpoint Integration](#api-endpoint-integration)
6. [Frontend Integration](#frontend-integration)
7. [Testing and Verification](#testing-and-verification)
8. [Migration Framework](#migration-framework)
9. [Troubleshooting](#troubleshooting)
10. [Best Practices](#best-practices)

## Prerequisites

Before starting the database integration, ensure you have:

- **Auth0 Configuration**: Properly set up Auth0 authentication in your Next.js app
- **Database Access**: Connection string to your database (PostgreSQL recommended)
- **Environment Variables**: Securely stored in `.env.local` or equivalent
- **TypeScript Types**: Defined for your data models

## Environment Setup

### Required Environment Variables

Create or update your `.env.local` file with the following variables:

```bash
# Database Configuration
DATABASE_URL=postgres://username:password@host:port/database?sslmode=require

# Auth0 Configuration (ensure these are set)
AUTH0_SECRET='your-secret-here'
AUTH0_BASE_URL='http://localhost:3000'
AUTH0_ISSUER_BASE_URL='https://your-domain.auth0.com'
AUTH0_CLIENT_ID='your-client-id'
AUTH0_CLIENT_SECRET='your-client-secret'
AUTH0_SCOPE='openid profile email'
AUTH0_AUDIENCE='your-api-audience' # Optional
```

### Verify Environment Setup

Create a simple test script to verify your environment:

```javascript
// scripts/verify-env.js
require("dotenv").config({ path: ".env.local" });

const requiredVars = [
  "DATABASE_URL",
  "AUTH0_SECRET",
  "AUTH0_BASE_URL",
  "AUTH0_ISSUER_BASE_URL",
  "AUTH0_CLIENT_ID",
  "AUTH0_CLIENT_SECRET",
];

console.log("🔍 Checking environment variables...");

requiredVars.forEach((varName) => {
  if (process.env[varName]) {
    console.log(`✅ ${varName}: Set`);
  } else {
    console.log(`❌ ${varName}: Missing`);
  }
});
```

## Database Setup

### 1. Install Required Dependencies

```bash
# For PostgreSQL with Neon serverless
npm install @neondatabase/serverless

# For UUID generation and types
npm install uuid @types/uuid

# Add to package.json scripts
npm pkg set scripts.db:test="node scripts/test-db-connection.js"
npm pkg set scripts.db:migrate="node scripts/migrate-schema.js"
npm pkg set scripts.env:check="node scripts/verify-env.js"
```

### 2. Create Database Schema

Create a schema that extends Auth0 user data with additional information:

```sql
-- Create: src/lib/database-schema.sql

-- Users table (extends Auth0 data)
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY, -- Auth0 sub as primary key
  email TEXT NOT NULL,
  name TEXT,
  nickname TEXT,
  profile_picture TEXT,
  email_verified BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User Settings table
CREATE TABLE IF NOT EXISTS user_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT REFERENCES users(id) ON DELETE CASCADE UNIQUE,
  email_notifications BOOLEAN DEFAULT true,
  marketing_emails BOOLEAN DEFAULT false,
  security_alerts BOOLEAN DEFAULT true,
  weekly_digest BOOLEAN DEFAULT true,
  profile_visible BOOLEAN DEFAULT true,
  activity_visible BOOLEAN DEFAULT false,
  theme TEXT DEFAULT 'light',
  language TEXT DEFAULT 'english',
  timezone TEXT DEFAULT 'America/New_York',
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Subscriptions table
CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
  tier TEXT CHECK (tier IN ('free', 'basic', 'pro', 'enterprise')) DEFAULT 'free',
  status TEXT CHECK (status IN ('active', 'inactive', 'cancelled', 'past_due')) DEFAULT 'active',
  stripe_subscription_id TEXT,
  current_period_start TIMESTAMP,
  current_period_end TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_user_settings_user_id ON user_settings(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions(user_id);
```

### 3. Database Connection Test Script

Create a connection test script to verify database connectivity:

```javascript
// scripts/test-db-connection.js
require("dotenv").config({ path: ".env.local" });
const { neon } = require("@neondatabase/serverless");

async function testConnection() {
  try {
    console.log("🔌 Testing database connection...");

    if (!process.env.DATABASE_URL) {
      throw new Error("DATABASE_URL environment variable is not set");
    }

    const sql = neon(process.env.DATABASE_URL);
    const result =
      await sql`SELECT NOW() as current_time, version() as db_version`;

    console.log("✅ Database connection successful!");
    console.log(`📅 Current time: ${result[0].current_time}`);
    console.log(`🗄️  Database: ${result[0].db_version.split(" ")[0]}`);

    return true;
  } catch (error) {
    console.error("❌ Database connection failed:", error.message);
    return false;
  }
}

if (require.main === module) {
  testConnection()
    .then((success) => {
      if (!success) process.exit(1);
    })
    .catch((err) => {
      console.error("Unexpected error:", err);
      process.exit(1);
    });
}

module.exports = { testConnection };
```

### 4. Set Up Database Connection

Create a database connection utility file:

```typescript
// src/lib/database.ts
import { neon } from "@neondatabase/serverless";

// Validate DATABASE_URL exists
if (!process.env.DATABASE_URL) {
  throw new Error("DATABASE_URL environment variable is required");
}

// Use the DATABASE_URL from environment variables
const sql = neon(process.env.DATABASE_URL);

// Export for testing and use
export { sql };
```

## Database Utility Functions

### 1. Define Types

Create TypeScript interfaces for your database models:

```typescript
// src/lib/database.ts (continued)

// Enhanced type definitions
export interface User {
  id: string;
  email: string;
  name?: string | null;
  nickname?: string | null;
  profile_picture?: string | null;
  email_verified: boolean;
  created_at: string;
  updated_at: string;
}

export interface UserSettings {
  id: string;
  user_id: string;
  email_notifications: boolean;
  marketing_emails: boolean;
  security_alerts: boolean;
  weekly_digest: boolean;
  profile_visible: boolean;
  activity_visible: boolean;
  theme: "light" | "dark";
  language: string;
  timezone: string;
  updated_at: string;
}

export interface Subscription {
  id: string;
  user_id: string;
  tier: "free" | "basic" | "pro" | "enterprise";
  status: "active" | "inactive" | "cancelled" | "past_due";
  stripe_subscription_id?: string | null;
  current_period_start?: string | null;
  current_period_end?: string | null;
  created_at: string;
  updated_at: string;
}

export interface Auth0User {
  sub: string;
  email: string;
  name?: string;
  picture?: string;
  email_verified?: boolean;
}

// Database error wrapper
export class DatabaseError extends Error {
  constructor(message: string, public originalError?: any) {
    super(message);
    this.name = "DatabaseError";

    // Capture stack trace
    if (Error.captureStackTrace) {
      Error.captureStackTrace(this, this.constructor);
    }
  }
}
```

### 2. Implement CRUD Functions

Create functions for common database operations:

```typescript
// src/lib/database.ts (continued)

// User Management Functions
export async function upsertUser(auth0User: Auth0User): Promise<User> {
  try {
    const result = await sql`
      INSERT INTO users (id, email, name, profile_picture, email_verified)
      VALUES (
        ${auth0User.sub}, 
        ${auth0User.email}, 
        ${auth0User.name || null}, 
        ${auth0User.picture || null}, 
        ${Boolean(auth0User.email_verified)}
      )
      ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        name = EXCLUDED.name,
        profile_picture = EXCLUDED.profile_picture,
        email_verified = EXCLUDED.email_verified,
        updated_at = CURRENT_TIMESTAMP
      RETURNING *
    `;

    if (!result[0]) {
      throw new DatabaseError("Failed to create or update user");
    }

    return result[0] as User;
  } catch (error) {
    console.error("Error upserting user:", error);
    throw new DatabaseError("Failed to upsert user", error);
  }
}

export async function getUser(userId: string): Promise<User | null> {
  try {
    const result = await sql`
      SELECT * FROM users WHERE id = ${userId}
    `;
    return (result[0] as User) || null;
  } catch (error) {
    console.error("Error getting user:", error);
    throw new DatabaseError("Failed to get user", error);
  }
}

export async function updateUserProfile(
  userId: string,
  updates: Partial<Pick<User, "name" | "nickname">>
): Promise<User> {
  try {
    const result = await sql`
      UPDATE users 
      SET 
        name = COALESCE(${updates.name || null}, name),
        nickname = COALESCE(${updates.nickname || null}, nickname),
        updated_at = CURRENT_TIMESTAMP
      WHERE id = ${userId}
      RETURNING *
    `;

    if (!result[0]) {
      throw new DatabaseError("User not found or update failed");
    }

    return result[0] as User;
  } catch (error) {
    console.error("Error updating user profile:", error);
    throw new DatabaseError("Failed to update user profile", error);
  }
}

// User Settings Functions
export async function getUserSettings(
  userId: string
): Promise<UserSettings | null> {
  try {
    const result = await sql`
      SELECT * FROM user_settings WHERE user_id = ${userId}
    `;
    return (result[0] as UserSettings) || null;
  } catch (error) {
    console.error("Error getting user settings:", error);
    throw new DatabaseError("Failed to get user settings", error);
  }
}

export async function upsertUserSettings(
  userId: string,
  settings: Partial<Omit<UserSettings, "id" | "user_id" | "updated_at">>
): Promise<UserSettings> {
  try {
    const result = await sql`
      INSERT INTO user_settings (
        user_id, email_notifications, marketing_emails, security_alerts,
        weekly_digest, profile_visible, activity_visible, theme, language, timezone
      )
      VALUES (
        ${userId}, 
        ${settings.email_notifications ?? true}, 
        ${settings.marketing_emails ?? false}, 
        ${settings.security_alerts ?? true},
        ${settings.weekly_digest ?? true},
        ${settings.profile_visible ?? true},
        ${settings.activity_visible ?? false},
        ${settings.theme ?? "light"}, 
        ${settings.language ?? "english"}, 
        ${settings.timezone ?? "America/New_York"}
      )
      ON CONFLICT (user_id) DO UPDATE SET
        email_notifications = EXCLUDED.email_notifications,
        marketing_emails = EXCLUDED.marketing_emails,
        security_alerts = EXCLUDED.security_alerts,
        weekly_digest = EXCLUDED.weekly_digest,
        profile_visible = EXCLUDED.profile_visible,
        activity_visible = EXCLUDED.activity_visible,
        theme = EXCLUDED.theme,
        language = EXCLUDED.language,
        timezone = EXCLUDED.timezone,
        updated_at = CURRENT_TIMESTAMP
      RETURNING *
    `;

    if (!result[0]) {
      throw new DatabaseError("Failed to create or update user settings");
    }

    return result[0] as UserSettings;
  } catch (error) {
    console.error("Error upserting user settings:", error);
    throw new DatabaseError("Failed to upsert user settings", error);
  }
}

// Subscription Management
export async function getUserSubscription(
  userId: string
): Promise<Subscription | null> {
  try {
    const result = await sql`
      SELECT * FROM subscriptions 
      WHERE user_id = ${userId} AND status = 'active'
      ORDER BY created_at DESC 
      LIMIT 1
    `;
    return (result[0] as Subscription) || null;
  } catch (error) {
    console.error("Error getting user subscription:", error);
    throw new DatabaseError("Failed to get user subscription", error);
  }
}

export async function createFreeSubscription(
  userId: string
): Promise<Subscription> {
  try {
    const result = await sql`
      INSERT INTO subscriptions (user_id, tier, status)
      VALUES (${userId}, 'free', 'active')
      RETURNING *
    `;

    if (!result[0]) {
      throw new DatabaseError("Failed to create free subscription");
    }

    return result[0] as Subscription;
  } catch (error) {
    console.error("Error creating free subscription:", error);
    throw new DatabaseError("Failed to create free subscription", error);
  }
}
```

## API Endpoint Integration

### 1. Create Auth0 Client Configuration

Ensure your Auth0 client is properly configured:

```typescript
// src/lib/auth0.ts
import { Auth0Client } from "@auth0/nextjs-auth0/server";

// Validate required environment variables
const requiredEnvVars = [
  "AUTH0_DOMAIN",
  "AUTH0_CLIENT_ID",
  "AUTH0_CLIENT_SECRET",
  "AUTH0_SECRET",
];
requiredEnvVars.forEach((varName) => {
  if (!process.env[varName]) {
    throw new Error(`${varName} environment variable is required`);
  }
});

export const auth0 = new Auth0Client({
  domain: process.env.AUTH0_DOMAIN!,
  clientId: process.env.AUTH0_CLIENT_ID!,
  clientSecret: process.env.AUTH0_CLIENT_SECRET!,
  baseURL: process.env.AUTH0_BASE_URL!,
  secret: process.env.AUTH0_SECRET!,

  authorizationParameters: {
    scope: process.env.AUTH0_SCOPE || "openid profile email",
    audience: process.env.AUTH0_AUDIENCE,
  },
});
```

### 2. Profile API Endpoint

Create or update your user profile API endpoint:

```typescript
// src/pages/api/user/profile.ts
import { NextApiRequest, NextApiResponse } from "next";
import { auth0 } from "../../../lib/auth0";
import {
  getUser,
  upsertUser,
  updateUserProfile,
  Auth0User,
  DatabaseError,
} from "../../../lib/database";

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  try {
    const session = await auth0.getSession(req);

    // Enhanced authentication check
    if (!session?.user?.email) {
      return res.status(401).json({
        error: "Authentication required",
        message: "Please log in to access this resource",
      });
    }

    const { user: sessionUser } = session;

    // GET - Return user profile data from database
    if (req.method === "GET") {
      // Map session user to Auth0User format
      const auth0User: Auth0User = {
        sub: sessionUser.sub,
        email: sessionUser.email,
        name: sessionUser.name,
        picture: sessionUser.picture,
        email_verified: sessionUser.email_verified,
      };

      // Ensure user exists in the database (creates if not exists)
      await upsertUser(auth0User);

      // Get user from database
      const user = await getUser(sessionUser.sub);

      if (!user) {
        return res.status(404).json({
          error: "User not found",
          message: "User profile could not be retrieved",
        });
      }

      return res.status(200).json(user);
    }

    // PUT - Update user profile data in database
    if (req.method === "PUT") {
      const { name, nickname } = req.body;

      // Input validation
      if (
        name !== undefined &&
        (typeof name !== "string" || name.length > 255)
      ) {
        return res.status(400).json({
          error: "Invalid input",
          message: "Name must be a string with maximum 255 characters",
        });
      }

      if (
        nickname !== undefined &&
        (typeof nickname !== "string" || nickname.length > 50)
      ) {
        return res.status(400).json({
          error: "Invalid input",
          message: "Nickname must be a string with maximum 50 characters",
        });
      }

      // Update the user in the database
      const updatedUser = await updateUserProfile(sessionUser.sub, {
        name: name?.trim(),
        nickname: nickname?.trim(),
      });

      return res.status(200).json(updatedUser);
    }

    // Method not allowed
    res.setHeader("Allow", ["GET", "PUT"]);
    return res.status(405).json({
      error: "Method not allowed",
      message: `Method ${req.method} is not supported for this endpoint`,
    });
  } catch (error) {
    console.error("Profile API error:", error);

    if (error instanceof DatabaseError) {
      return res.status(500).json({
        error: "Database error",
        message: "Unable to process your request due to a database issue",
      });
    }

    return res.status(500).json({
      error: "Internal server error",
      message: "An unexpected error occurred",
    });
  }
}
```

### 3. User Settings API Endpoint

Create an API endpoint for user settings:

```typescript
// src/pages/api/user/settings.ts
import { NextApiRequest, NextApiResponse } from "next";
import { auth0 } from "../../../lib/auth0";
import {
  getUserSettings,
  upsertUserSettings,
  upsertUser,
  Auth0User,
  DatabaseError,
} from "../../../lib/database";

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  try {
    const session = await auth0.getSession(req);

    // Authentication check
    if (!session?.user?.email) {
      return res.status(401).json({
        error: "Authentication required",
        message: "Please log in to access this resource",
      });
    }

    const { user: sessionUser } = session;

    // Ensure user exists in database
    const auth0User: Auth0User = {
      sub: sessionUser.sub,
      email: sessionUser.email,
      name: sessionUser.name,
      picture: sessionUser.picture,
      email_verified: sessionUser.email_verified,
    };

    await upsertUser(auth0User);

    // GET - Return user settings
    if (req.method === "GET") {
      let settings = await getUserSettings(sessionUser.sub);

      // If no settings exist yet, create default settings
      if (!settings) {
        settings = await upsertUserSettings(sessionUser.sub, {});
      }

      return res.status(200).json(settings);
    }

    // PUT - Update user settings
    if (req.method === "PUT") {
      const {
        email_notifications,
        marketing_emails,
        security_alerts,
        weekly_digest,
        profile_visible,
        activity_visible,
        theme,
        language,
        timezone,
      } = req.body;

      // Input validation
      const booleanFields = [
        "email_notifications",
        "marketing_emails",
        "security_alerts",
        "weekly_digest",
        "profile_visible",
        "activity_visible",
      ];

      for (const field of booleanFields) {
        if (
          req.body[field] !== undefined &&
          typeof req.body[field] !== "boolean"
        ) {
          return res.status(400).json({
            error: "Invalid input",
            message: `${field} must be a boolean value`,
          });
        }
      }

      if (theme && !["light", "dark"].includes(theme)) {
        return res.status(400).json({
          error: "Invalid input",
          message: "Theme must be 'light' or 'dark'",
        });
      }

      const updatedSettings = await upsertUserSettings(sessionUser.sub, {
        email_notifications,
        marketing_emails,
        security_alerts,
        weekly_digest,
        profile_visible,
        activity_visible,
        theme,
        language,
        timezone,
      });

      return res.status(200).json(updatedSettings);
    }

    // Method not allowed
    res.setHeader("Allow", ["GET", "PUT"]);
    return res.status(405).json({
      error: "Method not allowed",
      message: `Method ${req.method} is not supported for this endpoint`,
    });
  } catch (error) {
    console.error("Settings API error:", error);

    if (error instanceof DatabaseError) {
      return res.status(500).json({
        error: "Database error",
        message: "Unable to process your request due to a database issue",
      });
    }

    return res.status(500).json({
      error: "Internal server error",
      message: "An unexpected error occurred",
    });
  }
}
```

## Frontend Integration

### 1. Create Custom Hooks for API Calls

Create reusable hooks for API interactions:

```typescript
// src/hooks/useProfile.ts
import { useState, useEffect } from "react";
import { User } from "../lib/database";

export function useProfile() {
  const [profile, setProfile] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchProfile = async () => {
    try {
      setLoading(true);
      setError(null);

      const response = await fetch("/api/user/profile");

      if (!response.ok) {
        if (response.status === 401) {
          throw new Error("Please log in to view your profile");
        }
        throw new Error(`Failed to load profile: ${response.statusText}`);
      }

      const data = await response.json();
      setProfile(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load profile");
    } finally {
      setLoading(false);
    }
  };

  const updateProfile = async (updates: {
    name?: string;
    nickname?: string;
  }) => {
    try {
      setError(null);

      const response = await fetch("/api/user/profile", {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(updates),
      });

      if (!response.ok) {
        throw new Error(`Failed to update profile: ${response.statusText}`);
      }

      const updatedProfile = await response.json();
      setProfile(updatedProfile);
      return updatedProfile;
    } catch (err) {
      const errorMessage =
        err instanceof Error ? err.message : "Failed to update profile";
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  };

  useEffect(() => {
    fetchProfile();
  }, []);

  return {
    profile,
    loading,
    error,
    updateProfile,
    refetch: fetchProfile,
  };
}
```

### 2. Profile Page Component with Enhanced Error Handling

```typescript
// Example usage in profile component
import { useProfile } from "../hooks/useProfile";
import { useUser } from "@auth0/nextjs-auth0/client";

export default function ProfilePage() {
  const { user: auth0User, isLoading: auth0Loading } = useUser();
  const { profile, loading, error, updateProfile } = useProfile();
  const [isEditing, setIsEditing] = useState(false);
  const [formData, setFormData] = useState({ name: "", nickname: "" });
  const [isSaving, setIsSaving] = useState(false);
  const [successMessage, setSuccessMessage] = useState("");

  // Update form data when profile loads
  useEffect(() => {
    if (profile) {
      setFormData({
        name: profile.name || "",
        nickname: profile.nickname || "",
      });
    }
  }, [profile]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSaving(true);

    try {
      await updateProfile(formData);
      setSuccessMessage("Profile updated successfully!");
      setIsEditing(false);

      // Clear success message after 3 seconds
      setTimeout(() => setSuccessMessage(""), 3000);
    } catch (err) {
      // Error is already handled by the hook
    } finally {
      setIsSaving(false);
    }
  };

  // Loading states
  if (auth0Loading || loading) {
    return <div className="loading">Loading profile...</div>;
  }

  // Authentication check
  if (!auth0User) {
    return <div className="error">Please log in to view your profile.</div>;
  }

  // Error state
  if (error) {
    return (
      <div className="error">
        <p>Error: {error}</p>
        <button onClick={() => window.location.reload()}>Try Again</button>
      </div>
    );
  }

  return (
    <div className="profile-container">
      <h1>My Profile</h1>

      {successMessage && (
        <div className="success-message">{successMessage}</div>
      )}

      <form onSubmit={handleSubmit}>
        <div className="form-group">
          <label htmlFor="name">Name:</label>
          {isEditing ? (
            <input
              type="text"
              id="name"
              value={formData.name}
              onChange={(e) =>
                setFormData({ ...formData, name: e.target.value })
              }
              disabled={isSaving}
            />
          ) : (
            <span>{profile?.name || "Not set"}</span>
          )}
        </div>

        <div className="form-group">
          <label htmlFor="nickname">Nickname:</label>
          {isEditing ? (
            <input
              type="text"
              id="nickname"
              value={formData.nickname}
              onChange={(e) =>
                setFormData({ ...formData, nickname: e.target.value })
              }
              disabled={isSaving}
            />
          ) : (
            <span>{profile?.nickname || "Not set"}</span>
          )}
        </div>

        <div className="form-actions">
          {isEditing ? (
            <>
              <button type="submit" disabled={isSaving}>
                {isSaving ? "Saving..." : "Save Changes"}
              </button>
              <button
                type="button"
                onClick={() => setIsEditing(false)}
                disabled={isSaving}
              >
                Cancel
              </button>
            </>
          ) : (
            <button type="button" onClick={() => setIsEditing(true)}>
              Edit Profile
            </button>
          )}
        </div>
      </form>
    </div>
  );
}
```

## Testing and Verification

### 1. Automated Testing Scripts

Create comprehensive test scripts:

```javascript
// scripts/test-api-endpoints.js
require("dotenv").config({ path: ".env.local" });

async function testApiEndpoints() {
  console.log("🧪 Testing API endpoints...");

  const baseUrl = process.env.AUTH0_BASE_URL || "http://localhost:3000";

  // Test unauthenticated access (should return 401)
  try {
    const response = await fetch(`${baseUrl}/api/user/profile`);
    if (response.status === 401) {
      console.log("✅ Unauthenticated access properly blocked");
    } else {
      console.log(`❌ Expected 401, got ${response.status}`);
    }
  } catch (error) {
    console.log(`❌ Error testing unauthenticated access: ${error.message}`);
  }

  console.log(
    "ℹ️  To test authenticated endpoints, log in through the browser and extract session cookie"
  );
}

if (require.main === module) {
  testApiEndpoints();
}
```

### 2. Manual Testing Checklist

Create a comprehensive testing checklist:

```markdown
## Manual Testing Checklist

### Database Connection

- [ ] `npm run db:test` succeeds
- [ ] Environment variables are properly set
- [ ] Database schema is applied

### Authentication Flow

- [ ] User can log in successfully
- [ ] User can log out successfully
- [ ] Session persists across page refreshes
- [ ] Unauthenticated users are redirected to login

### Profile Management

- [ ] Profile page loads user data from database
- [ ] Profile updates are saved to database
- [ ] Changes persist after page refresh
- [ ] Form validation works correctly
- [ ] Error messages display appropriately

### Settings Management

- [ ] Settings page loads user preferences
- [ ] Settings updates are saved to database
- [ ] Default settings are created for new users
- [ ] All setting options function correctly

### API Endpoints

- [ ] Unauthenticated requests return 401
- [ ] Authenticated requests return proper data
- [ ] Invalid input is rejected with 400
- [ ] Error responses include helpful messages
```

### 3. API Testing with cURL

Enhanced cURL testing examples:

```bash
# Test Profile API (requires valid session cookie)
# First, log in through browser and extract appSession cookie

# Get profile
curl -X GET \
  -H "Cookie: appSession=YOUR_SESSION_COOKIE" \
  -H "Accept: application/json" \
  http://localhost:3000/api/user/profile

# Update profile with validation
curl -X PUT \
  -H "Content-Type: application/json" \
  -H "Cookie: appSession=YOUR_SESSION_COOKIE" \
  -H "Accept: application/json" \
  -d '{"name":"Updated Name","nickname":"UpdatedNick"}' \
  http://localhost:3000/api/user/profile

# Test settings API
curl -X GET \
  -H "Cookie: appSession=YOUR_SESSION_COOKIE" \
  -H "Accept: application/json" \
  http://localhost:3000/api/user/settings

# Update settings
curl -X PUT \
  -H "Content-Type: application/json" \
  -H "Cookie: appSession=YOUR_SESSION_COOKIE" \
  -d '{"theme":"dark","email_notifications":false}' \
  http://localhost:3000/api/user/settings

# Test error handling - invalid method
curl -X DELETE \
  -H "Cookie: appSession=YOUR_SESSION_COOKIE" \
  http://localhost:3000/api/user/profile

# Test unauthenticated access (should return 401)
curl -X GET \
  -H "Accept: application/json" \
  http://localhost:3000/api/user/profile
```

### 4. Database Verification Queries

```sql
-- Verify user data
SELECT
  id,
  email,
  name,
  nickname,
  email_verified,
  created_at,
  updated_at
FROM users
WHERE email = 'your-email@example.com';

-- Check user settings
SELECT
  user_id,
  email_notifications,
  marketing_emails,
  theme,
  language,
  timezone,
  updated_at
FROM user_settings
WHERE user_id = 'auth0|your-user-id';

-- Verify data relationships
SELECT
  u.email,
  u.name,
  us.theme,
  us.email_notifications,
  s.tier,
  s.status
FROM users u
LEFT JOIN user_settings us ON u.id = us.user_id
LEFT JOIN subscriptions s ON u.id = s.user_id
WHERE u.email = 'your-email@example.com';
```

## Migration Framework

### 1. Enhanced Migration Script

```javascript
// scripts/migrate-schema.js
require("dotenv").config({ path: ".env.local" });
const { neon } = require("@neondatabase/serverless");
const fs = require("fs");
const path = require("path");

class MigrationManager {
  constructor() {
    if (!process.env.DATABASE_URL) {
      throw new Error("DATABASE_URL environment variable is required");
    }
    this.sql = neon(process.env.DATABASE_URL);
  }

  async ensureMigrationsTable() {
    await this.sql`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        id SERIAL PRIMARY KEY,
        migration_name TEXT UNIQUE NOT NULL,
        applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        checksum TEXT,
        execution_time INTEGER
      )
    `;
  }

  calculateChecksum(content) {
    const crypto = require("crypto");
    return crypto.createHash("md5").update(content).digest("hex");
  }

  async applyMigration(migrationFile) {
    const startTime = Date.now();

    try {
      console.log(`🔄 Applying migration: ${migrationFile}`);

      const migrationPath = path.join(
        __dirname,
        "..",
        "migrations",
        migrationFile
      );

      if (!fs.existsSync(migrationPath)) {
        throw new Error(`Migration file not found: ${migrationPath}`);
      }

      const migrationContent = fs.readFileSync(migrationPath, "utf8");
      const checksum = this.calculateChecksum(migrationContent);

      // Check if migration was already applied
      const existing = await this.sql`
        SELECT checksum FROM schema_migrations WHERE migration_name = ${migrationFile}
      `;

      if (existing.length > 0) {
        if (existing[0].checksum === checksum) {
          console.log(
            `✅ Migration ${migrationFile} already applied, skipping`
          );
          return true;
        } else {
          throw new Error(
            `Migration ${migrationFile} has been modified since it was applied`
          );
        }
      }

      // Apply migration in a transaction
      await this.sql.begin(async (transaction) => {
        // Execute the migration SQL
        await transaction.unsafe(migrationContent);

        // Record the migration
        const executionTime = Date.now() - startTime;
        await transaction`
          INSERT INTO schema_migrations (migration_name, checksum, execution_time) 
          VALUES (${migrationFile}, ${checksum}, ${executionTime})
        `;
      });

      const executionTime = Date.now() - startTime;
      console.log(
        `✅ Migration ${migrationFile} applied successfully (${executionTime}ms)`
      );
      return true;
    } catch (error) {
      console.error(`❌ Migration ${migrationFile} failed:`, error.message);
      return false;
    }
  }

  async rollbackMigration(migrationFile) {
    try {
      console.log(`🔄 Rolling back migration: ${migrationFile}`);

      // Check if rollback file exists
      const rollbackPath = path.join(
        __dirname,
        "..",
        "migrations",
        "rollback",
        migrationFile
      );

      if (!fs.existsSync(rollbackPath)) {
        throw new Error(`Rollback file not found: ${rollbackPath}`);
      }

      const rollbackContent = fs.readFileSync(rollbackPath, "utf8");

      // Apply rollback in a transaction
      await this.sql.begin(async (transaction) => {
        // Execute the rollback SQL
        await transaction.unsafe(rollbackContent);

        // Remove the migration record
        await transaction`
          DELETE FROM schema_migrations WHERE migration_name = ${migrationFile}
        `;
      });

      console.log(`✅ Migration ${migrationFile} rolled back successfully`);
      return true;
    } catch (error) {
      console.error(`❌ Rollback of ${migrationFile} failed:`, error.message);
      return false;
    }
  }

  async getAppliedMigrations() {
    const result = await this.sql`
      SELECT migration_name, applied_at, execution_time 
      FROM schema_migrations 
      ORDER BY applied_at
    `;
    return result;
  }

  async migrateAll() {
    await this.ensureMigrationsTable();

    const migrationsDir = path.join(__dirname, "..", "migrations");

    if (!fs.existsSync(migrationsDir)) {
      fs.mkdirSync(migrationsDir, { recursive: true });
      console.log(`📁 Created migrations directory: ${migrationsDir}`);
    }

    const migrationFiles = fs
      .readdirSync(migrationsDir)
      .filter((file) => file.endsWith(".sql") && !file.startsWith("."))
      .sort();

    if (migrationFiles.length === 0) {
      console.log("ℹ️  No migrations found in migrations directory.");
      return true;
    }

    console.log(`🔄 Found ${migrationFiles.length} migration(s) to apply`);

    for (const file of migrationFiles) {
      const success = await this.applyMigration(file);
      if (!success) {
        console.error(`❌ Migration process failed at ${file}`);
        return false;
      }
    }

    console.log("🎉 All migrations applied successfully!");
    return true;
  }

  async status() {
    await this.ensureMigrationsTable();

    const applied = await this.getAppliedMigrations();

    console.log("\n📊 Migration Status:");
    console.log("═".repeat(60));

    if (applied.length === 0) {
      console.log("No migrations have been applied yet.");
    } else {
      applied.forEach((migration) => {
        const date = new Date(migration.applied_at).toLocaleString();
        const time = migration.execution_time
          ? `${migration.execution_time}ms`
          : "N/A";
        console.log(
          `✅ ${migration.migration_name.padEnd(30)} ${date} (${time})`
        );
      });
    }
    console.log("═".repeat(60));
  }
}

// CLI interface
async function main() {
  const manager = new MigrationManager();
  const command = process.argv[2] || "migrate";

  switch (command) {
    case "migrate":
      await manager.migrateAll();
      break;
    case "status":
      await manager.status();
      break;
    case "rollback":
      const migrationName = process.argv[3];
      if (!migrationName) {
        console.error("Please specify migration name to rollback");
        process.exit(1);
      }
      await manager.rollbackMigration(migrationName);
      break;
    default:
      console.log(
        "Usage: node migrate-schema.js [migrate|status|rollback <migration_name>]"
      );
      process.exit(1);
  }
}

if (require.main === module) {
  main().catch((err) => {
    console.error("Migration error:", err);
    process.exit(1);
  });
}

module.exports = { MigrationManager };
```

### 2. Example Migration Files

```sql
-- migrations/001_initial_schema.sql
-- Initial database schema setup

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL,
  name TEXT,
  nickname TEXT,
  profile_picture TEXT,
  email_verified BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS user_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT REFERENCES users(id) ON DELETE CASCADE UNIQUE,
  email_notifications BOOLEAN DEFAULT true,
  marketing_emails BOOLEAN DEFAULT false,
  security_alerts BOOLEAN DEFAULT true,
  weekly_digest BOOLEAN DEFAULT true,
  profile_visible BOOLEAN DEFAULT true,
  activity_visible BOOLEAN DEFAULT false,
  theme TEXT DEFAULT 'light',
  language TEXT DEFAULT 'english',
  timezone TEXT DEFAULT 'America/New_York',
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_user_settings_user_id ON user_settings(user_id);
```

```sql
-- migrations/002_add_subscriptions.sql
-- Add subscription management

CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
  tier TEXT CHECK (tier IN ('free', 'basic', 'pro', 'enterprise')) DEFAULT 'free',
  status TEXT CHECK (status IN ('active', 'inactive', 'cancelled', 'past_due')) DEFAULT 'active',
  stripe_subscription_id TEXT,
  current_period_start TIMESTAMP,
  current_period_end TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_stripe_id ON subscriptions(stripe_subscription_id);
```

### 3. Rollback Files

```sql
-- migrations/rollback/002_add_subscriptions.sql
-- Rollback subscription tables

DROP INDEX IF EXISTS idx_subscriptions_stripe_id;
DROP INDEX IF EXISTS idx_subscriptions_user_id;
DROP TABLE IF EXISTS subscriptions;
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Database Connection Issues

**Problem**: Cannot connect to database

```bash
❌ Database connection failed: connect ECONNREFUSED
```

**Solutions**:

- Verify `DATABASE_URL` is correctly set in `.env.local`
- Check if database server is running and accessible
- Test connection string manually using `psql` or database client
- Ensure firewall/security groups allow connections
- Verify SSL settings match database requirements

**Debug Steps**:

```javascript
// Add to test script for detailed debugging
console.log(
  "Database URL (redacted):",
  process.env.DATABASE_URL?.replace(/\/\/.*@/, "//***:***@")
);
```

#### 2. Auth0 Session Issues

**Problem**: `auth0.getSession(req)` returns null

```bash
❌ Profile API error: Cannot read properties of null (reading 'user')
```

**Solutions**:

- Ensure user is logged in through Auth0
- Check Auth0 configuration variables
- Verify callback URLs are configured correctly
- Test login flow manually
- Check browser cookies for `appSession`

**Debug Steps**:

```javascript
// Add to API handler for debugging
console.log("Session debug:", {
  hasSession: !!session,
  hasUser: !!session?.user,
  userSub: session?.user?.sub,
  userEmail: session?.user?.email,
});
```

#### 3. API 500 Errors

**Problem**: Internal server errors in API routes

**Debug Process**:

1. Check server console logs for detailed error messages
2. Add try-catch blocks with detailed logging
3. Test database operations in isolation
4. Verify data types match between frontend and API

**Enhanced Error Logging**:

```javascript
// Add to API routes
catch (error) {
  console.error('Detailed API Error:', {
    name: error.name,
    message: error.message,
    stack: error.stack,
    timestamp: new Date().toISOString(),
    endpoint: req.url,
    method: req.method
  });
  // ... rest of error handling
}
```

#### 4. Frontend State Issues

**Problem**: Profile changes don't persist or display incorrectly

**Solutions**:

- Verify API calls are actually being made (check Network tab)
- Ensure state updates happen after successful API responses
- Check for race conditions in useEffect hooks
- Validate form data before sending to API

**Debug Hooks**:

```javascript
// Add to custom hooks for debugging
useEffect(() => {
  console.log("Profile state changed:", { profile, loading, error });
}, [profile, loading, error]);
```

#### 5. TypeScript Type Errors

**Problem**: Type mismatches between Auth0, API, and database

**Solutions**:

- Ensure Auth0User interface matches session.user structure
- Use proper type assertions where necessary
- Handle optional/nullable fields consistently
- Validate data at API boundaries

#### 6. Migration Issues

**Problem**: Migrations fail or get stuck

**Solutions**:

- Check migration file syntax using database client
- Ensure migrations are idempotent (can be run multiple times)
- Use transactions to ensure atomicity
- Test migrations on development database first

**Recovery Steps**:

```bash
# Check migration status
npm run db:migrate status

# Manual rollback if needed
npm run db:migrate rollback migration_name

# Re-apply migrations
npm run db:migrate
```

### Monitoring and Logging

#### 1. Production Monitoring Setup

```javascript
// src/lib/monitoring.ts
export function logDatabaseOperation(
  operation: string,
  userId?: string,
  duration?: number
) {
  console.log(
    JSON.stringify({
      timestamp: new Date().toISOString(),
      type: "database_operation",
      operation,
      userId,
      duration,
      environment: process.env.NODE_ENV,
    })
  );
}

export function logApiRequest(
  req: NextApiRequest,
  res: NextApiResponse,
  duration: number
) {
  console.log(
    JSON.stringify({
      timestamp: new Date().toISOString(),
      type: "api_request",
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      duration,
      userAgent: req.headers["user-agent"],
    })
  );
}
```

#### 2. Health Check Endpoint

```typescript
// src/pages/api/health.ts
import { NextApiRequest, NextApiResponse } from "next";
import { sql } from "../../lib/database";

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  if (req.method !== "GET") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  try {
    const start = Date.now();

    // Test database connectivity
    const dbResult = await sql`SELECT 1 as test`;
    const dbLatency = Date.now() - start;

    const health = {
      status: "healthy",
      timestamp: new Date().toISOString(),
      database: {
        status: "connected",
        latency: `${dbLatency}ms`,
      },
      environment: process.env.NODE_ENV,
    };

    res.status(200).json(health);
  } catch (error) {
    console.error("Health check failed:", error);

    res.status(503).json({
      status: "unhealthy",
      timestamp: new Date().toISOString(),
      error: "Database connection failed",
    });
  }
}
```

## Best Practices

### 1. Security Best Practices

#### Environment Variables Security

- Never commit `.env.local` to version control
- Use different credentials for different environments
- Rotate database credentials regularly
- Use least privilege principle for database users

#### API Security

```typescript
// Input validation example
function validateUserInput(data: any): { isValid: boolean; errors: string[] } {
  const errors: string[] = [];

  if (data.name && (typeof data.name !== "string" || data.name.length > 255)) {
    errors.push("Name must be a string with maximum 255 characters");
  }

  if (data.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(data.email)) {
    errors.push("Email must be a valid email address");
  }

  return { isValid: errors.length === 0, errors };
}
```

#### Database Security

- Use parameterized queries (already handled by Neon)
- Implement row-level security where appropriate
- Regular security audits and updates
- Monitor for suspicious database activity

### 2. Performance Optimization

#### Database Optimization

```sql
-- Add appropriate indexes
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);
CREATE INDEX IF NOT EXISTS idx_users_email_verified ON users(email_verified);

-- Consider partial indexes for specific queries
CREATE INDEX IF NOT EXISTS idx_active_subscriptions
ON subscriptions(user_id) WHERE status = 'active';
```

#### API Optimization

```typescript
// Implement caching for frequently accessed data
const cache = new Map<string, { data: any; timestamp: number }>();
const CACHE_TTL = 5 * 60 * 1000; // 5 minutes

function getCachedData(key: string) {
  const cached = cache.get(key);
  if (cached && Date.now() - cached.timestamp < CACHE_TTL) {
    return cached.data;
  }
  return null;
}

function setCachedData(key: string, data: any) {
  cache.set(key, { data, timestamp: Date.now() });
}
```

#### Frontend Optimization

```typescript
// Use React Query for better data management
import { useQuery, useMutation, useQueryClient } from "react-query";

export function useProfile() {
  const queryClient = useQueryClient();

  const {
    data: profile,
    isLoading,
    error,
  } = useQuery(["profile"], fetchProfile);

  const updateMutation = useMutation(updateProfile, {
    onSuccess: () => {
      queryClient.invalidateQueries(["profile"]);
    },
  });

  return {
    profile,
    isLoading,
    error,
    updateProfile: updateMutation.mutate,
    isUpdating: updateMutation.isLoading,
  };
}
```

### 3. Code Organization

#### File Structure

```
src/
├── lib/
│   ├── auth0.ts              # Auth0 configuration
│   ├── database.ts           # Database utilities
│   ├── errors.ts             # Custom error classes
│   └── monitoring.ts         # Logging and monitoring
├── hooks/
│   ├── useProfile.ts         # Profile management hook
│   └── useSettings.ts        # Settings management hook
├── pages/
│   ├── api/
│   │   └── user/
│   │       ├── profile.ts    # Profile API endpoint
│   │       └── settings.ts   # Settings API endpoint
│   └── user/
│       ├── profile.tsx       # Profile page
│       └── settings.tsx      # Settings page
├── components/
│   ├── ErrorBoundary.tsx    # Error boundary component
│   └── LoadingSpinner.tsx   # Loading component
└── types/
    └── database.ts           # Shared type definitions
```

#### Code Quality

- Use ESLint and Prettier for consistent code style
- Implement comprehensive TypeScript types
- Write unit tests for critical functions
- Use meaningful variable and function names
- Keep functions small and focused on single responsibilities

### 4. Testing Strategy

#### Unit Testing Example

```typescript
// __tests__/database.test.ts
import { upsertUser, getUser } from "../src/lib/database";

describe("Database Functions", () => {
  test("upsertUser creates new user", async () => {
    const auth0User = {
      sub: "test-user-123",
      email: "test@example.com",
      name: "Test User",
    };

    const result = await upsertUser(auth0User);

    expect(result.id).toBe(auth0User.sub);
    expect(result.email).toBe(auth0User.email);
    expect(result.name).toBe(auth0User.name);
  });

  test("getUser returns existing user", async () => {
    const userId = "test-user-123";
    const user = await getUser(userId);

    expect(user).toBeTruthy();
    expect(user?.id).toBe(userId);
  });
});
```

#### Integration Testing

```typescript
// __tests__/api.test.ts
import { createMocks } from "node-mocks-http";
import handler from "../src/pages/api/user/profile";

describe("/api/user/profile", () => {
  test("returns 401 for unauthenticated request", async () => {
    const { req, res } = createMocks({
      method: "GET",
    });

    await handler(req, res);

    expect(res._getStatusCode()).toBe(401);
  });
});
```

---

## Conclusion

This enhanced guide provides a comprehensive, production-ready approach to integrating Auth0 authentication with a PostgreSQL database in a Next.js application. By following these practices and using the provided code examples, you'll have a robust, secure, and maintainable authentication and data persistence system.

The key improvements include:

- **Enhanced error handling** with custom error classes and detailed logging
- **Comprehensive input validation** for security and data integrity
- **Advanced migration framework** with rollback capabilities and checksums
- **Performance optimizations** including caching and proper indexing
- **Production monitoring** with health checks and structured logging
- **Comprehensive testing strategy** with examples for unit and integration tests
- **Security best practices** throughout the entire stack

Remember to always test thoroughly in a development environment before deploying to production, and consider implementing additional monitoring and alerting for production deployments.
