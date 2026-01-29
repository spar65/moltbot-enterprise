# Database Environment Management Guide

This guide establishes patterns for managing database connections, configurations, and data across different environments (development, testing, staging, and production).

## Overview

Maintaining proper isolation between database environments is critical for:

1. **Development Safety**: Preventing accidental changes to production data
2. **Testing Reliability**: Ensuring tests run against consistent, isolated data
3. **Staging Accuracy**: Providing a production-like environment without affecting real users
4. **Production Integrity**: Protecting production data from development/testing influences

This guide outlines strategies for managing environment-specific database configurations, connection handling, data seeding, and schema synchronization.

## Environment-Specific Database Configuration

### Connection String Management

Each environment should have its own dedicated connection string managed securely:

```typescript
// src/lib/database.ts
import { neon } from "@neondatabase/serverless";

// Environment-aware database connection
export function getDatabaseConnection() {
  const environment = process.env.NODE_ENV || "development";

  // Map environment to appropriate connection variable
  const connectionVarName =
    environment === "production"
      ? "DATABASE_URL"
      : environment === "staging"
      ? "STAGING_DATABASE_URL"
      : environment === "test"
      ? "TEST_DATABASE_URL"
      : "DEV_DATABASE_URL";

  // Get connection string for this environment
  const connectionString = process.env[connectionVarName];

  if (!connectionString) {
    throw new Error(
      `No database connection string found for environment: ${environment}`
    );
  }

  // Create and return database client
  try {
    return neon(connectionString);
  } catch (error) {
    console.error(`Failed to initialize database for ${environment}:`, error);
    throw error;
  }
}
```

### Environment Variables Structure

Structure your `.env` files to clearly separate database connections by environment:

```bash
# .env.development
DEV_DATABASE_URL=postgres://user:password@dev-db.example.com:5432/myapp_dev

# .env.test
TEST_DATABASE_URL=postgres://user:password@test-db.example.com:5432/myapp_test

# .env.staging
STAGING_DATABASE_URL=postgres://user:password@staging-db.example.com:5432/myapp_staging

# .env.production
DATABASE_URL=postgres://user:password@production-db.example.com:5432/myapp_prod
```

### Connection Pool Configuration

Adjust connection pool settings based on environment needs:

```typescript
function getConnectionPoolConfig() {
  const environment = process.env.NODE_ENV || "development";

  // Base configuration
  const config = {
    min: 1,
    max: 10,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
  };

  // Environment-specific overrides
  switch (environment) {
    case "production":
      return {
        ...config,
        min: 5,
        max: 50,
        idleTimeoutMillis: 60000,
      };
    case "staging":
      return {
        ...config,
        min: 2,
        max: 20,
      };
    case "test":
      return {
        ...config,
        min: 1,
        max: 5,
        idleTimeoutMillis: 10000,
      };
    default: // development
      return config;
  }
}
```

## Database Initialization & Schema Management

### Environment-Aware Schema Initialization

Create an initialization script that handles environment-specific setup:

```typescript
// scripts/init-database.ts
import { PrismaClient } from "@prisma/client";
import fs from "fs";
import path from "path";

async function initializeDatabase() {
  const environment = process.env.NODE_ENV || "development";
  console.log(`Initializing database for environment: ${environment}`);

  const prisma = new PrismaClient();

  try {
    // Basic connection test
    await prisma.$queryRaw`SELECT 1`;
    console.log("✅ Database connection successful");

    // Apply schema migrations
    await applyMigrations(environment);

    // Seed environment-specific data
    if (environment !== "production") {
      await seedDatabase(environment, prisma);
    }

    console.log(`✅ Database initialization complete for ${environment}`);
  } catch (error) {
    console.error(
      `❌ Database initialization failed for ${environment}:`,
      error
    );
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

async function applyMigrations(environment: string) {
  // Implementation depends on your migration strategy
  // (Prisma Migrate, custom SQL, etc.)
}

async function seedDatabase(environment: string, prisma: PrismaClient) {
  const seedFile = path.join(
    __dirname,
    "..",
    "prisma",
    "seeds",
    `${environment}.ts`
  );

  if (fs.existsSync(seedFile)) {
    console.log(`🌱 Seeding database with ${environment}-specific data`);
    // Import and run the environment-specific seed function
    const { seed } = require(seedFile);
    await seed(prisma);
  } else {
    console.log(`❓ No seed file found for ${environment}`);
  }
}

initializeDatabase().catch(console.error);
```

### Environment-Specific Migration Validation

Validate migrations before applying them to sensitive environments:

