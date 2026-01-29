# VibeCoder ORM Usage Guide

## Overview

This guide documents best practices for using Prisma ORM in VibeCoder, implementing the repository pattern, and ensuring consistent data access patterns.

## Repository Pattern Implementation

### Core Principles

1. **Separation of Concerns**

   - Repositories handle all database operations
   - Business logic remains separate from data access
   - Controllers/services use repositories via dependency injection

2. **Standardized Interface**
   - Each entity has a dedicated repository
   - Consistent method naming conventions
   - Standard error handling across repositories

### Repository Structure

A typical repository class should:

1. Encapsulate all database operations for a single entity
2. Implement tenant isolation in all queries
3. Handle errors consistently
4. Return strongly typed data

```typescript
// src/repositories/UserRepository.ts
import { PrismaClient, User, Prisma } from "@prisma/client";
import { DatabaseError } from "../errors/DatabaseError";

export class UserRepository {
  constructor(private prisma: PrismaClient) {}

  async findById(id: string, organizationId: string): Promise<User | null> {
    try {
      return await this.prisma.user.findFirst({
        where: {
          id,
          organizationId, // Multi-tenancy enforcement
        },
      });
    } catch (error) {
      throw new DatabaseError("Failed to find user by ID", error);
    }
  }

  async findByEmail(
    email: string,
    organizationId: string
  ): Promise<User | null> {
    try {
      return await this.prisma.user.findFirst({
        where: {
          email,
          organizationId,
        },
      });
    } catch (error) {
      throw new DatabaseError("Failed to find user by email", error);
    }
  }

  async findAll(
    organizationId: string,
    options?: {
      skip?: number;
      take?: number;
      orderBy?: Prisma.UserOrderByWithRelationInput;
    }
  ): Promise<User[]> {
    try {
      return await this.prisma.user.findMany({
        where: { organizationId },
        skip: options?.skip,
        take: options?.take,
        orderBy: options?.orderBy,
      });
    } catch (error) {
      throw new DatabaseError("Failed to find users", error);
    }
  }

  async create(data: Prisma.UserCreateInput): Promise<User> {
    try {
      return await this.prisma.user.create({ data });
    } catch (error) {
      throw new DatabaseError("Failed to create user", error);
    }
  }

  async update(
    id: string,
    organizationId: string,
    data: Prisma.UserUpdateInput
  ): Promise<User> {
    try {
      return await this.prisma.user.update({
        where: {
          id,
          organizationId, // Multi-tenancy enforcement
        },
        data,
      });
    } catch (error) {
      throw new DatabaseError("Failed to update user", error);
    }
  }

  async delete(id: string, organizationId: string): Promise<User> {
    try {
      return await this.prisma.user.delete({
        where: {
          id,
          organizationId, // Multi-tenancy enforcement
        },
      });
    } catch (error) {
      throw new DatabaseError("Failed to delete user", error);
    }
  }

  async count(organizationId: string): Promise<number> {
    try {
      return await this.prisma.user.count({
        where: { organizationId },
      });
    } catch (error) {
      throw new DatabaseError("Failed to count users", error);
    }
  }
}
```

### Repository Factory

For dependency injection and easier testing, consider using a repository factory:

```typescript
// src/repositories/index.ts
import { PrismaClient } from "@prisma/client";
import { UserRepository } from "./UserRepository";
import { ProjectRepository } from "./ProjectRepository";
import { TaskRepository } from "./TaskRepository";

// Singleton Prisma instance
const prisma = new PrismaClient();

// Repository factory
export const repositories = {
  user: new UserRepository(prisma),
  project: new ProjectRepository(prisma),
  task: new TaskRepository(prisma),
};

// For testing, we can create repositories with a test client
export function createTestRepositories(testPrisma: PrismaClient) {
  return {
    user: new UserRepository(testPrisma),
    project: new ProjectRepository(testPrisma),
    task: new TaskRepository(testPrisma),
  };
}
```

