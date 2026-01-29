# VibeCoder Database Migration Guide

## Overview

This guide documents best practices for evolving the database schema in VibeCoder, focusing on zero-downtime migrations, versioning, and maintaining data integrity throughout the schema evolution process.

## Migration Framework

### Prisma Migrate

VibeCoder uses Prisma Migrate for managing database schema changes. This tool provides:

1. **Version-controlled migrations**: Track and apply schema changes in a reliable, consistent manner
2. **Declarative schema definition**: Define your schema in Prisma Schema Language
3. **Automatic migration generation**: Generate SQL from schema changes
4. **Type-safe client generation**: Update TypeScript types to match schema changes

### Migration Workflow

> **🚨 CRITICAL RULE:** Database schema changes must ALWAYS be deployed BEFORE code that uses them. Never deploy frontend code that expects database columns that don't exist yet.

**Deployment Order (MANDATORY):**
1. Deploy database migration to production
2. Verify migration success
3. Deploy application code that uses new schema
4. Never reverse this order

1. **Update schema.prisma file**

   ```prisma
   // prisma/schema.prisma
   model User {
     id            String    @id @default(uuid())
     email         String    @unique
     name          String
     organizationId String
     organization  Organization @relation(fields: [organizationId], references: [id])
     profile       Profile?
     // New field being added
     lastLoginAt   DateTime?
     createdAt     DateTime  @default(now())
     updatedAt     DateTime  @updatedAt
   }
   ```

2. **Generate migration**

   ```bash
   # Generate migration files with descriptive name
   npx prisma migrate dev --name add_last_login_timestamp
   ```

3. **Review generated SQL**

   ```sql
   -- prisma/migrations/20250601120000_add_last_login_timestamp/migration.sql
   ALTER TABLE "User" ADD COLUMN "lastLoginAt" TIMESTAMP;
   ```

4. **Apply migration**

   ```bash
   # Development
   npx prisma migrate dev

   # Production
   npx prisma migrate deploy
   ```

5. **Update client types**
   ```bash
   npx prisma generate
   ```

## Zero-Downtime Migration Patterns

### Safe vs. Unsafe Migrations

#### Safe Migrations (Zero-Downtime)

Operations that can be performed while the application is running:

1. **Adding columns** (with appropriate defaults or nullable)
2. **Adding tables**
3. **Adding indexes** (with `CONCURRENTLY` in PostgreSQL)
4. **Adding constraints** that don't validate existing data

```sql
-- Safe: Adding new nullable column
ALTER TABLE "User" ADD COLUMN "preferences" JSONB;

-- Safe: Adding new column with default
ALTER TABLE "Task" ADD COLUMN "priority" INTEGER NOT NULL DEFAULT 1;

-- Safe: Adding new index concurrently
CREATE INDEX CONCURRENTLY "Task_assignedToId_idx" ON "Task"("assignedToId");
```

#### Unsafe Migrations (Require Downtime or Special Handling)

Operations that may block or require careful handling:

1. **Adding NOT NULL constraints** to existing columns
2. **Renaming columns or tables**
3. **Dropping columns or tables**
4. **Changing column types**

### Multi-Phase Migration Patterns

For potentially unsafe changes, use multi-phase migration patterns spread across multiple deployments:

#### Pattern 1: Adding NOT NULL Constraint

```
Phase 1: Add nullable column + Modify application to write to it
Phase 2: Backfill existing rows
Phase 3: Add NOT NULL constraint
```

**Example:**

```sql
-- Phase 1: Add nullable column
ALTER TABLE "Project" ADD COLUMN "status" TEXT;

-- Phase 2: Backfill data (in a separate migration)
UPDATE "Project" SET "status" = 'ACTIVE' WHERE "status" IS NULL;

-- Phase 3: Add NOT NULL constraint (in a separate migration)
ALTER TABLE "Project" ALTER COLUMN "status" SET NOT NULL;
```

#### Pattern 2: Renaming Columns

```
Phase 1: Add new column + Modify application to write to both
Phase 2: Copy data from old column to new
Phase 3: Modify application to only use new column
Phase 4: Drop old column
```

**Example:**

```sql
-- Phase 1: Add new column
ALTER TABLE "User" ADD COLUMN "fullName" TEXT;

-- Phase 2: Copy data (in a separate migration)
UPDATE "User" SET "fullName" = "name" WHERE "fullName" IS NULL;

-- Phase 3: Application now reads from fullName (code change)

-- Phase 4: Drop old column (in a separate migration)
ALTER TABLE "User" DROP COLUMN "name";
```

#### Pattern 3: Changing Column Types

```
Phase 1: Add new column with new type + Modify application to write to both
Phase 2: Convert and copy data from old column to new
Phase 3: Modify application to only use new column
Phase 4: Drop old column
```