```typescript
// scripts/validate-migrations.ts
import { PrismaClient } from "@prisma/client";
import { execSync } from "child_process";

async function validateMigrations() {
  const environment = process.env.TARGET_ENV || "development";
  console.log(`Validating migrations for target environment: ${environment}`);

  if (environment === "production" || environment === "staging") {
    // Create a temporary database for validation
    const tempDbName = `migration_validation_${Date.now()}`;

    try {
      // Create temp database (implementation depends on your setup)
      console.log(`Creating temporary database: ${tempDbName}`);
      execSync(`createdb ${tempDbName}`);

      // Set environment variable to point to temp database
      process.env.MIGRATION_VALIDATION_DB_URL = `postgres://localhost:5432/${tempDbName}`;

      // Run migrations on temp database
      console.log("Applying migrations to temporary database...");
      execSync("npx prisma migrate deploy", {
        env: {
          ...process.env,
          DATABASE_URL: process.env.MIGRATION_VALIDATION_DB_URL,
        },
      });

      // Validate database state
      await validateDatabaseState(tempDbName);

      console.log("✅ Migration validation successful");
    } catch (error) {
      console.error("❌ Migration validation failed:", error);
      process.exit(1);
    } finally {
      // Cleanup temp database
      console.log(`Cleaning up temporary database: ${tempDbName}`);
      execSync(`dropdb ${tempDbName}`);
    }
  } else {
    console.log(`Skipping detailed validation for ${environment} environment`);
  }
}

async function validateDatabaseState(dbName: string) {
  const prisma = new PrismaClient({
    datasources: {
      db: {
        url: process.env.MIGRATION_VALIDATION_DB_URL,
      },
    },
  });

  try {
    // Perform validation queries
    console.log("Validating database schema integrity...");

    // Example: Check if critical tables exist
    const userTable = await prisma.$queryRaw`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'users'
      );
    `;

    // Check for potential data loss operations
    const potentialDataLoss = checkForDataLossOperations();
    if (potentialDataLoss) {
      throw new Error("Migration contains operations that may cause data loss");
    }

    // Add more validation as needed
  } finally {
    await prisma.$disconnect();
  }
}

function checkForDataLossOperations() {
  // Analyze migration files for ALTER TABLE DROP COLUMN, etc.
  // Return true if potentially destructive operations found
  return false;
}

validateMigrations().catch(console.error);
```

## Environment Isolation Strategies

### Test Environment Data Management

For test environments, implement a clean slate approach:

```typescript
// src/test/setup-database.ts
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

// Setup function to run before tests
export async function setupTestDatabase() {
  // Ensure we're in test environment
  if (process.env.NODE_ENV !== "test") {
    throw new Error(
      "setupTestDatabase should only be called in test environment"
    );
  }

  try {
    // Truncate all tables for a clean slate
    await clearDatabase();

    // Seed with minimal test data
    await seedTestData();
  } catch (error) {
    console.error("Test database setup failed:", error);
    throw error;
  }
}

async function clearDatabase() {
  const tableNames = await getTableNames();

  // Disable foreign key checks temporarily
  await prisma.$executeRaw`SET FOREIGN_KEY_CHECKS = 0;`;

  // Truncate all tables
  for (const tableName of tableNames) {
    await prisma.$executeRaw`TRUNCATE TABLE ${tableName};`;
  }

  // Re-enable foreign key checks
  await prisma.$executeRaw`SET FOREIGN_KEY_CHECKS = 1;`;
}

async function getTableNames() {
  const results = await prisma.$queryRaw`
    SELECT table_name 
    FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_type = 'BASE TABLE';
  `;

  return results.map((r: any) => r.table_name);
}

async function seedTestData() {
  // Insert minimal data required for tests
  await prisma.user.create({
    data: {
      id: "test-user-id",
      email: "test@example.com",
      name: "Test User",
      // Add other required fields
    },
  });

  // Add other test data as needed
}

// Cleanup function to run after tests
export async function teardownTestDatabase() {
  await prisma.$disconnect();
}
```

### Development Environment Reset

Provide a utility to reset development databases:

```typescript
// scripts/reset-dev-database.ts
import { execSync } from "child_process";
import { PrismaClient } from "@prisma/client";

async function resetDevDatabase() {
  // Ensure we're in development environment
  if (process.env.NODE_ENV !== "development") {
    throw new Error("This script can only be run in development environment");
  }

  const prisma = new PrismaClient();

  try {
    console.log("🗄️ Resetting development database...");

    // Drop all tables
    await dropAllTables(prisma);

    // Re-apply all migrations
    console.log("📦 Applying migrations...");
    execSync("npx prisma migrate dev", { stdio: "inherit" });

    // Seed with development data
    console.log("🌱 Seeding development data...");
    execSync("npx prisma db seed", { stdio: "inherit" });

    console.log("✅ Development database reset successfully");
  } catch (error) {
    console.error("❌ Failed to reset development database:", error);
  } finally {
    await prisma.$disconnect();
  }
}