## Transaction Management

### Transaction Patterns

1. **Explicit Transactions**

   ```typescript
   // Using explicit transaction with Prisma
   async function createUserWithProfile(userData, profileData) {
     const result = await this.prisma.$transaction(async (tx) => {
       const user = await tx.user.create({
         data: userData,
       });

       await tx.userProfile.create({
         data: {
           userId: user.id,
           organizationId: user.organizationId,
           ...profileData,
         },
       });

       return user;
     });

     return result;
   }
   ```

2. **Transaction with Retry**

   ```typescript
   // Using transaction with retry for resilience
   import { withRetry } from "../utils/retry";

   async function createUserWithSettings(userData, settingsData) {
     return await withRetry(
       async () => {
         return this.prisma.$transaction(async (tx) => {
           const user = await tx.user.create({
             data: userData,
           });

           await tx.userSettings.create({
             data: {
               userId: user.id,
               organizationId: user.organizationId,
               ...settingsData,
             },
           });

           return user;
         });
       },
       { maxRetries: 3, delay: 100 }
     );
   }
   ```

3. **Transaction Isolation Levels**

   For operations that need specific isolation:

   ```typescript
   // Using a specific isolation level
   async function transferCredits(fromUserId, toUserId, amount) {
     // Use serializable for financial transactions
     await this.prisma
       .$executeRaw`SET TRANSACTION ISOLATION LEVEL SERIALIZABLE`;

     return await this.prisma.$transaction(async (tx) => {
       // Deduct credits from source
       const fromUser = await tx.user.update({
         where: { id: fromUserId },
         data: {
           credits: {
             decrement: amount,
           },
         },
       });

       if (fromUser.credits < 0) {
         throw new Error("Insufficient credits");
       }

       // Add credits to destination
       const toUser = await tx.user.update({
         where: { id: toUserId },
         data: {
           credits: {
             increment: amount,
           },
         },
       });

       // Create transaction record
       await tx.creditTransaction.create({
         data: {
           fromUserId,
           toUserId,
           amount,
           status: "completed",
         },
       });

       return { fromUser, toUser };
     });
   }
   ```

## Error Handling

### Standardized Error Approach

1. **Custom Error Classes**

   ```typescript
   // errors/DatabaseError.ts
   export class DatabaseError extends Error {
     constructor(
       message: string,
       public originalError?: unknown,
       public code?: string
     ) {
       super(message);
       this.name = "DatabaseError";
     }
   }

   export class NotFoundError extends DatabaseError {
     constructor(entity: string, id: string) {
       super(`${entity} with ID ${id} not found`);
       this.name = "NotFoundError";
       this.code = "NOT_FOUND";
     }
   }

   export class DuplicateError extends DatabaseError {
     constructor(entity: string, field: string, value: string) {
       super(`${entity} with ${field} ${value} already exists`);
       this.name = "DuplicateError";
       this.code = "DUPLICATE";
     }
   }
   ```

2. **Error Categorization**

   ```typescript
   // utils/errorHandlers.ts
   import { Prisma } from "@prisma/client";
   import {
     DatabaseError,
     NotFoundError,
     DuplicateError,
   } from "../errors/DatabaseError";

   export function handleDatabaseError(
     error: unknown,
     entity: string
   ): DatabaseError {
     // Handle Prisma-specific errors
     if (error instanceof Prisma.PrismaClientKnownRequestError) {
       // Unique constraint violation
       if (error.code === "P2002") {
         const field =
           (error.meta?.target as string[])?.join(", ") || "unknown";
         return new DuplicateError(entity, field, "value");
       }

       // Record not found
       if (error.code === "P2025") {
         return new NotFoundError(entity, "requested");
       }

       // Foreign key constraint failed
       if (error.code === "P2003") {
         return new DatabaseError(
           `Referenced ${error.meta?.field_name} does not exist`,
           error,
           "FOREIGN_KEY_CONSTRAINT"
         );
       }
     }

     // Handle generic database errors
     if (error instanceof Prisma.PrismaClientRustPanicError) {
       return new DatabaseError("Database server panic", error, "SERVER_PANIC");
     }

     if (error instanceof Prisma.PrismaClientInitializationError) {
       return new DatabaseError(
         "Failed to initialize database connection",
         error,
         "INITIALIZATION_FAILED"
       );
     }

     // Default case
     return new DatabaseError(
       `Unexpected database error for ${entity}`,
       error,
       "UNKNOWN"
     );
   }
   ```