**Example:**

```sql
-- Phase 1: Add new column with new type
ALTER TABLE "Task" ADD COLUMN "dueDate_new" TIMESTAMP;

-- Phase 2: Convert and copy data (in a separate migration)
UPDATE "Task" SET "dueDate_new" = "dueDate"::TIMESTAMP WHERE "dueDate" IS NOT NULL;

-- Phase 3: Application now uses dueDate_new (code change)

-- Phase 4: Rename columns (in a separate migration)
ALTER TABLE "Task" DROP COLUMN "dueDate";
ALTER TABLE "Task" RENAME COLUMN "dueDate_new" TO "dueDate";
```

### Large Data Migrations

For tables with large amounts of data, use batching to avoid long-running transactions:

```typescript
// scripts/migrations/backfill-project-status.ts
import { PrismaClient } from "@prisma/client";

async function backfillProjectStatus() {
  const prisma = new PrismaClient();
  let processed = 0;
  const batchSize = 1000;
  let hasMore = true;
  let lastId = "";

  console.log("Starting project status backfill...");

  while (hasMore) {
    // Process in batches using cursor-based pagination
    const projects = await prisma.project.findMany({
      where: {
        id: { gt: lastId },
        status: null,
      },
      orderBy: { id: "asc" },
      take: batchSize,
      select: { id: true },
    });

    if (projects.length === 0) {
      hasMore = false;
      break;
    }

    // Update projects in this batch
    await prisma.project.updateMany({
      where: {
        id: { in: projects.map((p) => p.id) },
      },
      data: {
        status: "ACTIVE",
      },
    });

    // Update progress tracking
    processed += projects.length;
    lastId = projects[projects.length - 1].id;

    console.log(`Processed ${processed} projects so far...`);
  }

  console.log(`Backfill complete. Updated ${processed} projects.`);
  await prisma.$disconnect();
}

backfillProjectStatus().catch((e) => {
  console.error("Error during backfill:", e);
  process.exit(1);
});
```

## Managing Tenant-Specific Migrations

### Organization-Scoped Migrations

For changes that need to be applied to specific tenants:

```typescript
// scripts/migrations/per-tenant-migration.ts
import { PrismaClient } from "@prisma/client";

async function migrateOrganization(organizationId: string) {
  const prisma = new PrismaClient();

  console.log(`Migrating organization: ${organizationId}`);

  try {
    // Set tenant context for RLS
    await prisma.$executeRaw`SELECT set_tenant_context(${organizationId}::uuid)`;

    // Perform tenant-specific migration
    const result = await prisma.$transaction(async (tx) => {
      // Get all projects
      const projects = await tx.project.findMany({
        where: { organizationId },
      });

      // Update each project
      for (const project of projects) {
        await tx.project.update({
          where: { id: project.id },
          data: {
            // Tenant-specific changes
            settings: {
              ...project.settings,
              newFeatureEnabled: true,
            },
          },
        });
      }

      return projects.length;
    });

    console.log(
      `Successfully migrated ${result} projects for organization ${organizationId}`
    );
  } catch (error) {
    console.error(`Error migrating organization ${organizationId}:`, error);
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}

async function migrateAllOrganizations() {
  const prisma = new PrismaClient();

  try {
    // Get all organizations
    const organizations = await prisma.organization.findMany({
      select: { id: true },
    });

    console.log(`Found ${organizations.length} organizations to migrate`);

    // Migrate each organization
    for (const org of organizations) {
      await migrateOrganization(org.id);
    }

    console.log("All organizations migrated successfully");
  } catch (error) {
    console.error("Migration failed:", error);
  } finally {
    await prisma.$disconnect();
  }
}

migrateAllOrganizations();
```

### Handling Row-Level Security in Migrations

When working with tables that have row-level security policies:

```sql
-- Temporarily disable RLS for migration
ALTER TABLE "Project" DISABLE ROW LEVEL SECURITY;

-- Perform migration operations
UPDATE "Project" SET "status" = 'ACTIVE' WHERE "status" IS NULL;

-- Re-enable RLS
ALTER TABLE "Project" ENABLE ROW LEVEL SECURITY;
```

## Migration Testing

### Pre-Migration Validation

Before applying migrations to production, validate them:

```typescript
// scripts/validate-migration.ts
import { PrismaClient } from "@prisma/client";
import { execSync } from "child_process";

async function validateMigration() {
  console.log("Creating test database...");
  execSync("createdb vibecoder_migration_test");

  // Apply migrations to test database
  process.env.DATABASE_URL =
    "postgresql://postgres:postgres@localhost:5432/vibecoder_migration_test";
  execSync("npx prisma migrate deploy");

  // Validate application can connect
  const prisma = new PrismaClient();
  try {
    console.log("Testing database connection...");
    await prisma.$connect();
    console.log("Connection successful!");

    // Run validation queries
    console.log("Running validation queries...");

    // Check schema matches expectations
    const tables = await prisma.$queryRaw`
      SELECT tablename FROM pg_catalog.pg_tables 
      WHERE schemaname = 'public'
    `;
    console.log(`Found ${tables.length} tables`);

    // Test basic queries on critical tables
    const userCount = await prisma.user.count();
    console.log(`User table accessible, contains ${userCount} rows`);

    // Add more validation as needed

    console.log("Migration validation successful!");
  } catch (error) {
    console.error("Migration validation failed:", error);
    process.exit(1);
  } finally {
    await prisma.$disconnect();

    // Clean up test database
    console.log("Cleaning up test database...");
    execSync("dropdb vibecoder_migration_test");
  }
}

validateMigration();
```

### Rollback Testing

Test rollback procedures for critical migrations:

```typescript
// scripts/test-migration-rollback.ts
import { execSync } from "child_process";

function testMigrationRollback(migrationId: string) {
  console.log(`Testing rollback for migration: ${migrationId}`);

  // Create test database
  execSync("createdb vibecoder_rollback_test");

  // Set environment to test database
  process.env.DATABASE_URL =
    "postgresql://postgres:postgres@localhost:5432/vibecoder_rollback_test";

  try {
    // Apply migrations up to the target
    console.log(`Applying migrations up to ${migrationId}...`);
    execSync(`npx prisma migrate resolve --applied ${migrationId}`);

    // Test the rollback
    console.log(`Testing rollback of ${migrationId}...`);
    execSync(`npx prisma migrate resolve --rolled-back ${migrationId}`);

    console.log("Rollback successful!");
  } catch (error) {
    console.error("Rollback test failed:", error);
    process.exit(1);
  } finally {
    // Clean up
    execSync("dropdb vibecoder_rollback_test");
  }
}

// Usage: Pass migration ID as argument
const migrationId = process.argv[2];
if (!migrationId) {
  console.error("Please provide a migration ID");
  process.exit(1);
}

testMigrationRollback(migrationId);
```

## Managing Migration Scripts

### Migration Scripts Organization

```
prisma/
├── schema.prisma           # Prisma schema file
├── migrations/             # Generated migrations
│   ├── 20250601120000_add_last_login/
│   │   ├── migration.sql   # Generated SQL
│   ├── 20250602150000_create_user_settings/
│   │   ├── migration.sql
│   └── migration_lock.toml # Lock file
└── seed.ts                 # Seed script
scripts/
├── migrations/             # Custom migration scripts
│   ├── backfill-data.ts    # Data migration script
│   ├── per-tenant-migration.ts
│   └── validate-migration.ts
```

### Versioning and Documentation

Document each migration with detailed notes on what changed and why:

```sql
-- prisma/migrations/20250605123000_add_subscription_features/migration.sql

-- This migration adds support for subscription features
-- It creates a many-to-many relationship between subscription plans and features

-- 1. Create features table
CREATE TABLE "Feature" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "name" TEXT NOT NULL,
  "code" TEXT NOT NULL,
  "description" TEXT,
  "createdAt" TIMESTAMP NOT NULL DEFAULT NOW(),
  "updatedAt" TIMESTAMP NOT NULL DEFAULT NOW(),

  CONSTRAINT "Feature_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "Feature_code_key" UNIQUE ("code")
);

-- 2. Create junction table for many-to-many relationship
CREATE TABLE "PlanFeature" (
  "planId" UUID NOT NULL,
  "featureId" UUID NOT NULL,
  "createdAt" TIMESTAMP NOT NULL DEFAULT NOW(),

  CONSTRAINT "PlanFeature_pkey" PRIMARY KEY ("planId", "featureId"),
  CONSTRAINT "PlanFeature_planId_fkey" FOREIGN KEY ("planId") REFERENCES "SubscriptionPlan"("id") ON DELETE CASCADE,
  CONSTRAINT "PlanFeature_featureId_fkey" FOREIGN KEY ("featureId") REFERENCES "Feature"("id") ON DELETE CASCADE
);

-- 3. Index for feature lookups by plan
CREATE INDEX "PlanFeature_planId_idx" ON "PlanFeature"("planId");

-- 4. Add RLS policies
ALTER TABLE "Feature" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "PlanFeature" ENABLE ROW LEVEL SECURITY;

-- Features are platform-level (no tenant isolation)
CREATE POLICY "platform_users_can_read_features" ON "Feature"
  FOR SELECT USING (true);

-- Plan features have tenant isolation via the plan relationship
CREATE POLICY "tenant_isolation_plan_features" ON "PlanFeature"
  USING (EXISTS (
    SELECT 1 FROM "SubscriptionPlan" sp
    WHERE sp.id = "PlanFeature"."planId"
    AND sp."organizationId" = current_setting('app.current_tenant_id')::UUID
  ));

-- Migration note: After applying this migration, run the feature seeding script:
-- npm run script:seed-features
```