async function dropAllTables(prisma: PrismaClient) {
  // Disable foreign key checks
  await prisma.$executeRaw`SET FOREIGN_KEY_CHECKS = 0;`;

  // Get all tables
  const tables = await prisma.$queryRaw`
    SELECT table_name 
    FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_type = 'BASE TABLE';
  `;

  // Drop each table
  for (const { table_name } of tables as any[]) {
    console.log(`Dropping table: ${table_name}`);
    await prisma.$executeRaw`DROP TABLE IF EXISTS "${table_name}" CASCADE;`;
  }

  // Re-enable foreign key checks
  await prisma.$executeRaw`SET FOREIGN_KEY_CHECKS = 1;`;
}

resetDevDatabase().catch(console.error);
```

### Production Data Protection

Implement safeguards to prevent accidental modification of production data:

```typescript
// src/lib/database-safety.ts
import { PrismaClient } from "@prisma/client";

// Create a safety wrapper around Prisma
export function createSafePrismaClient() {
  const prisma = new PrismaClient();
  const environment = process.env.NODE_ENV || "development";

  // In production, add extra safeguards for destructive operations
  if (environment === "production") {
    const originalDelete = prisma.user.deleteMany;
    const originalUpdate = prisma.user.updateMany;

    // Override deleteMany to require explicit confirmation
    prisma.user.deleteMany = async (args: any) => {
      // Check for confirmation flag
      if (!args?._safety?.confirmDelete) {
        throw new Error(
          "Delete operations in production require explicit confirmation. " +
            "Add { _safety: { confirmDelete: true } } to your query."
        );
      }

      // Remove safety object before passing to original function
      const { _safety, ...safeArgs } = args;
      return originalDelete.call(prisma.user, safeArgs);
    };

    // Similarly for updateMany
    prisma.user.updateMany = async (args: any) => {
      // Check for bulk updates without where clause
      if (!args.where || Object.keys(args.where).length === 0) {
        throw new Error(
          "Bulk updates without where clause are not allowed in production. " +
            "Specify a where condition to target specific records."
        );
      }

      return originalUpdate.call(prisma.user, args);
    };

    // Apply similar protections to other models
  }

  return prisma;
}
```

## Environment-Specific Data Seeding

### Seed Data Structure

Organize seed data by environment:

```
/prisma
  /seeds
    /development.ts  # Full development dataset
    /test.ts         # Minimal test dataset
    /staging.ts      # Representative production-like data
    /shared          # Data shared across environments
      /users.ts
      /products.ts
```

### Example Seed Implementation

```typescript
// prisma/seeds/development.ts
import { PrismaClient } from "@prisma/client";
import { users } from "./shared/users";
import { products } from "./shared/products";

export async function seed(prisma: PrismaClient) {
  // Seed users
  console.log("Seeding development users...");
  for (const user of users.development) {
    await prisma.user.upsert({
      where: { email: user.email },
      update: user,
      create: user,
    });
  }

  // Seed products
  console.log("Seeding development products...");
  for (const product of products.development) {
    await prisma.product.upsert({
      where: { sku: product.sku },
      update: product,
      create: product,
    });
  }

  // Seed development-specific data
  console.log("Seeding development-specific data...");

  // Add many test organizations
  await prisma.organization.createMany({
    data: Array.from({ length: 10 }).map((_, i) => ({
      name: `Test Organization ${i + 1}`,
      planId: i % 3 === 0 ? "pro" : "basic",
    })),
  });

  console.log("✅ Development seed completed");
}
```

```typescript
// prisma/seeds/test.ts
import { PrismaClient } from "@prisma/client";
import { users } from "./shared/users";
import { products } from "./shared/products";

export async function seed(prisma: PrismaClient) {
  // Seed minimal test data
  console.log("Seeding test users...");
  await prisma.user.create({
    data: users.test.admin,
  });

  await prisma.user.create({
    data: users.test.regularUser,
  });

  // Seed test organization
  console.log("Seeding test organization...");
  await prisma.organization.create({
    data: {
      id: "test-org-id",
      name: "Test Organization",
      planId: "basic",
      members: {
        connect: [
          { id: users.test.admin.id },
          { id: users.test.regularUser.id },
        ],
      },
    },
  });

  // Seed minimal product data
  console.log("Seeding test products...");
  await prisma.product.createMany({
    data: products.test,
  });

  console.log("✅ Test seed completed");
}
```

## Cross-Environment Data Migration

### Production Data Sanitization for Staging

Create a utility to copy production data to staging with sanitization:

```typescript
// scripts/copy-prod-to-staging.ts
import { PrismaClient } from "@prisma/client";
import { createHash } from "crypto";