3. **Usage in Repositories**

   ```typescript
   // Integrating error handling in repositories
   async findById(id: string, organizationId: string): Promise<User | null> {
     try {
       const user = await this.prisma.user.findFirst({
         where: {
           id,
           organizationId
         }
       });

       if (!user) {
         throw new NotFoundError('User', id);
       }

       return user;
     } catch (error) {
       if (error instanceof NotFoundError) {
         throw error; // Re-throw already handled errors
       }
       throw handleDatabaseError(error, 'User');
     }
   }
   ```

## Performance Considerations

### Prisma-Specific Optimizations

1. **Select Optimization**

   Only request fields you need:

   ```typescript
   // Only select required fields
   const users = await prisma.user.findMany({
     where: { organizationId },
     select: {
       id: true,
       name: true,
       email: true,
       // Don't select large fields like settings, avatars, etc.
     },
   });
   ```

2. **Eager Loading Optimization**

   Be specific with relationships:

   ```typescript
   // Bad: Loading everything
   const projects = await prisma.project.findMany({
     include: {
       tasks: true,
       owner: true,
       organization: true,
       comments: true,
     },
   });

   // Good: Only include what you need with nested selection
   const projects = await prisma.project.findMany({
     include: {
       tasks: {
         select: {
           id: true,
           title: true,
           status: true,
         },
         where: {
           status: {
             in: ["active", "in_progress"],
           },
         },
       },
       owner: {
         select: {
           id: true,
           name: true,
         },
       },
     },
   });
   ```

3. **Query Raw When Needed**

   For complex queries that the ORM can't optimize:

   ```typescript
   // Complex query using raw SQL
   const results = await prisma.$queryRaw`
     SELECT 
       p.id, p.name, p.status,
       COUNT(DISTINCT t.id) as task_count,
       SUM(CASE WHEN t.status = 'completed' THEN 1 ELSE 0 END) as completed_tasks
     FROM projects p
     LEFT JOIN tasks t ON p.id = t.project_id
     WHERE p.organization_id = ${organizationId}
     GROUP BY p.id, p.name, p.status
     HAVING COUNT(DISTINCT t.id) > 0
     ORDER BY completed_tasks / COUNT(DISTINCT t.id) DESC
     LIMIT 10
   `;
   ```

4. **Batching Operations**

   Use createMany/updateMany for bulk operations:

   ```typescript
   // Efficient batch creation
   await prisma.task.createMany({
     data: tasksData,
     skipDuplicates: true,
   });

   // Batch update
   await prisma.task.updateMany({
     where: {
       projectId,
       status: "pending",
     },
     data: {
       status: "active",
     },
   });
   ```

5. **Connection Pooling**

   Configure proper connection pool size:

   ```typescript
   // lib/prisma.ts
   import { PrismaClient } from "@prisma/client";

   const prismaClientSingleton = () => {
     return new PrismaClient({
       datasources: {
         db: {
           url: process.env.DATABASE_URL,
         },
       },
       // Configure connection pool
       log: ["query", "info", "warn", "error"],
     });
   };

   declare global {
     var prisma: undefined | ReturnType<typeof prismaClientSingleton>;
   }

   export const prisma = globalThis.prisma ?? prismaClientSingleton();

   if (process.env.NODE_ENV !== "production") {
     globalThis.prisma = prisma;
   }
   ```

## Implementing Soft Deletes

