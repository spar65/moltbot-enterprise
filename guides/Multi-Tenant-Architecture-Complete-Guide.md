# Multi-Tenant Architecture Complete Guide

**The definitive guide to building secure, scalable, and performant multi-tenant SaaS applications.**

## Table of Contents

1. [Overview](#overview)
2. [Architecture Patterns](#architecture-patterns)
3. [Data Isolation Strategies](#data-isolation-strategies)
4. [Database Design](#database-design)
5. [Query Optimization](#query-optimization)
6. [Security & Access Control](#security--access-control)
7. [Testing Multi-Tenant Systems](#testing-multi-tenant-systems)
8. [Migration Strategies](#migration-strategies)
9. [Performance Monitoring](#performance-monitoring)
10. [Cost Optimization](#cost-optimization)

---

## Overview

### What is Multi-Tenancy?

> **Multi-tenancy** is an architecture where a single instance of software serves multiple customers (tenants) while keeping their data isolated and secure.

**Benefits**:

- **Cost Efficiency**: Shared infrastructure reduces per-tenant costs
- **Simplified Maintenance**: Single codebase, easier updates
- **Scalability**: Efficient resource utilization
- **Faster Onboarding**: New tenants added instantly

**Challenges**:

- **Data Isolation**: Preventing data leakage between tenants
- **Performance**: "Noisy neighbor" problems
- **Customization**: Balancing standardization with tenant-specific needs
- **Security**: One breach could expose multiple tenants

### Multi-Tenancy Models

```
┌────────────────────────────────────────────────────┐
│          Multi-Tenancy Architecture Models          │
└────────────────────────────────────────────────────┘

1. SHARED DATABASE, SHARED SCHEMA (Most Common)
   ┌─────────────────────────────────────────┐
   │         Single Database Instance         │
   │  ┌─────────────────────────────────┐   │
   │  │    Organizations Table           │   │
   │  │  - org_1 (Acme Corp)            │   │
   │  │  - org_2 (Widget Inc)           │   │
   │  │  - org_3 (Gadget LLC)           │   │
   │  └─────────────────────────────────┘   │
   │  ┌─────────────────────────────────┐   │
   │  │    Users Table                   │   │
   │  │  - user_1 (org_1)               │   │
   │  │  - user_2 (org_1)               │   │
   │  │  - user_3 (org_2)               │   │
   │  │  - user_4 (org_3)               │   │
   │  └─────────────────────────────────┘   │
   └─────────────────────────────────────────┘
   ✅ Most cost-effective
   ✅ Easiest to maintain
   ⚠️  Requires careful query design
   ⚠️  "Noisy neighbor" risk

2. SHARED DATABASE, SEPARATE SCHEMAS
   ┌─────────────────────────────────────────┐
   │         Single Database Instance         │
   │  ┌──────────┐  ┌──────────┐  ┌────────┐│
   │  │ Schema   │  │ Schema   │  │ Schema ││
   │  │ org_1    │  │ org_2    │  │ org_3  ││
   │  │ (Acme)   │  │ (Widget) │  │(Gadget)││
   │  └──────────┘  └──────────┘  └────────┘│
   └─────────────────────────────────────────┘
   ✅ Better isolation
   ✅ Easier to backup individual tenants
   ⚠️  More complex migrations
   ⚠️  Schema proliferation

3. SEPARATE DATABASES (Least Common)
   ┌────────────┐  ┌────────────┐  ┌────────────┐
   │ Database   │  │ Database   │  │ Database   │
   │ org_1      │  │ org_2      │  │ org_3      │
   │ (Acme)     │  │ (Widget)   │  │ (Gadget)   │
   └────────────┘  └────────────┘  └────────────┘
   ✅ Maximum isolation
   ✅ Tenant-specific tuning
   ❌ High operational overhead
   ❌ Most expensive
```

**Our Approach**: **Shared Database, Shared Schema** with Row-Level Security (RLS)

---

## Architecture Patterns

### The Tenant Context Pattern

```typescript
// Tenant context flows through every layer

┌─────────────────────────────────────────────┐
│           HTTP Request                       │
│   Headers: { organizationId: "org-123" }    │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│        Middleware (Tenant Resolver)          │
│  - Extract organizationId from session       │
│  - Validate tenant exists                    │
│  - Attach to request context                 │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│          API Route Handler                   │
│  const { organizationId } = await            │
│    getServerSession();                       │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│        Service Layer                         │
│  async getUsers(organizationId: string)      │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│        Data Access Layer                     │
│  WHERE organizationId = $1                   │
└─────────────────────────────────────────────┘
```

### Implementation

```typescript
// lib/tenant-context.ts
import { getServerSession } from "next-auth";

export interface TenantContext {
  organizationId: string;
  organizationName: string;
  userId: string;
  userRole: string;
}

export async function getTenantContext(): Promise<TenantContext> {
  const session = await getServerSession();

  if (!session?.user) {
    throw new Error("Unauthorized: No active session");
  }

  if (!session.user.organizationId) {
    throw new Error("No organization context");
  }

  return {
    organizationId: session.user.organizationId,
    organizationName: session.user.organizationName,
    userId: session.user.id,
    userRole: session.user.role,
  };
}

// Usage in API routes
export async function GET(request: Request) {
  const { organizationId } = await getTenantContext();

  // All queries automatically scoped to tenant
  const users = await prisma.user.findMany({
    where: { organizationId },
  });

  return Response.json(users);
}
```

---

## Data Isolation Strategies

### Strategy 1: Application-Level Filtering

**How it works**: Application code adds tenant filter to every query

```typescript
// ✅ GOOD: Explicit tenant filtering
async function getUsers(organizationId: string): Promise<User[]> {
  return await prisma.user.findMany({
    where: { organizationId },
  });
}

// ❌ BAD: No tenant filter
async function getUsers(): Promise<User[]> {
  return await prisma.user.findMany();
}
```

**Pros**:

- Simple to implement
- Works with any database
- Full control over queries

**Cons**:

- Easy to forget (security risk!)
- No database-level enforcement
- Requires discipline

---

### Strategy 2: Row-Level Security (RLS)

**How it works**: Database automatically filters rows based on tenant

```sql
-- Enable RLS on table
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Create policy: users can only see their organization's data
CREATE POLICY tenant_isolation ON users
  USING (organization_id = current_setting('app.organization_id')::uuid);

-- Set tenant context for session
SET LOCAL app.organization_id = 'org-123';

-- Query automatically filtered by RLS
SELECT * FROM users;  -- Only returns users from org-123
```

**Pros**:

- **Database enforced** (can't be bypassed!)
- Works even if application code forgets
- Defense in depth

**Cons**:

- Database-specific (PostgreSQL, Oracle)
- Slightly more complex setup
- Performance overhead (small)

---

### Strategy 3: Hybrid Approach (Recommended)

```typescript
// Application-level filtering + RLS for defense in depth

// 1. Set tenant context at connection level
async function withTenantContext<T>(
  organizationId: string,
  callback: () => Promise<T>
): Promise<T> {
  // Set RLS context
  await prisma.$executeRaw`
    SET LOCAL app.organization_id = ${organizationId}
  `;

  try {
    return await callback();
  } finally {
    // Clear context
    await prisma.$executeRaw`
      RESET app.organization_id
    `;
  }
}

// 2. Use in API routes
export async function GET(request: Request) {
  const { organizationId } = await getTenantContext();

  return await withTenantContext(organizationId, async () => {
    // Even if we forget to add organizationId filter,
    // RLS will catch it!
    const users = await prisma.user.findMany({
      where: { organizationId }, // Application filter
    });

    return Response.json(users);
  });
}
```

---

## Database Design

### Schema Design Principles

```prisma
// prisma/schema.prisma

// ✅ Every multi-tenant model MUST have organizationId

model Organization {
  id        String   @id @default(uuid())
  name      String
  slug      String   @unique
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  // Relationships
  users     User[]
  projects  Project[]

  @@index([slug])
}

model User {
  id              String       @id @default(uuid())
  email           String       @unique
  name            String

  // REQUIRED: Tenant isolation
  organizationId  String
  organization    Organization @relation(fields: [organizationId], references: [id], onDelete: Cascade)

  // Relationships
  createdProjects Project[]    @relation("CreatedProjects")

  createdAt       DateTime     @default(now())
  updatedAt       DateTime     @updatedAt

  // CRITICAL: Composite index for tenant-scoped queries
  @@index([organizationId])
  @@index([organizationId, email])
  @@index([organizationId, createdAt])
}

model Project {
  id              String       @id @default(uuid())
  name            String
  description     String?

  // REQUIRED: Tenant isolation
  organizationId  String
  organization    Organization @relation(fields: [organizationId], references: [id], onDelete: Cascade)

  // Creator
  createdById     String
  createdBy       User         @relation("CreatedProjects", fields: [createdById], references: [id])

  createdAt       DateTime     @default(now())
  updatedAt       DateTime     @updatedAt

  // CRITICAL: Indexes for performance
  @@index([organizationId])
  @@index([organizationId, createdAt])
  @@index([organizationId, createdById])
}
```

### Index Strategy

```sql
-- RULE: Every tenant-scoped table needs indexes on organizationId

-- 1. Single-column index (for simple queries)
CREATE INDEX idx_users_organization_id ON users(organization_id);

-- 2. Composite indexes (for filtered + sorted queries)
CREATE INDEX idx_users_org_created ON users(organization_id, created_at DESC);
CREATE INDEX idx_users_org_email ON users(organization_id, email);

-- 3. Covering indexes (for common queries)
CREATE INDEX idx_users_org_name_email
  ON users(organization_id)
  INCLUDE (name, email, created_at);
```

**Index Guidelines**:

- **Always** index `organizationId`
- Add composite indexes for common query patterns
- Consider covering indexes for read-heavy queries
- Monitor index usage with `pg_stat_user_indexes`

---

## Query Optimization

### Common Query Patterns

#### Pattern 1: Simple Tenant-Scoped Query

```typescript
// Get all users in organization
const users = await prisma.user.findMany({
  where: { organizationId },
  orderBy: { createdAt: 'desc' }
});

// Generated SQL (optimized with index)
SELECT * FROM users
WHERE organization_id = 'org-123'
ORDER BY created_at DESC;

-- Uses: idx_users_org_created
```

#### Pattern 2: Filtered Tenant Query

```typescript
// Get active users in organization
const activeUsers = await prisma.user.findMany({
  where: {
    organizationId,
    status: 'ACTIVE'
  },
  orderBy: { name: 'asc' }
});

// Generated SQL
SELECT * FROM users
WHERE organization_id = 'org-123'
  AND status = 'ACTIVE'
ORDER BY name ASC;

-- Needs: idx_users_org_status_name
```

#### Pattern 3: Tenant-Scoped Join

```typescript
// Get projects with creator info
const projects = await prisma.project.findMany({
  where: { organizationId },
  include: {
    createdBy: {
      select: {
        id: true,
        name: true,
        email: true
      }
    }
  }
});

// Generated SQL
SELECT
  p.*,
  u.id, u.name, u.email
FROM projects p
INNER JOIN users u ON p.created_by_id = u.id
WHERE p.organization_id = 'org-123'
  AND u.organization_id = 'org-123';  -- CRITICAL!

-- Both tables filtered by organizationId
```

### Performance Best Practices

```typescript
// ✅ GOOD: Efficient pagination
async function getProjects(
  organizationId: string,
  page: number = 1,
  limit: number = 20
): Promise<{ projects: Project[]; total: number }> {
  const [projects, total] = await Promise.all([
    // Get page of results
    prisma.project.findMany({
      where: { organizationId },
      take: limit,
      skip: (page - 1) * limit,
      orderBy: { createdAt: "desc" },
    }),

    // Get total count (cached)
    prisma.project.count({
      where: { organizationId },
    }),
  ]);

  return { projects, total };
}

// ❌ BAD: Fetching all records
async function getProjects(organizationId: string): Promise<Project[]> {
  // Could return millions of records!
  return await prisma.project.findMany({
    where: { organizationId },
  });
}
```

### Query Performance Monitoring

```typescript
// lib/query-monitor.ts
import { Prisma } from "@prisma/client";

// Log slow queries
export async function monitorQuery<T>(
  queryName: string,
  query: () => Promise<T>
): Promise<T> {
  const startTime = Date.now();

  try {
    const result = await query();
    const duration = Date.now() - startTime;

    // Alert on slow queries (> 1 second)
    if (duration > 1000) {
      console.warn(`⚠️  Slow query detected: ${queryName} (${duration}ms)`);

      // Send to monitoring
      await sendMetric({
        name: "slow_query",
        value: duration,
        tags: {
          query: queryName,
        },
      });
    }

    return result;
  } catch (error) {
    console.error(`❌ Query failed: ${queryName}`, error);
    throw error;
  }
}

// Usage
const users = await monitorQuery("getUsers", () =>
  prisma.user.findMany({
    where: { organizationId },
  })
);
```

---

## Security & Access Control

### Tenant Isolation Validation

```typescript
// middleware/validate-tenant.ts

export async function validateTenantAccess(
  userId: string,
  organizationId: string
): Promise<boolean> {
  // Check if user belongs to organization
  const user = await prisma.user.findFirst({
    where: {
      id: userId,
      organizationId,
    },
  });

  return user !== null;
}

// API route usage
export async function GET(
  request: Request,
  { params }: { params: { organizationId: string } }
) {
  const session = await getServerSession();

  if (!session?.user) {
    return new Response("Unauthorized", { status: 401 });
  }

  // Validate user has access to this organization
  const hasAccess = await validateTenantAccess(
    session.user.id,
    params.organizationId
  );

  if (!hasAccess) {
    return new Response("Forbidden", { status: 403 });
  }

  // Safe to proceed
  const data = await getData(params.organizationId);
  return Response.json(data);
}
```

### Cross-Tenant Operations (Super Admin)

```typescript
// lib/super-admin.ts

export async function isSuperAdmin(userId: string): Promise<boolean> {
  const user = await prisma.user.findUnique({
    where: { id: userId },
  });

  return user?.role === "SUPER_ADMIN";
}

// API route for cross-tenant operations
export async function GET(request: Request) {
  const session = await getServerSession();

  if (!session?.user) {
    return new Response("Unauthorized", { status: 401 });
  }

  // Check super admin permission
  if (!(await isSuperAdmin(session.user.id))) {
    return new Response("Forbidden: Super admin only", { status: 403 });
  }

  // Super admin can query across tenants
  const allOrganizations = await prisma.organization.findMany({
    include: {
      _count: {
        select: {
          users: true,
          projects: true,
        },
      },
    },
  });

  return Response.json(allOrganizations);
}
```

---

## Testing Multi-Tenant Systems

### Test Data Factory

```typescript
// tests/factories/tenant-factory.ts

export async function createTestTenant(name: string = "Test Org") {
  const organization = await prisma.organization.create({
    data: {
      name,
      slug: `test-${Date.now()}`,
    },
  });

  return organization;
}

export async function createTestUser(
  organizationId: string,
  overrides: Partial<User> = {}
) {
  return await prisma.user.create({
    data: {
      email: `user-${Date.now()}@test.com`,
      name: "Test User",
      organizationId,
      ...overrides,
    },
  });
}
```

### Tenant Isolation Tests

```typescript
// tests/tenant-isolation.test.ts

describe("Tenant Isolation", () => {
  let org1: Organization;
  let org2: Organization;
  let user1: User;
  let user2: User;

  beforeEach(async () => {
    // Create two separate organizations
    org1 = await createTestTenant("Org 1");
    org2 = await createTestTenant("Org 2");

    // Create users in each organization
    user1 = await createTestUser(org1.id);
    user2 = await createTestUser(org2.id);
  });

  test("users can only see their own organization data", async () => {
    // Query as user from org1
    const users = await prisma.user.findMany({
      where: { organizationId: org1.id },
    });

    // Should only return user from org1
    expect(users).toHaveLength(1);
    expect(users[0].id).toBe(user1.id);

    // Should NOT include user from org2
    expect(users.find((u) => u.id === user2.id)).toBeUndefined();
  });

  test("cross-tenant access is prevented", async () => {
    // Try to access org2 project from org1 context
    const project = await prisma.project.create({
      data: {
        name: "Org 2 Project",
        organizationId: org2.id,
        createdById: user2.id,
      },
    });

    // Query as org1 user
    const result = await prisma.project.findFirst({
      where: {
        id: project.id,
        organizationId: org1.id, // Wrong organization!
      },
    });

    // Should not find the project
    expect(result).toBeNull();
  });

  test("data leakage prevented in joins", async () => {
    // Create projects in both orgs
    await prisma.project.create({
      data: {
        name: "Org 1 Project",
        organizationId: org1.id,
        createdById: user1.id,
      },
    });

    await prisma.project.create({
      data: {
        name: "Org 2 Project",
        organizationId: org2.id,
        createdById: user2.id,
      },
    });

    // Query with join
    const projects = await prisma.project.findMany({
      where: { organizationId: org1.id },
      include: {
        createdBy: true,
      },
    });

    // Should only get org1 project
    expect(projects).toHaveLength(1);
    expect(projects[0].organizationId).toBe(org1.id);
    expect(projects[0].createdBy.organizationId).toBe(org1.id);
  });
});
```

---

## Migration Strategies

### Adding Multi-Tenancy to Existing Tables

```typescript
// Migration: Add organizationId to existing table

// Step 1: Add nullable column
await prisma.$executeRaw`
  ALTER TABLE projects
  ADD COLUMN organization_id UUID;
`;

// Step 2: Create a default organization for orphaned data
const defaultOrg = await prisma.organization.create({
  data: {
    name: "Legacy Data",
    slug: "legacy-data",
  },
});

// Step 3: Backfill existing rows
await prisma.$executeRaw`
  UPDATE projects
  SET organization_id = ${defaultOrg.id}
  WHERE organization_id IS NULL;
`;

// Step 4: Make column required
await prisma.$executeRaw`
  ALTER TABLE projects
  ALTER COLUMN organization_id SET NOT NULL;
`;

// Step 5: Add foreign key
await prisma.$executeRaw`
  ALTER TABLE projects
  ADD CONSTRAINT fk_projects_organization
  FOREIGN KEY (organization_id)
  REFERENCES organizations(id)
  ON DELETE CASCADE;
`;

// Step 6: Add index
await prisma.$executeRaw`
  CREATE INDEX idx_projects_organization_id
  ON projects(organization_id);
`;
```

### Zero-Downtime Migration

```typescript
// Pattern: Dual-write during migration

// Phase 1: Add new column (nullable)
// Phase 2: Write to both old and new columns
// Phase 3: Backfill historical data
// Phase 4: Switch reads to new column
// Phase 5: Remove old column

// Example: Migrating from "tenant_id" to "organization_id"

// Phase 2: Dual write
async function createProject(data: ProjectData) {
  return await prisma.project.create({
    data: {
      ...data,
      tenant_id: data.organizationId, // Old column
      organization_id: data.organizationId, // New column
    },
  });
}

// Phase 3: Backfill (run as background job)
async function backfillOrganizationIds() {
  let processed = 0;
  const batchSize = 1000;

  while (true) {
    const batch = await prisma.$executeRaw`
      UPDATE projects
      SET organization_id = tenant_id
      WHERE organization_id IS NULL
      LIMIT ${batchSize}
    `;

    if (batch === 0) break;

    processed += batch;
    console.log(`✅ Backfilled ${processed} rows`);

    // Small delay between batches
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
}
```

---

## Performance Monitoring

### Tenant-Specific Metrics

```typescript
// lib/tenant-metrics.ts

interface TenantMetrics {
  organizationId: string;
  metrics: {
    activeUsers: number;
    apiRequests: number;
    databaseQueries: number;
    avgResponseTime: number;
    errorRate: number;
    storageUsed: number; // GB
  };
}

export async function collectTenantMetrics(
  organizationId: string
): Promise<TenantMetrics> {
  return {
    organizationId,
    metrics: {
      activeUsers: await getActiveUserCount(organizationId),
      apiRequests: await getAPIRequestCount(organizationId),
      databaseQueries: await getQueryCount(organizationId),
      avgResponseTime: await getAvgResponseTime(organizationId),
      errorRate: await getErrorRate(organizationId),
      storageUsed: await getStorageUsed(organizationId),
    },
  };
}

// Identify "noisy neighbors"
export async function identifyNoisyNeighbors(): Promise<string[]> {
  const allTenants = await prisma.organization.findMany();
  const metrics = await Promise.all(
    allTenants.map((org) => collectTenantMetrics(org.id))
  );

  // Find tenants using > 10x the median resources
  const medianRequests = median(metrics.map((m) => m.metrics.apiRequests));

  return metrics
    .filter((m) => m.metrics.apiRequests > medianRequests * 10)
    .map((m) => m.organizationId);
}
```

---

## Cost Optimization

### Per-Tenant Cost Tracking

```typescript
// Track costs per tenant
interface TenantCost {
  organizationId: string;
  costs: {
    compute: number; // Serverless function costs
    database: number; // Database query costs
    storage: number; // Storage costs
    network: number; // Data transfer costs
  };
  total: number;
}

export async function calculateTenantCost(
  organizationId: string,
  period: string = "month"
): Promise<TenantCost> {
  const metrics = await collectTenantMetrics(organizationId);

  // Estimate costs based on usage
  const compute = metrics.metrics.apiRequests * 0.0000002; // $0.20 per 1M requests
  const database = metrics.metrics.databaseQueries * 0.0000001;
  const storage = metrics.metrics.storageUsed * 0.023; // $0.023 per GB
  const network = metrics.metrics.storageUsed * 0.01; // Estimated egress

  return {
    organizationId,
    costs: {
      compute,
      database,
      storage,
      network,
    },
    total: compute + database + storage + network,
  };
}
```

---

## Related Resources

### Rules

- @016-platform-hierarchy.mdc - Platform hierarchy patterns
- @025-multi-tenancy.mdc - Multi-tenancy standards (comprehensive!)
- @017-platform-user-features.mdc - Platform user management
- @060-api-standards.mdc - Organization-scoped API patterns
- @376-database-test-isolation.mdc - Database testing with tenants

### Tools

- `.cursor/tools/inspect-model.sh` - Inspect Prisma models
- `.cursor/tools/check-schema-changes.sh` - Validate schema changes
- `.cursor/tools/analyze-performance.sh` - Performance analysis
- `.cursor/tools/check-infrastructure.sh` - Infrastructure health

### Guides

- `guides/Database-Operations-Complete-Guide.md` - Database management
- `guides/Monitoring-Complete-Guide.md` - Monitoring and alerting
- `guides/Cost-Optimization-Complete-Guide.md` - Cost management

---

## Quick Start Checklist

- [ ] Add `organizationId` to all tenant-scoped models
- [ ] Add indexes on `organizationId` for all tables
- [ ] Implement tenant context middleware
- [ ] Add tenant validation to all API routes
- [ ] Write tenant isolation tests
- [ ] Enable Row-Level Security (RLS) if using PostgreSQL
- [ ] Monitor per-tenant resource usage
- [ ] Set up alerts for "noisy neighbors"
- [ ] Document tenant onboarding process
- [ ] Plan for tenant data export/deletion (GDPR)

---

**Time Investment**: 2-3 hours to understand, ongoing practice  
**ROI**: Secure multi-tenant architecture, prevents data leakage, scales efficiently

---

**Remember**: In multi-tenant systems, **data isolation is not optional** - it's a **security requirement**. Always validate tenant context, test isolation thoroughly, and monitor for leaks. 🔒