## Deployment Strategy

### Critical Production Lessons (v2.1.1)

**Real-World Example:** During v2.1.1 story points implementation:
- ❌ **What Went Wrong:** Deployed frontend code expecting `story_points` column before database migration
- 💥 **Impact:** Task Manager completely broke in production with database errors  
- ✅ **Solution:** Applied migration via API endpoint, verified 297 tasks updated successfully
- 📚 **Lesson:** Always migrate database FIRST, then deploy code

**Mandatory Deployment Order:**
1. ✅ Deploy database migration to production
2. ✅ Verify migration success (check row counts, test queries)
3. ✅ Deploy application code that uses new schema
4. ❌ **NEVER reverse this order**

### Migration Planning

For each production migration:

1. **Assess Impact**

   - Will this migration block writes?
   - How long will it take to complete?
   - Can it be done zero-downtime?

2. **Plan Execution**

   - Schedule during low-traffic periods if necessary
   - Prepare rollback plan
   - Document steps and expected outcomes

3. **Testing**
   - Test on staging environment with production-like data
   - Validate both migration and rollback procedures
   - Measure execution time to estimate production impact

### Deployment Procedure

```bash
# 1. Backup database before migration
pg_dump -Fc -d vibecoder_production > pre_migration_backup.dump

# 2. Apply migration
npx prisma migrate deploy

# 3. Run post-migration scripts if needed
node scripts/migrations/post-deploy-hooks.js

# 4. Verify migration success
npx prisma db execute --file scripts/migrations/verification.sql
```

### Monitoring During Migration

Monitor database during migration execution:

```sql
-- Check for long-running queries
SELECT pid, now() - pg_stat_activity.query_start AS duration, query
FROM pg_stat_activity
WHERE state = 'active' AND now() - pg_stat_activity.query_start > interval '5 minutes'
ORDER BY duration DESC;

-- Check for locks
SELECT relation::regclass, mode, granted, pid, pg_blocking_pids(pid) as blocked_by
FROM pg_locks
WHERE NOT granted OR pg_blocking_pids(pid) <> '{}';
```

## Handling Migration Failures

### Rollback Procedures

If a migration fails, follow these steps:

1. **Assess Impact**

   - Is the application still functional?
   - What data might be affected?
   - How urgent is a rollback?

2. **Manual Rollback**

   ```bash
   # Rollback specific migration
   npx prisma migrate resolve --rolled-back 20250601120000_add_last_login

   # If needed, restore from backup
   pg_restore -d vibecoder_production pre_migration_backup.dump
   ```

3. **Post-Rollback Verification**

   ```bash
   # Verify application can connect
   npx prisma db execute --file scripts/migrations/health-check.sql

   # Check for data integrity
   node scripts/migrations/verify-integrity.js
   ```

### Retry Strategy

For failed migrations that need to be retried:

```bash
# Fix issues in migration files

# Clear migration state for specific migration
npx prisma migrate resolve --rolled-back 20250601120000_add_last_login

# Retry with fixed migration
npx prisma migrate deploy
```

## Migration Best Practices

1. **Plan for Zero-Downtime**

   - Use multi-phase migration patterns for potentially blocking changes
   - Test performance impact before production deployment

2. **Version Control Everything**

   - Keep all migration files in version control
   - Document migration purpose, impact, and post-deployment steps

3. **Use Transactions**

   - Wrap related changes in transactions
   - Ensure atomic application of changes

4. **Batch Large Data Changes**

   - Process large data migrations in small batches
   - Consider running data migrations outside of schema migrations

5. **Test Thoroughly**

   - Validate migrations on staging environment
   - Test rollback procedures
   - Measure performance impact

6. **Monitor Carefully**

   - Watch for locks during migration
   - Monitor application performance after migration
   - Check for unexpected query patterns

7. **Preserve Data**
   - Prefer adding over removing
   - Take backups before critical migrations
   - Have a tested restore procedure

## Conclusion

Database schema evolution is a critical aspect of application development. By following these patterns and practices, you can evolve your database schema safely, maintain data integrity, and minimize disruption to users.

Remember that database migrations should be:

- **Incremental**: Small, focused changes
- **Reversible**: Able to be rolled back if needed
- **Tested**: Validated before production deployment
- **Documented**: Clear purpose and impact

This guide should be updated as new migration patterns and best practices emerge in the VibeCoder project.