### Using Middleware

Prisma doesn't have built-in soft delete, but you can implement it with middleware:

```typescript
// lib/prisma.ts
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

// Middleware for handling soft deletes
prisma.$use(async (params, next) => {
  // Check if operation is delete
  if (params.action === "delete") {
    // Change action to update
    params.action = "update";
    params.args.data = { deletedAt: new Date() };
  }

  // Check if operation is deleteMany
  if (params.action === "deleteMany") {
    // Change action to updateMany
    params.action = "updateMany";
    if (params.args.data) {
      params.args.data.deletedAt = new Date();
    } else {
      params.args.data = { deletedAt: new Date() };
    }
  }

  // Filter out soft-deleted records on find operations
  if (params.action === "findUnique" || params.action === "findFirst") {
    // Change to findFirst - you cannot filter on non-existent
    // data in findUnique
    params.action = "findFirst";
    // Add 'deleted' filter
    if (!params.args.where.deletedAt) {
      params.args.where.deletedAt = null;
    }
  }

  if (params.action === "findMany") {
    // Find many queries
    if (!params.args) params.args = {};
    if (!params.args.where) params.args.where = {};

    if (params.args.where.deletedAt === undefined) {
      // Exclude deleted records if deletedAt is not explicitly provided
      params.args.where.deletedAt = null;
    }
  }

  return next(params);
});

export { prisma };
```

## Multi-Tenant Data Access

### Tenant Context Enforcement

1. **Using Prisma Middleware**

   ```typescript
   // lib/prisma.ts
   import { PrismaClient } from "@prisma/client";

   // Store tenant context in async local storage
   import { AsyncLocalStorage } from "async_hooks";

   interface TenantContext {
     organizationId: string;
   }

   export const tenantContext = new AsyncLocalStorage<TenantContext>();

   const prisma = new PrismaClient();

   // Middleware for enforcing tenant isolation
   prisma.$use(async (params, next) => {
     // Get current tenant context
     const context = tenantContext.getStore();
     const organizationId = context?.organizationId;

     // Skip if no tenant context or it's a special system operation
     if (!organizationId || params.args?.ignoreOrganizationId) {
       return next(params);
     }

     // Models that have organization_id field
     const tenantModels = [
       "User",
       "Project",
       "Task",
       "Comment",
       "UserSettings",
     ];

     // Add tenant filter to queries
     if (tenantModels.includes(params.model)) {
       if (
         ["findMany", "findFirst", "findUnique", "count", "aggregate"].includes(
           params.action
         )
       ) {
         if (!params.args) params.args = {};
         if (!params.args.where) params.args.where = {};

         // Add organization_id to where clause
         params.args.where.organizationId = organizationId;
       }

       // Ensure organization_id in create operations
       if (params.action === "create") {
         if (!params.args) params.args = {};
         if (!params.args.data) params.args.data = {};

         params.args.data.organizationId = organizationId;
       }

       // Ensure organization_id in update operations
       if (["update", "updateMany", "upsert"].includes(params.action)) {
         if (!params.args) params.args = {};
         if (!params.args.where) params.args.where = {};

         // Add organization_id to where clause
         params.args.where.organizationId = organizationId;

         // For upsert, also add to create data
         if (params.action === "upsert") {
           if (!params.args.create) params.args.create = {};
           params.args.create.organizationId = organizationId;
         }
       }

       // Ensure organization_id in delete operations
       if (["delete", "deleteMany"].includes(params.action)) {
         if (!params.args) params.args = {};
         if (!params.args.where) params.args.where = {};

         // Add organization_id to where clause
         params.args.where.organizationId = organizationId;
       }
     }

     return next(params);
   });

   export { prisma };
   ```