async function copyProductionToStaging() {
  // Connect to both databases
  const prodPrisma = new PrismaClient({
    datasources: {
      db: {
        url: process.env.PRODUCTION_DATABASE_URL,
      },
    },
  });

  const stagingPrisma = new PrismaClient({
    datasources: {
      db: {
        url: process.env.STAGING_DATABASE_URL,
      },
    },
  });

  try {
    console.log(
      "Starting production to staging data copy with sanitization..."
    );

    // Clear staging database
    await clearStagingDatabase(stagingPrisma);

    // Copy and sanitize users
    await copyAndSanitizeUsers(prodPrisma, stagingPrisma);

    // Copy other data
    await copyOrganizations(prodPrisma, stagingPrisma);
    await copyProducts(prodPrisma, stagingPrisma);
    // Add other tables as needed

    console.log("✅ Data copy completed successfully");
  } catch (error) {
    console.error("❌ Data copy failed:", error);
  } finally {
    await prodPrisma.$disconnect();
    await stagingPrisma.$disconnect();
  }
}

async function clearStagingDatabase(prisma: PrismaClient) {
  // Similar to development reset, truncate all tables
}

async function copyAndSanitizeUsers(
  prodPrisma: PrismaClient,
  stagingPrisma: PrismaClient
) {
  console.log("Copying and sanitizing users...");

  // Get all users from production
  const users = await prodPrisma.user.findMany();

  // Process in batches to avoid memory issues
  const batchSize = 100;
  for (let i = 0; i < users.length; i += batchSize) {
    const batch = users.slice(i, i + batchSize);

    // Sanitize each user
    const sanitizedUsers = batch.map((user) => {
      // Keep ID and basic info, sanitize sensitive data
      return {
        id: user.id,
        email: sanitizeEmail(user.email),
        name: user.name,
        // Hash or anonymize other PII
        phone: user.phone ? "XXXXX-XXXXX" : null,
        // Mask other sensitive fields
        password_hash: "REDACTED",
        // Keep non-sensitive data
        created_at: user.created_at,
        updated_at: user.updated_at,
      };
    });

    // Insert sanitized batch into staging
    await stagingPrisma.user.createMany({
      data: sanitizedUsers,
      skipDuplicates: true,
    });
  }

  console.log(`Sanitized ${users.length} users`);
}

function sanitizeEmail(email: string): string {
  // Keep domain for testing, hash local part
  const [localPart, domain] = email.split("@");
  const hashedLocal = createHash("md5")
    .update(localPart)
    .digest("hex")
    .substring(0, 8);
  return `${hashedLocal}@${domain}`;
}

// Implement other copy functions similarly
async function copyOrganizations(
  prodPrisma: PrismaClient,
  stagingPrisma: PrismaClient
) {
  // Copy organization data
}

async function copyProducts(
  prodPrisma: PrismaClient,
  stagingPrisma: PrismaClient
) {
  // Copy product data
}

copyProductionToStaging().catch(console.error);
```

## Environment-Specific Configuration Validation

### Database Environment Verification

Implement a startup check to validate the environment configuration:

```typescript
// src/lib/database-environment-check.ts
import { PrismaClient } from "@prisma/client";

export async function validateDatabaseEnvironment() {
  const environment = process.env.NODE_ENV || "development";
  const prisma = new PrismaClient();

  try {
    // Simple connection test
    await prisma.$queryRaw`SELECT 1 as test`;

    // Check for appropriate database name
    const dbInfo = await prisma.$queryRaw`SELECT current_database()`;
    const dbName = dbInfo[0].current_database;

    // Verify database name matches environment
    const expectedPattern = new RegExp(
      `${environment}|${environment.substring(0, 4)}`
    );
    if (!expectedPattern.test(dbName.toLowerCase())) {
      console.warn(
        `⚠️ Potential environment mismatch: Running in ${environment} but connected to database ${dbName}`
      );

      // In production, this is a critical error
      if (
        environment === "production" &&
        !dbName.toLowerCase().includes("prod")
      ) {
        throw new Error(
          `Critical environment mismatch: Production environment connected to non-production database ${dbName}`
        );
      }
    }

    console.log(
      `✅ Database environment validated: ${environment} -> ${dbName}`
    );
  } catch (error) {
    console.error(`❌ Database environment validation failed:`, error);
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}
```

## Conclusion

Proper database environment management is crucial for maintaining data integrity and ensuring reliable application behavior across different stages of development and deployment.

By implementing the strategies outlined in this guide, you can:

1. **Maintain Environment Isolation**: Keep development, testing, staging, and production data separate
2. **Automate Environment Setup**: Simplify the creation and management of consistent database environments
3. **Protect Production Data**: Implement safeguards to prevent accidental changes to production
4. **Support Testing**: Enable reliable and repeatable test scenarios with controlled data
5. **Facilitate Staging**: Create representative production-like environments with sanitized data

Follow these guidelines to establish robust environment management practices and prevent common issues related to database configuration, data isolation, and schema evolution.