2. **Using Middleware in API Routes**

   ```typescript
   // middleware/withTenant.ts
   import { NextApiRequest, NextApiResponse } from "next";
   import { tenantContext } from "../lib/prisma";
   import { getSession } from "@auth0/nextjs-auth0";

   export function withTenant(
     handler: (req: NextApiRequest, res: NextApiResponse) => Promise<void>
   ) {
     return async (req: NextApiRequest, res: NextApiResponse) => {
       const session = await getSession(req, res);
       if (!session?.user) {
         return res.status(401).json({ error: "Unauthorized" });
       }

       // Get organization ID from request header or query parameter
       const organizationId =
         req.headers["x-organization-id"] || req.query.organizationId;

       if (!organizationId || Array.isArray(organizationId)) {
         return res.status(400).json({ error: "Invalid organization ID" });
       }

       // Verify user has access to this organization
       // This would be implemented elsewhere, but for simplicity:
       const hasAccess = await checkUserOrganizationAccess(
         session.user.sub,
         organizationId
       );

       if (!hasAccess) {
         return res.status(403).json({ error: "Forbidden" });
       }

       // Set tenant context and run handler
       return tenantContext.run({ organizationId }, async () => {
         return handler(req, res);
       });
     };
   }

   async function checkUserOrganizationAccess(
     userId: string,
     organizationId: string
   ): Promise<boolean> {
     // Implementation of access check
     return true; // Simplified for example
   }
   ```

## Database Connection Management

### Connection Pooling

Configure the connection pool size based on your environment:

```typescript
// lib/prisma.ts
import { PrismaClient } from "@prisma/client";

// Parse connection URL to add connection pool config
function getDatabaseUrl() {
  const url = process.env.DATABASE_URL;
  if (!url) {
    throw new Error("DATABASE_URL environment variable is not set");
  }

  // Add connection pool configuration if not present
  if (!url.includes("connection_limit")) {
    const separator = url.includes("?") ? "&" : "?";

    // Production settings - adjust based on your application's needs
    if (process.env.NODE_ENV === "production") {
      return `${url}${separator}connection_limit=20&pool_timeout=30`;
    }

    // Development settings
    return `${url}${separator}connection_limit=5&pool_timeout=10`;
  }

  return url;
}

const prisma = new PrismaClient({
  datasources: {
    db: {
      url: getDatabaseUrl(),
    },
  },
  log:
    process.env.NODE_ENV === "development"
      ? ["query", "info", "warn", "error"]
      : ["error"],
});

export { prisma };
```

### Connection Health Checking

Implement a health check for your database connection:

```typescript
// utils/db-health.ts
import { prisma } from "../lib/prisma";

export async function checkDatabaseHealth() {
  try {
    // Simple query to test connectivity
    await prisma.$queryRaw`SELECT 1`;
    return { status: "healthy" };
  } catch (error) {
    console.error("Database health check failed:", error);
    return {
      status: "unhealthy",
      error: error instanceof Error ? error.message : String(error),
    };
  }
}

// Health API endpoint
// pages/api/health.ts
import { NextApiRequest, NextApiResponse } from "next";
import { checkDatabaseHealth } from "../../utils/db-health";

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const health = await checkDatabaseHealth();

  if (health.status === "healthy") {
    res.status(200).json({ database: health });
  } else {
    res.status(503).json({ database: health });
  }
}
```

## Testing with Prisma

### Setting Up Test Environment

1. **Create a Test Database Configuration**

   ```
   # .env.test
   DATABASE_URL=postgresql://postgres:postgres@localhost:5432/vibecoder_test
   ```

2. **Initialize Test Client**

   ```typescript
   // tests/helpers/db.ts
   import { PrismaClient } from "@prisma/client";
   import { execSync } from "child_process";
   import { join } from "path";

   // Test client setup
   const prisma = new PrismaClient({
     datasources: {
       db: {
         url: process.env.DATABASE_URL,
       },
     },
   });

   // Setup function to run before tests
   export async function setupTestDatabase() {
     // Clean database
     await prisma.$executeRaw`
       TRUNCATE TABLE "User" CASCADE;
       TRUNCATE TABLE "Project" CASCADE;
       TRUNCATE TABLE "Task" CASCADE;
     `;

     // Reset sequences if using them
     await prisma.$executeRaw`
       ALTER SEQUENCE "User_id_seq" RESTART WITH 1;
       ALTER SEQUENCE "Project_id_seq" RESTART WITH 1;
       ALTER SEQUENCE "Task_id_seq" RESTART WITH 1;
     `;

     console.log("Test database reset complete");
   }

   // Teardown function to run after tests
   export async function teardownTestDatabase() {
     await prisma.$disconnect();
   }

   export { prisma as testPrisma };
   ```

3. **Integration with Jest**

   ```typescript
   // jest.setup.js
   import { setupTestDatabase, teardownTestDatabase } from "./tests/helpers/db";

   // Global setup/teardown
   beforeAll(async () => {
     await setupTestDatabase();
   });

   afterAll(async () => {
     await teardownTestDatabase();
   });
   ```

### Testing Repositories

```typescript
// tests/repositories/UserRepository.test.ts
import { testPrisma } from "../helpers/db";
import { UserRepository } from "../../src/repositories/UserRepository";
import { tenantContext } from "../../src/lib/prisma";

describe("UserRepository", () => {
  let userRepository: UserRepository;
  const organizationId = "org-test-123";

  beforeAll(() => {
    userRepository = new UserRepository(testPrisma);
  });

  beforeEach(async () => {
    // Clean up before each test
    await testPrisma.user.deleteMany({
      where: { organizationId },
    });
  });

  test("should create a user", async () => {
    // Run with tenant context
    const result = await tenantContext.run({ organizationId }, async () => {
      return userRepository.create({
        name: "Test User",
        email: "test@example.com",
        organizationId,
      });
    });

    expect(result).toHaveProperty("id");
    expect(result.name).toBe("Test User");
    expect(result.email).toBe("test@example.com");
    expect(result.organizationId).toBe(organizationId);
  });

  test("should find a user by email", async () => {
    // Create test user
    await testPrisma.user.create({
      data: {
        name: "Find Me",
        email: "find@example.com",
        organizationId,
      },
    });

    // Find the user
    const user = await userRepository.findByEmail(
      "find@example.com",
      organizationId
    );

    expect(user).not.toBeNull();
    expect(user?.name).toBe("Find Me");
  });

  test("should enforce tenant isolation", async () => {
    // Create users in different organizations
    const org1 = "org-1";
    const org2 = "org-2";

    await testPrisma.user.createMany({
      data: [
        {
          name: "Org 1 User",
          email: "user@org1.com",
          organizationId: org1,
        },
        {
          name: "Org 2 User",
          email: "user@org2.com",
          organizationId: org2,
        },
      ],
    });

    // Should only find org1 users when querying with org1
    const org1Users = await userRepository.findAll(org1);
    expect(org1Users.length).toBe(1);
    expect(org1Users[0].email).toBe("user@org1.com");

    // Should only find org2 users when querying with org2
    const org2Users = await userRepository.findAll(org2);
    expect(org2Users.length).toBe(1);
    expect(org2Users[0].email).toBe("user@org2.com");
  });

  test("should handle errors properly", async () => {
    // Force a duplicate error
    await testPrisma.user.create({
      data: {
        name: "Unique User",
        email: "unique@example.com",
        organizationId,
      },
    });

    // Try to create another user with the same email
    await expect(
      userRepository.create({
        name: "Another User",
        email: "unique@example.com", // Same email
        organizationId,
      })
    ).rejects.toThrow(); // Should throw an error
  });
});
```

## Conclusion

Proper ORM usage through the repository pattern ensures:

1. **Consistent data access** across the application
2. **Proper tenant isolation** for multi-tenant data
3. **Robust error handling** for database operations
4. **Optimized queries** for performance
5. **Testable database code** for reliability

Follow these patterns consistently to maintain a clean, performant, and secure database layer in your application.
